######################################################################
#
# EPrints::Sword::Utils
#
######################################################################
#
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  This file is part of GNU EPrints 3.
#  
#  Copyright (c) 2000-2008 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 3 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 3 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 3; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

package EPrints::Sword::Utils;

use strict;
use warnings;

#use EPrints::Sword::FileType;
use MIME::Base64;

sub authenticate
{
	my ( $handle, $request ) = @_;

	my %response;

	my $authen = EPrints::Apache::AnApache::header_in( $request, 'Authorization' );

	$response{verbose_desc} = "";

        if(!defined $authen)
        {
		$response{error} = { 	
					status_code => 401, 
					x_error_code => "ErrorAuth",
					error_href => "http://eprints.org/sword/error/ErrorAuth",
					no_auth => 1, 
				   };

		$response{verbose_desc} .= "[ERROR] No authentication found in the headers.\n";
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
		$response{error} = { 	
					status_code => 401, 
					x_error_code => "ErrorAuth",
					error_href => "http://eprints.org/sword/error/ErrorAuth",
				   };
		$response{verbose_desc} .= "[ERROR] Authentication failed (invalid base64 encoding).\n";
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
		$response{error} = { 	
					status_code => 401, 
					x_error_code => "ErrorAuth",
					error_href => "http://eprints.org/sword/error/ErrorAuth",
				   };
		$response{verbose_desc} .= "[ERROR] Authentication failed (invalid base64 encoding).\n";
                return \%response;
        }

	unless( $handle->valid_login( $username, $password ) )
	{
		$response{error} = {
					status_code => 401, 
					x_error_code => "ErrorAuth",
					error_href => "http://eprints.org/sword/error/ErrorAuth",
				   };
		$response{verbose_desc} .= "[ERROR] Authentication failed.\n";
                return \%response;
        }

        my $user = EPrints::DataObj::User::user_with_username( $handle, $username );

	# This error could be a 500 Internal Error since the previous check ($db->valid_login) succeeded.
        if(!defined $user)
        {
		$response{error} = {
					status_code => 401, 
					x_error_code => "ErrorAuth",
					error_href => "http://eprints.org/sword/error/ErrorAuth",
				   };
		$response{verbose_desc} .= "[ERROR] Authentication failed.\n";
                return \%response;
        }

	# Now check we have a behalf user set, and whether the mediated deposit is allowed
        my $xbehalf = EPrints::Apache::AnApache::header_in( $request, 'X-On-Behalf-Of' );
        if(defined $xbehalf)
        {
		my $behalf_user = EPrints::DataObj::User::user_with_username( $handle, $xbehalf );

	        if(!defined $behalf_user)
		{
			$response{error} = {
					status_code => 401, 
					x_error_code => "TargetOwnerUnknown",
					error_href => "http://purl.org/net/sword/error/TargetOwnerUnknown",
				   };

			$response{verbose_desc} .= "[ERROR] Unknown user for mediation: '".$xbehalf."'\n";
	                return \%response;
		}

		if(!can_user_behalf( $handle, $user->get_value( "username" ), $behalf_user->get_value( "username" ) ))
		{
			$response{error} = {
					status_code => 403, 
					x_error_code => "TargetOwnerUnknown",
					error_href => "http://eprints.org/sword/error/MediationForbidden",
				   };
			$response{verbose_desc} .= "[ERROR] The user '".$user->get_value( "username" )."' cannot deposit on behalf of user '".$behalf_user->get_value("username")."'\n";
			return \%response;
		}

		$response{depositor} = $user;
		$response{owner} = $behalf_user;
	}
	else
	{
		$response{owner} = $user;
	}

	$response{verbose_desc} .= "[OK] Authentication successful.\n";

	return \%response;
}


sub process_headers
{
	my ( $handle, $request ) = @_;

	my %response;

	# X-Verbose
        my $verbose = EPrints::Apache::AnApache::header_in( $request, 'X-Verbose' );
	$response{x_verbose} = 0;
	$response{verbose_desc} = "";

        if(defined $verbose)
        {
		$response{x_verbose} = 1 if(lc $verbose eq 'true');
	}

	# Content-Type	
	my $content_type = EPrints::Apache::AnApache::header_in( $request, 'Content-Type' );
        if(!defined $content_type)
        {
		$response{error} = {
					status_code => 400,
					error_href => "http://eprints.org/sword/error/ContentTypeNotSet"
				   };

		$response{verbose_desc} .= "[ERROR] Content-Type not set.\n";
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
		$response{error} = {
					status_code => 400,
					error_href => "http://eprints.org/sword/error/ContentLengthNotSet"
				   };

		$response{verbose_desc} .= "[ERROR] Content-Length not set.\n";
		return \%response;
	}

	$response{content_len} = $content_len;

	# Collection
	my $uri = $request->uri;

        my $collection;
	my $url;

	if( $uri =~ /^.*\/(.*)$/ )	
        {
                $collection = $1;
        }

	if(!defined $collection)
	{
		$response{error} = {
					status_code => 400,
					error_href => "http://eprints.org/sword/error/TargetCollectionNotSet"
				   };
		$response{verbose_desc} .= "[ERROR] Collection not set.\n";
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


	# X-No-Op
	my $no_op = EPrints::Apache::AnApache::header_in( $request, 'X-No-Op' );
	$response{no_op} = 0;

        if(defined $no_op)
        {
		$response{no_op} = 1 if((lc $no_op) eq 'true');
	}


	# X-Format-Namespace: obsolete field from SWORD 1.2
        my $format_ns = EPrints::Apache::AnApache::header_in( $request, 'X-Format-Namespace' );

        if(defined $format_ns)
        {
		$response{format_ns} = $format_ns;
		$response{verbose_desc} .= "[WARNING] X-Format-Namespace is obsolete: X-Packaging should be used instead.";
	}

	my $xpackaging = EPrints::Apache::AnApache::header_in( $request, 'X-Packaging' );

	if( defined $xpackaging)
	{
		$response{x_packaging} = $xpackaging;
	}
	else
	{
		if( defined $format_ns )
		{
			$response{x_packaging} = $format_ns;
			$response{verbose_desc} .= "[WARNING] Using X-Format-Namespace instead of X-Packaging.";
		}

	}

	# Slug
	if( defined EPrints::Apache::AnApache::header_in( $request, 'Slug' ) )
	{
		$response{verbose_desc} .= "[WARNING] 'Slug' header is obsolete and will not be saved.";
	}


	# userAgent
	my $user_agent = EPrints::Apache::AnApache::header_in( $request, 'User-Agent' );

        if(defined $user_agent)
        {
		$response{user_agent} = $user_agent;
	}

	$response{verbose_desc} .= "[OK] HTTP Headers processed successfully.\n";

	return \%response;
}




sub can_user_behalf
{
	my ( $handle, $username, $behalf_username ) = @_;

	my $allowed = $handle->get_repository->get_conf( "sword", "allowed_mediations" );

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



sub is_collection_valid_OBSOLETE_METHOD
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
	my ( $handle ) = @_;

	my $coll_conf = $handle->get_repository->get_conf( "sword","collections" );
	return undef unless(defined $coll_conf);
	
	my $mime_types = $handle->get_repository->get_conf( "sword", "accept_mime_types" );
	my $packages = $handle->get_repository->get_conf( "sword", "supported_packages" );

	my $coll_count = 0;
	foreach my $c (keys %$coll_conf)
	{

		my $conf = $coll_conf->{$c};
	
		$conf->{title} = $c unless(defined $conf->{title});
		$conf->{sword_policy} = "" unless(defined $conf->{sword_policy});
		$conf->{dcterms_abstract} = "" unless(defined $conf->{dcterms_abstract});
		$conf->{treatment} = "" unless(defined $conf->{treatment});
		$conf->{mediation} = "true" unless(defined $conf->{mediation});
		$conf->{mediation} = "true" if(! ($conf->{mediation} eq "true" || $conf->{mediation} eq "false") );

		# mime types might be redefined locally for a specific collection:
		$conf->{mime_types} = defined $conf->{accept_mime_types} ? $conf->{accept_mime_types} : $mime_types;
		delete $conf->{accept_mime_types};
		$conf->{packages} = $packages;
	
		$coll_conf->{$c} = $conf;
		$coll_count++;
	}

	return undef unless( $coll_count );

	return $coll_conf;
}


sub is_mime_allowed
{
	my ( $allowed, $mime ) = @_;

	foreach( @$allowed )
	{
		return 1 if( $_ eq '*/*' );
		return 1 if( $_ eq $mime );
	}
	
	return 0;
}


sub get_files_mime_OBSOLETE_METHOD
{
	my ( $handle, $f ) = @_;

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


sub get_file_to_import_OBSOLETE_METHOD
{
	my ( $handle, $files, $mime_type, $return_all ) = @_;


print STDERR "\nWARNING Sword::FileType::get_file_to_import was called!!";


	my $mimes = get_files_mime( $handle, $files );
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


sub get_atom_url
{
	my ( $handle, $eprint ) = @_;
	return $handle->get_repository->get_conf( "base_url" )."/sword-app/atom/".$eprint->get_id.".atom";
}



sub get_deposit_url
{
	my ( $handle ) = @_;
	return $handle->get_repository->get_conf( "base_url" )."/sword-app/deposit/"
}

sub get_collections_url
{
        my ( $handle ) = @_;
        return $handle->get_repository->get_conf( "base_url" )."/id/eprint/";
}




# other helper functions:
sub generate_error_document
{
        my ( $handle, %opts ) = @_;

        my $error = $handle->make_element( "sword:error", "xmlns:atom" => "http://www.w3.org/2005/Atom",
                                                           "xmlns:sword" => "http://purl.org/net/sword/" );

	$opts{href} = "http://eprints.org/sword/error/UnknownError" unless( defined $opts{href} );
	$error->setAttribute( "href", $opts{href} );

        my $title = $handle->make_element( "atom:title" );
        $title->appendChild( $handle->make_text( "ERROR" ) );
        $error->appendChild( $title );

        my $updated = $handle->make_element( "atom:updated" );
        $updated->appendChild( $handle->make_text( EPrints::Time::get_iso_timestamp() ) );
        $error->appendChild( $updated );

        my $source_gen = $handle->get_repository->get_conf( "sword", "service_conf" )->{generator};
        unless( defined $source_gen )
        {
                $source_gen = $handle->phrase( "archive_name" )." [".$handle->get_repository->get_conf( "version_id" )."]";
        }

        my $generator = $handle->make_element( "atom:generator" );
        $generator->setAttribute( "uri", $handle->get_repository->get_conf( "base_url" ) );
        $generator->setAttribute( "version", "1.3" );
        $generator->appendChild($handle->make_text( $source_gen ) );
        $error->appendChild( $generator );

	my $summary = $handle->make_element( "atom:summary" );
	$error->appendChild( $summary );

	if( defined $opts{summary} )
        {
                $summary->appendChild( $handle->make_text( $opts{summary} ) );
        }

        if( defined $opts{verbose_desc} )
        {
                my $desc = $handle->make_element( "sword:verboseDescription" );
                $desc->appendChild( $handle->make_text( $opts{verbose_desc} ) );
                $error->appendChild( $desc );
        }

	if( defined $opts{user_agent} )
	{
                my $sword_agent = $handle->make_element( "sword:userAgent" );
                $sword_agent->appendChild( $handle->make_text( $opts{user_agent} ) );
                $error->appendChild( $sword_agent );
        }

        EPrints::XML::tidy( $error );

        return '<?xml version="1.0" encoding="UTF-8"?>'.$error->toString();
}


sub create_xml
{
        my ( $handle, %opts ) = @_;

        my $eprint = $opts{eprint};
        my $owner = $opts{owner};
        my $depositor = $opts{depositor};
	my $deposited_file_docid = $opts{deposited_file_docid};

        # ENTRY
        my $entry = $handle->make_element( "atom:entry", "xmlns:atom" => "http://www.w3.org/2005/Atom",
                                        "xmlns:sword" => "http://purl.org/net/sword/" );

        # TITLE
        my $eptitle = $eprint->get_value( "title" );
        $eptitle = "UNSPECIFIED" unless defined( $eptitle );

        my $title = $handle->make_element( "atom:title" );
        $title->appendChild( $handle->make_text( $eptitle ) );
        $entry->appendChild( $title );

        # ID
        my $uid = $handle->make_element( "atom:id" );
        $uid->appendChild( $handle->make_text( $eprint->get_id ) );
        $entry->appendChild( $uid );

        # UPDATED
	my $time_updated;
        my $lastmod = $eprint->get_value( "lastmod" );
        if( defined $lastmod && $lastmod =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})$/ )
        {
                $time_updated = "$1T$2Z";
        }
        else
        {
                $time_updated =  EPrints::Time::get_iso_timestamp();
        }

        my $updated = $handle->make_element( "atom:updated" );
        $updated->appendChild( $handle->make_text( $time_updated ) );
        $entry->appendChild( $updated );
        
	my $time_pub;
	my $datestamp = $eprint->get_value( "datestamp" );
        if( defined $datestamp && $datestamp =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})$/ )
        {
                $time_pub = "$1T$2Z";
        }
        else
        {
		$time_pub = $time_updated;
        }
        
	my $published = $handle->make_element( "atom:published" );
        $published->appendChild( $handle->make_text( $time_pub ) );
        $entry->appendChild( $published );


        # AUTHOR/CONTRIBUTOR
	if( defined $depositor )
        {
                my $author = $handle->make_element( "atom:author" );
                my $name = $handle->make_element( "atom:name" );
                $name->appendChild( $handle->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                my $email_tag;
                if( defined $author_email )
                {
                        $email_tag = $handle->make_element( "atom:email" );
                        $email_tag->appendChild( $handle->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );

                my $contributor = $handle->make_element( "atom:contributor" );
                my $name2 = $handle->make_element( "atom:name" );
                $name2->appendChild( $handle->make_text( $depositor->get_value( "username" ) ) );
                $contributor->appendChild( $name2 );
                my $contrib_email = $depositor->get_value( "email" );
                if( defined $contrib_email )
                {
                        $email_tag = $handle->make_element( "atom:email" );
                        $email_tag->appendChild( $handle->make_text( $contrib_email ) );
                        $contributor->appendChild( $email_tag );
                }
                $entry->appendChild( $contributor );
        }
        else
        {
                my $author = $handle->make_element( "atom:author" );
                my $name = $handle->make_element( "atom:name" );
                $name->appendChild( $handle->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                if( defined $author_email )
                {
                        my $email_tag = $handle->make_element( "atom:email" );
                        $email_tag->appendChild( $handle->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );
        }

        # SUMMARY
	my $summary = $handle->make_element( "atom:summary", "type" => "text" );
	$entry->appendChild( $summary );
	my $abstract = $eprint->get_value( "abstract" );
        if( defined $abstract && length $abstract > 100 )        # display 100 characters max for the abstract
        {
                $abstract = substr( $abstract, 0, 96 );
                $abstract .= "...";
                $summary->appendChild( $handle->make_text( $abstract ) );
        }

	# if docid is defined, <content> should point to that document, otherwise point to the abstract page
	my $content;
	if( defined $deposited_file_docid )
	{
		my $doc = EPrints::DataObj::Document->new( $handle, $deposited_file_docid );
	
		if( defined $doc )
		{
			$content = $handle->make_element( "atom:content", 
							"type" => $doc->get_value( "format" ),
							"src" => $doc->uri );
		}		
	}

	unless( defined $content )
	{
		$content = $handle->make_element( "atom:content", "type" => "text/html", src=> $eprint->uri )
	}
        $entry->appendChild( $content );

	my $edit_link = $handle->make_element( "atom:link", 
					"rel" => "edit",
					"href" => EPrints::Sword::Utils::get_atom_url( $handle, $eprint ) );

	$entry->appendChild( $edit_link );


        # SOURCE GENERATOR
	my $source_gen = $handle->get_repository->get_conf( "sword", "service_conf" )->{generator};
	unless( defined $source_gen )
	{
	        $source_gen = $handle->phrase( "archive_name" )." [".$handle->get_repository->get_conf( "version_id" )."]";
	}

        my $generator = $handle->make_element( "atom:generator" );
        $generator->setAttribute( "uri", $handle->get_repository->get_conf( "base_url" ) );
	$generator->setAttribute( "version", "1.3" );
        $generator->appendChild($handle->make_text( $source_gen ) );
        $entry->appendChild( $generator );


        # VERBOSE
        if(defined $opts{verbose_desc})
        {
                my $sword_verbose = $handle->make_element( "sword:verboseDescription" );
                $sword_verbose->appendChild( $handle->make_text( $opts{verbose_desc} ) );
                $entry->appendChild( $sword_verbose );
        }


        # SWORD TREATMEMT
	my $sword_treat = $handle->make_element( "sword:treatment" );
        $sword_treat->appendChild( $handle->make_text( $opts{sword_treatment} ) );
        $entry->appendChild( $sword_treat );


	if( defined $opts{x_packaging} )
	{
		my $sword_xpack = $handle->make_element( "sword:packaging" );
		$sword_xpack->appendChild( $handle->make_text( $opts{x_packaging} ) );
		$entry->appendChild( $sword_xpack );
	}

	if(defined $opts{user_agent})
        {
                my $sword_agent = $handle->make_element( "sword:userAgent" );
                $sword_agent->appendChild( $handle->make_text( $opts{user_agent} ) );
                $entry->appendChild( $sword_agent );
        }
	
	my $sword_noop = $handle->make_element( "sword:noOp" );
	$sword_noop->appendChild( $handle->make_text( "false" ) );
	$entry->appendChild( $sword_noop );

	EPrints::XML::tidy( $entry );
	
        return '<?xml version="1.0" encoding="UTF-8"?>'.$entry->toString;

}


# the XML sent when performing a No-Op operation
sub create_noop_xml
{
        my ( $handle, %opts ) = @_;

        my $sword_treatment = $opts{sword_treatment};
        my $owner = $opts{owner};
        my $depositor = $opts{depositor};
        my $verbose = $opts{verbose_desc};

        # ENTRY
        my $entry = $handle->make_element( "atom:entry", "xmlns:atom" => "http://www.w3.org/2005/Atom",
                                        "xmlns:sword" => "http://purl.org/net/sword/" );

        # UPDATED
        my $time_updated = EPrints::Time::get_iso_timestamp();
        my $updated = $handle->make_element( "atom:updated" );
        $updated->appendChild( $handle->make_text( $time_updated ) );
        $entry->appendChild( $updated );

        my $published = $handle->make_element( "atom:published" );
        $published->appendChild( $handle->make_text( $time_updated ) );
        $entry->appendChild( $published );

        # AUTHOR/CONTRIBUTOR
	if( defined $depositor )
        {
                my $author = $handle->make_element( "atom:author" );
                my $name = $handle->make_element( "atom:name" );
                $name->appendChild( $handle->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                my $email_tag;
                if( defined $author_email )
                {
                        $email_tag = $handle->make_element( "atom:email" );
                        $email_tag->appendChild( $handle->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );

                my $contributor = $handle->make_element( "atom:contributor" );
                my $name2 = $handle->make_element( "atom:name" );
                $name2->appendChild( $handle->make_text( $depositor->get_value( "username" ) ) );
                $contributor->appendChild( $name2 );
                my $contrib_email = $depositor->get_value( "email" );
                if( defined $contrib_email )
                {
                        $email_tag = $handle->make_element( "atom:email" );
                        $email_tag->appendChild( $handle->make_text( $contrib_email ) );
                        $contributor->appendChild( $email_tag );
                }
                $entry->appendChild( $contributor );
        }
        else
        {
                my $author = $handle->make_element( "atom:author" );
                my $name = $handle->make_element( "atom:name" );
                $name->appendChild( $handle->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                if( defined $author_email )
                {
                        my $email_tag = $handle->make_element( "atom:email" );
                        $email_tag->appendChild( $handle->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );
        }

        # SOURCE GENERATOR
	my $source_gen = $handle->get_repository->get_conf( "sword", "service_conf" )->{generator};
        $source_gen = $handle->phrase( "archive_name" ) unless(defined $source_gen);

        my $source = $handle->make_element( "atom:source" );
        my $generator = $handle->make_element( "atom:generator" );
        $generator->setAttribute( "uri", $handle->get_repository->get_conf( "base_url" ) );
        $generator->appendChild($handle->make_text( $source_gen ) );
        $source->appendChild( $generator );
        $entry->appendChild( $source );

        #VERBOSE (if defined)
       if(defined $verbose)
        {
                my $sword_verbose = $handle->make_element( "sword:verboseDescription" );
                $sword_verbose->appendChild( $handle->make_text( $verbose ) );
                $entry->appendChild( $sword_verbose );
        }

        # SWORD TREATMEMT
	my $sword_treat = $handle->make_element( "sword:treatment" );
        $sword_treat->appendChild( $handle->make_text( $sword_treatment ) );
        $entry->appendChild( $sword_treat );


	if( defined $opts{x_packaging} )
	{
		my $sword_xpack = $handle->make_element( "sword:packaging" );
		$sword_xpack->appendChild( $handle->make_text( $opts{x_packaging} ) );
		$entry->appendChild( $sword_xpack );
	}

        # USER AGENT (if set)
	if(defined $opts{user_agent})
        {
                my $sword_agent = $handle->make_element( "sword:userAgent" );
                $sword_agent->appendChild( $handle->make_text( $opts{user_agent} ) );
                $entry->appendChild( $sword_agent );
        }
	
	my $sword_noop = $handle->make_element( "sword:noOp" );
	$sword_noop->appendChild( $handle->make_text( "true" ) );
	$entry->appendChild( $sword_noop );

	my $sword_summ = $handle->make_element( "atom:summary" );
	$entry->appendChild( $sword_summ );

	EPrints::XML::tidy( $entry );

        return '<?xml version="1.0" encoding="UTF-8"?>'.$entry->toString;

}

        
1;

