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
use EPrints::RequestWrapper;

sub authen
{
	my( $r ) = @_;

	my($res, $passwd_sent) = $r->get_basic_auth_pw;

	my ($user_sent) = $r->connection->user;

	return OK unless $r->is_initial_req; # only the first internal request


	my $hpp=$r->hostname.":".$r->get_server_port.$r->uri;
	my $session = new EPrints::Session( 2 , $hpp );
	
	if( !defined $session )
	{
		return FORBIDDEN;
	}

	if( !defined $user_sent )
	{
		$session->terminate();
		return AUTH_REQUIRED;
	}

	my $area = $r->dir_config( "EPrints_Security_Area" );
	if( $area eq "ChangeUser" )
	{
		my $user_sent = $r->connection->user;
		if( $r->uri !~ m#/$user_sent$# )
		{
			return OK;
		}
		
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	my $user_ds = $session->get_archive()->get_dataset( "user" );

	my $user = EPrints::User::user_with_username( $session, $user_sent );
	if( !defined $user )
	{
		$r->note_basic_auth_failure;
		$session->terminate();
		return AUTH_REQUIRED;
	}

	my $userauthdata = $session->get_archive()->get_conf( 
		"userauth", $user->get_value( "usertype" ) );

	if( !defined $userauthdata )
	{
		$session->get_archive()->log(
			"Unknown user type: ".$user->get_value( "usertype" ) );
		$session->terminate();
		return AUTH_REQUIRED;
	}
	my $authconfig = $userauthdata->{auth};
	my $handler = $authconfig->{handler}; 
	# {handler} should really be removed before passing authconfig
	# to the requestwrapper. cjg

	my $rwrapper = EPrints::RequestWrapper->new( $r , $authconfig );
	my $result = &{$handler}( $rwrapper );
	$session->terminate();
	return $result;
}

sub authz
{
	my( $r ) = @_;

	# If we are looking at the users section then do nothing, 
	# but if we are looking at a document in the secure area then
	# we need to do some work.

	my $hpp=$r->hostname.":".$r->get_server_port.$r->uri;
	my $session = new EPrints::Session( 2 , $hpp );
	my $archive = $session->get_archive();

	my $uri = $r->uri;

	my $area = $r->dir_config( "EPrints_Security_Area" );

	if( $area eq "ChangeUser" )
	{
		# All we need here is to check it's a valid user
		# this is a valid user, which we have so let's
		# return OK.

		$session->terminate();
		return OK;
	}

	if( $area eq "User" )
	{
		# All we need in the user area is to check that
		# this is a valid user, which we have so let's
		# return OK.

		$session->terminate();
		return OK;
	}

	if( $area ne "Documents" )
	{
		# Ok, It's not User or Documents which means
		# something screwed up. 

		$archive->log( "Request to ".$r->uri." in unknown EPrints HTTP Security area \"$area\"." );
		$session->terminate();
		return FORBIDDEN;
	}

	my $secpath = $archive->get_conf( "secure_url_dir" );
	
	if( $uri !~ m#^$secpath/(\d+)/(\d+)/# )
	{
		# isn't in format:
		# /archive/00000001/01/.....

		$archive->log( "Request to ".$r->uri." in secure documents area failed to match REGEXP." );
		$session->terminate();
		return FORBIDDEN;
	}

	my $user_sent = $r->connection->user;
	my $eprintid = $1+0; # force it to be integer. (Lose leading zeros)
	my $docid = "$eprintid-$2";
	my $user = EPrints::User::user_with_username( $session, $user_sent );
	my $document = EPrints::Document->new( $session, $docid );

	unless( $document->can_view( $user ) )
	{
		$session->terminate();
		return FORBIDDEN;
	}	

	$session->terminate();
	return OK;
}

1;
