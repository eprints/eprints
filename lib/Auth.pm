######################################################################
#
# cjg
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Auth;

use strict;

use Apache::AuthDBI;
use Apache::Constants qw( OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR );

use EPrints::Session;


sub authen
{
	my( $r ) = @_;

	print STDERR "Authen\n";

	my($res, $passwd_sent) = $r->get_basic_auth_pw;

	my ($user_sent) = $r->connection->user;

print STDERR ref($r)."!!\n";
	return OK unless $r->is_initial_req; # only the first internal request

	if( !defined $user_sent )
	{
		print STDERR "bleep\n";
		return AUTH_REQUIRED;
	}
	print STDERR "URL: ".$r->the_request()."\n";
	my $session = new EPrints::Session( 2 , $r->hostname.$r->uri );
	print STDERR "Blop\n";
	print STDERR "THE USER IS: $user_sent\n";
	my $result;
	$result = Apache::AuthDBI::authen( $r );
	$session->terminate();
	return $result;
}

sub authz
{
	my( $r ) = @_;
	print STDERR "Authz\n";
	my ($user_sent) = $r->connection->user;
	print STDERR "THE USER IS: $user_sent\n";
return OK;
	return Apache::AuthDBI::authz( $r );
}

1;
