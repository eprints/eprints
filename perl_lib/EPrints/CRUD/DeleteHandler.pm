package EPrints::CRUD::DeleteHandler;

use strict;

use Digest::MD5;

use EPrints;
use EPrints::Sword::Utils;

use EPrints::Const qw( :http );

sub handler 
{
	my $request = shift;

	my $repository = $EPrints::HANDLE->current_repository();

	# "verbose_desc" is only sent when verbose is enabled. The desc itself is always built though.
	my $verbose_desc = "[OK] Verbose mode enabled.\n";

	my $response = EPrints::Sword::Utils::authenticate( $repository, $request );
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
			$repository->terminate;
			return DONE;
                }

		my $error_doc = EPrints::Sword::Utils::generate_error_document( $repository, 
					summary => "Authentication error.",
					href => $error->{error_href}, 
					verbose_desc => $verbose_desc );

		$request->status( $error->{status_code} );
	        $request->headers_out->{'Content-Length'} = length $error_doc;
        	$request->content_type('application/atom+xml');
		$request->print( $error_doc );
                $repository->terminate;
                return DONE;
        }
	
	my $uri = $request->uri;
	
	# Suppoerted URIs: Hopeing to expand beyond these if possible 

	if(!( $uri =~ m! ^/id/(eprint|document|file)/\d+$ !x ))
	{
		
		$request->status( 400 );
		$repository->terminate;
		return HTTP_BAD_REQUEST;

	}

	# Processing HTTP headers in order to retrieve SWORD options
	my $headers = $request->headers_in;
	$verbose_desc .= $headers->{verbose_desc};

	my $VERBOSE = $headers->{x_verbose};

	#GET THE EPRINT/DOCUMENT/FILE/WHATEVER FROM THE ID URI
	my $datasetid;
	my $id;

	if( $uri =~ m! ^/id/([^/]+)/(.*)$ !x )
	{
		( $datasetid, $id ) = ( $1, $2 );
	}

	my $dataset = $repository->dataset( $datasetid );
	my $item;
	if( defined $dataset )
	{
		$item = $dataset->dataobj( $id );
	}

	if (!defined $item) 
	{
		$request->status( 404 );
		$repository->terminate;
		return HTTP_NOT_FOUND;

	}

	#GET THE COLLECTION FROM THE EPRINT , FROM THE PARENT IF NECESSARY.

	my $eprint = $item;
	
	if ($dataset->base_id eq "document") {
		$eprint = $item->parent;
	} 
	elsif ($dataset->base_id eq "file")
	{
		my $doc = $item->parent;
		if (!defined $doc) {
			$request->status( 500 );
			$repository->terminate;
			return HTTP_INTERNAL_SERVER_ERROR;
		}
		$eprint = $doc->parent;
	}
	if (!defined $eprint) 
	{
		$request->status( 500 );
		$repository->terminate;
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	my $owner = $response->{owner};
	$repository->{current_user} = EPrints::DataObj::User->new($repository, $owner->get_value("userid"));
	my $user = $repository->current_user();

	my $collection = $eprint->dataset->id;
		
	my $collections = EPrints::Sword::Utils::get_collections( $repository );
	
	my $collec_conf = $collections->{$collection};
	
	unless ($eprint->obtain_lock($user)) 
	{ 
		$request->status( 409 );
		$repository->terminate;
		return HTTP_CONFLICT;
	}
	
	if ($collec_conf->{deletion} eq 'true') 
	{
		if ($item->remove()) {
			$request->status( 204 );
			$repository->terminate;
			return HTTP_NO_CONTENT;
		}
	}
	else 
	{
		if ($dataset->{id} eq "eprint") 
		{
			if (allow( $eprint, "eprint/move_deletion" ))
			{
				$eprint->move_to_deletion;

				$request->status( 204 );	# No Content
				$repository->terminate;
				return HTTP_NO_CONTENT;
			}
			my $processor = EPrints::ScreenProcessor->new(
					session => $repository,
					eprint => $eprint,
					);
			my $plugin = $repository->plugin( "Screen::EPrint::RequestRemoval", processor => $processor );
			if ($plugin->action_send()) {
				$eprint->remove_lock( $user );
				$request->status( 202 );
				$repository->terminate;
				return HTTP_ACCEPTED;
			} else {
				$eprint->remove_lock( $user );
				$eprint->commit();
				$request->status( 500 );
				$repository->terminate;
				return HTTP_INTERNAL_SERVER_ERROR;
			}	
		}
		else 
		{
			# Mark the item you want removed with a relation
			# Clone the eprint you want to remove the item from
			# Remove the item from the new eprint by searching for the flag
			# Set it back in the old eprint

			my $original_value;
			if ($dataset->{id} eq "file") {
				$original_value = $item->value("hash");
			} else {
				$original_value = $item->value("pos");
			}
			$item->commit;

			my $dest_dataset = "buffer";
			if ($collection eq "inbox") {
				$dest_dataset = "inbox";
			}

			my $ds = $repository->get_archive()->get_dataset( $dest_dataset );
			my $new_eprint = $eprint->clone($ds,1,undef);
			
			my @eprint_docs = $new_eprint->get_all_documents;
			foreach my $doc ( @eprint_docs )
			{
				if ($dataset->{id} eq "document" && $doc->value("pos") eq $original_value)
				{
					$doc->remove();
					$item->set_value("formatdesc", $original_value);
				} 
				else
				{
					foreach my $file (@{($doc->value( "files" ))})
					{
						if ($file->value("hash") eq $original_value)
						{
							$file->remove();
						}
					}
				}
			}
			$eprint->remove_lock( $user );
			$eprint->commit();
			$new_eprint->commit();

			#TODO - This needs to be a list of things which is exported via $list->export()

			my %xml_opts;
			$xml_opts{eprint} = $new_eprint;
			$xml_opts{x_packaging} = $headers->{x_packaging};
			$xml_opts{owner} = $new_eprint->get_user;
			$xml_opts{depositor} = $repository->current_user;
			$xml_opts{verbose_desc} = $verbose_desc if( $VERBOSE );
			$xml_opts{user_agent} = $headers->{user_agent};

			my $xml = EPrints::Sword::Utils::create_xml( $repository, %xml_opts );

			$request->headers_out->{'Location'} = EPrints::Sword::Utils::get_atom_url( $repository, $new_eprint );
			$request->headers_out->{'Content-Length'} = length $xml;
			$request->content_type('application/atom+xml');

			$request->print( $xml );
			$request->status( 201 );	# Created
			$repository->terminate;	
			return HTTP_CREATED;

		}
	}
	$eprint->remove_lock( $user );
	$item->commit();
	
	$request->status( 400 );	
	$repository->terminate;
	return HTTP_BAD_REQUEST;
}

sub allow
{
	my( $eprint, $priv ) = @_;

	my $repository = $EPrints::HANDLE->current_repository();

	return 0 unless defined $eprint;

	my $status = $eprint->dataset->id;

	$priv =~ s/^eprint\//eprint\/$status\//;	

	return 1 if( $repository->allow_anybody( $priv ) );
	return 0 if( !defined $repository->current_user );
	return $repository->current_user->allow( $priv, $eprint );

}

1;
