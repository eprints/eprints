package EPrints::CRUD::PostHandler;

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

	#Get the collection from the EPrint, from the parent if necessary

	my $eprint = $item;
	my $new_object_dataset = "document";
	

	if ($dataset->base_id eq "document") {
		$eprint = $item->parent;
		$new_object_dataset = "file";
	} 
	elsif ($dataset->base_id eq "file")
	{
		# Can't post to a file! Invalaid request
		
		$request->status( 400 );	
		$repository->terminate;
		return HTTP_BAD_REQUEST;
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

	#check the user can edit this eprint
	unless (allow( $eprint, "eprint/edit" )) {
		$request->status( 403 );
		$repository->terminate;
		return HTTP_FORBIDDEN;
	}

	$repository->read_params();

	# Saving the data/file sent through POST
        my $postdata = $repository->{query}->{'POSTDATA'};

 	# This is because CGI.pm (>3.15) has changed:
        if( !defined $postdata || scalar @$postdata < 1 )
	{
		push @$postdata, $repository->{query}->param( 'POSTDATA' );
	}
		
	# to let cURL works
        if( !defined $postdata || scalar @$postdata < 1 )
        {
		push @$postdata, $repository->{query}->param();
	}

        if( !defined $postdata || scalar @$postdata < 1 )
        {
		$verbose_desc .= "[ERROR] No files found in the postdata.\n";

                my $error_doc = EPrints::Sword::Utils::generate_error_document( $repository,
					user_agent => $headers->{user_agent},
					summary => "Missing postdata.",
                                        href => "http://purl.org/net/sword/error/ErrorBadRequest",
					verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

                $request->headers_out->{'Content-Length'} = length $error_doc;
                $request->content_type('application/atom+xml');
                $request->print( $error_doc );
		$request->headers_out->{'X-Error-Code'} = 'ErrorBadRequest';
		$request->status( 400 );
		$repository->terminate;
		return DONE;
        }

        my $post = $$postdata[0];
	
	# Check the MD5 we received is correct
	if(defined $headers->{md5})
	{
                my $real_md5 = Digest::MD5::md5_hex( $post );
                if( $real_md5 ne $headers->{md5} )
                {
			$verbose_desc .= "[ERROR] MD5 checksum is incorrect.\n";

			my $error_doc = EPrints::Sword::Utils::generate_error_document( $repository,
					user_agent => $headers->{user_agent},
						summary => "MD5 checksum is incorrect",
						href => "http://purl.org/net/sword/error/ErrorChecksumMismatch",
						verbose_desc => ($VERBOSE ? $verbose_desc : undef) );

			$request->headers_out->{'Content-Length'} = length $error_doc;
			$request->content_type('application/atom+xml');
			$request->print( $error_doc );
			$request->headers_out->{'X-Error-Code'} = 'ErrorChecksumMismatch';
			$request->status( 412 );
			$repository->terminate;
			return Apache2::Const::DONE;
                }
	}

	# Create a temp directory which will be automatically removed by PERL
	my $tmp_dir = File::Temp->newdir( "swordXXXX", TMPDIR => 1 );
 
	if( !defined $tmp_dir )
        {
                print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp directory!";
		$request->status( 500 );
		$repository->terminate;
                return Apache2::Const::DONE;
        }

	# Save post data to file
	my $filename = "posted_file";
	if (defined $headers->{filename}) {
		$filename = $headers->{filename};
	} elsif (defined $headers->{"Content-Disposition"}) {
		my @values = split(/;/,$headers->{"Content-Disposition"});
		foreach my $value (@values) {
			my @keypairs = split(/=/,$value);
			my $key = _trim(@keypairs[0]);
			if ($key eq "filename") {
				if (defined _trim(@keypairs[1])) {
					$filename = _trim(@keypairs[1]);
				}
			}
		}
	}

	my $file = $tmp_dir.'/'. $filename;

        if (open( TMP, '>'.$file ))
        {
		binmode( TMP );
		print TMP $post;
		close(TMP);
        }
        else
	{
		print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp file because: $!";
		$request->status( 500 );
		$repository->terminate;
		return Apache2::Const::DONE;
	}

	my $xml;
	my $list;
	
	if (open (my $fh, '<'.$file)) {
		if ($new_object_dataset eq "file") {
			my @in_ids;
			my @out_ids;
			foreach my $file (@{($item->get_value( "files" ))}) {
				push (@in_ids,$file->get_value( "fileid" ));
			}
			if ($headers->{"X-Extract-Archive"} eq "true") {
				my $format = "zip";
				if ((index $filename, "tar") > 0) {
					$format = "targz"
				}
				$item->upload_archive($fh,$filename,$format);
			} else {
				$item->upload($fh,$filename,0,$headers->{"Content-Length"});	
			}
			foreach my $file (@{($item->get_value( "files" ))}) {
				push (@out_ids,$file->get_value( "fileid" ));
			}
			$list = get_file_list($repository,\@in_ids,\@out_ids,"file");
		}
		if ($new_object_dataset eq "document") {
			my $format = $repository->call( 'guess_doc_type', $repository, $filename );			
			my( @plugins ) = $repository->get_plugins(
					type => "Import",
					can_produce => "dataobj/document",
					can_accept => $format,
					);

			my $plugin = $plugins[0];

			if( !defined $plugin )
			{
				#create a blank doc and add the file.
				my $doc = $eprint->create_subdataobj( "documents", {
						format => $format,
						} );
				$doc->upload($fh,$filename,0,$headers->{"Content-Length"});
				my @docs;
				push (@docs,$doc);
				$list = EPrints::List->new(
						session => $repository,
						dataset => $repository->dataset( "document" ),
						ids => [map { $_->id } @docs] );
			} else {
				if( $headers->{"X-Extract-Archive"} eq "true" )
				{
					$list = $plugin->input_fh(
							fh => $fh,
							dataobj => $eprint,
							);
				}
				else
				{
					my $doc = $eprint->create_subdataobj( "documents", {
							format => "other",
							} );
					$list = $plugin->input_fh(
							fh => $fh,
							dataobj => $doc	
							);
					$doc->remove if !defined $list;
				}
			}
		}
		close($fh);
	}
	$eprint->remove_lock( $user );
	
	my $accept = $headers->{ "Accept" };
	$accept = "application/atom+xml" unless defined $accept;
	my $list_dataset = $list->{dataset};
	my $can_accept = "list/" . $list_dataset->id;

	my $plugin = EPrints::Apache::Rewrite::content_negotiate_best_plugin( 
		$repository, 
		accept_header => $accept,
		consider_summary_page => 0,
		plugins => [$repository->get_plugins(
			type => "Export",
			is_visible => "all",
			can_accept => $can_accept )]
	);

	if (!defined $plugin) {

		$xml = $list->export("Atom");

	} else {
	
		$xml = $list->export($plugin->{name});

	}

	if (defined $xml) {
		$request->headers_out->{'Content-Length'} = length $xml;
		$request->content_type('application/atom+xml');
	
		$request->print( $xml );
		$request->status( 201 );	
		
		$repository->terminate;
		return HTTP_CREATED;
	}
		
	$request->status( 500 );	
	
	$repository->terminate;
	return HTTP_INTERNAL_SERVER_ERROR;
}

sub get_file_list 
{
	my ($repository, $in_ids, $out_ids, $dataset) = @_;

	my $added_ids = get_added_ids($in_ids,$out_ids);
	my @files;

	foreach my $added_id(@{$added_ids}) {
		my $file = EPrints::DataObj::File->new( $repository, $added_id );
		push(@files,$file);
	}

	return EPrints::List->new(
			session => $repository,
			dataset => $repository->dataset( "file" ),
			ids => [map { $_->id } @files] );
	
}

sub get_added_ids
{
	my ($in_ids, $out_ids) = @_;
	my @added_ids;
	foreach my $out_id(@{$out_ids}) {
		my $got_it = 0;
		foreach my $in_id(@{$in_ids}) {
			if ($in_id eq $out_id) {
				$got_it = 1;
			} 
		}
		if ($got_it < 1) {
			push (@added_ids, $out_id);
		}
	}
	return \@added_ids;
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

sub _trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	$string =~ s/^"//;
	$string =~ s/"$//;
	return $string;
}

1;
