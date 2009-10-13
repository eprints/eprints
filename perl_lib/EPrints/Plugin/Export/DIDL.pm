package EPrints::Plugin::Export::DIDL;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "DIDL";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";

	$self->{xmlns} = "urn:mpeg:mpeg21:2002:02-DIDL-NS",
	$self->{schemaLocation} = "http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/did/didmodel.xsd";

	return $self;
}



sub xml_dataobj
{
	my( $plugin, $eprint ) = @_;

	my $didl = $plugin->{session}->make_element( 
		"didl:DIDL",
		"xmlns:didl"=>"urn:mpeg:mpeg21:2002:02-DIDL-NS",
		"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation"=>"urn:mpeg:mpeg21:2002:02-DIDL-NS 
			 http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/did/didmodel.xsd" );
	my $item = $plugin->{session}->make_element( "didl:Item" );
	$didl->appendChild( $item );


	my $d1 = $plugin->{session}->make_element( "didl:Descriptor" );
	my $s1 = $plugin->{session}->make_element( "didl:Statement", mimeType=>"application/xml; charset=utf-8" );
	my $ident = $plugin->{session}->make_element( 
		"dii:Identifier",
		"xmlns:dii"=>"urn:mpeg:mpeg21:2002:01-DII-NS",
		"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation"=>"urn:mpeg:mpeg21:2002:01-DII-NS
		 	http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/dii/dii.xsd" );
	$ident->appendChild( $plugin->{session}->make_text( $eprint->get_url ) );
	$s1->appendChild( $ident );
	$d1->appendChild( $s1 );
	$item->appendChild( $d1 );


	my $d2 = $plugin->{session}->make_element( "didl:Descriptor" );
	my $s2 = $plugin->{session}->make_element( "didl:Statement", mimeType=>"application/xml; charset=utf-8" );
	my $dc_plugin = $plugin->{session}->plugin( "Export::OAI_DC" );
	$s2->appendChild( $dc_plugin->xml_dataobj( $eprint ) ); 
	$d2->appendChild( $s2 );
	$item->appendChild( $d2 );

	#my $mimetypes = $plugin->{session}->get_repository->get_conf( "oai", "mime_types" );
	foreach my $doc ( $eprint->get_all_documents )
	{
		my $comp = $plugin->{session}->make_element( "didl:Component" );
		$item->appendChild( $comp );


		my $d3 = $plugin->{session}->make_element( "didl:Descriptor" );
		my $s3 = $plugin->{session}->make_element( "didl:Statement", mimeType=>"application/xml; charset=utf-8" );
		my $i3 = $plugin->{session}->make_element( 
			"dii:Identifier",
			"xmlns:dii"=>"urn:mpeg:mpeg21:2002:01-DII-NS",
			"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
			"xsi:schemaLocation"=>"urn:mpeg:mpeg21:2002:01-DII-NS
		 	    http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/dii/dii.xsd" );
		$i3->appendChild( $plugin->{session}->make_text( $doc->get_baseurl ) );
		$s3->appendChild( $i3 );
		$d3->appendChild( $s3 );
		$comp->appendChild( $d3 );

		my %files = $doc->files;
		foreach my $file ( keys %files )
		{
			my $res = $plugin->{session}->make_element( "didl:Resource", 
	#				mimeType=>$format,
					ref=>$doc->get_url( $file ) );
			$comp->appendChild( $res );
		}
	}

	return $didl;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $didl = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $didl );
}


1;
