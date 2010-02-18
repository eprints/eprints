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

	# "verbose_desc" is only sent when verbose is enabled. The desc itself is always built though.
	my $verbose_desc = "[OK] Verbose mode enabled.\n";

	my $response = EPrints::Sword::Utils::authenticate( $session, $request );
	$verbose_desc .= $response->{verbose_desc};

	if( defined $response->{error} )
        {
		my $error = $response->{error};
                if( defined $error->{x_error_code} )
                {
                        $request->headers_out->{'X-Error-Code'} = $error->{x_error_code};
                }
                
		if( $error->{no_auth} )
                {
                        $request->headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
			$request->status( $error->{status_code} );
			$session->terminate;
			return Apache2::Const::DONE;
                }

		my $error_doc = EPrints::Sword::Utils::generate_error_document( $session, 
					summary => "Authentication error.",
					href => $error->{error_href}, 
					verbose_desc => $verbose_desc );

		$request->status( $error->{status_code} );
	        $request->headers_out->{'Content-Length'} = length $error_doc;
        	$request->content_type('application/atom+xml');
		$request->print( $error_doc );
                $session->terminate;
                return Apache2::Const::DONE;
        }

	my $owner = $response->{owner};
	my $depositor = $response->{depositor};		# undef unless mediated deposit

	# Processing HTTP headers in order to retrieve SWORD options
	my $headers = EPrints::Sword::Utils::process_headers( $session, $request );
	$verbose_desc .= $headers->{verbose_desc};

	my $VERBOSE = $headers->{x_verbose};
	my $NO_OP = $headers->{no_op};

	if( defined $headers->{error} )
	{
		my $error = $headers->{error};
                if( defined $error->{x_error_code} )
                {
                        $request->headers_out->{'X-Error-Code'} = $error->{x_error_code};
                }
		
		my $error_doc = EPrints::Sword::Utils::generate_error_document( $session, 
					user_agent => $headers->{user_agent},
					summary => "Failed to parse the HTTP headers.",
					href => $error->{error_href}, 
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->status( $error->{status_code} );
	        $request->headers_out->{'Content-Length'} = length $error_doc;
        	$request->content_type('application/atom+xml');
		$request->print( $error_doc );
                $session->terminate;
                return Apache2::Const::DONE;
	}

	# Check that the collection exists on this repository:
	my $target_collection = $headers->{collection};
	my $collections = EPrints::Sword::Utils::get_collections( $session );
	
	my $collec_conf = $collections->{$target_collection};

	if(!defined $collec_conf)
	{
		$verbose_desc .= "ERROR: The collection '$target_collection' does not exist.\n";
		
                my $error_doc = EPrints::Sword::Utils::generate_error_document( $session, 
					user_agent => $headers->{user_agent},
					summary => "Unknown or invalid collection: '$target_collection'.",
					href => "http://eprints.org/sword/error/UnknownCollection", 
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );
		$request->status( 400 );
		$session->terminate; 	
		return Apache2::Const::DONE;
	}

        my $sword_treatment = "";
        if(defined $collec_conf->{treatment})
        {
                $sword_treatment = $collec_conf->{treatment};
        }

	# Allow Mediations by default (this doesn't mean any mediation is authorised)
	my $allow_mediation = 1;

	# Unless this is disabled in the conf:
	if(defined $collec_conf->{mediation} && (lc $collec_conf->{mediation}) eq 'false')
	{
		$allow_mediation = 0;
	}
	
	if( defined $depositor && !$allow_mediation )	
	{
		$verbose_desc .= "ERROR: Mediated deposits are disabled.\n";

		my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
					summary => "Invalid mediated deposit.",
                                        href => "http://purl.org/net/sword/error/MediationNotAllowed",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );
		$request->headers_out->{'X-Error-Code'} = 'MediationNotAllowed';
		$request->status( 401 );
		$session->terminate;
		return Apache2::Const::DONE;
	}

	unless( EPrints::Sword::Utils::is_mime_allowed( $collec_conf->{mime_types}, $headers->{content_type} ) )
	{
		$verbose_desc .= "[ERROR] Mime-type '".$headers->{content_type}."' is not supported by this collection.\n";

		my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
					summary => "Invalid mime type.",
                                        href => "http://purl.org/net/sword/error/ErrorContent",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );
		$request->headers_out->{'X-Error-Code'} = 'ErrorContent';
		$request->status( 400 );
		$session->terminate;
		return Apache2::Const::DONE;
	}

	$session->read_params();

	# Saving the data/file sent through POST
        my $postdata = $session->{query}->{'POSTDATA'};

 	# This is because CGI.pm (>3.15) has changed:
        if( !defined $postdata || scalar @$postdata < 1 )
	{
		push @$postdata, $session->{query}->param( 'POSTDATA' );
	}
		
	# to let cURL works
        if( !defined $postdata || scalar @$postdata < 1 )
        {
		push @$postdata, $session->{query}->param();
	}

        if( !defined $postdata || scalar @$postdata < 1 )
        {
		$verbose_desc .= "[ERROR] No files found in the postdata.\n";

                my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
					summary => "Missing postdata.",
                                        href => "http://purl.org/net/sword/error/ErrorBadRequest",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );
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
			$verbose_desc .= "[ERROR] MD5 checksum is incorrect.\n";

			my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
						summary => "MD5 checksum is incorrect",
						href => "http://purl.org/net/sword/error/ErrorChecksumMismatch",
						verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

			$request->headers_out->{'Content-Length'} = length $error_doc;
			$request->content_type('application/atom+xml');
			$request->print( $error_doc );
			$request->headers_out->{'X-Error-Code'} = 'ErrorChecksumMismatch';
			$request->status( 412 );
			$session->terminate;
			return Apache2::Const::DONE;
                }
	}

	# Create a temp directory which will be automatically removed by PERL
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
		binmode( TMP );
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


	my $xpackage = $headers->{x_packaging};
	my $import_plugin_conf;
	my $import_plugin_id;

	if(defined $xpackage)
	{
		$import_plugin_conf = $session->get_repository->get_conf( "sword", "supported_packages" )->{$xpackage};
		if( defined $import_plugin_conf )
		{
			$import_plugin_id = $import_plugin_conf->{plugin};
			my $import_plugin_name = $import_plugin_conf->{name};
			$verbose_desc .= "[OK] selecting import plugin '$import_plugin_name'";
		}
	}
	else
	{
		my $enable_generic = $session->get_repository->get_conf( "sword", "enable_generic_importer" );
		if( $enable_generic )
		{
			$verbose_desc .= "[WARNING] X-Packaging not set (I will just import the uploaded file).\n";
			$import_plugin_id = "Sword::Import::GenericFile";
		}
		else
		{
			$verbose_desc .= "[ERROR] X-Packaging not set.\n";
			my $error_doc = EPrints::Sword::Utils::generate_error_document( $session, 
					user_agent => $headers->{user_agent},
						href => "http://purl.org/net/sword/error/ErrorBadRequest",
						summary => "X-Packaging not set.",
						verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

			$request->headers_out->{'Content-Length'} = length $error_doc;
			$request->content_type('application/atom+xml');
			$request->print( $error_doc );
			$request->status( 400 );
			$session->terminate;
			return Apache2::Const::DONE;
		}
	}

	unless(defined $import_plugin_id)
	{
		# APP Profile 1.3 stipulates we send this:
		$verbose_desc .= "[ERROR] X-Package '$xpackage' is not supported by this repository.\n";
		
		my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
					href => "http://purl.org/net/sword/error/ErrorContent", 
					summary => "Unsupported packaging format: '$xpackage'.",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );
		$request->headers_out->{'Content-Length'} = length $error_doc;
		$request->content_type('application/atom+xml');
		$request->print( $error_doc );
		$request->status( 415 );	# Unsupported Media Type
		$session->terminate;
		return Apache2::Const::DONE;
	}

	my $import_plugin = $session->plugin( $import_plugin_id );
	unless( defined $import_plugin )
	{
                print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to load the plugin '".$import_plugin_id."'. Make sure SWORD is properly configured.";
                $verbose_desc .= "[INTERNAL ERROR] Failed to load the import plugin.\n";

                my $error_doc = EPrints::Sword::Utils::generate_error_document( $session, 
					user_agent => $headers->{user_agent},
					href => "http://eprints.org/sword/error/UnknownCollection",
					summary => "Internal error: failed to load the import plugin.",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );
                $request->status( 500 );
                $session->terminate;
                return Apache2::Const::DONE;
	}

	my %opts;
	$opts{file} = $file;
	$opts{mime_type} = $headers->{content_type};
        $opts{dataset_id} = $target_collection;
        $opts{owner_id} = $owner->get_id;
        $opts{depositor_id} = $depositor->get_id if(defined $depositor);
	$opts{verbose} = $VERBOSE;
	$opts{no_op} = $NO_OP;
	my $eprint = $import_plugin->input_file( %opts );
	$verbose_desc .= $import_plugin->get_verbose();

	if( $NO_OP )
	{
		my $code = $import_plugin->get_status_code();
		$code = 400 unless( defined $code );	

		if( $code == 200 )
		{
			my %xml_opts;
			$xml_opts{user_agent} = $headers->{user_agent};
			$xml_opts{x_packaging} = $headers->{x_packaging};
			$xml_opts{sword_treatment} = $sword_treatment;
			$xml_opts{owner} = $owner;
			$xml_opts{depositor} = $depositor if( defined $depositor );
			$xml_opts{verbose_desc} = $verbose_desc if( $VERBOSE );

			my $noop_xml = EPrints::Sword::Utils::create_noop_xml( $session, %xml_opts );

			$request->headers_out->{'Content-Length'} = length $noop_xml;
			$request->content_type( 'application/atom+xml' );
			$request->status( 200 );        # Successful
		        $request->print( $noop_xml );
		        $session->terminate;
		        return Apache2::Const::OK;
		}

                my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
                                        href => "http://purl.org/net/sword/error/ErrorContent",
                                        summary => "Import plugin failed in no-op mode.",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );

		$request->status( $code );
		$session->terminate;
                return Apache2::Const::OK;

	}

	unless(defined $eprint)
	{
		my $code = $import_plugin->get_status_code();
		$code = 400 unless(defined $code);
	        $request->status( $code );
                
                my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
                                        href => "http://purl.org/net/sword/error/ErrorContent",
                                        summary => "Import plugin failed.",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );
                $request->status( $code );        # Unsupported Media Type
                $session->terminate;
                return Apache2::Const::DONE;
        }

	my %xml_opts;
	$xml_opts{eprint} = $eprint;
	$xml_opts{x_packaging} = $headers->{x_packaging};
	$xml_opts{sword_treatment} = $sword_treatment;
	$xml_opts{owner} = $owner;
	$xml_opts{depositor} = $depositor;
	$xml_opts{verbose_desc} = $verbose_desc if( $VERBOSE );
	$xml_opts{user_agent} = $headers->{user_agent};
	$xml_opts{deposited_file_docid} = $import_plugin->get_deposited_file_docid();

	my $xml = EPrints::Sword::Utils::create_xml( $session, %xml_opts );

	$request->headers_out->{'Location'} = EPrints::Sword::Utils::get_atom_url( $session, $eprint );
	$request->headers_out->{'Content-Length'} = length $xml;
	$request->content_type('application/atom+xml');

	$request->print( $xml );
	$request->status( 201 );	# Created

	$session->terminate;	
	return Apache2::Const::OK;
}

1;

