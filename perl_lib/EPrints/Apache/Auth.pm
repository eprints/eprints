######################################################################
#
# EPrints::Apache::Auth
#
######################################################################
#
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
use MIME::Base64;

sub authen
{
	my( $r, $realm ) = @_;

	return OK unless $r->is_initial_req; # only the first internal request
	
	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return FORBIDDEN;
	}

	my $rc;
	if( !_use_auth_basic( $r, $repository ) )
	{
		$rc = auth_cookie( $r, $repository );
	}
	else
	{
		$rc = auth_basic( $r, $repository, $realm );
	}

	return $rc;
}

sub _use_auth_basic
{
	my( $r, $repository ) = @_;

	my $rc = 0;

	if( !$repository->config( "cookie_auth" ) ) 
	{
		$rc = 1;
	}
	if( !$rc )
	{
		my $uri = URI->new( $r->uri, "http" );
		my $script = $uri->path;

		my $econf = $repository->config( "auth_basic" ) || [];

		foreach my $exppath ( @$econf )
		{
			if( $exppath !~ /^\// )
			{
				$exppath = $repository->config( "rel_cgipath" )."/$exppath";
			}
			if( $script =~ /^$exppath/ )
			{
				$rc = 1;
				last;
			}
		}
	}
	# if the user agent doesn't support text/html then use Basic Auth
	# NOTE: browsers requesting objects in <img src> will also not specify
	# text/html, so we always look for a cookie-authentication before checking
	# basic auth
	if( !$rc )
	{
		my $accept = $r->headers_in->{'Accept'} || '';
		my @types = split /\s*,\s*/, $accept;
		if( !grep { m#^text/html\b# } @types )
		{
			$rc = 1;
		}
		# Microsoft Internet Explorer - Accept: */*
		my $agent = $r->headers_in->{'User-Agent'} || '';
		# http://msdn.microsoft.com/en-us/library/ms537509(v=vs.85).aspx
		if( $agent =~ /\bMSIE ([0-9]{1,}[\.0-9]{0,})/ )
		{
			$rc = 0;
		}
	}

	return $rc;
}

sub authen_doc
{
	my( $r, $realm ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return FORBIDDEN;
	}

	my $rvalue = _authen_doc( $r, $repository, $realm );

	return $rvalue;
}

sub _authen_doc
{
	my( $r, $repository, $realm ) = @_;

	my $document = $r->pnotes( "document" );
	return NOT_FOUND if( !defined $document );

	my $security = $document->get_value( "security" );

	my $result = $repository->call( "can_request_view_document", $document, $r );

	if( $result eq "ALLOW" )
	{
		return OK;
	}
	elsif( $result eq "DENY" )
	{
		return FORBIDDEN;
	}
	elsif( $result ne "USER" )
	{
		$repository->log( "Response from can_request_view_document was '$result'. Only ALLOW, DENY, USER are allowed." );
		return FORBIDDEN;
	}

	my $rc;
	if( !_use_auth_basic( $r, $repository ) )
	{
		$rc = auth_cookie( $r, $repository, 1 );
	}
	else
	{
		$rc = auth_basic( $r, $repository, $realm );
	}

	return $rc;
}




sub auth_cookie
{
	my( $r, $repository, $redir ) = @_;

	my $user = $repository->current_user;

	# Check we logged in successfully, if so skip do the real URL
	if( $repository->param( "login_check" ) && defined $user )
	{
		my $url = $repository->get_url( host=>1 );
		my $login_params = $repository->param("login_params");
		if( EPrints::Utils::is_set( $login_params ) ) { $url .= "?".$login_params; }
		$repository->redirect( $url );
		return DONE;
	}

	if( !defined $user ) 
	{
		my $login_url = $repository->get_url(
			path => "cgi",
		) . "/users/login";
		my $target_url = $repository->get_url(
			host => 1,
			path => "auto",
			query => 1,
		);
		$login_url = URI->new( $login_url );
		$login_url->query_form(
			target => $target_url
		);
		if( $repository->can_call( 'get_login_url' ) )
		{
			$login_url = $repository->call( 'get_login_url', $repository, $target_url );
			$redir = 1 if( defined $login_url );
		}
		if( $redir )
		{
			EPrints::Apache::AnApache::send_status_line( $r, 302, "Need to login first" );
			EPrints::Apache::AnApache::header_out( $r, "Location", $login_url );
			EPrints::Apache::AnApache::send_http_header( $r );
			return DONE;
		}

		$r->handler( 'perl-script' );
		$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Login' ] );
		return OK;
	}

	my $loginparams = $repository->param("loginparams");
	if( EPrints::Utils::is_set( $loginparams ) ) 
	{
		my $url = $repository->get_url( host=>1 )."?".$loginparams;
		$repository->redirect( $url );
		return DONE;
	}

	return OK;
}


sub auth_basic
{
	my( $r, $repository, $realm ) = @_;

	# user has been logged in by some other means
	my $user = $repository->current_user;
	return OK if defined $user;

	if( !EPrints::Utils::is_set( $realm ) )
	{
		$realm = $repository->phrase( "archive_name" );
	}

	my $authorization = $r->headers_in->{'Authorization'};
	$authorization = '' if !defined $authorization;

	my( $username, $password );
	if( $authorization =~ s/^Basic\s+// )
	{
		$authorization = MIME::Base64::decode_base64( $authorization );
		($username, $password) = split /:/, $authorization, 2;
	}

	if( !defined $username )
	{
		$r->err_headers_out->{'WWW-Authenticate'} = "Basic realm=\"$realm\"";
		return AUTH_REQUIRED;
	}

	if( !$repository->valid_login( $username, $password ) )
	{
		$r->note_basic_auth_failure;
		$r->err_headers_out->{'WWW-Authenticate'} = "Basic realm=\"$realm\"";
		return AUTH_REQUIRED;
	}

	$r->user( $username );

	return OK;
}

sub authz
{
	my( $r ) = @_;

	return OK;
}

sub authz_doc
{
	my( $r ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return FORBIDDEN;
	}

	my $document = $r->pnotes( "document" );
	if( !defined $document ) 
	{
		return NOT_FOUND;
	}

	my $result = $repository->call( "can_request_view_document", $document, $r );
	if( $result eq "ALLOW" )
	{
		return OK;
	}
	elsif( $result eq "DENY" )
	{
		return FORBIDDEN;
	}

	my $user = $repository->current_user;

	if( $document->user_can_view( $user ) )
	{
		return OK;
	}
	else
	{
		return FORBIDDEN;
	}
}

1;

######################################################################
=pod

=back

=cut


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

