=head1 NAME

EPrints::CRUD::PutHandler

=cut

package EPrints::CRUD::PutHandler;

use strict;

use Digest::MD5;

use EPrints;
use EPrints::Sword::Utils;

use EPrints::Const qw( :http );

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
			my $realm = $repository->phrase( "archive_name" );
                        $request->err_headers_out->{'WWW-Authenticate'} = 'Basic realm="'.$realm.'"';
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
	my $document;	

	if ($dataset->base_id eq "document") {
		$eprint = $item->parent;
	} 
	elsif ($dataset->base_id eq "file")
	{
		# Can't post to a file! Invalaid request
		$document = $item->parent;
		$eprint = $document->parent;
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

	#$repository->read_params();

	# Saving the data/file sent through POST
	#foreach my $key (keys %{$repository->{query}}) {
	#	print STDERR "KEY : $key \n\n";
	#}

	local $/;
	my $post = <STDIN>;

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

	my $content_type;
	if (defined $headers->{"Content-Type"}) {
		$content_type = $headers->{"Content-Type"};
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
	
	my $filesize = -s $file;
	my $list;

	if (open (my $fh, '<'.$file)) {
		if ($dataset->base_id eq "file") {
			$item->get_session->get_storage->delete( $item );
			$item->upload($fh,$filename,$filesize,undef);
			$item->commit();
		}
		if ($dataset->base_id eq "document") {
			# remove dependent objects and relations
			foreach my $dataobj (@{($item->get_related_objects())})
			{
				if(
					$dataobj->has_object_relations( $item, EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) ||
					$dataobj->has_object_relations( $item, EPrints::Utils::make_relation( "isPartOf" ) )
				  )
				{
					$dataobj->remove_object_relations( $item ); # avoid infinite loop
					$dataobj->remove();
				}
				else
				{
					$dataobj->remove_object_relations( $item );
					$dataobj->commit;
				}
			}
			
			# remove the files
			foreach my $file (@{($item->get_value( "files" ))})
			{
				$file->remove();
			}
			
			# build a blank epdata for the doc ?
	
			# The rest is as POST
			my $format = $content_type;
			if (!defined $format) 
			{
				$format = $repository->call( 'guess_doc_type', $repository, $filename );		
			}
			
			my( @plugins ) = $repository->get_plugins(
					type => "Import",
					can_produce => "dataobj/document",
					can_accept => $format,
					);
	
			my $plugin = $plugins[0];

			my $grammar = get_grammar();
			my $flags = {};
			foreach my $key (keys %{$headers}) {
				my $value = $grammar->{$key};
				if ((defined $value) and ($headers->{$key} eq "true")) {
					$flags->{$value} = 1;
				}
			}

			if( !defined $plugin )
			{
				#create a blank doc and add the file.
				$item->upload($fh,$filename,0,$headers->{"Content-Length"});
				$item->set_main($filename);
				$item->set_value("format", $format);
				$item->commit();
				my @docs;
				push (@docs,$item);
				$list = EPrints::List->new(
						session => $repository,
						dataset => $repository->dataset( "document" ),
						ids => [map { $_->id } @docs] );
			} else {
				$list = $plugin->input_fh(
					fh => $fh,
					filename => $filename,
					dataobj => $item,
					flags => $flags,
				);
			}
		}
		if ($dataset->base_id eq "eprint") {
			my $format = $content_type;
			if (!defined $format) 
			{
				$format = $repository->call( 'guess_doc_type', $repository, $filename );		
			}

			my $handler = EPrints::CRUD::PutHandler::Handler->new();
			
			my( @plugins ) = $repository->get_plugins(
{
	parse_only => 1,
	Handler => $handler
},
				type => "Import",
				can_produce => "dataobj/eprint",
				can_accept => $format,
			);
			
			my $plugin = $plugins[0];
			if (!defined $plugin) {
				$eprint->remove_lock( $user );
				$request->status( 415 );	
				$repository->terminate;
				return HTTP_UNSUPPORTED_MEDIA_TYPE;
			} 
			
			$plugin->input_fh(
				fh => $fh,
				filename => $filename,
				dataobj => $item,
				dataset => $dataset,
			);
			my $epdata = $handler->{epdata};

			if( defined( $item ) )
			{	
				foreach my $fieldname (keys %$epdata)
				{
					if( $dataset->has_field( $fieldname ) )
					{
						# Can't currently set_value on subobjects
						my $field = $dataset->get_field( $fieldname );
						next if $field->is_type( "subobject" );
						$item->set_value( $fieldname, $epdata->{$fieldname} );
					}
				}
				$item->commit();
			}
		}
		close($fh);
	}
	$eprint->remove_lock( $user );
	
	$request->status( 200 );	
	
	$repository->terminate;
	return HTTP_OK;
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

package EPrints::CRUD::PutHandler::Handler;

sub new
{
	my( $class, %self ) = @_;

	$self{wrote} = 0;
	$self{parsed} = 0;

	bless \%self, $class;
}

sub message
{
	my( $self, $type, $msg ) = @_;

	unless( $self->{quiet} )
	{
		$self->{processor}->add_message( $type, $msg );
	}
}

sub parsed
{
	my( $self, $epdata ) = @_;

	$self->{epdata} = $epdata;

	$self->{parsed}++;
}

sub object
{
	my( $self, $dataset, $dataobj ) = @_;

	$self->{wrote}++;

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

