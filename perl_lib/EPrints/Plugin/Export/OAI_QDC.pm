package EPrints::Plugin::Export::OAI_QDC;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Qualified Dublin Core - OAI Schema";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";
	
	$self->{xmlns} = "http://www.w3.org/2005/Atom";
	$self->{schemaLocation} = "http://www.kbcafe.com/rss/atom.xsd.xml";
	$self->{dc_xmlns} = "http://purl.org/dc/terms/";
	$self->{dc_schemaLocation} = "http://dublincore.org/schemas/xmls/qdc/2008/02/11/dcterms.xsd";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}


sub xml_dataobj
{
	my( $self, $dataobj ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;

	my $dc_plugin = $session->plugin( "Export::DC" );
	my $data = $dc_plugin->convert_dataobj( $dataobj );

	my $entry = $xml->create_element(
		"entry",
		"xmlns" => $self->{xmlns},
		"xmlns:dc" => $self->{dc_xmlns},
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => join(" ",
			$self->{xmlns} => $self->{schemaLocation},
			$self->{dc_xmlns} => $self->{dc_schemaLocation},
		),
	);

	# atom:id
	$entry->appendChild(
		$xml->create_element( "id" )
	)->appendChild( $xml->create_text_node( $dataobj->uri ) );

	# atom:title
	if( $dataobj->get_dataset->has_field( "title" ) )
	{
		$entry->appendChild(
			$xml->create_element( "title" )
		)->appendChild( $dataobj->render_value( "title" ) );
	}
	else
	{
		$entry->appendChild(
			$xml->create_element( "title" )
		)->appendChild( $xml->create_text_node( $dataobj->uri ) );
	}

	# atom:updated
	my $lastmod = $dataobj->value( "lastmod" );
	$lastmod =~ s/^([\d\-]*)[T ]([\d:]*)Z?$/$1T$2Z/;
	$entry->appendChild(
		$xml->create_element( "updated" )
	)->appendChild( $xml->create_text_node( $lastmod ) );

	if( $dataobj->exists_and_set( "bibliography" ) )
	{
		for( @{$dataobj->value( "bibliography" )} )
		{
			push @$data, [references => $_];
		}
	}

	for(@$data)
	{
		if( $_->[0] eq "identifier" && $_->[1] !~ /^https?:/ )
		{
			$_->[0] = "bibliographicCitation";
		}
	}

	# turn each pair into a <dc:NAME>VALUE</> data element
	foreach( @$data )
	{
		$entry->appendChild(
			$xml->create_element( "dc:".$_->[0] )
		)->appendChild( $xml->create_text_node( $_->[1] ) );
	}

	return $entry;
}


1;
