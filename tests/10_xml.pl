use strict;
use Test::More tests => (3 + 3 * 7);

our $XML_LIB;
our $XML_NS = "http://localhost/";
our $XML_STR = "<xml><p:x xmlns:p='$XML_NS'>contents</p:x><y /></xml>";
our $UTF8_STR = "abc ".chr(0x410).chr(0x411).chr(0x412)." abc";
utf8::decode($UTF8_STR) unless utf8::is_utf8($UTF8_STR);

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

&load_xml_lib( "DOM" );
&xml_tests();

SKIP: {
	eval { require XML::GDOME; };
	skip "XML::GDOME unavailable", 7 if $@;

	&load_xml_lib( "GDOME" );
	&xml_tests();
}

SKIP: {
	eval { require XML::LibXML; };
	skip "XML::LibXML 1.66+ unavailable", 7 if $@;

	&load_xml_lib( "LibXML" );
	&xml_tests();
}

ok(1);

sub xml_tests
{
	my $handle = EPrints::Test::get_test_session( 0 );

	my $node;
	my $frag;

	$node = $handle->make_element( "x" );
	ok(EPrints::XML::is_dom( $node, "Element" ), "$XML_LIB: is_dom (Element)");

	$frag = $handle->make_doc_fragment;
	ok(EPrints::XML::is_dom( $frag, "DocumentFragment" ), "$XML_LIB: is_dom (DocumentFragment)");

	my $doc = eval { EPrints::XML::parse_xml_string( $XML_STR ) };
	ok(defined($doc), "parse_xml_string");

	ok(defined($doc) && $doc->documentElement->nodeName eq "xml", "$XML_LIB: parse_xml_string documentElement");

	$doc = EPrints::XML::make_document();
	BAIL_OUT "make_document failed" unless defined $doc;
	$doc->appendChild( my $x_node = $doc->createElement( "x" ) );
	$x_node->appendChild( $doc->createTextNode( $UTF8_STR ) );

	my $xml_str;

	$xml_str = EPrints::XML::to_string( $x_node );
	ok(utf8::is_utf8($xml_str), "$XML_LIB: to_string utf8 element");

	$xml_str = EPrints::XML::to_string( $doc );
	ok(utf8::is_utf8($xml_str), "$XML_LIB: to_string utf8 document");

	$handle->terminate;

	ok(1, "$XML_LIB complete");
}

sub load_xml_lib
{
	my( $lib ) = @_;

	$XML_LIB = "XML::${lib}";

	$EPrints::SystemSettings::conf->{enable_gdome} = 0;
	$EPrints::SystemSettings::conf->{enable_libxml} = 0;
	if( $lib eq "GDOME" )
	{
		$EPrints::SystemSettings::conf->{enable_gdome} = 1;
	}
	elsif( $lib eq "LibXML" )
	{
		$EPrints::SystemSettings::conf->{enable_libxml} = 1;
	}

	delete $INC{"EPrints/XML.pm"};
	delete $INC{"EPrints/XML/$lib.pm"};

	# reload the module, suppressing warnings (methods are re-declared)
	eval {
		local $SIG{__WARN__} = sub {};
		do "EPrints/XML.pm";
	};

	if( $@ )
	{
		BAIL_OUT "Error reloading EPrints::XML: $@";
	}
}
