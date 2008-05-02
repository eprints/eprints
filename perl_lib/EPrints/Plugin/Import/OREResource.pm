package EPrints::Plugin::Import::OREResource;

use strict;

our $RDF_NS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
our $ORE_NS = "http://www.openarchives.org/ore/terms/";
our $DC_NS = "http://purl.org/dc/elements/1.1/";
our $DCTERMS_NS = "http://purl.org/dc/terms/";
our $OAI_DC_NS = "http://www.openarchives.org/OAI/2.0/oai_dc/";

use EPrints::Plugin::Import::DefaultXML;

our @ISA = qw/ EPrints::Plugin::Import::DefaultXML /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "OAI-ORE Resource";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	return $self;
}

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my $fh = $opts{"fh"};

	my $xml = join "", <$fh>;

	my $list;

	if( $xml =~ /^<\?xml/ )
	{
		$list = $plugin->input_fh_xml( $xml, %opts );
	}
	else
	{
		$list = $plugin->input_fh_list( $xml, %opts );
	}

	$list ||= EPrints::List->new(
			dataset => $opts{dataset},
			session => $plugin->{session},
			ids => [] );

	return $list;
}

sub input_fh_xml
{
	my( $plugin, $xml, %opts ) = @_;

	my $doc = EPrints::XML::parse_xml_string( $xml );

	my $dataobj = $plugin->xml_to_dataobj( $opts{dataset}, $doc->documentElement );

	EPrints::XML::dispose( $doc );

	return EPrints::List->new(
			dataset => $opts{dataset},
			session => $plugin->{session},
			ids => [$dataobj->get_id] );
}

sub input_fh_list
{
	my( $plugin, $url, %opts ) = @_;

	my $max_records = 10;

	$url =~ s/\s+//g;

	my $tmpfile = File::Temp->new;

	my $r = EPrints::Utils::wget( $plugin->{session}, $url, $tmpfile );
	seek($tmpfile,0,0);

	if( $r->is_error )
	{
		$plugin->error( "Error reading resource map list from $url: ".$r->code." ".$r->message );
		return;
	}

	my @ids;

	while(my $url = <$tmpfile>)
	{
		$url =~ s/\s+//g;
		next unless $url =~ /^http/;

		my $doc;
		eval { $doc = EPrints::XML::parse_url( $url ) };
		if( $@ )
		{
			$plugin->warning( "Error parsing resource map: $url\n" );
		}

		my $dataobj = $plugin->xml_to_dataobj( $opts{dataset}, $doc->documentElement );

		EPrints::XML::dispose( $doc );

		if( defined $dataobj )
		{
			push @ids, $dataobj->get_id;
			last unless $max_records--;
		}
	}

	return EPrints::List->new(
			dataset => $opts{dataset},
			session => $plugin->{session},
			ids => \@ids );
}

sub xml_to_dataobj
{
	# $xml is the PubmedArticle element
	my( $plugin, $dataset, $xml ) = @_;

	my $session = $plugin->{session};

	my $epdata = {};

	my $baseURI = $xml->getAttribute( "xml:base" );

	my @descs = $xml->getElementsByTagNameNS( $RDF_NS, "Description" );

	my $ore_resource_uri;
	my $oai_dc;
	my %resources;
	my %aggregates;

	foreach my $desc (@descs)
	{
		my $uri = $desc->getAttributeNS( $RDF_NS, "about" );
		if( defined($baseURI) )
		{
			$uri = URI->new_abs(
				$uri,
				$baseURI
			);
		}
		my $format;
		my @ore_aggregates = $desc->getElementsByTagNameNS( $ORE_NS, "aggregates" );
		foreach( @ore_aggregates )
		{
			$ore_resource_uri ||= $uri;
			my $resource = $_->getAttributeNS( $RDF_NS, "resource" );
			$aggregates{$resource} = 1;
		}
		my @dc_formats = $desc->getElementsByTagNameNS( $DCTERMS_NS, "format" );
		push @dc_formats, $desc->getElementsByTagNameNS( $DC_NS, "format" );
		foreach( @dc_formats )
		{
			my $format = EPrints::Utils::tree_to_utf8( $_ );
			if( defined $uri && $format =~ /\// )
			{
				$resources{"$uri"} = $format;
			}
		}
		my @conforms_to = $desc->getElementsByTagNameNS( $DCTERMS_NS, "conformsTo" );
		foreach(@conforms_to)
		{
			my $rdf_resource = $_->getAttributeNS( $RDF_NS, "resource" );
			$rdf_resource ||= EPrints::Utils::tree_to_utf8( $_ );
			$rdf_resource =~ s/\/?$/\//; # fix for bug in Export
			if( $rdf_resource eq $OAI_DC_NS )
			{
				$oai_dc = $desc->getAttributeNS( $RDF_NS, "about" );
				if( defined($baseURI) )
				{
					$oai_dc = URI->new_abs(
						$oai_dc,
						$baseURI
					);
				}
			}
		}
	}

	if( !$oai_dc )
	{
		if( $ore_resource_uri )
		{
			$plugin->warning( "No OAI_DC found in resource map for $ore_resource_uri: ignoring!\n" );
		}
		return;
	}

	my $tmpfile = File::Temp->new;

	EPrints::Utils::wget( $session, $oai_dc, "$tmpfile" );
	seek($tmpfile,0,0);

	$plugin->handler->parsed( $epdata );
	return if( $plugin->{parse_only} );

	my $dc_plugin = $session->plugin( "Import::XSLT::OAI_Dublin_Core_XML",
		processor => $plugin->{processor},
		dataset => $dataset,
	);

	my $dc_xml = join "", <$tmpfile>;
	$dc_xml =~ s/
		(<(?:\w+:)?date\s*>)([^>]+)(<\s*\/(?:\w+:)?date>)
	/&format_dc_date($1,$2,$3)/exg;

	my $tmpfile2 = File::Temp->new;
	print $tmpfile2 $dc_xml;
	seek($tmpfile2,0,0);

	my $list = $dc_plugin->input_fh( fh => $tmpfile2, dataset => $dataset );

	my( $eprint ) = $list->get_records( 0, 1 );

	while(my( $uri, $format ) = each %resources)
	{
		next unless $aggregates{$uri};
		my $doc = EPrints::DataObj::Document->create_from_data(
			$session,
			{
				eprintid => $eprint->get_id,
				format => $format,
			},
			$session->get_repository->get_dataset( "document" )
		);
		$doc->upload_url( $uri );
	}

	$plugin->handler->object( $dataset, $eprint );

	return $eprint;
}

sub format_dc_date
{
	my( $open, $date, $close ) = @_;

	$date =~ s/\s+//g;

	if( $date =~ /^\d{4}(-\d{2}(-\d{2})?)?$/ )
	{
		return "$open$date$close";
	}
	return "";
}

1;
