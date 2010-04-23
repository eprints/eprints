package EPrints::Plugin::Export::XSLT;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub output_dataobj
{
	my( $self, $dataobj ) = @_;

	my $session;
	local $session->{xml};

	my $xml = $dataobj->to_xml;
	my $doc = $xml->ownerDocument;
	$doc->setDocumentElement( $xml );

	return $self->{stylesheet}->output_as_bytes( $doc );
}

1;
