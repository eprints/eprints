######################################################################
#
# EPrints::MetaField::Recaptcha;
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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

use EPrints::MetaField::Text;
@ISA = qw( EPrints::MetaField::Text );

use strict;

sub render_input_field_actual
{
	my( $self, $handle, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) = @_;

	my $public_key = $handle->get_repository->get_conf( "recaptcha", "public_key" );

	if( !defined $public_key )
	{
		$handle->get_repository->log( "recaptcha public_key not set" );
		return undef;
	}

	my $frag = $handle->make_doc_fragment;

	my $url = URI->new( "https://api-secure.recaptcha.net/challenge" );
	$url->query_form(
		k => $public_key,
		error => $value,
		);

	my $script = $frag->appendChild( $handle->make_element( "script",
		type => "text/javascript",
		src => $url ) );

	$url = URI->new( "https://api-secure.recaptcha.net/noscript" );
	$url->query_form(
		k => $public_key,
		error => $value,
		);

	my $noscript = $frag->appendChild( $handle->make_element( "noscript" ) );
	$noscript->appendChild( $handle->make_element( "iframe",
		src => $url,
		height => "300",
		width => "500",
		frameborder => "0"
		) );
	$noscript->appendChild( $handle->make_element( "br" ) );
	$noscript->appendChild( $handle->make_element( "textarea",
		name => "recaptcha_challenge_field",
		rows => "3",
		cols => "40"
		) );
	$noscript->appendChild( $handle->make_element( "input",
		type => "hidden",
		name => "recaptcha_response_field",
		value => "manual_challenge"
		) );

	return $frag;
}

sub form_value_actual
{
	my( $self, $handle, $object, $basename ) = @_;

	my $private_key = $handle->get_repository->get_conf( "recaptcha", "private_key" );
	my $remote_ip = $handle->get_request->connection->remote_ip;
	my $challenge = $handle->param( "recaptcha_challenge_field" );
	my $response = $handle->param( "recaptcha_response_field" );

	if( !defined $private_key )
	{
		$handle->get_repository->log( "recaptcha private_key not set" );
		return undef;
	}

	# don't bother reCaptcha if the user didn't enter the data
	if( !EPrints::Utils::is_set( $challenge ) || !EPrints::Utils::is_set( $response ) )
	{
		return "invalid-captcha-sol";
	}

	my $url = URI->new( "http://api-verify.recaptcha.net/verify" );

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
	$handle->get_repository->log( "Error contacting recaptcha: ".$r->code." ".$r->message );

	return undef;
}

sub validate
{
	my( $self, $handle, $value, $object ) = @_;

	my @probs;

	if( $value )
	{
		push @probs, $handle->html_phrase( "validate:recaptcha_mismatch" );
	}

	return @probs;
}

######################################################################
1;
