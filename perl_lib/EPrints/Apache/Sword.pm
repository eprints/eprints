=head1 NAME

EPrints::Apache::Sword

=cut

package EPrints::Apache::Sword;

use EPrints::Const qw( :http );
use MIME::Base64;

use strict;

sub handler_servicedocument
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;
	my $xml = $repo->xml;

# Authenticating user and behalf user
	my $response = authenticate( $repo, $r );
	my $error = $response->{error};

	if( defined $error )
	{       
		if( defined $error->{x_error_code} )
		{
			$r->err_headers_out->{'X-Error-Code'} = $error->{x_error_code};
		}

		if( $error->{no_auth} )
		{
			$r->err_headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
		}

		$r->status( $error->{status_code} );
		return $error->{status_code};
	}

	my $owner = $response->{owner};
	my $depositor = $response->{depositor};		# can be undef if no X-On-Behalf-Of in the request

	my $service_conf = $repo->config( "sword","service_conf" );

# Load some default values if those were not set in the sword.pl configuration file
	if(!defined $service_conf || !defined $service_conf->{title})
	{
		$service_conf = {};
		$service_conf->{title} = $repo->phrase( "archive_name" );
	}

# SERVICE and WORKSPACE DEFINITION

	my $service = $xml->create_element( "service", 
			xmlns => "http://www.w3.org/2007/app",
			"xmlns:atom" => "http://www.w3.org/2005/Atom",
			"xmlns:sword" => "http://purl.org/net/sword/",
			"xmlns:dcterms" => "http://purl.org/dc/terms/" );

	my $workspace = $xml->create_data_element( "workspace", [
		[ "atom:title", $service_conf->{title} ],
# SWORD LEVEL
		[ "sword:version", "1.3" ],
# SWORD VERBOSE	(Unsupported)
		[ "sword:verbose", "true" ],
# SWORD NOOP (Unsupported)
		[ "sword:noOp", "true" ],
	]);
	$service->appendChild( $workspace );

# COLLECTION DEFINITION
	my $collections = get_collections( $repo );

# Note: if no collections are defined, we send an empty ServiceDocument

	my $deposit_url = get_deposit_url( $repo );

	foreach my $collec (keys %$collections)
	{
		my $conf = $collections->{$collec};

		my $href = defined $conf->{href} ? $conf->{href} : $deposit_url.$collec;

		my $collection = $xml->create_element( "collection" , "href" => $href );

		$collection->appendChild(
			$xml->create_data_element( "atom:title", $conf->{title} )
		);

		foreach(@{$conf->{mime_types}})
		{
			$collection->appendChild(
				$xml->create_data_element( "accept", $_ )
			);
		}

		my $supported_packages = $conf->{packages};
		foreach( keys %$supported_packages )
		{
			my $qvalue = $supported_packages->{$_}->{qvalue};
			$collection->appendChild( 
				$xml->create_data_element( "sword:acceptPackaging", $_,
					(defined $qvalue ? (q => $qvalue) : ())
			) );
		}

# COLLECTION POLICY
		$collection->appendChild(
			$xml->create_data_element( "sword:collectionPolicy", $conf->{sword_policy} )
		);

# COLLECTION TREATMENT
		my $treatment = $conf->{treatment};
		if( defined $depositor )
		{
			$treatment .= $repo->phrase( "Sword/ServiceDocument:note_behalf", username=>$depositor->value( "username" ));
		}

		$collection->appendChild( 
			$xml->create_data_element( "sword:treatment", $treatment )
		);

# COLLECTION MEDIATED
		$collection->appendChild( 
			$xml->create_data_element( "sword:mediation", $conf->{mediation} )
		);

# DCTERMS ABSTRACT
		$collection->appendChild( 
			$xml->create_data_element( "dcterms:abstract", $conf->{dcterms_abstract} )
		);

		$workspace->appendChild( $collection );
	}

	my $content = "<?xml version='1.0' encoding='UTF-8'?>\n" .
		$xml->to_string( $service, indent => 1 );

	return send_response( $r,
		OK,
		'application/xtom+xml; charset=UTF-8',
		$content
	);
}

sub handler_atom
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;

# Authenticating user and behalf user
	my $response = authenticate( $repo, $r );
	my $error = $response->{error};

	if( defined $error )
	{       
		if( defined $error->{x_error_code} )
		{
			$r->err_headers_out->{'X-Error-Code'} = $error->{x_error_code};
		}

		if( $error->{no_auth} )
		{
			$r->err_headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
		}

		$r->status( $error->{status_code} );
		return $error->{status_code};
	}

	my $owner = $response->{owner};
	my $depositor = $response->{depositor};		# can be undef if no X-On-Behalf-Of in the request

# then what?
#
# get the eprint ID from the URI
# can the user view that eprint?
# if so, send the xml, probably using Utils:create_xml

	my $uri = $r->pnotes( "uri" );

	my( $epid ) = $uri =~ /^(\d+)\.atom$/;

	if( !defined $epid )
	{
		return HTTP_BAD_REQUEST;
	}

	my $eprint = $repo->eprint( $epid );

	if( !defined $eprint )
	{
		return HTTP_BAD_REQUEST;
	}

# now should check the current user has auth to view this eprint
	my $user_to_test = defined $depositor ? $depositor : $owner;

	if( !$eprint->has_owner( $user_to_test ) )
	{
		return HTTP_UNAUTHORIZED;
	}

	my $real_owner = $repo->user( $eprint->value( "userid" ) );
	my $real_depositor = $repo->user( $eprint->value( "sword_depositor" ) );

	my $xml = create_xml( $repo,
			eprint => $eprint,
			sword_treatment => "",
			owner => $real_owner,
			depositor => $real_depositor );

	$r->err_headers_out->{'Location'} = get_atom_url( $repo, $eprint );

	return send_response( $r,
		HTTP_CREATED,
		'application/xtom+xml; charset=UTF-8',
		$xml
	);
}

sub handler_deposit
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;

# "verbose_desc" is only sent when verbose is enabled. The desc itself is always built though.
	my $verbose_desc = "[OK] Verbose mode enabled.\n";

	my $response = authenticate( $repo, $r );
	$verbose_desc .= $response->{verbose_desc};

	if( defined $response->{error} )
	{
		my $error = $response->{error};
		if( defined $error->{x_error_code} )
		{
			$r->headers_out->{'X-Error-Code'} = $error->{x_error_code};
		}

		if( $error->{no_auth} )
		{
			my $realm = $repo->phrase( "archive_name" );
			$r->err_headers_out->{'WWW-Authenticate'} = 'Basic realm="'.$realm.'"';
			return $error->{status_code};
		}

		my $error_doc = generate_error_document( $repo, 
				summary => "Authentication error.",
				href => $error->{error_href}, 
				verbose_desc => $verbose_desc );

		return send_response( $r,
			$error->{status_code},
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

	my $owner = $response->{owner};
	my $depositor = $response->{depositor};		# undef unless mediated deposit

# Processing HTTP headers in order to retrieve SWORD options
	my $headers = process_headers( $repo, $r );
	$verbose_desc .= $headers->{verbose_desc};

	my $VERBOSE = $headers->{x_verbose};
	my $NO_OP = $headers->{no_op};

	if( defined $headers->{error} )
	{
		my $error = $headers->{error};
		if( defined $error->{x_error_code} )
		{
			$r->headers_out->{'X-Error-Code'} = $error->{x_error_code};
		}

		my $error_doc = generate_error_document( $repo, 
				user_agent => $headers->{user_agent},
				summary => "Failed to parse the HTTP headers.",
				href => $error->{error_href}, 
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		return send_response( $r,
			$error->{status_code},
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

# Check that the collection exists on this repository:
	my $target_collection = $headers->{collection};
	my $collections = get_collections( $repo );

	my $collec_conf = $collections->{$target_collection};

	if(!defined $collec_conf)
	{
		$verbose_desc .= "ERROR: The collection '$target_collection' does not exist.\n";

		my $error_doc = generate_error_document( $repo, 
				user_agent => $headers->{user_agent},
				summary => "Unknown or invalid collection: '$target_collection'.",
				href => "http://eprints.org/sword/error/UnknownCollection", 
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		return send_response( $r,
			HTTP_BAD_REQUEST,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
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

		my $error_doc = generate_error_document( $repo,
				user_agent => $headers->{user_agent},
				summary => "Invalid mediated deposit.",
				href => "http://purl.org/net/sword/error/MediationNotAllowed",
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		$r->err_headers_out->{'X-Error-Code'} = 'MediationNotAllowed';

		return send_response( $r,
			HTTP_UNAUTHORIZED,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

	unless( is_mime_allowed( $collec_conf->{mime_types}, $headers->{content_type} ) )
	{
		$verbose_desc .= "[ERROR] Mime-type '".$headers->{content_type}."' is not supported by this collection.\n";

		my $error_doc = generate_error_document( $repo,
				user_agent => $headers->{user_agent},
				summary => "Invalid mime type.",
				href => "http://purl.org/net/sword/error/ErrorContent",
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		$r->err_headers_out->{'X-Error-Code'} = 'ErrorContent';

		return send_response( $r,
			HTTP_BAD_REQUEST,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

	$repo->read_params();

# Saving the data/file sent through POST
	my $postdata = $repo->{query}->{'POSTDATA'};

# This is because CGI.pm (>3.15) has changed:
	if( !defined $postdata || scalar @$postdata < 1 )
	{
		push @$postdata, $repo->{query}->param( 'POSTDATA' );
	}

# to let cURL works
	if( !defined $postdata || scalar @$postdata < 1 )
	{
		push @$postdata, $repo->{query}->param();
	}

	if( !defined $postdata || scalar @$postdata < 1 )
	{
		$verbose_desc .= "[ERROR] No files found in the postdata.\n";

		my $error_doc = generate_error_document( $repo,
				user_agent => $headers->{user_agent},
				summary => "Missing postdata.",
				href => "http://purl.org/net/sword/error/ErrorBadRequest",
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		$r->err_headers_out->{'X-Error-Code'} = 'ErrorBadRequest';

		return send_response( $r,
			HTTP_BAD_REQUEST,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

	my $post = $$postdata[0];

# Check the MD5 we received is correct
	if(defined $headers->{md5})
	{
		my $real_md5 = Digest::MD5::md5_hex( $post );
		if( $real_md5 ne $headers->{md5} )
		{
			$verbose_desc .= "[ERROR] MD5 checksum is incorrect.\n";

			my $error_doc = generate_error_document( $repo,
					user_agent => $headers->{user_agent},
					summary => "MD5 checksum is incorrect",
					href => "http://purl.org/net/sword/error/ErrorChecksumMismatch",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

			$r->err_headers_out->{'X-Error-Code'} = 'ErrorChecksumMismatch';

			return send_response( $r,
				HTTP_PRECONDITION_FAILED,
				'application/xtom+xml; charset=UTF-8',
				$error_doc
			);
		}
	}

# Create a temp directory which will be automatically removed by PERL
	my $tmp_dir = File::Temp->newdir( "swordXXXX", TMPDIR => 1 );

	if( !defined $tmp_dir )
	{
		print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp directory!";
		$r->status( 500 );
		$repo->terminate;
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
		$r->status( 500 );
		$repo->terminate;
		return Apache2::Const::DONE;
	}


	my $xpackage = $headers->{x_packaging};
	my $import_plugin_conf;
	my $import_plugin_id;

	if(defined $xpackage)
	{
		$import_plugin_conf = $repo->config( "sword", "supported_packages" )->{$xpackage};
		if( defined $import_plugin_conf )
		{
			$import_plugin_id = $import_plugin_conf->{plugin};
			my $import_plugin_name = $import_plugin_conf->{name};
			$verbose_desc .= "[OK] selecting import plugin '$import_plugin_name'";
		}
	}
	else
	{
		my $enable_generic = $repo->config( "sword", "enable_generic_importer" );
		if( $enable_generic )
		{
			$verbose_desc .= "[WARNING] X-Packaging not set (I will just import the uploaded file).\n";
			$import_plugin_id = "Sword::Import::GenericFile";
		}
		else
		{
			$verbose_desc .= "[ERROR] X-Packaging not set.\n";
			my $error_doc = generate_error_document( $repo, 
					user_agent => $headers->{user_agent},
					href => "http://purl.org/net/sword/error/ErrorBadRequest",
					summary => "X-Packaging not set.",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

			return send_response( $r,
				HTTP_BAD_REQUEST,
				'application/xtom+xml; charset=UTF-8',
				$error_doc
			);
		}
	}

	if($headers->{content_type} eq "application/atom+xml") {
		$import_plugin_id = "Import::XSLT::Atom";
	}

	unless(defined $import_plugin_id)
	{
# APP Profile 1.3 stipulates we send this:
		$verbose_desc .= "[ERROR] X-Package '$xpackage' is not supported by this repository.\n";

		my $error_doc = generate_error_document( $repo,
				user_agent => $headers->{user_agent},
				href => "http://purl.org/net/sword/error/ErrorContent", 
				summary => "Unsupported packaging format: '$xpackage'.",
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		return send_response( $r,
			HTTP_UNSUPPORTED_MEDIA_TYPE,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

	my $import_plugin = $repo->plugin( $import_plugin_id );
	unless( defined $import_plugin )
	{
		print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to load the plugin '".$import_plugin_id."'. Make sure SWORD is properly configured.";
		$verbose_desc .= "[INTERNAL ERROR] Failed to load the import plugin.\n";

		my $error_doc = generate_error_document( $repo, 
				user_agent => $headers->{user_agent},
				href => "http://eprints.org/sword/error/UnknownCollection",
				summary => "Internal error: failed to load the import plugin.",
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		return send_response( $r,
			HTTP_INTERNAL_SERVER_ERROR,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

	my %opts;
	$opts{file} = $file;
	$opts{filename} = $file;
	$opts{mime_type} = $headers->{content_type};
	$opts{dataset_id} = $target_collection;
	$opts{dataset} = $repo->get_repository()->get_dataset( $target_collection );
	$opts{owner_id} = $owner->get_id;
	$opts{depositor_id} = $depositor->get_id if(defined $depositor);
	$opts{verbose} = $VERBOSE;
	$opts{no_op} = $NO_OP;

	my $grammar = get_grammar();
	my $flags = {};
	my $headers_in = $r->headers_in;
	foreach my $key (keys %{$headers_in}) {
		my $value = $grammar->{$key};
		if ((defined $value) and ($headers_in->{$key} eq "true")) {
			$flags->{$value} = 1;
		}
	}
	$opts{flags} = $flags;
	$import_plugin->{parse_only} = $NO_OP;

	my $handler = EPrints::CLIProcessor->new(
			session => $repo,
			scripted => 0,
			);
	$import_plugin->set_handler($handler);

	my $eprint = $import_plugin->input_file( %opts );

	my $count = $NO_OP ? $handler->{parsed} : $handler->{wrote};

	if ($eprint->isa( "EPrints::List" )) {
		$eprint = $eprint->item(0);
	}
	if (defined $eprint) {
		$eprint->set_value( "userid", $owner->get_id);
		if (defined $depositor) {
			$eprint->set_value( "sword_depositor", $depositor->get_id);
		}
		$eprint->commit();
	}

#	$verbose_desc .= $import_plugin->get_verbose();

	if( $NO_OP )
	{

#		my $code = $import_plugin->get_status_code();
#		$code = 400 unless( defined $code );	

		if($count > 0)
		{
			my %xml_opts;
			$xml_opts{user_agent} = $headers->{user_agent};
			$xml_opts{x_packaging} = $headers->{x_packaging};
			$xml_opts{sword_treatment} = $sword_treatment;
			$xml_opts{owner} = $owner;
			$xml_opts{depositor} = $depositor if( defined $depositor );
			$xml_opts{verbose_desc} = $verbose_desc if( $VERBOSE );

			my $noop_xml = create_noop_xml( $repo, %xml_opts );

			return send_response( $r,
				HTTP_OK,
				'application/xtom+xml; charset=UTF-8',
				$noop_xml
			);
		} 

		my $error_doc = generate_error_document( $repo,
				user_agent => $headers->{user_agent},
				href => "http://purl.org/net/sword/error/ErrorContent",
				summary => "Import plugin failed in no-op mode.",
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		return send_response( $r,
			HTTP_BAD_REQUEST,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

	unless(defined $eprint)
	{
#		my $code = $import_plugin->get_status_code();
#		$code = 400 unless(defined $code);
#	        $r->status( $code );
		my $error_doc = generate_error_document( $repo,
				user_agent => $headers->{user_agent},
				href => "http://purl.org/net/sword/error/ErrorContent",
				summary => "Import plugin failed.",
				verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

		return send_response( $r,
			HTTP_BAD_REQUEST,
			'application/xtom+xml; charset=UTF-8',
			$error_doc
		);
	}

#	my %xml_opts;
#	$xml_opts{eprint} = $eprint;
#	$xml_opts{x_packaging} = $headers->{x_packaging};
#	$xml_opts{sword_treatment} = $sword_treatment;
#	$xml_opts{owner} = $owner;
#	$xml_opts{depositor} = $depositor;
#	$xml_opts{verbose_desc} = $verbose_desc if( $VERBOSE );
#	$xml_opts{user_agent} = $headers->{user_agent};
#	$xml_opts{deposited_file_docid} = $import_plugin->get_deposited_file_docid();
#
	my $accept = $r->headers_in->{'Accept'};
	$accept = "application/atom+xml" if (!defined $accept);
	my $repository = $repo->get_repository();
	my $match = EPrints::Apache::Rewrite::content_negotiate_best_plugin( 
			$repository, 
			accept_header => $accept,
			plugins => [$repository->get_plugins(
				type => "Export",
				is_visible => "all",
				can_accept => 'dataobj/eprint' )],
			);
	my $xml = $match->output_eprint($eprint);

	$r->err_headers_out->{'Location'} = $eprint->uri;

	return send_response( $r,
		HTTP_CREATED,
		'application/xtom+xml; charset=UTF-8',
		$xml
	);
}

### Utility methods below

sub authenticate
{
	my ( $repo, $request ) = @_;

	my %response;

	my $authen = EPrints::Apache::AnApache::header_in( $request, 'Authorization' );

	$response{verbose_desc} = "";

	if(!defined $authen)
	{
		$response{error} = { 	
			status_code => HTTP_UNAUTHORIZED, 
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
			status_code => HTTP_UNAUTHORIZED, 
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
			status_code => HTTP_UNAUTHORIZED, 
			x_error_code => "ErrorAuth",
			error_href => "http://eprints.org/sword/error/ErrorAuth",
		};
		$response{verbose_desc} .= "[ERROR] Authentication failed (invalid base64 encoding).\n";
		return \%response;
	}

	unless( $repo->valid_login( $username, $password ) )
	{
		$response{error} = {
			status_code => HTTP_UNAUTHORIZED, 
			x_error_code => "ErrorAuth",
			error_href => "http://eprints.org/sword/error/ErrorAuth",
		};
		$response{verbose_desc} .= "[ERROR] Authentication failed.\n";
		return \%response;
	}

	my $user = $repo->user_by_username( $username );

# This error could be a 500 Internal Error since the previous check ($db->valid_login) succeeded.
	if(!defined $user)
	{
		$response{error} = {
			status_code => HTTP_UNAUTHORIZED, 
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
		my $behalf_user = $repo->user_by_username( $xbehalf );

		if(!defined $behalf_user)
		{
			$response{error} = {
				status_code => HTTP_UNAUTHORIZED, 
				x_error_code => "TargetOwnerUnknown",
				error_href => "http://purl.org/net/sword/error/TargetOwnerUnknown",
			};

			$response{verbose_desc} .= "[ERROR] Unknown user for mediation: '".$xbehalf."'\n";
			return \%response;
		}

		if(!can_user_behalf( $repo, $user->get_value( "username" ), $behalf_user->get_value( "username" ) ))
		{
			$response{error} = {
				status_code => HTTP_FORBIDDEN, 
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
	my ( $repo, $request ) = @_;

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
		if( $filename =~ /(.*)filename\=(.*)/)
		{
			$filename = $2;
		}
		$filename =~ s/^"//;
		$filename =~ s/"$//;
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
	my ( $repo, $username, $behalf_username ) = @_;

	my $allowed = $repo->config( "sword", "allowed_mediations" );

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

sub get_collections
{
	my ( $repo ) = @_;

	my $coll_conf = $repo->config( "sword","collections" );
	return undef unless(defined $coll_conf);
	
	my $mime_types = $repo->config( "sword", "accept_mime_types" );
	my $packages = $repo->config( "sword", "supported_packages" );

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

sub get_atom_url
{
	my ( $repo, $eprint ) = @_;
	return $repo->config( "base_url" )."/sword-app/atom/".$eprint->get_id.".atom";
}



sub get_deposit_url
{
	my ( $repo ) = @_;
	return $repo->config( "base_url" )."/sword-app/deposit/"
}

sub get_collections_url
{
        my ( $repo ) = @_;
        return $repo->config( "base_url" )."/id/eprint/";
}




# other helper functions:
sub generate_error_document
{
        my ( $repo, %opts ) = @_;

        my $error = $repo->make_element( "sword:error", "xmlns:atom" => "http://www.w3.org/2005/Atom",
                                                           "xmlns:sword" => "http://purl.org/net/sword/" );

	$opts{href} = "http://eprints.org/sword/error/UnknownError" unless( defined $opts{href} );
	$error->setAttribute( "href", $opts{href} );

        my $title = $repo->make_element( "atom:title" );
        $title->appendChild( $repo->make_text( "ERROR" ) );
        $error->appendChild( $title );

        my $updated = $repo->make_element( "atom:updated" );
        $updated->appendChild( $repo->make_text( EPrints::Time::get_iso_timestamp() ) );
        $error->appendChild( $updated );

        my $source_gen = $repo->config( "sword", "service_conf" )->{generator};
        unless( defined $source_gen )
        {
                $source_gen = $repo->phrase( "archive_name" )." [".$repo->config( "version_id" )."]";
        }

        my $generator = $repo->make_element( "atom:generator" );
        $generator->setAttribute( "uri", $repo->config( "base_url" ) );
        $generator->setAttribute( "version", "1.3" );
        $generator->appendChild($repo->make_text( $source_gen ) );
        $error->appendChild( $generator );

	my $summary = $repo->make_element( "atom:summary" );
	$error->appendChild( $summary );

	if( defined $opts{summary} )
        {
                $summary->appendChild( $repo->make_text( $opts{summary} ) );
        }

        if( defined $opts{verbose_desc} )
        {
                my $desc = $repo->make_element( "sword:verboseDescription" );
                $desc->appendChild( $repo->make_text( $opts{verbose_desc} ) );
                $error->appendChild( $desc );
        }

	if( defined $opts{user_agent} )
	{
                my $sword_agent = $repo->make_element( "sword:userAgent" );
                $sword_agent->appendChild( $repo->make_text( $opts{user_agent} ) );
                $error->appendChild( $sword_agent );
        }

        EPrints::XML::tidy( $error );

        return '<?xml version="1.0" encoding="UTF-8"?>'.$error->toString();
}


sub create_xml
{
        my ( $repo, %opts ) = @_;

        my $eprint = $opts{eprint};
        my $owner = $opts{owner};
        my $depositor = $opts{depositor};
	my $deposited_file_docid = $opts{deposited_file_docid};

        # ENTRY
        my $entry = $repo->make_element( "atom:entry", "xmlns:atom" => "http://www.w3.org/2005/Atom",
                                        "xmlns:sword" => "http://purl.org/net/sword/" );

        # TITLE
        my $eptitle = $eprint->get_value( "title" );
        $eptitle = "UNSPECIFIED" unless defined( $eptitle );

        my $title = $repo->make_element( "atom:title" );
        $title->appendChild( $repo->make_text( $eptitle ) );
        $entry->appendChild( $title );

        # ID
        my $uid = $repo->make_element( "atom:id" );
	$uid->appendChild( $repo->make_text( $eprint->uri ) );
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

        my $updated = $repo->make_element( "atom:updated" );
        $updated->appendChild( $repo->make_text( $time_updated ) );
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
        
	my $published = $repo->make_element( "atom:published" );
        $published->appendChild( $repo->make_text( $time_pub ) );
        $entry->appendChild( $published );


        # AUTHOR/CONTRIBUTOR
	if( defined $depositor )
        {
                my $author = $repo->make_element( "atom:author" );
                my $name = $repo->make_element( "atom:name" );
                $name->appendChild( $repo->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                my $email_tag;
                if( defined $author_email )
                {
                        $email_tag = $repo->make_element( "atom:email" );
                        $email_tag->appendChild( $repo->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );

                my $contributor = $repo->make_element( "atom:contributor" );
                my $name2 = $repo->make_element( "atom:name" );
                $name2->appendChild( $repo->make_text( $depositor->get_value( "username" ) ) );
                $contributor->appendChild( $name2 );
                my $contrib_email = $depositor->get_value( "email" );
                if( defined $contrib_email )
                {
                        $email_tag = $repo->make_element( "atom:email" );
                        $email_tag->appendChild( $repo->make_text( $contrib_email ) );
                        $contributor->appendChild( $email_tag );
                }
                $entry->appendChild( $contributor );
        }
        else
        {
                my $author = $repo->make_element( "atom:author" );
                my $name = $repo->make_element( "atom:name" );
                $name->appendChild( $repo->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                if( defined $author_email )
                {
                        my $email_tag = $repo->make_element( "atom:email" );
                        $email_tag->appendChild( $repo->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );
        }

        # SUMMARY
	my $summary = $repo->make_element( "atom:summary", "type" => "text" );
	$entry->appendChild( $summary );
	my $abstract = $eprint->get_value( "abstract" );
        if( defined $abstract && length $abstract > 100 )        # display 100 characters max for the abstract
        {
                $abstract = substr( $abstract, 0, 96 );
                $abstract .= "...";
                $summary->appendChild( $repo->make_text( $abstract ) );
        }

	# if docid is defined, <content> should point to that document, otherwise point to the abstract page
	my $content;
	my $edit_media;
	if( defined $deposited_file_docid )
	{
		my $doc = EPrints::DataObj::Document->new( $repo, $deposited_file_docid );
	
		if( defined $doc )
		{
			$content = $repo->make_element( "atom:content", 
							"type" => $doc->get_value( "format" ),
							"src" => $doc->uri );
			$edit_media = $repo->make_element( "atom:link",
							"rel" => "edit-media",
							"href" => $doc->uri );
		}		
	}

	unless( defined $content )
	{
		$content = $repo->make_element( "atom:content", "type" => "text/html", src=> $eprint->uri )
	}
        $entry->appendChild( $content );
	if (defined $edit_media) {
		$entry->appendChild( $edit_media );
	}

	my $edit_link = $repo->make_element( "atom:link", 
					"rel" => "edit",
					"href" => $eprint->uri 
					);
#					"href" => get_atom_url( $repo, $eprint ) );

	$entry->appendChild( $edit_link );


        # SOURCE GENERATOR
	my $source_gen = $repo->config( "sword", "service_conf" )->{generator};
	unless( defined $source_gen )
	{
	        $source_gen = $repo->phrase( "archive_name" )." [".$repo->config( "version_id" )."]";
	}

        my $generator = $repo->make_element( "atom:generator" );
        $generator->setAttribute( "uri", $repo->config( "base_url" ) );
	$generator->setAttribute( "version", "1.3" );
        $generator->appendChild($repo->make_text( $source_gen ) );
        $entry->appendChild( $generator );


        # VERBOSE
        if(defined $opts{verbose_desc})
        {
                my $sword_verbose = $repo->make_element( "sword:verboseDescription" );
                $sword_verbose->appendChild( $repo->make_text( $opts{verbose_desc} ) );
                $entry->appendChild( $sword_verbose );
        }


        # SWORD TREATMEMT
	my $sword_treat = $repo->make_element( "sword:treatment" );
        $sword_treat->appendChild( $repo->make_text( $opts{sword_treatment} ) );
        $entry->appendChild( $sword_treat );


	if( defined $opts{x_packaging} )
	{
		my $sword_xpack = $repo->make_element( "sword:packaging" );
		$sword_xpack->appendChild( $repo->make_text( $opts{x_packaging} ) );
		$entry->appendChild( $sword_xpack );
	}

	if(defined $opts{user_agent})
        {
                my $sword_agent = $repo->make_element( "sword:userAgent" );
                $sword_agent->appendChild( $repo->make_text( $opts{user_agent} ) );
                $entry->appendChild( $sword_agent );
        }
	
	my $sword_noop = $repo->make_element( "sword:noOp" );
	$sword_noop->appendChild( $repo->make_text( "false" ) );
	$entry->appendChild( $sword_noop );

	EPrints::XML::tidy( $entry );
	
        return '<?xml version="1.0" encoding="UTF-8"?>'.$entry->toString;

}


# the XML sent when performing a No-Op operation
sub create_noop_xml
{
        my ( $repo, %opts ) = @_;

        my $sword_treatment = $opts{sword_treatment};
        my $owner = $opts{owner};
        my $depositor = $opts{depositor};
        my $verbose = $opts{verbose_desc};

        # ENTRY
        my $entry = $repo->make_element( "atom:entry", "xmlns:atom" => "http://www.w3.org/2005/Atom",
                                        "xmlns:sword" => "http://purl.org/net/sword/" );

        # UPDATED
        my $time_updated = EPrints::Time::get_iso_timestamp();
        my $updated = $repo->make_element( "atom:updated" );
        $updated->appendChild( $repo->make_text( $time_updated ) );
        $entry->appendChild( $updated );

        my $published = $repo->make_element( "atom:published" );
        $published->appendChild( $repo->make_text( $time_updated ) );
        $entry->appendChild( $published );

        # AUTHOR/CONTRIBUTOR
	if( defined $depositor )
        {
                my $author = $repo->make_element( "atom:author" );
                my $name = $repo->make_element( "atom:name" );
                $name->appendChild( $repo->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                my $email_tag;
                if( defined $author_email )
                {
                        $email_tag = $repo->make_element( "atom:email" );
                        $email_tag->appendChild( $repo->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );

                my $contributor = $repo->make_element( "atom:contributor" );
                my $name2 = $repo->make_element( "atom:name" );
                $name2->appendChild( $repo->make_text( $depositor->get_value( "username" ) ) );
                $contributor->appendChild( $name2 );
                my $contrib_email = $depositor->get_value( "email" );
                if( defined $contrib_email )
                {
                        $email_tag = $repo->make_element( "atom:email" );
                        $email_tag->appendChild( $repo->make_text( $contrib_email ) );
                        $contributor->appendChild( $email_tag );
                }
                $entry->appendChild( $contributor );
        }
        else
        {
                my $author = $repo->make_element( "atom:author" );
                my $name = $repo->make_element( "atom:name" );
                $name->appendChild( $repo->make_text( $owner->get_value( "username" ) ) );
                $author->appendChild( $name );
                my $author_email = $owner->get_value( "email" );
                if( defined $author_email )
                {
                        my $email_tag = $repo->make_element( "atom:email" );
                        $email_tag->appendChild( $repo->make_text( $author_email ) );
                        $author->appendChild( $email_tag );
                }
                $entry->appendChild( $author );
        }

        # SOURCE GENERATOR
	my $source_gen = $repo->config( "sword", "service_conf" )->{generator};
        $source_gen = $repo->phrase( "archive_name" ) unless(defined $source_gen);

        my $source = $repo->make_element( "atom:source" );
        my $generator = $repo->make_element( "atom:generator" );
        $generator->setAttribute( "uri", $repo->config( "base_url" ) );
        $generator->appendChild($repo->make_text( $source_gen ) );
        $source->appendChild( $generator );
        $entry->appendChild( $source );

        #VERBOSE (if defined)
       if(defined $verbose)
        {
                my $sword_verbose = $repo->make_element( "sword:verboseDescription" );
                $sword_verbose->appendChild( $repo->make_text( $verbose ) );
                $entry->appendChild( $sword_verbose );
        }

        # SWORD TREATMEMT
	my $sword_treat = $repo->make_element( "sword:treatment" );
        $sword_treat->appendChild( $repo->make_text( $sword_treatment ) );
        $entry->appendChild( $sword_treat );


	if( defined $opts{x_packaging} )
	{
		my $sword_xpack = $repo->make_element( "sword:packaging" );
		$sword_xpack->appendChild( $repo->make_text( $opts{x_packaging} ) );
		$entry->appendChild( $sword_xpack );
	}

        # USER AGENT (if set)
	if(defined $opts{user_agent})
        {
                my $sword_agent = $repo->make_element( "sword:userAgent" );
                $sword_agent->appendChild( $repo->make_text( $opts{user_agent} ) );
                $entry->appendChild( $sword_agent );
        }
	
	my $sword_noop = $repo->make_element( "sword:noOp" );
	$sword_noop->appendChild( $repo->make_text( "true" ) );
	$entry->appendChild( $sword_noop );

	my $sword_summ = $repo->make_element( "atom:summary" );
	$entry->appendChild( $sword_summ );

	EPrints::XML::tidy( $entry );

        return '<?xml version="1.0" encoding="UTF-8"?>'.$entry->toString;

}

our $GRAMMAR = {
	'X-Extract-Archive' => 'explode',
	'X-Override-Metadata' => 'metadata',
	'X-Extract-Bibliography' => 'bibliography',
	'X-Extract-Media' => 'media',
};

sub get_grammar
{
	return $GRAMMAR;
}

sub send_response
{
	my( $r, $status, $content_type, $content ) = @_;

	use bytes;

	$r->status( $status );
	$r->err_headers_out->{'Content-Type'} = $content_type;
	if( defined $content )
	{
		$r->err_headers_out->{'Content-Length'} = length $content;
		binmode(STDOUT, ":utf8");
		print $content;
	}

	return $status;
}

1;

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

