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

use EPrints::Apache; # exports apache constants
use URI;
use MIME::Base64;

# sf2 - rewritten to call a stack of Auth triggers - cf. lib/cfg.d/auth_*.pl
sub authen
{
	my( $r, $realm ) = @_;

	return OK unless $r->is_initial_req; # only the first internal request
	
	my $repo = $EPrints::HANDLE->current_repository;
	if( !defined $repo )
	{
		return FORBIDDEN;
	}

	# this may load a cookie based user session
	if( defined $repo->current_user )
	{
		return OK;
	} 

	# AUTH_REQUIRED

	$repo->debug_log( "auth", "calling for credentials handlers..." );

	# typically this will either process BasicAuth included in the request
	# or redirect to a Login UI page
	# or redirect to a CAS page
        my $rc = undef;
        $repo->run_trigger( EPrints::Const::EP_TRIGGER_REQUEST_AUTH_CREDENTIALS,
                request => $r,
		realm => $realm,
		repository => $repo,
		return_code => \$rc,
        );
        return $rc if defined $rc;

	# if we arrive here, there are no mechanisms to either collect credentials or validate them...
	# so let's default to BasicAuth

        $realm ||= $repo->phrase( "archive_name" );
        $r->err_headers_out->{'WWW-Authenticate'} = "Basic realm=\"$realm\"";

	$repo->debug_log( "auth", "unauthorized" );

	return EPrints::Apache::HTTP_UNAUTHORIZED;
}

# tells if a user is required given a dataobj and an action
sub authen_dataobj_action
{
	my( %params ) = @_;

	my $repository = $params{repository};
	my $request = $params{request};
	
	# Internet Explorer launches Office with a URL, which then performs an
	# OPTIONS on the URL. By returning FORBIDDEN we stop some annoying
	# challenge-dialogs.
	return FORBIDDEN if $request->method eq "OPTIONS";

	my $dataobj = $params{dataobj};
	my $dataset = $params{dataset};
	my $action = $params{action};

	return FORBIDDEN if( !EPrints::Utils::is_set( $action ) );

	# simply check if the action (and associated privs) are public
	# if not, we need an authenticated user
	if( defined $dataobj )
	{
		if( $dataobj->public_action( $action ) )
		{
			$repository->debug_log( "auth", "authen_dataobj_action OK (public_action)" );
			return OK;
		}
	}

	if( defined $dataset )
	{
		if( $dataset->public_action( $action ) )
		{
			$repository->debug_log( "auth", "authen_dataobj_action OK (public action)" );
			return OK;
		}
	}

	$repository->debug_log( "auth", "authen_dataobj_action AUTH REQUIRED" );

	return EPrints::Apache::Auth::authen( $request );
}

sub authz
{
	my( $r ) = @_;

	return OK;
}

# similar to authen_dataobj_action - checks if a user can
# perform a given action on a given dataset or dataobj
sub authz_dataobj_action
{
	my( %params ) = @_;

	my $repository = $params{repository};
	my $request = $params{request};

	my $dataobj = $params{dataobj};
	my $dataset = $params{dataset};
	my $action = $params{action};

	return FORBIDDEN if( !EPrints::Utils::is_set( $action ) );
	
	if( defined $dataobj )
	{
		if( $dataobj->permit_action( $action, $repository->current_user ) )
		{
			$repository->debug_log( "auth", "authz_dataobj_action OK" );
			return OK ;
		}
	}
	if( defined $dataset )
	{
		if( $dataset->permit_action( $action, $repository->current_user ) )
		{
			$repository->debug_log( "auth", "authz_dataobj_action OK" );
			return OK ;
		}
	}

	$repository->debug_log( "auth", "authz_dataobj_action FORBIDDEN" );

	return FORBIDDEN;
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

