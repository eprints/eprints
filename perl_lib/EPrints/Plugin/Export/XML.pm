package EPrints::Plugin::Export::XML;

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "EP3 XML";
	$self->{accept} = [ 'list/*', 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{xmlns} = EPrints::Const::EP_NS_DATA;
	$self->{qs} = 0.8;
	$self->{arguments}->{hide_volatile} = 1;

	return $self;
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = $type."s";
	
	my $output = "";

	my $wr = EPrints::XML::SAX::PrettyPrint->new(
		Handler => EPrints::XML::SAX::Writer->new(
			Output => defined $opts{fh} ? $opts{fh} : \$output
	));

	$wr->start_document({});
	$wr->xml_decl({
		Version => '1.0',
		Encoding => 'utf-8',
	});
	$wr->start_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});

	$wr->start_element({
		Prefix => '',
		LocalName => $toplevel,
		Name => $toplevel,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
		Attributes => {},
	});
	$opts{list}->map( sub {
		my( undef, undef, $item ) = @_;

		$self->output_dataobj( $item, Handler => $wr );
	});

	$wr->end_element({
		Prefix => '',
		LocalName => $toplevel,
		Name => $toplevel,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$wr->end_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$wr->end_document({});

	return $output;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	if( $opts{Handler} )
	{
		return $dataobj->to_sax( %opts );
	}

	my $output = "";

	my $wr = EPrints::XML::SAX::PrettyPrint->new(
		Handler => EPrints::XML::SAX::Writer->new(
			Output => defined $opts{fh} ? $opts{fh} : \$output
	));


	$wr->start_document({});
	$wr->xml_decl({
		Version => '1.0',
		Encoding => 'utf-8',
	});
	$wr->start_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$dataobj->to_sax( %opts, Handler => $wr );
	$wr->end_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$wr->end_document({});

	return $output;
}

1;
