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

This field renders a Captcha (a test that only humans can easily pass). It uses the "reCaptcha" service (http://recaptcha.net/). A single database text column is used to store the captcha error code.

Two configuration options are required to define the reCaptcha keys:

	$c->{recaptcha}->{private_key} = "PRIVATE_KEY";
	$c->{recaptcha}->{public_key} = "PUBLIC_KEY";

You can get these keys by registering at http://recaptcha.net/.

=over 4

=cut

package EPrints::MetaField::Recaptcha;

use EPrints::MetaField::Id;
@ISA = qw( EPrints::MetaField::Id );

use strict;

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

	my $url = URI->new( "https://www.google.com/recaptcha/api/challenge" );
	$url->query_form(
		k => $public_key,
		error => $value,
		);

	my $script = $frag->appendChild( $session->make_javascript( undef,
		src => $url ) );

	$url = URI->new( "https://www.google.com/recaptcha/api/noscript" );
	$url->query_form(
		k => $public_key,
		error => $value,
		);

	my $noscript = $frag->appendChild( $session->make_element( "noscript" ) );
	$noscript->appendChild( $session->make_element( "iframe",
		src => $url,
		height => "300",
		width => "500",
		frameborder => "0"
		) );
	$noscript->appendChild( $session->make_element( "br" ) );
	$noscript->appendChild( $session->make_element( "textarea",
		name => "recaptcha_challenge_field",
		rows => "3",
		cols => "40"
		) );
	$noscript->appendChild( $session->make_element( "input",
		type => "hidden",
		name => "recaptcha_response_field",
		value => "manual_challenge"
		) );

	return $frag;
}

sub form_value_actual
{
	my( $self, $repo, $object, $basename ) = @_;

	my $private_key = $repo->config( "recaptcha", "private_key" );

	my $remote_ip = $repo->remote_ip;
	my $challenge = $repo->param( "recaptcha_challenge_field" );
	my $response = $repo->param( "recaptcha_response_field" );

	if( !defined $private_key )
	{
		$repo->log( "recaptcha private_key not set" );
		return undef;
	}

	# don't bother reCaptcha if the user didn't enter the data
	if( !EPrints::Utils::is_set( $challenge ) || !EPrints::Utils::is_set( $response ) )
	{
		return "invalid-captcha-sol";
	}

	my $url = URI->new( "http://www.google.com/recaptcha/api/verify" );

	my $ua = LWP::UserAgent->new();

	my $r = $ua->post( $url, [
		privatekey => $private_key,
		remoteip => $remote_ip,
		challenge => $challenge,
		response => $response
		]);

	my $recaptcha_error;

	if( $r->is_success )
	{
		my( $success, $recaptcha_error ) = split /\n/, $r->content;
		if( defined($success) && lc($success) eq "true" )
		{
			return undef
		}
		return $recaptcha_error;
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

