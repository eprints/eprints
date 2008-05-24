######################################################################
#
# EPrints::Sword::DepositHandler
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
#	This handler manages deposits made through SWORD.
# 	
# METHODS:
#
# handler( $request ):	
#	Apache/mod_perl handler. 	
#
# unpack_files():
# 	Internal method called by the handler to unpack files.
#
# create_xml():
# 	Internal method which creates the XML provided in the answer. 	
#
#####################################################################

package EPrints::Sword::DepositHandler;

use strict;
use warnings;
 
use Digest::MD5;

use EPrints;
use EPrints::Sword::Utils;
 
use Apache2::RequestRec ();
use Apache2::RequestIO ();


sub handler 
{
	my $request = shift;

	my $session = new EPrints::Session;
	if(! defined $session )
	{
		print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Could not create session object.";
		$request->status( 500 );
		return Apache2::Const::DONE;
	}

	# using EPrints::Sword::Utils to authenticate (and check if mediation is allowed)
	my $response = EPrints::Sword::Utils::authenticate( $session, $request );

 	# status_code is set when there is an error
	if( defined $response->{status_code} )
        {
                if( defined $response->{x_error_code} )
                {
                        $request->headers_out->{'X-Error-Code'} = $response->{x_error_code};
                }

                if( $response->{status_code} == 401 )
                {
                        $request->headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
                }

                $request->status( $response->{status_code} );

                $session->terminate;
                return Apache2::Const::DONE;
        }

	my $owner = $response->{owner};
	# $depositor will be undef is this is not a mediated deposit
	my $depositor = $response->{depositor};

	# Processing HTTP headers in order to retrieve SWORD options
	my $headers = EPrints::Sword::Utils::process_headers( $session, $request );

	if(defined $headers->{status_code})
	{
                if( defined $headers->{x_error_code} )
                {
                        $request->headers_out->{'X-Error-Code'} = $response->{x_error_code};
                }

                if( $headers->{status_code} == 401 )
                {
                        $request->headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
                }

                $request->status( $headers->{status_code} );

                $session->terminate;
                return Apache2::Const::DONE;
	}

	# Check that the collection exists on this repository:
	my $target_collection = $headers->{collection};
	my $collections = EPrints::Sword::Utils::get_collections( $session );
	
	my $collec_conf = $collections->{$target_collection};

	if(!defined $collec_conf)
	{
		# NOTE: 'UnknownCollection' is not specified by SWORD
		$request->headers_out->{'X-Error-Code'} = 'UnknownCollection';
		$request->status( 400 );
		$session->terminate; 	
		return Apache2::Const::DONE;
	}

	# Allow Mediations by default:
	my $allow_mediation = 1;

	# Unless this is disabled in the conf:
	if(defined $collec_conf->{mediation} && lc $collec_conf->{mediation} eq 'false')
	{
		$allow_mediation = 0;
	}
	
	if( defined $depositor && !$allow_mediation )	
	{
		$request->headers_out->{'X-Error-Code'} = 'MediationNotAllowed';
		$request->status( 403 );
		$session->terminate;
		return Apache2::Const::DONE;
	}
	
	# Saving the data/file sent through POST
        my $postdata = $session->{query}->{'POSTDATA'};

        if( !defined $postdata || scalar @$postdata < 1 )
        {
		$request->headers_out->{'X-Error-Code'} = 'ErrorBadRequest';
		$request->status( 400 );
		$session->terminate;
		return Apache2::Const::DONE;
        }

        my $post = $$postdata[0];

	# Check the MD5 we received is correct
	if(defined $headers->{md5})
	{
                my $real_md5 = Digest::MD5::md5_hex( $post );
                if( $real_md5 ne $headers->{md5} )
                {
			$request->headers_out->{'X-Error-Code'} = 'ErrorChecksumMismatch';
			$request->status( 412 );
			$session->terminate;
			return Apache2::Const::DONE;
                }
	}

	# Create a temp directory which will be automatically removed by EPrints
	# NOTE: TEMPLATE 'swordXXX' does not seem to work (but it doesn't matter)
	my $tmp_dir = EPrints::TempDir->new( "swordXXX", UNLINK => 1 );	
 
	if( !defined $tmp_dir )
        {
                print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp directory!";
		$request->status( 500 );
		$session->terminate;
                return Apache2::Const::DONE;
        }

	# Save post data to file
	my $file = $tmp_dir.'/'.$headers->{filename};

        if (open( TMP, '+>'.$file ))
        {
                print TMP $post;
                close(TMP);
        }
        else
	{
		print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp file because: $!";
		$request->status( 500 );
		$session->terminate;
		return Apache2::Const::DONE;
	}

	# now call to the appropriate Sword::Unpack plugin
        my $supported_mime = $session->get_repository->get_conf( "sword", "mime_types");

        if(!defined $supported_mime)
        {
		print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] No supported MIME types found. Hint: configure sword.pl.";
		$request->status( 500 );
		$session->terminate;
                return Apache2::Const::OK;
        }

        my $unpack_pluginid = $$supported_mime{$headers->{content_type}};

        if(!defined $unpack_pluginid)
	{
		$request->headers_out->{'X-Error-Code'} = 'ErrorContent';
		$request->status( 415 );	# Unsupported media type
		$session->terminate;
		return Apache2::Const::DONE;
	}

	
	# Check if we're doing a direct import. In this case, no need to unpack the file.
	my $direct_import = $unpack_pluginid->{direct_import};

	my @files;
	my $import_pluginid;

	if( $direct_import )
	{
		push @files, $file;
		$import_pluginid = $unpack_pluginid->{plugin};
	}
	else
	{

		my $response = unpack_files( $session, $unpack_pluginid->{plugin}, $tmp_dir, $headers->{filename} );

		if( defined $response->{status_code} )
		{
			$request->status( $response->{status_code} );
			$session->terminate;
			return Apache2::Const::DONE;
		}

		@files = @{ $response->{files} };

		# then look for a Sword::Import plugin (if direct import, we already know the name of the Import plugin)
	        my $supported_import = $session->get_repository->get_conf( "sword", "importers" );

        	if(!defined $supported_import)
	        {
	                print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] No Supported namespaces defined. Hint: configure sword.pl.";
        	        $request->status( 500 );    # Internal Error! At least one Namespace should be defined and supported
			$session->terminate;
			return Apache2::Const::DONE;
	        }

	       	$import_pluginid = $$supported_import{$headers->{format_ns}};

	        if(!defined $import_pluginid)
	        {
			$request->status( 415 );
			$request->headers_out->{'X-Error-Code'} = 'ErrorContent';
			$session->terminate;
                	return Apache2::Const::DONE;
	        }

	}

        my $import_plugin = $session->plugin( $import_pluginid );

	if(!defined $import_plugin)
	{
		print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to load the plugin ".$import_pluginid;
		$request->status( 500 );
		$session->terminate;
		return Apache2::Const::DONE;
	}

	my $new_eprintid;
	my %opts;

	# The directory where files will be unpacked to (if needed)
	$opts{dir} = $tmp_dir."/content";
	$opts{files} = \@files;
	$opts{dataset_id} = $target_collection;
	$opts{owner_id} = $owner->get_id;
	$opts{depositor_id} = $depositor->get_id if(defined $depositor);
	
	# Call to the import plugin
	$new_eprintid = $import_plugin->input_file( %opts );

	if(!defined $new_eprintid)
        {
		$request->status( 400 );	# Bad Request
		$session->terminate;
                return Apache2::Const::DONE;
        }

        my $eprint = EPrints::DataObj::EPrint->new( $session, $new_eprintid );

        if(!defined $eprint)
        {
                print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to open the newly created eprint!";
		$request->status( 500 );
		$session->terminate;
                return Apache2::Const::OK;
        }

	my $slug = $headers->{slug};
	if(defined $slug)
	{
		$eprint->set_value( "sword_slug", $slug );
		$eprint->commit;
	}

	# By default we keep the deposited files
	my $keep_deposited_file = 1;

	# Unless we are doing a direct import of the file, or it is disabled in the conf file
	if($direct_import || (defined $session->get_repository->get_conf( "sword", "keep_deposited_file" ) && $session->get_repository->get_conf( "sword", "keep_deposited_file" ) == 0)) 
	{
		$keep_deposited_file = 0;
	}

	# Attach the file sent via POST to the newly created EPrint
	if( $keep_deposited_file )
	{
		my %doc_data;
		$doc_data{eprintid} = $new_eprintid;
		$doc_data{format} =  $headers->{content_type};
		$doc_data{formatdesc} = $session->phrase( "Sword/Deposit:document_formatdesc" );
		$doc_data{main} = $headers->{filename};

		my %file_data;
		$file_data{filename} = $headers->{filename};
		$file_data{data} = $file;

		$doc_data{files} = [ \%file_data ];

		my $doc_dataset = $session->get_repository->get_dataset( "document" );

		my $document = EPrints::DataObj::Document->create_from_data( $session, \%doc_data, $doc_dataset );

		if(!defined $document)
		{
			print STDERR "\n[SWORD-DEPOSIT] [ERROR] Failed to add the original file to the eprint.";
		}
		else
		{
			$document->make_thumbnails;
			$eprint->generate_static;
		}


	}

        my $sword_treatment = "";

        if(defined $collec_conf->{treatment})
        {
                $sword_treatment = $collec_conf->{treatment};
        }

	# $xml will contain the XML fragment for the reply, never undef.
	my $xml;

	my %xml_opts;
	$xml_opts{eprint} = $eprint;
	$xml_opts{headers} = $headers;
	$xml_opts{sword_treatment} = $sword_treatment;

	$xml_opts{owner} = $owner;
	$xml_opts{depositor} = $depositor if( defined $depositor );

	$xml = create_xml( $session, %xml_opts );

	my $xmlsize = length $xml;

	$request->headers_out->{'Content-Length'} = "$xmlsize";

	my $collec_url = EPrints::Sword::Utils::get_collections_url( $session );

	$request->headers_out->{'Location'} = $collec_url."/".$eprint->get_id.".atom";
	
	$request->content_type('application/atom+xml');
	$request->status( 201 );	# Created

	$request->print( $xml );

	return Apache2::Const::OK;
}





sub unpack_files
{
	my ( $session, $plugin_id, $dir, $fn ) = @_;

	my $response = {};
	my $unpack_plugin = $session->plugin( $plugin_id );

	if(!defined $unpack_plugin)
	{
        	print STDER "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to load plugin ".$plugin_id;
		$response->{status_code} = 500;
		return $response;
	}

	my %opts;
	$opts{dir} = $dir."/content";
	$opts{filename} = $dir."/".$fn;

	my $files = $unpack_plugin->export( %opts );

	# test if the unpack plugin succeeded 
	if( !defined $files )		
        {
		$response->{status_code} = 400;		# 400 Bad Request
		return $response;
	}

        # add the full path to each files: (eg file.xml => /tmp/eprints12345/content/file.xml)
	for(my $i = 0; $i < scalar @$files; $i++)
       {
        	next if $$files[$i] =~ /^\//;            # unless it already contains the full path
        	$$files[$i] = $dir."/content/".$$files[$i];
        }
               
	$response->{files} = $files;
 
	return $response; 

}




sub create_xml
{
	my ( $session, %opts ) = @_;

	my $eprint = $opts{eprint};
	my $headers = $opts{headers};
	my $sword_treatment = $opts{sword_treatment};
	my $owner = $opts{owner};
	my $depositor = $opts{depositor};

	my $content_type = $headers->{content_type};
	my $format_ns = $headers->{format_ns};
	my $filename = $headers->{filename};
	my $slug = $headers->{slug};	

	# ENTRY
        my $entry = $session->make_element( "entry", "xmlns" => "http://www.w3.org/2005/Atom", 
					"xmlns:sword" => "http://purl.org/net/sword/" );

	# TITLE
        my $eptitle = $eprint->get_value( "title" );
	$eptitle = "UNSPECIFIED" unless defined( $eptitle );

        my $title = $session->make_element( "title" );
        $title->appendChild( $session->make_text( $eptitle ) );
        $entry->appendChild( $title );

	# ID	( or SLUG => at the mo, the Slug value is kept in the db, but not shown in the answer )
	my $epid = $eprint->get_id();
	my $uid = $session->make_element( "id" );
	$uid->appendChild( $session->make_text( $epid ) );
	$entry->appendChild( $uid );

	# UPDATED
	my $time_updated;
        my $datestamp = $eprint->get_value( "datestamp" );
        if( defined $datestamp && $datestamp =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})$/ )
        {
        	$time_updated = "$1T$2Z";
        }
        else
        {
                $time_updated =  EPrints::Time::get_iso_timestamp();
       	}

        my $updated = $session->make_element( "updated" );
        $updated->appendChild( $session->make_text( $time_updated ) );
        $entry->appendChild( $updated );

	# AUTHOR/CONTRIBUTOR
	if( defined $depositor )
	{
	        my $author = $session->make_element( "author" );
	        my $name = $session->make_element( "name" );
		$name->appendChild( $session->make_text( $owner->get_value( "username" ) ) );
	        $author->appendChild( $name );
		my $author_email = $owner->get_value( "email" );
		my $email_tag;
		if( defined $author_email )
		{
			$email_tag = $session->make_element( "email" );
			$email_tag->appendChild( $session->make_text( $author_email ) );
			$author->appendChild( $email_tag );
		}
	        $entry->appendChild( $author );

                my $contributor = $session->make_element( "contributor" );
                my $name2 = $session->make_element( "name" );
		$name2->appendChild( $session->make_text( $depositor->get_value( "username" ) ) );                
                $contributor->appendChild( $name2 );
		my $contrib_email = $depositor->get_value( "email" );
		if( defined $contrib_email )
		{
			$email_tag = $session->make_element( "email" );
                        $email_tag->appendChild( $session->make_text( $contrib_email ) );
                        $contributor->appendChild( $email_tag );
		}
                $entry->appendChild( $contributor );
	}
	else
	{
	        my $author = $session->make_element( "author" );
	        my $name = $session->make_element( "name" );
		$name->appendChild( $session->make_text( $owner->get_value( "username" ) ) );	        
	        $author->appendChild( $name );
		my $author_email = $owner->get_value( "email" );
		if( defined $author_email )
		{
			my $email_tag = $session->make_element( "email" );
        	        $email_tag->appendChild( $session->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
		}
	        $entry->appendChild( $author );
	}

	# SUMMARY
	my $abstract = $eprint->get_value( "abstract" );
	if( defined $abstract && length $abstract > 50 )	# display 50 characters max for the abstract
	{
		$abstract = substr( $abstract, 0, 47 );
		$abstract .= "...";
	
		my $summary = $session->make_element( "summary", "type" => "text" );
		$summary->appendChild( $session->make_text( $abstract ) );
		$entry->appendChild( $summary );
	}

	my $collec_url = EPrints::Sword::Utils::get_collections_url( $session );

	# CONTENT
        my $content = $session->make_element( "content", "type" => $content_type,
	                                         "src" => $collec_url.$epid."/".$filename );
        $entry->appendChild( $content );


	# EDIT-MEDIA
        my $link1 = $session->make_element( "link", "rel" => "edit-media",
						"href" => $collec_url.$epid ); 
       $entry->appendChild( $link1 );

	# EDIT
        my $link2 = $session->make_element( "link", "rel" => "edit",
						"href" => $collec_url.$epid.".atom" );
        $entry->appendChild( $link2 );


	# SOURCE GENERATOR 
	my $source_gen = $session->get_repository->get_conf( "sword", "service_conf" )->{generator};
	$source_gen = $session->phrase( "archive_name" ) unless(defined $source_gen);

	my $source = $session->make_element( "source" );
	my $generator = $session->make_element( "generator" );
	$generator->setAttribute( "uri", $session->get_repository->get_conf( "base_url" ) );
	$generator->appendChild($session->make_text( $source_gen ) );
	$source->appendChild( $generator );
	$entry->appendChild( $source );

	# SWORD TREATMEMT
        my $sword_treat = $session->make_element( "sword:treatment" );
        $sword_treat->appendChild( $session->make_text( $sword_treatment ) );
        $entry->appendChild( $sword_treat );


	# FORMAT NAMESPACE
	my $sword_ns = $session->make_element( "sword:formatNamespace" );
	$sword_ns->appendChild( $session->make_text( $format_ns ) );
	$entry->appendChild( $sword_ns );

	my $response = '<?xml version="1.0" encoding=\'utf-8\'?>'.$entry->toString;

	return $response;
}



1;

