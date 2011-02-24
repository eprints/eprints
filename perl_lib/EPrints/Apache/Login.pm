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

	my $screenid = $session->param( "screen" );
	if( !defined $screenid || $screenid !~ /^Login::/ )
	{
		$screenid = "Login";
	}

	EPrints::ScreenProcessor->process(
		session => $session,
		screenid => $screenid,
		problems => $problems,
	);

	return DONE;
}

1;
