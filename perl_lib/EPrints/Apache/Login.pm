######################################################################
#
# EPrints::Apache::Login
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Apache::Login;

use strict;

use EPrints;
use EPrints::Apache::AnApache;

sub handler
{
	my( $r ) = @_;

	my $session = new EPrints::Session;
	my $problems;

	if( $session->param( "login_check" ) )
	{
		# If this is set, we didn't log in after all!
		$problems = $session->html_phrase( "cgi/login:no_cookies" );
	}

	my $username = $session->param( "login_username" );
	my $password = $session->param( "login_password" );
	if( defined $username )
	{
		my $real_username = $session->valid_login( $username, $password );
		if( defined $real_username )
		{
			my $user = $session->user_by_username( $real_username );

			my $url = $session->get_url( host=>1 );
			$url .= "?login_params=".URI::Escape::uri_escape( $session->param("login_params") );
			$url .= "&login_check=1";
			# always set a new random cookie value when we login
			my @a = ();
			srand;
			my $r = $session->get_request;
			for(1..16) { push @a, sprintf( "%02X",int rand 256 ); }
			my $code = join( "", @a );
			$session->login( $user,$code );
			my $cookie = $session->{query}->cookie(
				-name    => "eprints_session",
				-path    => "/",
				-value   => $code,
				-domain  => $session->get_conf("cookie_domain"),
			);			
			$r->err_headers_out->add('Set-Cookie' => $cookie);
			$session->redirect( $url );
			return DONE;
		}

		$problems = $session->html_phrase( "cgi/login:failed" );
	}

	$r->status( 401 );
	$r->custom_response( 401, '' ); # disable the normal error document

	EPrints::ScreenProcessor->process(
		session => $session,
		screenid => "Login",
		problems => $problems,
	);

	return DONE;
}

1;
