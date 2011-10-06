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

    $self->{metadataPrefix} = "oai_bibl";

	return $self;
}

sub xml_dataobj
{
	my( $self, $dataobj ) = @_;

	my @data;
	my $doc = $self->{session}->dataset( "document" )->search(
		filters => [
			{ meta_fields => [qw( content )], value => "bibliography" },
			{ meta_fields => [qw( eprintid )], value => $dataobj->id },
		])->item( 0 );
	my $file;
	my $import;
	if( defined $doc )
	{
		my $xml_mime_type = $self->{session}->plugin( "Export::XML" )->param( "mimetype" );
		$xml_mime_type =~ s/;.*$//;

		$file = $doc->stored_file( $doc->get_main );
		if( defined $file )
		{
			( $import ) = $self->{session}->get_plugins(
				type => "Import",
				can_produce => "list/eprint",
				can_accept => $file->value( "mime_type" ),
			);
		}
	}

	if( defined $import )
	{
		my $dataset = $self->{session}->dataset( "eprint" );
		$import->set_handler(EPrints::CLIProcessor->new(
			session => $self->{session},
			epdata_to_dataobj => sub {
				my( $epdata ) = @_;
				my $eprint = $dataset->make_dataobj( $epdata );
				push @data, [ relation => $eprint->export( "COinS" ) ];
				return undef;
			},
		) );
		$import->input_fh(
			dataset => $dataset,
			fh => $file->get_local_copy,
		);
	}
	elsif( defined $file && $file->value( "mime_type" ) eq "text/plain" )
	{
		my $fh = $file->get_local_copy;
		my $buffer = "";
		while(defined(my $line = <$fh>))
		{
			if( $line !~ /\S/ )
			{
				push @data, [ relation => $buffer ];
				$buffer = "";
			}
			else
			{
				$buffer .= $line;
			}
		}
		push @data, [ relation => $buffer ] if $buffer =~ /\S/;
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
