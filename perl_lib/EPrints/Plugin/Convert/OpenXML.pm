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

	my $session = $plugin->{session};
	my $doc_ds = $doc->get_dataset;
        
	$plugin->{dataset} = $eprint->get_dataset;
	$plugin->{_eprint} = $eprint;

	my @new_docs;

	my $dir = EPrints::TempDir->new( "ep-convertXXXXX", UNLINK => 1);

	my @files = $plugin->export( $dir, $doc, $type );

	push @new_docs, $plugin->_extract_bibl( $doc, $dir );

	foreach my $filename (@files)
	{
		my $fh;
		unless( open($fh, "<", "$dir/$filename") )
		{
			$session->log( "Error reading from $dir/$filename: $!" );
			next;
		}

		# file will take care of closing $fh for us
		push @new_docs, $eprint->create_subdataobj( "documents", {
			files => [{
				filename => $filename,
				filesize => (-s "$dir/$filename"),
				url => "file://$dir/$filename",
				_content => $fh,
			}],
			main => $filename,
			format => $session->call( "guess_doc_type", $session, $filename ),
			formatdesc => 'extracted from openxml format',
			security => $doc->value( "security" ),
			relation => [{
				type => EPrints::Utils::make_relation( "isVersionOf" ),
				uri => $doc->internal_uri(),
				},{
				type => EPrints::Utils::make_relation( "isPartOf" ),
				uri => $doc->internal_uri(),
			}],
			});
	}

	# add the reciprocal relations
	if( scalar(@new_docs) )
	{
		foreach my $new_doc ( @new_docs )
		{
			foreach my $relation ( @{$new_doc->value( "relation" )} )
			{
				next if $relation->{uri} ne $doc->internal_uri;
				my $type = $relation->{type};
				next if $type !~ s# /is(\w+)Of$ #/has$1#x;
				$doc->add_object_relations(
					$new_doc,
					$type
				);
			}
		}
		$doc->commit;
	}

	$eprint->commit;

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

sub _extract_bibl
{
	my( $self, $doc, $dir ) = @_;

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

		$self->_extract_references( "$custom_dir/item$idx.xml" );
	}
	closedir($dh);

	return () if !scalar @files;

	return $self->{_eprint}->create_subdataobj( "documents", {
		files => \@files,
		main => $files[0]->{filename},
		format => "text/xml",
		formatdesc => 'extracted from openxml',
		content => "bibliography",
		security => $doc->value( "security" ),
		relation => [{
			type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
			uri => $doc->internal_uri(),
			},{
			type => EPrints::Utils::make_relation( "isVersionOf" ),
			uri => $doc->internal_uri(),
			},{
			type => EPrints::Utils::make_relation( "isPartOf" ),
			uri => $doc->internal_uri(),
		}],
		});
}

sub _extract_references
{
	my( $self, $fn ) = @_;

	my $eprint = $self->{_eprint};
	return if !$eprint->get_dataset->has_field( "bibliography" );
	return if $eprint->is_set( "bibliography" );

	my $doc = eval { $self->{session}->xml->parse_file( $fn ) };
	return if !defined $doc;

	my $Sources = $doc->documentElement;

	my @bibls = map { $_->toString } $Sources->getElementsByTagName( "Source" );

	$eprint->set_value( "bibliography", \@bibls );
}

sub _extract_media_files
{
	my( $self, $dir, $content_dir ) = @_;

	my $media_dir = join_path( $dir, $content_dir, "media" );
	
	my $dh;
        opendir $dh, $media_dir;
        return unless( defined $dh );

        my @files = grep { $_ !~ /^\./ } readdir($dh);
        closedir $dh;

	my @real_files;
	foreach(@files)
	{
		push @real_files, join_path( $content_dir, "media", $_ );
	}

	if( $content_dir eq 'ppt' )
	{
		my $thumbnail = join_path( $dir, "docProps/thumbnail.jpeg" );
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

sub join_path
{
	return join('/', @_);
}

1;


