######################################################################
#
# EPrints::Sword::Utils
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

######################################################################
#
# PURPOSE:
#
# 	This is the general API for the SWORD implementation on EPrints 3, as used by the other modules (mostly
# 	ServiceDocument.pm and DepositHandler.pm).
#
#
# METHODS:
# 
#
# authenticate( $session, $request )
#	Parameters: 	$session -> the current Session object
#			$request -> the mod_perl object
#	Returns:	in case of error: a hash with HTTP status code and related error codes set (eg. X-Error-Code in SWORD)			
#			otherwise: a hash with the user and behalf user objects
#	Notes:		This also tests whether the (optional) mediation is allowed or not			
#
# process_headers( $session, $request )
# 	Parameters:	cf. above
#	Returns:	in case of error: a hash with HTTP status code and related error codes set (eg. X-Error-Code in SWORD)
#			otherwise: a hash with the options sent through HTTP headers
#	Notes:		This will test if the options are valid (and set default options if not)
#
# can_user_behalf( $session, $username, $behalf_username )
# 	Parameters:	$session -> the current Session object
# 			$username -> the user currently logged in
# 			$behalf_username -> the user one is depositing on behalf of
# 	Returns:	1 if the user 'username' can deposit on behalf of 'behalf_username', 0 otherwise
#
# is_collection_valid( $collection )
# 	Parameters:	$collection -> the name of the collection
# 	Returns:	1 if the collection is valid (so either 'inbox', 'buffer' or 'archive'), 0 otherwise
#
# get_collections( $session )
# 	Parameters:	$session -> the current Session object
# 	Returns:	A hash with the configuration for each defined collections in sword.pl
# 	Notes:		This will test if the options are valid (and set default options if not)
#
# get_files_mime( $session, $files )
# 	Parameters:	$session
# 			$files -> a reference to a hash of file names
# 	Returns:	A hash: { filename => mime_type }
# 	Notes:		the files should contain the full path.
#
# get_file_to_import( $session, $files, $mime_type, $return_all )
# 	Parameters:	$session
# 			$files	-> a reference to a hash of file names
# 			$mime_type -> the MIME type used for filtering (eg. 'application/pdf')
# 			$return_all -> (optional) a boolean value, cf Notes below.
# 	Returns:	a scalar, an array or undef, cf Notes below.
# 	Notes:		Used to filter out a set of files. The method tests the MIME type of each file, and keep only the one(s) 
# 			which matches the provided 'mime_type' argument. If 'return_all' is set to 0 or 'undef', the method tries to find only 
# 			ONE file which matches the 'mime_type' (and will return 'undef' if there are MORE than one file). If 'return_all'
# 			is set to 1, the method returns ALL files matching the 'mime_type'.
#
# get_deposit_url( $session )
# 	Parameters:	$session
# 	Returns:	the URL for deposits.
# 	Notes:		The name of each collection will be appended to the end of this URL. You may modify this method if you need
# 			the deposit URLs to point to somewhere else than the default ones.
# 			By default this points to "http://myserver.org/CGI/APP/DEPOSIT/{collection_name}"
#
## get_collections_url( $session )
#	Parameters:	$session
#	Returns:	the base URL of the available collections.
#	Notes:		Again, the name of the collections will be appended to the end. You may also modify this method.
#			By default this points to "http://myserver.org/CGI/APP/COLLECTIONS/{collection_name}"
#			You may over-ride the default collection URLs by setting the 'href' variables in the collections definitions inside sword.pl
#
######################################################################


package EPrints::Sword::Utils;

use strict;
use warnings;

use EPrints::Sword::FileType;
use MIME::Base64;


sub authenticate
{
	my ( $session, $request ) = @_;

	my %response;

	my $disable_auth = $session->get_repository->get_conf( "sword", "disable_authentication" );

	if( defined $disable_auth && $disable_auth eq "1")
	{
		# Sending on behalf of is disabled in this case.
		my $ann_oneem = $session->get_repository->get_conf( "sword", "anonymous_user" );
		if( !defined $ann_oneem )
		{
			print STDERR "\n[SWORD] [INTERNAL-ERROR] No anonymous user defined. You NEED to supply an anonymous user if you disable the authentication.";
			$response{status_code} = 500;			
			return \%response;
		}

		# check if user is valid?
		my $anon_user = EPrints::DataObj::User::user_with_username( $session, $ann_oneem );

                if(!defined $anon_user)
                {
			print STDERR "\n[SWORD] [INTERNAL-ERROR] The anonymous user does not exist on this repository.";
        		$response{status_code} = 500;
			return \%response;
		}

		$response{owner} = $anon_user;

		return \%response;
	}

	my $authen = EPrints::Apache::AnApache::header_in( $request, 'Authorization' );

        if(!defined $authen)
        {
		$response{status_code} = 401;
		$response{x_error_code} = "ErrorAuth";
		return \%response;
        }

	# Check we have Basic authentication sent in the headers, and decode the Base64 string:
        if($authen =~ /^Basic\ (.*)$/)
        {
                $authen = $1;
        }
        my $decode_authen = MIME::Base64::decode_base64( $authen );
        if(!defined $decode_authen)
        {
                $response{status_code} = 401;
		$response{x_error_code} = "ErrorAuth";
                return \%response;
        }

        my $username;
        my $password;

	if($decode_authen =~ /^(\w+)\:(\w+)$/)
        {
                $username = $1;
                $password = $2;
        }
        else
        {
                $response{status_code} = 401;
		$response{x_error_code} = "ErrorAuth";
                return \%response;
        }

        my $db = EPrints::Database->new( $session );

	if(!defined $db)
	{
		print STDERR "\n[SWORD] [INTERNAL-ERROR] Failed to open database.";
		$response{status_code} = 500;	#Internal Error
		return \%response;
	}

	# Does user exist in EPrints?
	if( ! $db->valid_login( $username, $password ) )
	{
                $response{status_code} = 401;
		$response{x_error_code} = "TargetOwnerUnknown";
                return \%response;
        }

        my $user = EPrints::DataObj::User::user_with_username( $session, $username );

	# This error could be a 500 Internal Error since the previous check ($db->valid_login) succeeded.
        if(!defined $user)
        {
                $response{status_code} = 401;
		$response{x_error_code} = "TargetOwnerUnknown";
                return \%response;
        }

	# Now check we have a behalf user set, and whether the mediated deposit is allowed
        my $xbehalf = EPrints::Apache::AnApache::header_in( $request, 'X-On-Behalf-Of' );
        if(defined $xbehalf)
        {
		my $behalf_user = EPrints::DataObj::User::user_with_username( $session, $xbehalf );

	        if(!defined $behalf_user)
		{
			$response{status_code} = 401;
			$response{x_error_code} = "TargetOwnerUnknown";
	                return \%response;
		}

		if(!can_user_behalf( $session, $user->get_value( "username" ), $behalf_user->get_value( "username" ) ))
		{
			$response{status_code} = 403;
			return \%response;
		}

		$response{depositor} = $user;
		$response{owner} = $behalf_user;
	}
	else
	{
		$response{owner} = $user;
	}

	return \%response;
}




sub process_headers
{
	my ( $session, $request ) = @_;

	my %response;

# first let's check some mandatory fields:

	# Content-Type	
	my $content_type = EPrints::Apache::AnApache::header_in( $request, 'Content-Type' );
        if(!defined $content_type)
        {
		$response{status_code} = 400;
		return \%response;
	}
	if( $content_type eq 'application/xml' )
	{
		$content_type = 'text/xml';
	}
        $response{content_type} = $content_type;

	# Content-Length
        my $content_len = EPrints::Apache::AnApache::header_in( $request, 'Content-Length' );
	
        if(!defined $content_len)
        {
		$response{status_code} = 400;
		return \%response;
	}

	$response{content_len} = $content_len;

	# Collection
	my $uri = $request->uri;

        my $collection;
	my $url;

# TODO more checks on the URI part
#	if( $uri =~ /^\/cgi\/app\/deposit\/(.*)$/ )       
	if( $uri =~ /^.*\/(.*)$/ )	
        {
                $collection = $1;
        }

	if(!defined $collection)
	{
		$response{status_code} = 400;	# Bad Request
		return \%response;
	}

	# Note that we don't check (here) if the collection exists or not in this repository
	$response{collection} = $collection;

# now we can parse the rest (or set default values if not found in headers):

	# Content-MD5	
        my $md5 = EPrints::Apache::AnApache::header_in( $request, 'Content-MD5' );

        if(defined $md5)
        {
		$response{md5} = $md5;
	}

	# Content-Disposition
	my $filename = EPrints::Apache::AnApache::header_in( $request, 'Content-Disposition' );

        if(defined $filename)
        {
		if( $filename =~ /^filename\=(.*)/)
		{
			$filename = $1;
		}

		$filename =~ s/\s/\_/g;		# replace white chars by underscores
		
		$response{filename} = $filename;
	}
	else
	{
		$response{filename} = "deposit";	# default value
	}

	# X-Verbose (NOT SUPPORTED)
        my $verbose = EPrints::Apache::AnApache::header_in( $request, 'X-Verbose' );

        if(defined $verbose)
        {
		$response{verbose} = 1 if(lc $verbose eq 'true');
	}

	# X-No-Op (NOT SUPPORTED)
	my $no_op = EPrints::Apache::AnApache::header_in( $request, 'X-No-Op' );

        if(defined $no_op)
        {
		$response{no_op} = 1 if(lc $no_op eq 'true');
	}

	# X-Format-Namespace
        my $format_ns = EPrints::Apache::AnApache::header_in( $request, 'X-Format-Namespace' );

        if(defined $format_ns)
        {
		$response{format_ns} = $format_ns;
	}
	else
	{
		$response{format_ns} = "http://eprints.org/ep2/data/2.0";	# eprints NS
	}

	# Slug
	my $slug = EPrints::Apache::AnApache::header_in( $request, 'Slug' );

        if(defined $slug)
        {
		$response{slug} = $slug;
	}

	return \%response;
}




sub can_user_behalf
{
	my ( $session, $username, $behalf_username ) = @_;

	my $allowed = $session->get_repository->get_conf( "sword", "allowed_mediation" );

	# test if ALL mediations are allowed
	my $all_allowed = $allowed->{'*'};
	if( defined $all_allowed )
	{
		return 1 if( $$all_allowed[0] eq '*' );
	}
	
	my $allmed = $$allowed{$username};	#allmed = allowed mediations

	if(!defined $allmed)
	{
		return 0;
	}

	foreach( @$allmed )
	{
		if($_ eq $behalf_username || $_ eq '*')
		{
			return 1;
		}
	}

	return 0;
}



sub is_collection_valid
{
	my ( $collection ) = @_;

	if( $collection eq 'inbox' || $collection eq 'buffer' || $collection eq 'archive' )
	{
		return 1;
	}

	return 0;
}



sub get_collections
{
	my ( $session ) = @_;

	my $coll_conf = $session->get_repository->get_conf( "sword","collections_conf" );
	
	my @mimes;
	my $mime_types = $session->get_repository->get_conf( "sword", "mime_types" );
	@mimes = keys %$mime_types if defined $mime_types;

	my @namespaces;
	my $supported_ns = $session->get_repository->get_conf( "sword", "importers" );
	@namespaces = keys %$supported_ns if defined $supported_ns;

	if(!defined $coll_conf)
	{
		return undef;
	}

	# parse the options
	
	my $c;
	my $coll_count = 0;
	foreach $c (keys %$coll_conf)
	{
		if( !is_collection_valid( $c ) )
		{
			delete $$coll_conf{$c};		# ignore this invalid collection...
			next;
		}
	
		my %conf = %{$$coll_conf{$c}};	
	
		$conf{title} = $c unless(defined $conf{title});
		$conf{sword_policy} = "" unless(defined $conf{sword_policy});
		$conf{dcterms_abstract} = "" unless(defined $conf{dcterms_abstract});
		$conf{treatment} = "" unless(defined $conf{treatment});
		$conf{mediation} = "true" unless(defined $conf{mediation});
		$conf{mediation} = "true" if(! ($conf{mediation} eq "true" || $conf{mediation} eq "false") );
	
		if(!defined $conf{accept_mime})
		{
			$conf{accept_mime} = \@mimes;	# that could still be empty...
		}

		if(!defined $conf{format_ns})
		{
			$conf{format_ns} = \@namespaces; # could still be empty
		}
		
		$$coll_conf{$c} = \%conf;
		$coll_count++;
	}

	if($coll_count == 0)
	{
                return undef;
	}

	return $coll_conf;
}



sub get_files_mime
{
	my ( $session, $f ) = @_;

	my $mimes = {};

	foreach(@$f)
	{
		if( -e $_ )	# does file exist?
                {
			# FileType defaults to 'application/octetstream', and always returns a MIME type.
			my $mime = EPrints::Sword::FileType::checktype_filename( $_ );
			$mimes->{$_} = $mime;
        	}
	}

        return $mimes;
}


sub get_file_to_import
{
	my ( $session, $files, $mime_type, $return_all ) = @_;

	my $mimes = get_files_mime( $session, $files );
        my @candidates;

	$return_all = 0 unless(defined $return_all);

	# some useful transformations to the correct MIME type:
	if( $mime_type eq 'application/xml' )
	{
		$mime_type = 'text/xml';
	}
	elsif( $mime_type eq 'application/x-zip' )
	{
		$mime_type = 'application/zip';
	}
	elsif( $mime_type eq 'application/x-zip-compressed' )
	{
		$mime_type = 'application/zip';
	}

        foreach(keys %$mimes)
        {
		if( $$mimes{$_} eq $mime_type )
                {
                        push @candidates, $_;
                }
        }

	# returns all matches
	if( $return_all )
	{
		return \@candidates if scalar @candidates > 0;
		return undef;
	}

	# othwerwise, returns only ONE match (or undef if there is no match, or more than one match)
        if( scalar @candidates != 1 )
        {
  		return undef;
        }

	return $candidates[0];

}



sub get_deposit_url
{
	my ( $session ) = @_;

	my $base_url = $session->get_repository->get_conf( "base_url" );

	return $base_url."/sword-app/deposit/";
}

sub get_collections_url
{
        my ( $session ) = @_;

        my $base_url = $session->get_repository->get_conf( "base_url" );

#	should be /app/collections/
        return $base_url."/sword-app/collections/";
}




1;
