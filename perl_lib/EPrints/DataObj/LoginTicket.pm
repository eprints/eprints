######################################################################
#
# EPrints::DataObj::LoginTicket
#
######################################################################
#
#
######################################################################

=for Pod2Wiki

=head1 NAME

B<EPrints::DataObj::LoginTicket> - user system loginticket

=head1 DESCRIPTION

Login tickets are the database entries for the user's session cookies.

=head2 Configuration Settings

=over 4

=item user_cookie_timeout = undef

Set an expiry on the session cookies. This will cause the user's browser to delete the cookie after the given time. The time is specified according to L<CGI>'s cookie constructor. This allows settings like C<+1h> and C<+7d>.

=item user_inactivity_timeout = 86400 * 7

How long to wait in seconds before logging the user out after their last activity.

=item user_session_timeout = undef

How long in seconds the user can stay logged in before they must re-log in. Defaults to never - if you do specify this setting you probably want to reduce user_inactivity_timeout to <1 hour.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::LoginTicket;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use Digest::MD5;

use strict;

our $SESSION_KEY = "eprints_session";
our $SECURE_SESSION_KEY = "secure_eprints_session";
our $SESSION_TIMEOUT = 86400 * 7; # 7 days

=item $thing = EPrints::DataObj::Access->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"code", type=>"id", required=>1 },

		{ name=>"securecode", type=>"id", required=>1 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>1 },

		{ name=>"ip", type=>"id", required=>1 },

		{ name=>"time", type=>"bigint", required=>1 },

		{ name=>"expires", type=>"bigint", required=>1 },
	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::LoginTicket->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "loginticket";
}

sub get_defaults
{
	my( $class, $repo, $data, $dataset ) = @_;

	$class->SUPER::get_defaults( $repo, $data, $dataset );

	$data->{code} = &_code();
	$data->{securecode} = &_code();
	if( !$repo->config( "ignore_login_ip" ) )
	{
		$data->{ip} = $repo->remote_ip;
	}

	$data->{time} = time();
	my $timeout = $repo->config( "user_inactivity_timeout" );
	$timeout = $SESSION_TIMEOUT if !defined $timeout;
	$data->{expires} = time() + $timeout;

	return $data;
}

sub _code
{
	my $ctx = Digest::MD5->new;
	srand;
	$ctx->add( $$, time, rand() );
	return $ctx->hexdigest;
}

sub new_from_request
{
	my( $class, $repo, $r ) = @_;

	my $dataset = $repo->dataset( $class->get_dataset_id );

	my $ip = $r->connection->remote_ip;

	my $ticket;

	if( $repo->get_secure )
	{
		my $securecode = EPrints::Apache::AnApache::cookie(
			$r,
			$class->secure_session_key($repo)
		);
		if (EPrints::Utils::is_set($securecode)) {
			$ticket = $dataset->search(filters => [
				{ meta_fields => [qw( securecode )], value => $securecode },
			])->item( 0 );
		}
	}
	else
	{
		my $code = EPrints::Apache::AnApache::cookie(
			$r,
			$class->session_key($repo)
		);
		if (EPrints::Utils::is_set($code)) {
			$ticket = $dataset->search(filters => [
				{ meta_fields => [qw( code )], value => $code },
			])->item( 0 );
		}
	}

	my $timeout = $repo->config( "user_session_timeout" );

	if( 
		defined $ticket &&
		# maximum time in seconds someone can stay logged in
		(!defined $timeout || $ticket->value( "time" ) + $timeout >= time()) &&
		# maximum time in seconds between actions
		(!$ticket->is_set( "expires" ) || $ticket->value( "expires" ) >= time()) &&
		# same-origin IP
		(!$ticket->is_set( "ip" ) || $ticket->value( "ip" ) eq $ip)
	  )
	{
		return $ticket;
	}

	return undef;
}

sub expire_all
{
	my( $class, $repo ) = @_;

	my $dataset = $repo->dataset( $class->get_dataset_id );

	$dataset->search(filters => [
		{ meta_fields => [qw( expires )], value => "..".time() },
	])->map(sub {
		$_[2]->remove;
	});
}

=item EPrints::DataObj::LoginTicket->session_key($repo)

=item EPrints::DataObj::LoginTicket->secure_session_key($repo)

Get the key to use for the session cookies.

In the following circumstance:

	example.org
	custom.example.org

Where both hosts use the same cookie key the cookie from example.org will collide with the cookie from custom.example.org. To avoid this the full hostname is embedded in the cookie key.

=cut

sub session_key
{
	my ($class, $repo) = @_;

	return join ':', $SESSION_KEY, $repo->config('host');
}

sub secure_session_key
{
	my ($class, $repo) = @_;

	return join ':', $SECURE_SESSION_KEY, $repo->config('securehost');
}

######################################################################

=head2 Object Methods

=over 4

=cut

######################################################################

=begin InternalDoc

=item $cookie = $ticket->generate_cookie( %opts )

Returns the HTTP (non-secure) session cookie.

=end InternalDoc

=cut

sub generate_cookie
{
	my( $self, %opts ) = @_;

	my $repo = $self->{session};

	return $repo->query->cookie(
		-name    => $self->session_key($repo),
		-path    => ($repo->config( "http_root" ) || '/'),
		-value   => $self->value( "code" ),
		-domain  => $repo->config( "host" ),
		-expires => $repo->config( "user_cookie_timeout" ),
		%opts,
	);			
}

=begin InternalDoc

=item $cookie = $ticket->generate_secure_cookie( %opts )

Returns the HTTPS session cookie.

=end InternalDoc

=cut

sub generate_secure_cookie
{
	my( $self, %opts ) = @_;

	my $repo = $self->{session};

	return $repo->query->cookie(
		-name    => $self->secure_session_key($repo),
		-path    => ($repo->config( "https_root" ) || '/'),
		-value   => $self->value( "securecode" ),
		-domain  => $repo->config( "securehost" ),
		-secure  => 1,
		-expires => $repo->config( "user_cookie_timeout" ),
		%opts,
	);			
}

=item $ticket->set_cookies()

Set the session cookies for this login ticket.

=cut

sub set_cookies
{
	my( $self ) = @_;

	my $repo = $self->{session};

	$repo->get_request->err_headers_out->add(
		'Set-Cookie' => $self->generate_cookie
	);
	if( $repo->config( "securehost" ) )
	{
		$repo->get_request->err_headers_out->add(
			'Set-Cookie' => $self->generate_secure_cookie
		);
	}
}

=item $ticket->update()

Update the login ticket by increasing the expiry time.

The expiry time is increased C<user_inactivity_timeout> or 7 days.

=cut

sub update
{
	my( $self ) = @_;

	my $timeout = $self->{session}->config( "user_inactivity_timeout" );
	$timeout = $SESSION_TIMEOUT if !defined $timeout;

	$self->set_value( "expires", time() + $timeout );
	$self->commit;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut


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

