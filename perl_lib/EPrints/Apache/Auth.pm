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



sub authen
{
	my( $r ) = @_;

	return OK unless $r->is_initial_req; # only the first internal request
	
	my $session = new EPrints::Session(2); # don't open the CGI info
	
	if( !defined $session )
	{
		return FORBIDDEN;
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

sub authen_doc
{
	my( $r ) = @_;

	my $session = new EPrints::Session(2); # don't open the CGI info

	return FORBIDDEN if( !defined $session );

	my $rvalue = _authen_doc( $r, $session );
	$session->terminate;

	return $rvalue;
}

sub _authen_doc
{
	my( $r, $session ) = @_;

	my $document = secure_doc_from_url( $r, $session );
	return FORBIDDEN if( !defined $document );

	my $security = $document->get_value( "security" );

	my $result = $session->get_repository->call( "can_request_view_document", $document, $r );

	return OK if( $result eq "ALLOW" );
	return FORBIDDEN if( $result eq "DENY" );
	if( $result ne "USER" )
	{
		$session->get_repository->log( "Response from can_request_view_document was '$result'. Only ALLOW, DENY, USER are allowed." );
		return FORBIDDEN;
	}

	my $rc;
	if( $session->get_archive->get_conf( "cookie_auth" ) ) 
	{
		$rc = auth_cookie( $r, $session, 1 );
	}
	else
	{
		$rc = auth_basic( $r, $session );
	}

	return $rc;
}




sub auth_cookie
{
	my( $r, $session, $redir ) = @_;

	my $user = $session->current_user;

	if( !defined $user ) 
	{
		if( $redir )
		{
			my $target_url = $r->uri;
			$target_url =~ s/([^A-Z0-9])/sprintf( "%%%02X", ord($1) )/ieg;
			my $login_url = $session->get_repository->get_conf( "perl_url" )."/users/login?target=$target_url";
			EPrints::Apache::AnApache::send_status_line( $r, 302, "Need to login first" );
			EPrints::Apache::AnApache::header_out( $r, "Location", $login_url );
			EPrints::Apache::AnApache::send_http_header( $r );
			return DONE;
		}


		# bad ticket or no ticket
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

	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $user = EPrints::DataObj::User::user_with_username( $session, $user_sent );
	if( !defined $user )
	{
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	my $user_type = $user->get_value( "usertype" );

	my $userauthdata = $session->get_repository->get_conf( 
		"userauth", $user_type ); 

	if( !defined $userauthdata )
	{
		$session->get_repository->log(
			"Unknown user type: ".$user_type );
		return AUTH_REQUIRED;
	}
	my $authconfig = $userauthdata->{auth};
	
	# {handler} should really be removed before passing authconfig
	# to the requestwrapper. cjg

	my $rwrapper = $EPrints::Apache::AnApache::RequestWrapper->new( $r , $authconfig );
	
	my $result = $session->get_repository->call( 
		[ "userauth", $user_type, "auth", "handler" ],
		$rwrapper );
	
	return $result;
}



sub authz
{
	my( $r ) = @_;


	return OK;
}

sub authz_doc
{
	my( $r ) = @_;

	my $session = new EPrints::Session(2); # don't open the CGI info

	my $document = secure_doc_from_url( $r, $session );
	if( !defined $document ) 
	{
		$session->terminate();
		return FORBIDDEN;
	}

	my $request_result = $session->get_repository->call( "can_request_view_document", $document, $r );
	return OK if( $request_result eq "ALLOW" );
	return FORBIDDEN if( $request_result eq "DENY" );

	my $security = $document->get_value( "security" );

	my $user = $session->current_user;

	my $result = $document->user_can_view( $user );
	$session->terminate();

	if( $result )
	{
		return OK;
	}
	else
	{
		return FORBIDDEN;
	}
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

	if( $uri =~ m#^/(\d+)/(\d+)/# )
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

