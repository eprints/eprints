package EPrints::CRUD::DeleteHandler;

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
	my $repository = $session->get_repository();

	if(! defined $session )
	{
		print STDERR "\n[CRUD HANDLER] [INTERNAL-ERROR] Could not create session objecti.";
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
                        $request->err_headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
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
	
	my $uri = $request->uri;
	
	# SUPPORTED URIS 

	if(!( $uri =~ m! ^/id/(eprint|document|file)/\d+$ !x ))
	{
		
		$request->status( 400 );
		$session->terminate;
		return Apache2::Const::HTTP_BAD_REQUEST;

	}

	my $owner = $response->{owner};
	my $depositor = $response->{depositor};		# undef unless mediated delete

	# Processing HTTP headers in order to retrieve SWORD options
	my $headers = $request->headers_in;
	$verbose_desc .= $headers->{verbose_desc};

	my $VERBOSE = $headers->{x_verbose};
	my $NO_OP = $headers->{no_op};

	#GET THE EPRINT/DOCUMENT/FILE/WHATEVER FROM THE ID URI
	my $datasetid;
	my $id;

	if( $uri =~ m! ^/id/([^/]+)/(.*)$ !x )
	{
		( $datasetid, $id ) = ( $1, $2 );
	}

	my $dataset = $repository->get_dataset( $datasetid );
	my $item;
	if( defined $dataset )
	{
		$item = $dataset->dataobj( $id );
	}

	if (!defined $item) 
	{
		$request->status( 404 );
		$session->terminate;
		return Apache2::Const::HTTP_NOT_FOUND;

	}

	#GET THE COLLECTION FROM THE EPRINT , FROM THE PARENT IF NECESSARY.

	my $eprint = $item;
	
	if (!($dataset->{id} eq "eprint")) {
		$eprint = $item->get_parent();
	}
	if ($dataset->{id} eq "file") {
		# This means that we need the parent of the document which we got from the previous get_parent() call.
		$eprint = $eprint->get_parent();
	}
	
	#CHECK THAT THE OWNER OF THIS ITEM IS THE OWNER OF THE REQUEST
	$eprint = EPrints::DataObj::EPrint->new( $session, $eprint->get_value("eprintid") );
	my $user = EPrints::DataObj::User->new( $session, $owner->get_value("userid") );
	$session->{eprint} = $eprint;
	$session->{current_user} = $user;

	my $collection = $eprint->get_value ( "eprint_status" );
		
	my $collections = EPrints::Sword::Utils::get_collections( $session );
	
	my $collec_conf = $collections->{$collection};
	
	unless ($owner->get_value("userid") eq $eprint->get_value("userid")) 
	{

# Allow Mediations by default (this doesn't mean any mediation is authorised)
		my $allow_mediation = 1;

# Unless this is disabled in the conf:
		if(defined $collec_conf->{mediation} && (lc $collec_conf->{mediation}) eq 'false')
		{
			$allow_mediation = 0;
		}

		if( defined $depositor && !$allow_mediation )	
		{
			$verbose_desc .= "ERROR: Mediated deletion is disabled.\n";

			my $error_doc = EPrints::Sword::Utils::generate_error_document( $session,
					user_agent => $headers->{user_agent},
					summary => "Invalid mediated delete.",
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
	}

	unless ($eprint->obtain_lock($user)) 
	{ 
		$request->status( 409 );
		$session->terminate;
		return Apache2::Const::HTTP_CONFLICT;
	}
	if (defined $collec_conf->{deletion} && (lc $collec_conf->{mediation}) eq 'true') 
	{
		if ($item->remove()) {
			$request->status( 204 );
			$session->terminate;
			return Apache2::Const::HTTP_NO_CONTENT;
		}
	}
	else 
	{
		if ($dataset->{id} eq "eprint") 
		{
			if (allow( $session, "eprint/move_deletion" ))
			{
				$eprint->move_to_deletion;

				$request->status( 204 );	# No Content
				$session->terminate;
				return Apache2::Const::HTTP_NO_CONTENT;
			}
			if (request_delete($session)) {
				$eprint->set_value( "edit_lock_until", 0 );
				$eprint->commit();
				$request->status( 202 );
				$session->terminate;
				return Apache2::Const::HTTP_ACCEPTED;
			} else {
				$eprint->set_value( "edit_lock_until", 0 );
				$eprint->commit();
				$request->status( 500 );
				$session->terminate;
				return Apache2::Const::HTTP_INTERNAL_SERVER_ERROR;
			}	
		}
		else 
		{
			#MARK THE ITEM YOU WANT REMOVED WITH A RELATION
			#CLONE THE EPRINT WITHOUT THE ITEM YOU WANT TO REMOVE (SEARCH FOR IT AFTER BY RELATIONS)

			my $original_value;
			if ($dataset->{id} eq "file") {
				$original_value = $item->get_value("filename");
				$item->set_value("filename","move_deletion");
			} else {
				$original_value = $item->get_value("formatdesc");
				$item->set_value("formatdesc","move_deletion");
			}
			$item->commit;

			my $dest_dataset = "buffer";
			if ($collection eq "inbox") {
				$dest_dataset = "inbox";
			}

			my $ds = $session->get_archive()->get_dataset( $dest_dataset );
			my $new_eprint = $eprint->clone($ds,1,undef);
			
			my @eprint_docs = $new_eprint->get_all_documents;
			foreach my $doc ( @eprint_docs )
			{
				if ($doc->get_value("formatdesc") eq "move_deletion")
				{
					$doc->remove();
					$item->set_value("formatdesc", $original_value);
				}
				foreach my $file (@{($doc->get_value( "files" ))})
				{
					if ($file->get_value("filename") eq "move_deletion")
					{
						$file->remove();
						$item->set_value("filename", $original_value);
					}
				}
			}
			$eprint->set_value( "edit_lock_until", 0 );
			$item->commit();
			$eprint->commit();
			$new_eprint->commit();

			my %xml_opts;
			$xml_opts{eprint} = $new_eprint;
			$xml_opts{x_packaging} = $headers->{x_packaging};
			$xml_opts{owner} = $owner;
			$xml_opts{depositor} = $depositor;
			$xml_opts{verbose_desc} = $verbose_desc if( $VERBOSE );
			$xml_opts{user_agent} = $headers->{user_agent};

			my $xml = EPrints::Sword::Utils::create_xml( $session, %xml_opts );

			$request->headers_out->{'Location'} = EPrints::Sword::Utils::get_atom_url( $session, $new_eprint );
			$request->headers_out->{'Content-Length'} = length $xml;
			$request->content_type('application/atom+xml');

			$request->print( $xml );
			$request->status( 201 );	# Created
			$session->terminate;	
			return Apache2::Const::HTTP_CREATED;

		}
	}
	$eprint->set_value( "edit_lock_until", 0 );
	$item->commit();
	
	$request->status( 400 );	
	$session->terminate;
	return Apache2::Const::HTTP_BAD_REQUEST;
}

sub allow
{
	my( $session, $priv ) = @_;
	return 0;
	return 0 unless defined $session->{eprint};
	my $status = $session->{eprint}->get_value( "eprint_status" );

	$priv =~ s/^eprint\//eprint\/$status\//;	

	return 1 if( $session->allow_anybody( $priv ) );
	return 0 if( !defined $session->current_user );
	return $session->current_user->allow( $priv, $session->{eprint} );
}

sub request_delete
{
	my( $session ) = @_;

	my $eprint = $session->{eprint};
	my $user = $session->current_user;

	# nb. Phrases in language of target not sender.

	my $ed = $eprint->get_editorial_contact;

	my $langid;
	if( defined $ed )
	{
		$langid = $ed->get_value( "lang" );
	}
	else
	{
		$langid = $session->get_conf( "defaultlanguage" );
	}
	my $lang = $session->get_language( $langid );

	my %mail;
	$mail{session} = $session;
	$mail{langid} = $langid;
	$mail{subject} = EPrints::Utils::tree_to_utf8( $lang->phrase( 
		"Plugin/Screen/EPrint/RequestRemoval:subject",
		{},
		$session ) );
	$mail{sig} = $lang->phrase( 
		"mail_sig",
		{},
		$session );

	if( defined $ed )
	{
 		$mail{to_name} = EPrints::Utils::tree_to_utf8( $ed->render_description ),
 		$mail{to_email} = $ed->get_value( "email" );
	}
	else
	{
 		$mail{to_name} = EPrints::Utils::tree_to_utf8( $lang->phrase( 
			"lib/session:archive_admin",
			{},
			$session ) );
 		$mail{to_email} = $session->get_repository->get_conf( "adminemail" );
	}
	
	my $from_user = $session->current_user;
	$mail{from_name} = EPrints::Utils::tree_to_utf8( $from_user->render_description() );
	$mail{from_email} = $from_user->get_value( "email" );

	my $reason = $session->html_phrase("Plugin/Screen/EPrint/RequestRemoval:reason");
	$mail{message} = $session->html_phrase(
		"Plugin/Screen/EPrint/RequestRemoval:mail",
		user => $from_user->render_description,
		email => $session->make_text( $from_user->get_value( "email" )),
		citation => $eprint->render_citation,
		url => $session->render_link(
				$eprint->get_control_url ),
		reason => $reason );

	my $mail_ok = EPrints::Email::send_mail( %mail );

	if( !$mail_ok ) 
	{
		return 0;
	}

	my $history_ds = $session->get_repository->get_dataset( "history" );

	$history_ds->create_object( 
		$session,
		{
			userid=>$from_user->get_id,
			datasetid=>"eprint",
			objectid=>$eprint->get_id,
			revision=>$eprint->get_value( "rev_number" ),
			action=>"removal_request",
			details=> EPrints::Utils::tree_to_utf8( $mail{message} , 80 ),
		}
	);

	return 1;
}


1;
