package EPrints::Plugin::Import::OpenXML;

use EPrints::Plugin::Import;

@ISA = qw( EPrints::Plugin::Import );

use strict;

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

sub input_fh
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};
	my $eprint = $opts{dataobj};

	my $flags = $opts{flags};

	my $filename = $opts{filename};

	my $format = $session->call( "guess_doc_type", $session, $filename );

	# create the main document
	my $main_doc = $eprint->create_subdataobj( "documents", {
		format => $format,
		main => $filename,
		files => [{
			filename => $filename,
			filesize => (-s $opts{fh}),
			_content => $opts{fh}
		}],
	});
	if( !defined $main_doc )
	{
		$self->error( $self->phrase( "create_failed" ) );
		return;
	}
	
	my $main_file = $main_doc->get_stored_file( $main_doc->get_main );
	my $dir = $self->unpack( $main_file->get_local_copy, %opts );

	my @new_docs;

	if( $flags->{metadata} )
	{
		$self->_parse_dc( $main_doc, $dir );
	}

	if( $flags->{media} )
	{
		push @new_docs, $self->_extract_media_files( $main_doc, $dir ); 
	}

	if( $flags->{bibliography} )
	{
		push @new_docs, $self->_extract_bibl( $main_doc, $dir );
	}

	# add the reciprocal relations
	foreach my $new_doc ( @new_docs )
	{
		foreach my $relation ( @{$new_doc->value( "relation" )} )
		{
			next if $relation->{uri} ne $main_doc->internal_uri;
			my $type = $relation->{type};
			next if $type !~ s# /is(\w+)Of$ #/has$1#x;
			$main_doc->add_object_relations(
				$new_doc,
				$type
			);
		}
	}

	$main_doc->commit;
	$eprint->commit;

	return EPrints::List->new(
		session => $session,
		dataset => $main_doc->get_dataset,
		ids => [map { $_->id } $main_doc, @new_docs ],
		);
}

sub _extract_bibl
{
	my( $self, $main_doc, $dir ) = @_;

	my $eprint = $main_doc->get_parent;

	my $custom_dir = join_path( $dir, "customXml" );

	my @files;

	opendir(my $dh, $custom_dir) or return ();
	while(my $fn = readdir($dh))
	{
		next if $fn !~ /^itemProps(\d+)\.xml$/;
		my $idx = $1;

		next if !-e "$custom_dir/item$idx.xml";

		my $doc = eval { $self->{session}->xml->parse_file( "$custom_dir/$fn" ) };
		next if !defined $doc;

		my( $schemaRef ) = $doc->documentElement->getElementsByTagNameNS(
			"http://schemas.openxmlformats.org/officeDocument/2006/customXml",
			"schemaRef"
		);
		next if !defined $schemaRef;

		my $uri = $schemaRef->getAttributeNS(
			"http://schemas.openxmlformats.org/officeDocument/2006/customXml",
			"uri" );		
		next if !defined $uri;
		next if $uri ne "http://schemas.openxmlformats.org/officeDocument/2006/bibliography";

		next if !open(my $fh, "<", "$custom_dir/item$idx.xml");
		push @files, {
			filename => "item$idx.xml",
			filesize => (-s "$custom_dir/item$idx.xml"),
			mime_type => "text/xml",
			_content => $fh,
		};

		$self->_extract_references( $main_doc, $doc );
	}
	closedir($dh);

	return () if !scalar @files;

	return $eprint->create_subdataobj( "documents", {
		files => \@files,
		main => $files[0]->{filename},
		format => "text/xml",
		formatdesc => 'extracted from openxml',
		content => "bibliography",
		security => $main_doc->value( "security" ),
		relation => [{
			type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
			uri => $main_doc->internal_uri(),
			},{
			type => EPrints::Utils::make_relation( "isVersionOf" ),
			uri => $main_doc->internal_uri(),
			},{
			type => EPrints::Utils::make_relation( "isPartOf" ),
			uri => $main_doc->internal_uri(),
		}],
		});
}

sub _extract_references
{
	my( $self, $main_doc, $doc ) = @_;

	my $session = $self->{session};

	my $eprint = $main_doc->get_parent;
	return if !$eprint->get_dataset->has_field( "bibliography" );
	return if $eprint->is_set( "bibliography" );

	my $translator = $session->plugin( "Import::XSLT::OpenXMLBibl" );
	return if !defined $translator;

	my $epxml = $translator->transform( $doc );

	my @bibls;

	my $dataset = $eprint->get_dataset;
	my $class = $dataset->get_object_class;

	foreach my $xml ($epxml->documentElement->getElementsByTagName( 'eprint' ))
	{
		my $epdata = $class->xml_to_epdata( $session, $xml );
		$epdata->{eprint_status} = 'inbox';
		my $dataobj = $class->new_from_data(
			$session,
			$epdata,
			$dataset );
		my $citation = $dataobj->render_citation;
		push @bibls, join '', $session->xhtml->to_xhtml( $citation );
		$session->xml->dispose( $citation );
	}

	$eprint->set_value( "bibliography", \@bibls );
}

sub _extract_media_files
{
	my( $self, $doc, $dir ) = @_;

	my $eprint = $doc->get_parent;
	my $session = $self->{session};

	my $content_dir;

	my $main = $doc->get_main;
	if( $main =~ /\.docx$/ )
	{
		$content_dir = "word";
	}
	elsif( $main =~ /\.pptx$/ )
	{
		$content_dir = "ppt";
	}
	else
	{
		return; # unknown doc type
	}

	my $media_dir = join_path( $dir, $content_dir, "media" );
	
	my @files;

	opendir( my $dh, $media_dir ) or die "Error opening $media_dir: $!";
	foreach my $fn (readdir($dh))
	{
		next if $fn =~ /^\./;
		push @files, [$fn => join_path( $content_dir, "media", $fn )];
	}
	closedir $dh;

	if( $content_dir eq 'ppt' )
	{
		my $thumbnail = join_path( $dir, "docProps/thumbnail.jpeg" );
		push @files, ["thumbnail.jpeg" => $thumbnail] if( -e $thumbnail );
	}

	my @new_docs;

	foreach my $file (@files)
	{
		open(my $fh, "<", $$file[1]) or die "Error opening $$file[1]: $!";
		push @new_docs, $eprint->create_subdataobj( "documents", {
			main => $$file[0],
			format => $session->call( "guess_doc_type", $session, $$file[0] ),
			files => [{
				filename => $$file[0],
				filesize => (-s $fh),
				_content => $fh
			}],
			relation => [{
				type => EPrints::Utils::make_relation( "isVersionOf" ),
				uri => $doc->internal_uri(),
				},{
				type => EPrints::Utils::make_relation( "isPartOf" ),
				uri => $doc->internal_uri(),
			}],
		});
	}

	return @new_docs;
}


sub _parse_dc
{
	my( $self, $doc, $dir ) = @_;

	my $eprint = $doc->get_parent;
	my $dataset = $eprint->get_dataset;

	my ($file,$fh);

	$file = join_path( $dir, "docProps/core.xml" );

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
                        next unless $dataset->has_field( $fieldname );
                     
		        $eprint->set_value( $fieldname, $ep_value );
                }
                else
                {
			my $fieldname = $f;
                        # skip this field if it isn't supported by the current repository
                        next unless $dataset->has_field( $fieldname );

                        my $field = $dataset->get_field( $fieldname );
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

sub join_path
{
	return join('/', @_);
}

sub unpack
{
	my( $self, $tmpfile, %opts ) = @_;

	my $dir = EPrints::TempDir->new( CLEANUP => 1 );

	my $rc = $self->{session}->exec( "zip",
		DIR => $dir,
		ARC => $tmpfile
	);

	return $rc == 0 ? $dir : undef;
}

1;
