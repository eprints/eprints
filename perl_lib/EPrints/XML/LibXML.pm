######################################################################
#
# EPrints::XML::LibXML
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::XML::LibXML> - LibXML subs for EPrints::XML

=head1 DESCRIPTION

This module is not a package, it's a set of subroutines to be
loaded into EPrints::XML namespace if we're using XML::LibXML

=over 4

=cut

use warnings;
use strict;

use XML::LibXML 1.63;
use XML::LibXML::SAX;
# $XML::LibXML::skipXMLDeclaration = 1; # Same behaviour as XML::DOM

$EPrints::XML::CLASS = "EPrints::XML::LibXML";

$EPrints::XML::LIB_LEN = length("XML::LibXML::");

##############################################################################
# DOM spec fixes
##############################################################################

*XML::LibXML::NodeList::length = \&XML::LibXML::NodeList::size;

##############################################################################
# GDOME compatibility
##############################################################################

# Make getElementsByTagName use LocalName, because EPrints doesn't use
# namespacing when searching DOM trees
*XML::LibXML::Element::getElementsByTagName =
*XML::LibXML::Document::getElementsByTagName =
*XML::LibXML::DocumentFragment::getElementsByTagName =
	\&XML::LibXML::Element::getElementsByLocalName;

# If $doc->appendChild is called with an element set it as the root element,
# otherwise it will normally get ignored 
*XML::LibXML::Document::appendChild = sub {
		my( $self, $node ) = @_;
		return $node->nodeType == XML_ELEMENT_NODE ?
			XML::LibXML::Document::setDocumentElement( @_ ) :
			XML::LibXML::Node::appendChild( @_ );
	};

##############################################################################
# Bug work-arounds
##############################################################################

##############################################################################

our $PARSER = XML::LibXML->new();

sub CLONE
{
	$PARSER = XML::LibXML->new();
}

=item $doc = parse_xml_string( $string )

Create a new DOM document from $string.

=cut

sub parse_xml_string
{
	my( $string ) = @_;

	return $PARSER->parse_string( $string );
}

sub _parse_url
{
	my( $url, $no_expand ) = @_;

	my $doc = $PARSER->parse_file( "$url" );

	return $doc;
}

=item $doc_frag = parse_xml_frag_string( $string )

Parse $string and return it as a new DOM Document Fragment.

=cut

sub parse_xml_frag_string
{
	my( $string ) = @_;

	my $frag = $PARSER->parse_balanced_chunk( $string );

	return $frag;
}

=item $doc = parse_xml( $filename [, $basepath [, $no_expand]] )

Parse $filename and return it as a new DOM document.

=cut

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::abort( "Can't read XML file: '$file'" );
	}

	open(my $fh, "<", $file) or die "Error opening $file: $!";
	my $doc = $PARSER->parse_fh( $fh, $basepath );
	close($fh);

	return $doc;
}

=item event_parse( $fh, $handler )

Parses the XML from filehandle $fh, calling the appropriate events
in the handler where necessary.

=cut

sub event_parse
{
	my( $fh, $handler ) = @_;	

	# XML::LibXML causes a "stack smashing detected" on utf8 input FHs. The XML
	# library ought to read the <?xml> declaration anyway, to determine the
	# encoding
	binmode($fh);

	my $parser = new XML::LibXML::SAX->new(Handler => $handler);
	$parser->parse_file( $fh );	
}


sub _dispose
{
	my( $node ) = @_;
}

=item $node = clone_and_own( $node, $doc [, $deep] )

Clone $node and set its owner to $doc. Optionally clone child nodes with $deep.

=cut

sub clone_and_own
{
	my( $node, $doc, $deep ) = @_;
	$deep ||= 0;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to clone_and_own" );
	}

	if( is_dom( $node, "DocumentFragment" ) )
	{
		my $f = $doc->createDocumentFragment;
		return $f unless $deep;

		foreach my $c ( $node->getChildNodes )
		{
			$f->appendChild( $c->cloneNode( $deep ));
		}

		return $f;
	}

	my $newnode = $node->cloneNode( $deep );
#	$newnode->setOwnerDocument( $doc );

	return $newnode;
}

=item $string = document_to_string( $doc, $enc )

Return DOM document $doc as a string in encoding $enc.

=cut

sub document_to_string
{
	my( $doc, $enc ) = @_;

	$doc->setEncoding( $enc );

	my $xml = $doc->toString();
	utf8::decode($xml);

	return $xml;
}

=item $doc = make_document()

Return a new, empty DOM document.

=cut

sub make_document
{
	# no params

	# leave ($version, $encoding) blank to avoid getting a declaration
	# *implicitly* utf8
	return XML::LibXML::Document->new();
}

sub version
{
	"XML::LibXML $XML::LibXML::VERSION ".$INC{'XML/LibXML.pm'};
}

package EPrints::XML::LibXML;

our @ISA = qw( EPrints::XML );

use strict;

1;

__END__

=back

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

