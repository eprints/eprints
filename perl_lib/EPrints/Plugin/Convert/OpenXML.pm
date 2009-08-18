package EPrints::Plugin::Convert::OpenXML;

use strict;
use warnings;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

# adpated from Import::DSpace:
our $GRAMMAR = {
                'dcterms:created' => [ 'date' ],
                'dc:publisher' => [ 'publisher' ],
                'dc:title' => [ 'title' ],
                'dc:description' => [ \&ep_dc_join, 'abstract' ],
                'dc:creator' => [ \&ep_dc_creator, 'creators_name' ],
                'dc:rights' => [ 'notes' ],
};


our $SWORD_GRAMMAR = {
		'my:kwd.controltype.richtextbox.' => ['keywords'],
		'my:contrib.' => ['creators_name']
};



sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "metadata/media extractor";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	# don't want to be called by the Uploader or else at this stage
	return;
}


# type = { both, metadata, media } decides on what to extract
sub convert
{
        my ($plugin, $eprint, $doc, $type, $user) = @_;
	
#	if( defined $plugin->{handle}->current_user )
#	{
#		unless( $eprint->obtain_lock( $plugin->{handle}->current_user ) )
#		{
#			print STDERR "\nFailed to obtain the lock for eprint object.";
#			return;
#		}
#	}
#	else
#	{
#		if(defined $user)
#		{
#			unless( $eprint->obtain_lock( $user ) )
#			{
#				print STDERR "\nFailed to obtain the lock for eprint object (2).";
#				return;
#			}
#		}
#	}

	$plugin->{dataset} = $plugin->{handle}->get_repository->get_dataset( $eprint->get_dataset_id );
	$plugin->{_eprint} = $eprint;

        my $dir = EPrints::TempDir->new( "ep-convertXXXXX", UNLINK => 1);

        my @files = $plugin->export( $dir, $doc, $type );
        unless( @files ) {
                return undef;
        }

        my $handle = $plugin->{handle};
        
	my $doc_ds = $handle->get_repository->get_dataset( "document" );

	my @new_docs;

        foreach my $filename (@files)
        {
                my $fh;
                unless( open($fh, "<", "$dir/$filename") )
                {
                        $handle->get_repository->log( "Error reading from $dir/$filename: $!" );
                        next;
                }
		my @filedata;
                push @filedata, {
                        filename => $filename,
                        filesize => (-s "$dir/$filename"),
                        url => "file://$dir/$filename",
                        _filehandle => $fh,
                };
                # file will take care of closing $fh for us
    
	        my $new_doc = $doc_ds->create_object( $handle, {
			files => \@filedata,
			main => $filename,
			eprintid => $eprint->get_id,
			_parent => $eprint,
			format =>  $handle->get_repository->call( "guess_doc_type", $handle, $filename ),
			formatdesc => 'extracted from openxml format',
			relation => [{
				type => EPrints::Utils::make_relation( "isVersionOf" ),
				uri => $doc->internal_uri(),
			},{
				type => EPrints::Utils::make_relation( "isPartOf" ),
				uri => $doc->internal_uri(),
			}] } );


	        $new_doc->set_value( "security", $doc->get_value( "security" ) );
		$new_doc->commit();

        	$doc->add_object_relations(
                        $new_doc,
                        EPrints::Utils::make_relation( "hasVersion" ) => undef,
                        EPrints::Utils::make_relation( "hasPart" ) => undef,
                );

		push @new_docs, $new_doc;
	}

	$doc->commit;
	$eprint->commit;

	return undef unless(scalar(@new_docs));

        return wantarray ? @new_docs : $new_docs[0];
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	my $main = $doc->get_main;
	
	my $repository = $plugin->get_repository();

	my $file = $doc->get_stored_file( $doc->get_main )->get_local_copy();

	my %opts = (
		ARC => "$file",
		DIR => $dir,
	);	

	if( !$repository->can_invoke( "zip", %opts ) )
	{
		$repository->log( "cannot invoke unzip" );
		return;
	}

	$repository->exec( "zip", %opts );

	my $dh;
	opendir $dh, $dir;
	unless( defined $dh )
	{
		$repository->log( "Unable to open directory $dir: $!" );
		return;
	}

	my @files = grep { $_ !~ /^\./ } readdir($dh);
	closedir $dh;
	foreach( @files ) { EPrints::Utils::chown_for_eprints( $_ ); }

	return unless( scalar(@files) );

	# try to open/parse the DC
	# try to open "word/_rels/document.xml.rels" for embedded media
	# try to open/parse item2.xml for SWORD imports

	my $content_dir;
	$content_dir = "word" if( $main =~ /.docx$/ );
	$content_dir = "ppt" if( $main =~ /.pptx$/ );
	
	return unless( defined $content_dir );
	
	# will attempt to parse the DC metadata, and commit to the eprint object
	
	if( $type eq 'both' || $type eq 'metadata' )
	{
		$plugin->_parse_dc( $dir ); 
	}

	my $files;
	if( $type eq 'both' || $type eq 'media' )
	{
		$files = $plugin->_extract_media_files( $dir, $content_dir ); 
	}
	
	return unless( defined $files );
	
	return @$files;
}


sub _extract_media_files
{
	my( $self, $dir, $content_dir ) = @_;

	my $media_dir = EPrints::Platform::join_path( $dir, $content_dir, "media" );
	
	my $dh;
        opendir $dh, $media_dir;
        return unless( defined $dh );

        my @files = grep { $_ !~ /^\./ } readdir($dh);
        closedir $dh;

	my @real_files;
	foreach(@files)
	{
		push @real_files, EPrints::Platform::join_path( $content_dir, "media", $_ );
	}

	if( $content_dir eq 'ppt' )
	{
		my $thumbnail = EPrints::Platform::join_path( $dir, "docProps/thumbnail.jpeg" );
		push @real_files, "docProps/thumbnail.jpeg" if( -e $thumbnail );
	}

	return \@real_files;
}


sub _parse_dc
{
	my ( $self, $dir ) = @_;

	my $eprint = $self->{_eprint};
	return unless( defined $eprint );

	my ($file,$fh);

	$file = EPrints::Platform::join_path( $dir, "docProps/core.xml" );

        return unless( open( $fh, $file ) );

        my ($xml,$dom_doc);
        while( my $d = <$fh> )
        {
                $xml .= $d;
        }
        close $fh;	
        eval
        {
                $dom_doc = EPrints::XML::parse_xml_string( $xml );
        };

        return if($@ || !defined $dom_doc);

        my $dom_top = $dom_doc->getDocumentElement;

        return if( (lc $dom_top->tagName) ne 'cp:coreproperties' );

	my @nodes = $dom_top->childNodes;

	my $dcdata = {};

	foreach(@nodes)
	{
		my @v = $_->childNodes();
		next unless( scalar( @v ) );
		next unless( defined $v[0]->nodeValue );
		$dcdata->{$_->tagName} = $v[0]->nodeValue;

	}

	my $grammar = $self->get_grammar;

	foreach my $dc (keys %$dcdata)
	{
		my $opts = $grammar->{$dc};
		next if( !defined $opts || scalar(@$opts) == 0 );
		my $f = $$opts[0];
		delete $$opts[0];
		my $ep_value = {};

		my $values = $dcdata->{$dc};
		next unless( defined $values );

                if( ref($f) eq "CODE" )
                {	
			my $fieldname = $$opts[1];
			next unless(defined $fieldname);
				
			eval {
	                        $ep_value = &$f( $self, $values, $fieldname );
			};

			next if($@ || !defined $ep_value);
                        next unless $self->{dataset}->has_field( $fieldname );
                     
		        $eprint->set_value( $fieldname, $ep_value );
                }
                else
                {
			my $fieldname = $f;
                        # skip this field if it isn't supported by the current repository
                        next unless $self->{dataset}->has_field( $fieldname );

                        my $field = $self->{dataset}->get_field( $fieldname );
                        if( $field->get_property( "multiple" ) )
                        {
				my @a = ($values);
				$eprint->set_value( $fieldname, \@a );
                        }
                        else
                        {
				$eprint->set_value( $fieldname, $values );
                        }
		}
	}
	
	$file = "file://" . $dir . "/word/document.xml";
	$dom_doc = eval { EPrints::XML::parse_url( $file ) };

	if( defined $dom_doc )
	{
		$dom_top = $dom_doc->documentElement;

		my %alias_sections;

		foreach my $alias ($dom_top->getElementsByLocalName( "alias" ))
		{
			my $type = $alias->getAttribute( "w:val" );

			my $sdt = $alias->parentNode;
			$sdt = $sdt->parentNode while $sdt->localName ne "sdt";

			$alias_sections{lc($type)} = $sdt->textContent;
		}
		if( defined $alias_sections{"title"} )
		{
			$eprint->set_value( "title", $alias_sections{"title"} );
		}
		if( defined $alias_sections{"abstract"} )
		{
			$eprint->set_value( "abstract", $alias_sections{"abstract"} );
		}
	}

#	$eprint->commit(1);

	$file = "file://" . $dir . "/customXml/item2.xml";
	$dom_doc = eval { EPrints::XML::parse_url( $file ) };

	if( defined $dom_doc )
	{
		$dom_top = $dom_doc->documentElement;

		my @names;

		foreach my $name ($dom_top->getElementsByLocalName("name."))
		{
			my( $surname ) = $name->getElementsByLocalName("surname.");
			my( $given ) = $name->getElementsByLocalName("given-names.");
			push @names, {
				family => $surname->textContent,
				given => $given->textContent };
		}
		$eprint->set_value( "creators_name", \@names ) if scalar @names;
	}

	$eprint->commit(1);

	return;
}

sub get_grammar
{
        return $GRAMMAR;
}

# there's only one creator in openxml (the owner of the doc I guess)
sub ep_dc_creator
{
        my( $self, $values, $fieldname ) = @_;

        my @names;

        my( $given, $family ) = split /\s* \s*/, $values;

	push @names, {
		family => $family,
		given => $given,
	};

	return \@names;
}

sub ep_dc_join
{
        my( $self, $values, $fieldname ) = @_;
	return join("\n", @$values );
}


1;


