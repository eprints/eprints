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

use XML::LibXML;
# $XML::LibXML::skipXMLDeclaration = 1; # Same behaviour as XML::DOM

# DOM spec fixes
{
no warnings;
*XML::LibXML::CDATASection::nodeName = sub { '#cdata-section' };
*XML::LibXML::Document::nodeName = sub { '#document' };
*XML::LibXML::DocumentFragment::nodeName = sub { '#document-fragment' };
# incorrectly set to 'text'
*XML::LibXML::Text::nodeName = sub { '#text' };
# otherwise getElementsByTagName never matches namespaced tags
*XML::LibXML::Document::getElementsByTagName = \&XML::LibXML::Document::getElementsByLocalName;
*XML::LibXML::DocumentFragment::getElementsByTagName = \&XML::LibXML::DocumentFragment::getElementsByLocalName;
}

$EPrints::XML::PREFIX = "XML::LibXML::";

our $PARSER = XML::LibXML->new();

=item $doc = parse_xml_string( $string )

Create a new DOM document from $string.

=cut

sub parse_xml_string
{
	my( $string ) = @_;

	my $doc = $PARSER->parse_string( $string );

	return bless $doc, LibXMLDocWrapper;
}

=item $doc = parse_xml( $filename [, $basepath [, $no_expand]] )

Parse $filename and return it as a new DOM document.

=cut

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::Config::abort( "Can't read XML file: '$file'" );
	}

	my $tmpfile = $file;
	if( defined $basepath )
	{	
		$tmpfile =~ s#/#_#g;
		$tmpfile = $basepath."/".$tmpfile;
		symlink( $file, $tmpfile );
	}
	my $fh;
	open( $fh, $tmpfile );
	my $doc = $PARSER->parse_fh( $fh, $basepath );
	close $fh;
	if( defined $basepath )
	{
		unlink( $tmpfile );
	}
	return bless $doc, LibXMLDocWrapper;
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
		$f = bless $f, LibXMLDocFragWrapper;
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
		$f = bless $f, LibXMLDocFragWrapper;
		return $f unless $deep;

		foreach my $c ( $node->getChildNodes )
		{
			$newnode->appendChild( $c->cloneNode( $deep ));
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
	my $doc = XML::LibXML::Document->new();

	return bless $doc, LibXMLDocWrapper;
}

=back

=head2 SUPPORT MODULES

LibXML doesn't use $doc->appendChild in the DOM way so we need to wrap it.

=over 4

=cut

package LibXMLDocWrapper;

use vars qw( @ISA );
@ISA = qw( XML::LibXML::Document );

=item LibXMLDocWrapper::appendChild()

Wrapper for setDocumentElement().

=cut

sub appendChild
{
	shift->setDocumentElement( @_ );
}

package LibXMLDocFragWrapper;

use vars qw( @ISA );
@ISA = qw( XML::LibXML::DocumentFragment );

=item LibXMLDocFragWrapper::appendChild()

Wrapper for setDocumentElement().

=cut

sub appendChild
{
	shift->setDocumentElement( @_ );
}

1;

__END__

=back
