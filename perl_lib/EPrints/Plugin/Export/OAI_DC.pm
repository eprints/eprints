package EPrints::Plugin::Export::OAI_DC;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Dublin Core - OAI Schema";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";
	
	$self->{xmlns} = "http://www.openarchives.org/OAI/2.0/oai_dc/";
	$self->{schemaLocation} = "http://www.openarchives.org/OAI/2.0/oai_dc.xsd";

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
	my( $plugin, $dataobj ) = @_;

	my $main_dc_plugin = $plugin->{handle}->plugin( "Export::DC" );
	
	my $data = $main_dc_plugin->convert_dataobj( $dataobj );

	my $dc = $plugin->{handle}->make_element(
        	"oai_dc:dc",
		"xmlns:oai_dc" => "http://www.openarchives.org/OAI/2.0/oai_dc/",
        	"xmlns:dc" => "http://purl.org/dc/elements/1.1/",
        	"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" =>
 	"http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd" );

	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	foreach( @{$data} )
	{
		$dc->appendChild(  $plugin->{handle}->render_data_element( 8, "dc:".$_->[0], $_->[1] ) );
		# produces <key>value</key>
	}

	return $dc;
}


1;
