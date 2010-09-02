package EPrints::Test::XML;

use Test::More;
use EPrints::Test;

our $XML_NS = "http://localhost/";
our $XML_STR = "<xml><p:x xmlns:p='$XML_NS'>contents</p:x><y /></xml>";
our $UTF8_STR = "abc ".chr(0x410).chr(0x411).chr(0x412)." abc";
utf8::decode($UTF8_STR) unless utf8::is_utf8($UTF8_STR);

sub xml_tests
{
	my( $repo ) = @_;

	my $node;
	my $frag;

	$node = $repo->make_element( "x" );
	ok(EPrints::XML::is_dom( $node, "Element" ), "is_dom (Element)");

	$frag = $repo->make_doc_fragment;
	ok(EPrints::XML::is_dom( $frag, "DocumentFragment" ), "is_dom (DocumentFragment)");

	my $doc = eval { EPrints::XML::parse_xml_string( $XML_STR ) };
	ok(defined($doc), "parse_xml_string");

	ok(defined($doc) && $doc->documentElement->nodeName eq "xml", "parse_xml_string documentElement");

	$doc = EPrints::XML::make_document();
	BAIL_OUT "make_document failed" unless defined $doc;
	$doc->appendChild( my $x_node = $doc->createElement( "x" ) );
	$x_node->appendChild( $doc->createTextNode( $UTF8_STR ) );

	my $xml_str;

	$xml_str = EPrints::XML::to_string( $x_node );
	ok(utf8::is_utf8($xml_str), "to_string utf8 element");

	$xml_str = EPrints::XML::to_string( $doc );
	ok(utf8::is_utf8($xml_str), "to_string utf8 document");

	ok(1, "complete");
}

1;
