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
use URI;

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
	if( !_use_auth_basic( $r, $session ) )
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

sub _use_auth_basic
{
	my( $r, $session ) = @_;

	my $rc = 0;

	if( !$session->get_repository->get_conf( "cookie_auth" ) ) 
	{
		$rc = 1;
	}
	else
	{
		my $uri = URI->new( $r->uri, "http" );
		my $script = $uri->path;

		my $econf = $session->get_repository->get_conf( "auth_basic" ) || [];

		foreach my $exppath ( @$econf )
		{
			if( $exppath !~ /^\// )
			{
				$exppath = $session->get_repository->get_conf( "rel_cgipath" )."/$exppath";
			}
			if( $script =~ /^$exppath/ )
			{
				$rc = 1;
				last;
			}
		}
	}

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
	return NOT_FOUND if( !defined $document );

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
	if( !_use_auth_basic( $r, $session ) )
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
		my $login_url = $session->get_url(
			path => "cgi",
		) . "/users/login";
		my $target_url = $session->get_url(
			host => 1,
			path => "auto",
		);
		$login_url = URI->new( $login_url );
		$login_url->query_form(
			target => $target_url
		);
		if( $session->get_repository->can_call( 'get_login_url' ) )
		{
			$login_url = $session->get_repository->call( 'get_login_url', $session, $target_url );
			$redir = 1;
		}
		if( $redir )
		{
			EPrints::Apache::AnApache::send_status_line( $r, 302, "Need to login first" );
			EPrints::Apache::AnApache::header_out( $r, "Location", $login_url );
			EPrints::Apache::AnApache::send_http_header( $r );
			return DONE;
		}

		$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Login' ] );
		return OK;
	}

	my $loginparams = $session->param("loginparams");
	if( EPrints::Utils::is_set( $loginparams ) ) 
	{
		my $url = $session->get_url( host=>1 )."?".$loginparams;
		$session->redirect( $url );
		return DONE;
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

	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $user = EPrints::DataObj::User::user_with_username( $session, $user_sent );
	if( !defined $user )
	{
		$r->note_basic_auth_failure;
		return AUTH_REQUIRED;
	}

	return $session->valid_login( $user_sent, $passwd_sent ) ?
			OK : AUTH_REQUIRED;
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
		return NOT_FOUND;
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

	my $urlpath = $repository->get_conf( "rel_path" );

	$uri =~ s/^$urlpath//;

	my $eprintid;
	my $pos;
	if( $uri =~ m#^/(\d+)/(thumbnails/)?(\d+)/# )
	{
		$eprintid = $1+0;
		$pos = $3+0;
	}
	else
	{
		$repository->log( 
"Request to ".$r->uri." in secure documents area failed to match REGEXP." );
		return undef;
	}

	my $document = EPrints::DataObj::Document::doc_with_eprintid_and_pos( $session, $eprintid, $pos );
	if( !defined $document ) {
		$repository->log( 
"Request to ".$r->uri.": document eprintid=$eprintid pos=$pos not found." );
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

