=head1 NAME

EPrints::DataObj::OpenID

=cut

package EPrints::DataObj::OpenID;

use Digest::SHA;
use MIME::Base64;

@ISA = qw( EPrints::DataObj );

use strict;

sub get_dataset_id { "openid" }

sub get_system_field_info
{
	my( $self ) = @_;

	return (
		{ name => "openidid", type => "counter", sql_counter => "openidid" },
		{ name => "op_endpoint", type => "id", sql_index => 1 },
		{ name => "expires", type => "int", sql_index => 1 },
		{ name => "assoc_handle", type => "id", sql_index => 1 },
		{ name => "mac_key", type => "id", sql_index => 0 },
		{ name => "response_nonce", type => "id", sql_index => 1 },
	);
}

sub new_by_op_endpoint
{
	my( $class, $repo, $op_endpoint, $assoc_handle ) = @_;

	return $repo->dataset( $class->get_dataset_id )->search(filters => [
		{ meta_fields => [qw( op_endpoint )], value => $op_endpoint },
		{ meta_fields => [qw( response_nonce )], value => "", match => "EX" },
	])->item( 0 );
}

sub new_by_assoc_handle
{
	my( $class, $repo, $op_endpoint, $assoc_handle ) = @_;

	return $repo->dataset( $class->get_dataset_id )->search(filters => [
		{ meta_fields => [qw( op_endpoint )], value => $op_endpoint },
		{ meta_fields => [qw( assoc_handle )], value => $assoc_handle }
	])->item( 0 );
}

sub new_by_response_nonce
{
	my( $class, $repo, $op_endpoint, $response_nonce ) = @_;

	return $repo->dataset( $class->get_dataset_id )->search(filters => [
		{ meta_fields => [qw( op_endpoint )], value => $op_endpoint },
		{ meta_fields => [qw( response_nonce )], value => $response_nonce }
	])->item( 0 );
}

sub create_by_op_endpoint
{
	my( $class, $repo, $op_endpoint ) = @_;

	my $ua = LWP::UserAgent->new;

	my $uri = URI->new( $op_endpoint );
	$uri->query_form(
		$uri->query_form,
		'openid.ns' => 'http://specs.openid.net/auth/2.0',
		'openid.mode' => 'associate',
		'openid.assoc_type' => 'HMAC-SHA256',
		'openid.session_type' => 'no-encryption',
		);
	my $r = $ua->get( $uri );
	my %kv = EPrints::DataObj::OpenID->parse_key_value( $r->content );

	if( !$r->is_success || $kv{error} )
	{
		die "$kv{error_code}: $kv{error}";
	}

	if( !$kv{expires_in} || $kv{expires_in} > 86400 )
	{
		$kv{expires_in} = 86400;
	}

	return $class->create_from_data(
		$repo,
		{
			op_endpoint => $op_endpoint,
			expires => time() + $kv{expires_in},
			assoc_handle => $kv{assoc_handle},
			mac_key => $kv{mac_key},
		});
}

=item EPrints::DataObj::OpenID->cleanup()

=cut

sub cleanup
{
	my( $class, $repo ) = @_;

	my $now = time();

	$repo->dataset( $class->get_dataset_id )->search(
		filters => [{ meta_fields => [qw( expires )], value => "-$now" }]
	)->map(sub { $_[2]->remove });
}

=item @kvs = EPrints::DataObj::OpenID->parse_key_value( $content )

=cut

sub parse_key_value
{
	my( $class, $cnt ) = @_;

	my @kvs;
	for(split /\r?\n/, $cnt)
	{
		push @kvs, split /\s*:\s*/, $_, 2;
	}
	
	return @kvs;
}

=item %attr = EPrints::DataObj::OpenID->retrieve_attributes( REPOSITORY )

Retrieve all attributes defined using OpenID Attribute Extensions.

=cut

sub retrieve_attributes
{
	my( $class, $repo ) = @_;

	my $prefix = '';

	for($repo->param())
	{
		if( $repo->param( $_ ) eq 'http://openid.net/srv/ax/1.0' )
		{
			/^openid\.ns\.([^\.]+)$/;
			$prefix = $1;
			last;
		}
	}

	my @kv;
	for($repo->param())
	{
		next unless /^openid\.$prefix\.(.+)$/;
		push @kv, $1 => $repo->param( $_ );
	}

	return @kv;
}

=item $ok = $openid->verify( [ @extra_keys ] )

=cut

sub verify
{
	my( $self, @extra_keys ) = @_;

	my $repo = $self->{session};
	my $mac_key = $self->value( "mac_key" );

	my $sig = $repo->param( "openid.sig" ) || '';
	my $signed = $repo->param( "openid.signed" ) || '';
	my @signed = split /,/, $signed;
	my %signed = map { $_ => 1 } @signed;

	return if !@signed;

	# see http://idmanagement.gov/documents/ICAM_OpenID20Profile.pdf
	foreach my $key (qw( op_endpoint return_to response_nonce assoc_handle claimed_id identity ), @extra_keys)
	{
		return if !$signed{$key};
	}

	my $data = '';
	foreach my $key (@signed)
	{
		$data .= join(':', $key, scalar($repo->param( 'openid.'.$key )))."\n";
	}

	$mac_key = MIME::Base64::decode_base64( $mac_key );
	my $digest = MIME::Base64::encode_base64( Digest::SHA::hmac_sha256( $data, $mac_key ), '' );

	return $digest eq $sig;
}

sub auth_uri
{
	my( $self, %q ) = @_;

	$q{'openid.ns'} = 'http://specs.openid.net/auth/2.0';
	$q{'openid.mode'} ||= 'checkid_setup';
	$q{'openid.assoc_handle'} ||= $self->value( 'assoc_handle' );
	$q{'openid.claimed_id'} ||= 'http://specs.openid.net/auth/2.0/identifier_select';
	$q{'openid.identity'} ||= 'http://specs.openid.net/auth/2.0/identifier_select';

	my @q = map { $_ => $q{$_} } sort keys %q;

	my $uri = URI->new( $self->value( "op_endpoint" ) );
	$uri->query_form(
		$uri->query_form,
		@q
		);

	return $uri;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

