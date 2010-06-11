package EPrints::Plugin::Export::OAI_Bibliography;

use EPrints::Plugin::Export::OAI_DC;
@ISA = qw( EPrints::Plugin::Export::OAI_DC );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "DC Bibliography - OAI Schema";
	$self->{accept} = [qw( dataobj/eprint )];
	$self->{visible} = "";

	return $self;
}

sub xml_dataobj
{
	my( $self, $dataobj ) = @_;

	my $plugin = $self->{session}->plugin( "Export::Bibliography" );

	my $refs = $plugin->convert_dataobj( $dataobj );

	my $dc = $self->{session}->make_element(
		"oai_dc:dc",
		"xmlns:oai_dc" => $self->{xmlns},
		"xmlns:dc" => "http://purl.org/dc/elements/1.1/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => join(" ", $self->{xmlns}, $self->{schemaLocation} ),
	);

	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	for( @$refs )
	{
		my $value = $_;
		if( ref($value) && $value->isa( "EPrints::DataObj::EPrint" ) )
		{
			$value = $value->export( "COinS" );
		}
		$dc->appendChild(  $self->{session}->render_data_element( 8, "dc:relation", $value ) );
		# produces <key>value</key>
	}

	return $dc;
}

1;
