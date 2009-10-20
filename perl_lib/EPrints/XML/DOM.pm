######################################################################
#
# EPrints::XML::DOM
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

$EPrints::XML::LIB_LEN = length("XML::DOM::");

# DOM spec fixes
*XML::DOM::Document::documentElement = \&XML::DOM::Document::getDocumentElement;
*XML::DOM::Node::ownerDocument = \&XML::DOM::Node::getOwnerDocument;
*XML::DOM::Node::attributes = sub { shift->getAttributes(@_) };
*XML::DOM::Node::nodeName = sub { shift->getNodeName(@_) };
*XML::DOM::Node::nodeValue = sub { shift->getNodeValue(@_) };
*XML::DOM::Node::nodeType = sub { shift->getNodeType(@_) };
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
				foreach my $k ( keys %a ) { $attr->{$k} = { Name=>$k, Value=>$a{$k} }; }
				$handler->start_element( { Name=>$v, Attributes=>$attr } );
			},
                        End => sub { 
				my( $p, $v ) = @_; 
				$handler->end_element( { Name=>$v } );
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

sub make_document_fragment
{
	my( $session ) = @_;
	
	return $session->{doc}->createDocumentFragment;
}

sub version
{
	"XML::DOM $XML::DOM::VERSION ".$INC{'XML/DOM.pm'};
}

