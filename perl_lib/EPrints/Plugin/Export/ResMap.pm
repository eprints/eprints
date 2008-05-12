package EPrints::Plugin::Export::ResMap;

use EPrints::Plugin::Export;
@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
        my( $class, %opts ) = @_;
	my $self = $class->SUPER::new( %opts );

        $self->{name} = "Resource Map";
        $self->{accept} = [ 'dataobj/eprint', 'list/eprint' ];
        $self->{visible} = "all";
        $self->{suffix} = ".xml";
        $self->{mimetype} = "application/rdf+xml; charset=utf-8";

        return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	
	my $r = [];

	my $part = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n\txmlns:ore=\"http://www.openarchives.org/ore/terms/\"\n\txmlns:dc=\"http://purl.org/dc/terms/\">\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	$opts{list}->map(sub {
		my( $session, $dataset, $dataobj ) = @_;
		$part = $plugin->output_dataobj( $dataobj, single => 1, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	});

	$part= "</rdf:RDF>\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
        my( $plugin, $dataobj, %opts ) = @_;

	my $single = $opts{"single"};
	
	my $title = $dataobj->get_value( "title" );
	my $lastmod = $dataobj->get_value( "lastmod" );
	my $eprint_id = $dataobj->get_value( "eprintid" );
	my $eprint_rev = $dataobj->get_value( "rev_number" );
	my $eprint_url = $dataobj->get_url;
	my $resmap_url = $plugin->dataobj_export_url( $dataobj );
	my $session = $plugin->{session};
	my $base_url = $session->get_repository->get_conf("base_url");
	my $archive_id = $session->get_repository->get_id;
	
	my $additional = "";	
	my $head = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n\txmlns:ore=\"http://www.openarchives.org/ore/terms/\"\n\txmlns:dc=\"http://purl.org/dc/terms/\">\n";
	my $content = "\t<rdf:Description rdf:about=\"$resmap_url\">\n";
	$content .= "\t\t<rdf:type rdf:resource=\"http://www.openarchives.org/ore/terms/ResourceMap\" />\n";
	$content .= "\t\t<dc:modified rdf:datatype=\"http://www.w3.org/2001/XMLSchema#dateTime\">" . $lastmod . "</dc:modified>\n";
	$content .= "\t\t<ore:describes rdf:resource=\"$resmap_url#aggregation\" />\n";
	$content .= "\t</rdf:Description>\n";

	$content .= "\t<rdf:Description rdf:about=\"$resmap_url#aggregation\">\n";

	##Metadata 
	my $file_url = "$base_url/cgi/export/$eprint_id/XML/$archive_id-eprint-$eprint_id.xml";
	$content .= "\t\t<ore:aggregates rdf:resource=\"$file_url\"/>\n";
	$additional .= "\t<rdf:Description rdf:about=\"$file_url\">\n";
	$additional .= "\t\t<dc:format>EP3_XML</dc:format>\n";
	$additional .= "\t\t<dc:format>application/xml+EP3</dc:format>\n";
	$additional .= "\t\t<dc:hasVersion>$eprint_rev</dc:hasVersion>\n";
	$additional .= "\t</rdf:Description>\n";
	
	$file_url = "$base_url/cgi/export/$eprint_id/OAI_DC/$archive_id-eprint-$eprint_id.xml";
	$content .= "\t\t<ore:aggregates rdf:resource=\"$file_url\"/>\n";
	$additional .= "\t<rdf:Description rdf:about=\"$file_url\">\n";
	$additional .= "\t\t<dc:format>OAI_DC</dc:format>\n";
	$additional .= "\t\t<dc:format>text/xml</dc:format>\n";
	$additional .= "\t\t<dc:conformsTo>http://www.openarchives.org/OAI/2.0/oai_dc/</dc:conformsTo>\n";
	$additional .= "\t</rdf:Description>\n";

	my @docs = $dataobj->get_all_documents;
	foreach my $doc (@docs)
	{
		my $format = $doc->get_value("format");
		my $rev_number = $doc->get_value("rev_number");
		my %files = $doc->files;
		foreach my $key (keys %files)
		{
			my $fileurl = $doc->get_url($key);
			$content .= "\t\t<ore:aggregates rdf:resource=\"$fileurl\" />\n";
			$additional .= "\t<rdf:Description rdf:about=\"$fileurl\">\n";
			$additional .= "\t\t<dc:format>$format</dc:format>\n";
			$additional .= "\t\t<dc:hasVersion>$rev_number</dc:hasVersion>\n";	
			$additional .= "\t</rdf:Description>\n";
		}

	}
		
	$content .= "\t</rdf:Description>\n";

	my $tail = '</rdf:RDF>';
	
	if( $single )
	{
		return $content . $additional;
	}
	else
	{
		return $head . $content . $additional . $tail;
	}

}

1;
