######################################################################
#
# EPrints::Auth
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

B<EPrints::Auth> - Password authentication & authorisation checking 
for EPrints.

=head1 DESCRIPTION

This module handles the authentication and authorisation of users
viewing private sections of an EPrints website.

=over 4

=cut
######################################################################

package EPrints::Auth;

use strict;

use Apache::AuthDBI;
use Apache::Constants qw( OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR );

use EPrints::Session;
use EPrints::RequestWrapper;


######################################################################
=pod

=item $result = EPrints::Auth::authen( $r )

Authenticate a request. This works in a slightly whacky way.

If the username isn't a valid user in the current archive then it
fails right away.

Otherwise it looks up the type of the given user. Then it looks up
in the archive configuration to find how to authenticate that user
type (a reference to another authen function, probably a normal
3rd party mod_perl library like AuthDBI.) and then makes a mock
request and attempts to authenticate it using the authen function for
that usertype.

This is a bit odd, but allows, for example, you to have local users 
being authenticated via LDAP and remote users authenticated by the
normal eprints AuthDBI method.

If the authentication area is "ChangeUser" then it returns true unless
the current user is the user specified in the URL. This will allow a
user to log in as someone else.

=cut
######################################################################

sub authen
{
	my( $r ) = @_;

	my($res, $passwd_sent) = $r->get_basic_auth_pw;

	my ($user_sent) = $r->connection->user;

	return OK unless $r->is_initial_req; # only the first internal request


	my $hp=$r->hostname.$r->uri;
	my $session = new EPrints::Session( 2 , $hp );
	
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


######################################################################
=pod

=item $results = EPrints::Auth::authz( $r )

Tests to see if the user making the current request is authorised to
see this URL.

There are three kinds of security area in the system:

=over 4

=item User

The main user area. Noramally /perl/users/. This just returns true -
any valid user can access it. Individual scripts worry about who is 
running them.

=item Documents

This is the secure documents area - for documents of records which
are either not in the public archive, or have a non-public security
option.

In which case it works out which document is being viewed and calls
$doc->can_view( $user ) to decide if it should allow them to view it
or not.

=item ChangeUser

This area is just a way to de-validate the current user, so the user
can log in as some other user. 

=back

=cut
######################################################################

sub authz
{
	my( $r ) = @_;

	# If we are looking at the users section then do nothing, 
	# but if we are looking at a document in the secure area then
	# we need to do some work.

	my $hp=$r->hostname.$r->uri;
	my $session = new EPrints::Session( 2 , $hp );
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

######################################################################
=pod

=back

=cut

