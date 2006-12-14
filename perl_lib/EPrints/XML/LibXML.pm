######################################################################
#
# EPrints::XML::LibXML
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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

use XML::LibXML 1.62;
use XML::LibXML::SAX::Parser;
# $XML::LibXML::skipXMLDeclaration = 1; # Same behaviour as XML::DOM

$EPrints::XML::PREFIX = "XML::LibXML::";

##############################################################################
# DOM spec fixes
##############################################################################

{
	no warnings; # don't complain about redefinition
	*XML::LibXML::CDATASection::nodeName = sub { '#cdata-section' }; # '#cdata'
	*XML::LibXML::Text::nodeName = sub { '#text' }; # 'text'
	*XML::LibXML::Comment::nodeName = sub { '#comment' }; # 'comment'
}

# these aren't set at all
*XML::LibXML::Document::nodeName = sub { '#document' };
*XML::LibXML::DocumentFragment::nodeName = sub { '#document-fragment' };

# Element::cloneNode should copy attributes too
*XML::LibXML::Element::cloneNode = sub {
		my( $self, $deep ) = @_;
		my $node = XML::LibXML::Node::cloneNode( @_ );
		return $node if $deep;
		$node->setAttribute( $_->nodeName, $_->value ) for $self->attributes();
		return $node;
	};

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

# Check for empty DocumentFragments - causes segfault in LibXML <= 1.61
*XML::LibXML::DocumentFragment::appendChild =
*XML::LibXML::Element::appendChild = sub {
		my( $self, $node ) = @_;
		return if(
			$node->nodeType == XML_DOCUMENT_FRAG_NODE and
			!$node->hasChildNodes
		);
		return XML::LibXML::Node::appendChild( @_ );
	};

# Text returns undef on empty string
*XML::LibXML::Text::toString = sub {
		my( $node ) = @_;
		return $node->data ne '' ? XML::LibXML::Node::toString($node) : '';
	};

##############################################################################

our $PARSER = XML::LibXML->new();

=item $doc = parse_xml_string( $string )

Create a new DOM document from $string.

=cut

sub parse_xml_string
{
	my( $string ) = @_;

	return $PARSER->parse_string( $string );
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

#	my $tmpfile = $file;
#	if( defined $basepath )
#	{	
#		$tmpfile =~ s#/#_#g;
#		$tmpfile = $basepath."/".$tmpfile;
#		symlink( $file, $tmpfile );
#	}
	my $fh;
	open( $fh, $file );
	my $doc = $PARSER->parse_fh( $fh, $basepath );
	close $fh;
#	if( defined $basepath )
#	{
#		unlink( $tmpfile );
#	}

	return $doc;
}

=item event_parse( $fh, $handler )

Parses the XML from filehandle $fh, calling the appropriate events
in the handler where necessary.

=cut

sub event_parse
{
	my( $fh, $handler ) = @_;	
	my $parser = new XML::LibXML::SAX::Parser->new(Handler => $handler);
	$parser->parse_file( $fh );	
}


=item dispose( $node )

Unused

=cut

sub dispose
{
	my( $node ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "attempt to dispose an undefined dom node" );
	}
}

=item $node = clone_node( $node [, $deep] )

Clone $node and return it, optionally descending into child nodes ($deep).

=cut

sub clone_node
{
	my( $node, $deep ) = @_;

	$deep ||= 0;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to clone_node" );
	}

	if( is_dom( $node, "DocumentFragment" ) )
	{
		my $doc = $node->getOwner;
		my $f = $doc->createDocumentFragment;
		return $f unless $deep;
		
		foreach my $c ( $node->getChildNodes )
		{
			$f->appendChild( $c->cloneNode( $deep ) );
		}
		return $f;
	}

	my $newnode = $node->cloneNode( $deep );

	return $newnode;
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

	return $doc->toString();
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

=item $doc = make_document_fragment( $session )

Return a new, empty DOM document fragment.

=cut

sub make_document_fragment
{
	my( $session ) = @_;
	
	return $session->{doc}->createDocumentFragment();
}

__END__

=back
