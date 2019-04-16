######################################################################
#
# EPrints::MetaField::Recaptcha;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Recaptcha> - a Captcha

=head1 DESCRIPTION

Please refer to the notes in [EPRINTS_ROOT]/archives/[ARCHIVEID]/cfg/cfg.d/recaptcha.pl.

If this files does not exist, copy [EPRINTS_ROOT]/lib/defaultcfg/cfg.d/recaptcha.pl.example
to the path above and edit it.

This field uses the Google "reCAPTCHA" service (https://www.google.com/recaptcha/intro/) and
renders a Captcha (a test that humans can easily pass, but robots shouldn't be able to).

Note: 
This MetaField was updated in October 2017 to reCAPTCHA v2.
The previous version of reCAPTCHA will cease to work in March 2018.

Kudos to Matthew Kerwin (https://github.com/phluid61) for most of the work on the new version.

=over 4

=cut

package EPrints::MetaField::Recaptcha;

use EPrints::MetaField::Id;
@ISA = qw( EPrints::MetaField::Id );

use strict;
use JSON;

sub is_virtual { 1 }

sub render_input_field_actual
{
	my( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) = @_;

	my $public_key = $session->config( "recaptcha", "public_key" );

	if( !defined $public_key )
	{
		return $session->render_message( "error", $session->make_text( "public_key not set" ) );
	}

	my $frag = $session->make_doc_fragment;

	my $url = URI->new( "https://www.google.com/recaptcha/api.js" );

	$frag->appendChild( $session->make_javascript( undef,
		src => $url,
		async => 'async',
		defer => 'defer'
	) );

	$frag->appendChild( $session->make_element( "div",
		class => "g-recaptcha",
		'data-sitekey' => $public_key,
	) );

	# No-Script, for users with javascript diabled
	$url = URI->new( "https://www.google.com/recaptcha/api/fallback" );
	$url->query_form( k => $public_key );

	my $noscript = $frag->appendChild( $session->make_element( "noscript" ) );
	$noscript->appendChild( $session->make_element( "iframe",
		src => $url,
		height => "422",
		width => "302",
		frameborder => "0"
	) );
	$noscript->appendChild( $session->make_element( "br" ) );
	$noscript->appendChild( $session->make_element( "textarea",
		id => "g-recaptcha-response",
		name => "g-recaptcha-response",
		rows => "3",
		cols => "40"
	) );

	return $frag;
}

sub form_value_actual
{
	my( $self, $repo, $object, $basename ) = @_;

	my $private_key = $repo->config( "recaptcha", "private_key" );
	my $timeout = $repo->config( "recaptcha", "timeout" ) || 5;

	if( !defined $private_key )
	{
		$repo->log( "recaptcha private_key not set" );
		return undef;
	}

	my $response = $repo->param( "g-recaptcha-response" );
	if( !EPrints::Utils::is_set( $response ) )
	{
		return "invalid-captcha-sol";
	}

	my $url = URI->new( "https://www.google.com/recaptcha/api/siteverify" );

	my $ua = LWP::UserAgent->new();
	$ua->env_proxy;
	$ua->timeout( $timeout ); #LWP default timeout is 180 seconds. 

	my $r = $ua->post( "https://www.google.com/recaptcha/api/siteverify", [
		secret => $private_key,
		response => $response
	]);

	# the request returned a response - but we have to check whether the human (or otherwise)
	# passed the Captcha 
	if( $r->is_success )
	{
		my $hash = decode_json( $r->content );
		if( !$hash->{success} )
		{
			my $recaptcha_error = 'unknown-error';
			my $codes = $hash->{'error-codes'};
			if( $codes && scalar @{$codes} )
			{
				$recaptcha_error = join '+', @{$codes};
			}
			return $recaptcha_error;
		}
		return undef; #success!
	}

	# error talking to recaptcha, so lets continue to avoid blocking the user
	# in case of network problems
	$repo->log( "Error contacting recaptcha: ".$r->code." ".$r->message );

	return undef;
}

sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my @probs;

	if( $value )
	{
		push @probs, $session->html_phrase( "validate:recaptcha_mismatch" );
	}

	return @probs;
}

######################################################################
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

