=head1 NAME

EPrints::Test::XML

=cut

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

	my $eprint = EPrints::Test::get_test_dataobj( $repo->dataset( "eprint" ) );
	my $dataset = $eprint->get_dataset;

	my $xml_dump = $eprint->to_xml;
	my $epdata = $eprint->xml_to_epdata( $repo, $xml_dump );
	# MetaField::Subobject can't to_xml non-objects, which is what
	# xml_to_epdata gives us, but Subobject will retrieve the records for us in
	# the final object
	foreach my $field ($dataset->fields)
	{
		next if !$field->isa( "EPrints::MetaField::Subobject" );
		delete $epdata->{$field->name};
	}
	my $eprint2 = $repo->dataset( "eprint" )->make_dataobj( $epdata );

	is( $xml_dump->toString(), $eprint2->to_xml->toString(), "to_xml==xml_to_epdata" );

	ok(1, "complete");
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

