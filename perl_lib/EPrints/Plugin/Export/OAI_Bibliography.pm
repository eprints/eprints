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

	my @data;
	my $doc = $self->{session}->dataset( "document" )->search(
		filters => [
			{ meta_fields => [qw( content )], value => "bibliography" },
			{ meta_fields => [qw( format )], value => "text/xml" },
			{ meta_fields => [qw( eprintid )], value => $dataobj->id },
		])->item( 0 );

	if( defined $doc )
	{
		my $buffer = "";
		$doc->stored_file( $doc->get_main )->get_file( sub { $buffer .= $_[0] } );
		my $xml = eval { $self->{session}->xml->parse_string( $buffer ) };
		if( defined $xml )
		{
			for($xml->documentElement->childNodes)
			{
				next if $_->nodeName ne "eprint";
				my $epdata = EPrints::DataObj::EPrint->xml_to_epdata(
					$self->{session},
					$_ );
				my $ep = EPrints::DataObj::EPrint->new_from_data(
					$self->{session},
					$epdata );
				push @data, [ relation => $ep->export( "COinS" ) ];
			}
			$self->{session}->xml->dispose( $xml );
		}
	}
	elsif( $dataobj->exists_and_set( "referencetext" ) )
	{
		my $bibl = $dataobj->value( "referencetext" );
		for(split /\s*\n\s*\n+/, $bibl)
		{
			push @data, [ relation => $_ ];
		}
	}

	my $dc = $self->{session}->make_element(
		"oai_dc:dc",
		"xmlns:oai_dc" => $self->{xmlns},
		"xmlns:dc" => "http://purl.org/dc/elements/1.1/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => join(" ", $self->{xmlns}, $self->{schemaLocation} ),
	);

	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	for( @data )
	{
		$dc->appendChild(  $self->{session}->render_data_element( 8, "dc:".$_->[0], $_->[1] ) );
		# produces <key>value</key>
	}

	return $dc;
}

1;
