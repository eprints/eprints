package EPrints::Plugin::Import::XSLT;

use EPrints::Plugin::Import;

@ISA = ( "EPrints::Plugin::Import" );

use strict;

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	my $session = $self->{session};

	my $dataset = $opts{dataset};
	my $class = $dataset->get_object_class;
	my $root_name = $dataset->base_id;

	# read the source XML
	my $source = XML::LibXML->load_xml({
		IO => $fh
	});

	# transform it using our stylesheet
	my $result = $self->transform( $source );

	my @ids;

	my $root = $result->documentElement;
	foreach my $node ($root->getElementsByTagName( $root_name ))
	{
		push @ids, $self->epdata_to_dataobj(
			$dataset,
			$class->xml_to_epdata( $session, $node )
		)->id;
	}

	$session->xml->dispose( $source );
	$session->xml->dispose( $result );

	return EPrints::List->new(
		session => $session,
		dataset => $dataset,
		ids => \@ids );
}

sub transform
{
	my( $self, $doc ) = @_;

	return $self->{stylesheet}->transform( $doc );
}

1;
