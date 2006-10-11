######################################################################
#
# EPrints::Apache::Auth
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

B<EPrints::Apache::Auth> - Password authentication & authorisation checking 
for EPrints.

=head1 DESCRIPTION

This module handles the authentication and authorisation of users
viewing private sections of an EPrints website.

=over 4

=cut
######################################################################

package EPrints::Apache::Auth;

use strict;

use EPrints::Apache::AnApache; # exports apache constants

#use EPrints::Session;
#use EPrints::SystemSettings;


######################################################################
=pod

=item $result = EPrints::Apache::Auth::authen( $r )

Authenticate a request. This works in a slightly whacky way.

If the username isn't a valid user in the current repository then it
fails right away.

Otherwise it looks up the type of the given user. Then it looks up
in the repository configuration to find how to authenticate that user
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

	return OK unless $r->is_initial_req; # only the first internal request

	my $session = new EPrints::Session(2); # don't open the CGI info
	
	if( !defined $session )
	{
		return FORBIDDEN;
	}

	my $area = $r->dir_config( "EPrints_Security_Area" );

	if( $area eq "Documents" )
	{
		my $document = secure_doc_from_url( $r, $session );
		if( !defined $document ) 
		{
			$session->terminate();
			return FORBIDDEN;
		}

		my $security = $document->get_value( "security" );

#		if( $security->is_public )
#		{
#			$session->terminate();
#			return OK;
#		}

		my $rule = "REQ_AND_USER";
		if( $session->get_repository->can_call( "document_security_rule" ) )
		{
			$rule = $session->get_repository->call("document_security_rule", $security );
		}
		if( $rule !~ m/^REQ|REQ_AND_USER|REQ_OR_USER$/ )
		{
			$session->get_repository->log( "Bad document_security_rule: '$rule'." );
			$session->terminate();
			return FORBIDDEN;
		}

		my $req_view = 1;
		if( $session->get_repository->can_call( "can_request_view_document" ) )
		{
			$req_view = $session->get_repository->call( "can_request_view_document", $document, $r );
		}

		if( $rule eq "REQ" )
		{
			if( $req_view )
			{
				$session->terminate();
				return OK;
			}

			$session->terminate();
			return FORBIDDEN;
		}

		if( $rule eq "REQ_AND_USER" )
		{
			if( !$req_view )
			{
				$session->terminate();
				return FORBIDDEN;
			}
		}

		if( $rule eq "REQ_OR_USER" )
		{
			if( $req_view )
			{
				$session->terminate();
				return OK;
			}
		}

		#otherwise we need a valid username
	}


	my $rc;
	if( $session->get_archive->get_conf( "cookie_auth" ) ) 
	{
		$rc = auth_cookie( $r, $session );
	}
	else
	{
		$rc = auth_basic( $r, $session );
	}

	$session->terminate();

	return $rc;
}



sub auth_cookie
{
	my( $r, $session ) = @_;

	my $user = $session->current_user;

	if( !defined $user ) 
	{
		# bad ticket or no ticket
		my $registry_module;
		my $av =  $EPrints::SystemSettings::conf->{apache};
		if( !defined $av || $av eq "1" ) 
		{
			$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Login', 'Apache::Registry' ] );
		}
		else # apache 2
		{
			$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Login', 'ModPerl::Registry' ] );
		}

	}

	return OK;
}


sub auth_basic
{
	my( $r, $session ) = @_;

	my( $res, $passwd_sent ) = $r->get_basic_auth_pw;
	my( $user_sent ) = $r->user;

	if( !defined $user_sent )
	{
		return AUTH_REQUIRED;
	}

	my $area = $r->dir_config( "EPrints_Security_Area" );
	if( $area eq "ChangeUser" )
	{
		if( $r->uri !~ m/\/$user_sent$/i )
		{
			return OK;
		}
		
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $user = EPrints::DataObj::User::user_with_username( $session, $user_sent );
	if( !defined $user )
	{
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	my $userauthdata = $session->get_repository->get_conf( 
		"userauth", $user->get_value( "usertype" ) );

	if( !defined $userauthdata )
	{
		$session->get_repository->log(
			"Unknown user type: ".$user->get_value( "usertype" ) );
		return AUTH_REQUIRED;
	}
	my $authconfig = $userauthdata->{auth};
	my $handler = $authconfig->{handler}; 
	# {handler} should really be removed before passing authconfig
	# to the requestwrapper. cjg

	my $rwrapper = $EPrints::Apache::AnApache::RequestWrapper->new( $r , $authconfig );
	my $result = &{$handler}( $rwrapper );
	return $result;
}


######################################################################
=pod

=item $results = EPrints::Apache::Auth::authz( $r )

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
are either not in the public repository, or have a non-public security
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

	my $session = new EPrints::Session(2); # don't open the CGI info
	my $repository = $session->get_repository;

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

		$repository->log( "Request to ".$r->uri." in unknown EPrints HTTP Security area \"$area\"." );
		$session->terminate();
		return FORBIDDEN;
	}

	my $document = secure_doc_from_url( $r, $session );
	if( !defined $document ) {
		$session->terminate();
		return FORBIDDEN;
	}

	my $security = $document->get_value( "security" );

#	if( $security->is_public )
#	{
#		$session->terminate();
#		return OK;
#	}

	my $rule = "REQ_AND_USER";
	if( $session->get_repository->can_call( "document_security_rule" ) )
	{
		$rule = $session->get_repository->call("document_security_rule", $security );
	}
	# no need to check authen is always called first

	my $req_view = 1;
	if( $session->get_repository->can_call( "can_request_view_document" ) )
	{
		$req_view = $session->get_repository->call( "can_request_view_document", $document, $r );
	}

	if( $rule eq "REQ_AND_USER" )
	{
		if( !$req_view )
		{
			$session->terminate();
			return FORBIDDEN;
		}
	}
	if( $rule eq "REQ_OR_USER" )
	{
		if( $req_view )
		{
			$session->terminate();
			return OK;
		}
	}
	# REQ should not have made it this far.

	my $user_sent = $r->user;
	my $user = EPrints::DataObj::User::user_with_username( $session, $user_sent );
	unless( $document->can_view( $user ) )
	{
		$session->terminate();
		return FORBIDDEN;
	}	


	$session->terminate();
	return OK;
}

######################################################################
=pod

=item $document = EPrints::Apache::Auth::secure_doc_from_url( $r, $session )

Return the document that the current URL, in the secure documents area
relates to, if any. Or undef.

=cut
######################################################################


sub secure_doc_from_url
{
	my( $r, $session ) = @_;

	# hack to reduce load. We cache the document in the request object.
	#if( defined $r->{eprint_document} ) { return $r->{eprint_document}; }

	my $repository = $session->{repository};
	my $uri = $r->uri;

	my $secpath = $repository->get_conf( "secure_urlpath" );
	my $esec = $r->dir_config( "EPrints_Secure" );
	my $https = (defined $esec && $esec eq "yes" );
	my $urlpath;
	if( $https ) 
	{ 
		$urlpath = $repository->get_conf( "securepath" );
	}
	else
	{ 
		$urlpath = $repository->get_conf( "urlpath" );
	}

	$uri =~ s/^$urlpath$secpath//;
	my $docid;
	my $eprintid;

	if( $uri =~ m#^/(\d\d\d\d\d\d\d\d)/(\d+)/# )
	{
		# /archive/00000001/01/.....
		# or
		# /$archiveid/archive/00000001/01/.....

		# force it to be integer. (Lose leading zeros)
		$eprintid = $1+0; 
		$docid = "$eprintid-$2";
	}
	else
	{
		$repository->log( 
"Request to ".$r->uri." in secure documents area failed to match REGEXP." );
		return undef;
	}
	my $document = EPrints::DataObj::Document->new( $session, $docid );
	if( !defined $document ) {
		$repository->log( 
"Request to ".$r->uri.": document $docid not found." );
		return undef;
	}

	# cache $document in the request object
	#$r->{eprint_document} = $document;


	return $document;
}




1;

######################################################################
=pod

=back

=cut

