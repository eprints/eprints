######################################################################
#
# EPrints::XML::DOM
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::XML::DOM> - DOM subs for EPrints::XML

=head1 DESCRIPTION

This module is not a package, it's a set of subroutines to be
loaded into EPrints::XML namespace if we're using XML::DOM

=over 4

=cut

require XML::DOM; 
use XML::Parser;
# DOM runs really slowly if it checks all it's data is
# valid...
$XML::DOM::SafeMode = 0;

XML::DOM::setTagCompression( \&_xmldom_tag_compression );

$EPrints::XML::CLASS = "EPrints::XML::DOM";

$EPrints::XML::LIB_LEN = length("XML::DOM::");

# DOM spec fixes
*XML::DOM::Document::documentElement = \&XML::DOM::Document::getDocumentElement;
*XML::DOM::Document::setDocumentElement = sub {
		my( $self, $node ) = @_;
		$self->removeChild( $self->documentElement ) if $self->documentElement;
		$self->appendChild( $node );
	};
*XML::DOM::Node::ownerDocument = \&XML::DOM::Node::getOwnerDocument;
*XML::DOM::Node::attributes = sub {
	my $attrs = shift->getAttributes(@_);
	return wantarray ? (map { $attrs->item( $_ ) } 0..($attrs->getLength-1) ) : $attrs;
};
*XML::DOM::Node::nodeName = sub { shift->getNodeName(@_) };
*XML::DOM::Node::nodeValue = sub { shift->getNodeValue(@_) };
*XML::DOM::Node::nodeType = sub { shift->getNodeType(@_) };
*XML::DOM::Node::prefix = sub {
		my $name = shift->getNodeName(@_);
		$name =~ s/^(.*)://;
		return $1 || '';
	};
*XML::DOM::Node::localName = sub {
		my $name = shift->getNodeName(@_);
		$name =~ s/^.*://;
		return $name;
	};
*XML::DOM::Node::parentNode = sub { shift->getParentNode(@_) };
*XML::DOM::Attr::name = \&XML::DOM::Attr::getName;
*XML::DOM::Attr::nodeName = \&XML::DOM::Attr::getName;
*XML::DOM::Attr::value = \&XML::DOM::Attr::getValue;
*XML::DOM::Attr::nodeValue = \&XML::DOM::Attr::getValue;
*XML::DOM::Element::tagName = \&XML::DOM::Element::getTagName;
*XML::DOM::NamedNodeMap::length = \&XML::DOM::NamedNodeMap::getLength;
*XML::DOM::NodeList::length = \&XML::DOM::NodeList::getLength;
*XML::DOM::Element::hasAttribute = sub { defined(shift->getAttributeNode(@_)) };
*XML::DOM::Node::childNodes = \&XML::DOM::Node::getChildNodes;
*XML::DOM::Node::firstChild = \&XML::DOM::Node::getFirstChild;
*XML::DOM::Document::importNode = sub {
		my( $doc, $node, $deep ) = @_;

		$node = $node->cloneNode( $deep );
		$node->setOwnerDocument( $doc );

		return $node;
	};
*XML::DOM::Element::getAttributeNodeNS = sub {
		my( $node, $nsuri, $name ) = @_;

		foreach my $attr ($node->attributes)
		{
			if( $attr->nodeName eq $name )
			{
				return $attr;
			}
		}

		return undef;
	};

######################################################################
# 
# EPrints::XML::_xmldom_tag_compression( $tag, $elem )
#
# Only used by the DOM module.
#
######################################################################

sub _xmldom_tag_compression
{
	my ($tag, $elem) = @_;
	
	# Print empty br, hr and img tags like this: <br />
	foreach my $ctag ( @EPrints::XML::COMPRESS_TAGS )
	{
		return 2 if( $ctag eq $tag );
	}

	# Print other empty tags like this: <empty></empty>
	return 1;
}

sub parse_xml_string
{
	my( $string ) = @_;

	my $doc;
	my( %c ) = (
		Namespaces => 1,
		ParseParamEnt => 1,
		ErrorContext => 2,
		NoLWP => 1 );
	$c{ParseParamEnt} = 0;
	my $parser =  XML::DOM::Parser->new( %c );

	$doc = eval { $parser->parse( $string ); };
	if( $@ )
	{
		my $err = $@;
		$err =~ s# at /.*##;
		$err =~ s#\sXML::Parser::Expat.*$##s;
		print STDERR "Error parsing XML $string";
		return;
	}
	return $doc;
}

sub _parse_url
{
	my( $url, $no_expand ) = @_;

	my( %c ) = (
		Namespaces => 1,
		ParseParamEnt => 1,
		ErrorContext => 2,
	);
	if( $no_expand )
	{
		$c{ParseParamEnt} = 0;
	}
	my $parser =  XML::DOM::Parser->new( %c );

	my $doc = $parser->parsefile( $url );

	return $doc;
}

sub parse_xml_frag_string
{
	# FIXME: bet this doesn't like missing <?xml?> and stuff
	my $doc = parse_xml_string( @_ );
	my $frag = XML::DOM::Document->new->createDocumentFragment;
	$frag->cloneChildren( $doc, 1 );
	return $frag;
}

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::abort( "Can't read XML file: '$file'" );
	}

	my( %c ) = (
		Base => $basepath,
		Namespaces => 1,
		ParseParamEnt => 1,
		ErrorContext => 2,
		NoLWP => 1 );
	if( $no_expand )
	{
		$c{ParseParamEnt} = 0;
	}
	my $parser =  XML::DOM::Parser->new( %c );

	unless( open( XML, $file ) )
	{
		print STDERR "Error opening XML file: $file\n";
		return;
	}
	my $doc = eval { $parser->parse( *XML ); };
	close XML;

	if( $@ )
	{
		my $err = $@;
		$err =~ s# at /.*##;
		print STDERR "Error parsing XML $file ($err)";
		return;
	}

	return $doc;
}

=item event_parse( $fh, $handler )

Parses the XML from filehandle $fh, calling the appropriate events
in the handler where necessary.

=cut

sub event_parse
{
	my( $fh, $handler ) = @_;	
	
	my $parser = new XML::Parser(
		Style => "Subs",
		ErrorContext => 5,
		Handlers => {
		Start => sub { 
			my( $p, $v, %a ) = @_; 
			my $attr = {};
			foreach my $k ( keys %a )
			{
				my( $prefix, $localname ) = split /:/, $k;
				($prefix,$localname) = ('',$prefix) if !$localname;
				$attr->{'{}'.$k} = { Prefix=>$prefix, LocalName=>$localname, Name=>$k, Value=>$a{$k} };
			}
			my( $prefix, $localname ) = split /:/, $v;
			($prefix,$localname) = ('',$prefix) if !$localname;
			$handler->start_element( { Prefix=>$prefix, LocalName=>$localname, Name=>$v, Attributes=>$attr } );
		},
		End => sub { 
			my( $p, $v ) = @_; 
			my( $prefix, $localname ) = split /:/, $v;
			($prefix,$localname) = ('',$prefix) if !$localname;
			$handler->end_element( { Prefix=>$prefix, LocalName=>$localname, Name=>$v } );
		},
		Char => sub { 
			my( $p, $data ) = @_; 
			$handler->characters( { Data=>$data } );
		},
	} );

	$parser->parse( $fh );
}


sub _dispose
{
	my( $node ) = @_;

	if( !$node->isa( "XML::DOM::Node" ) )
	{
		EPrints::abort "attempt to dispose an dom node which isn't a dom node";
	}
	
	$node->dispose;
}


sub clone_and_own
{
	my( $node, $doc, $deep ) = @_;

	my $newnode;
	$deep = 0 unless defined $deep;

	# XML::DOM 
	$newnode = $node->cloneNode( $deep );
	$newnode->setOwnerDocument( $doc );

	return $newnode;
}

# ignores encoding!
sub document_to_string
{
	my( $doc, $enc ) = @_;

	my $xml = $doc->toString;
	utf8::decode($xml);

	return $xml;
}

sub make_document
{
	# no params

	my $doc = new XML::DOM::Document();

	return $doc;
}

sub version
{
	"XML::DOM $XML::DOM::VERSION ".$INC{'XML/DOM.pm'};
}

package EPrints::XML::DOM;

our @ISA = qw( EPrints::XML );

use strict;

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

