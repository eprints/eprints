######################################################################
#
# EPrints::XML
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

B<EPrints::XML> - XML Abstraction Module

=head1 SYNOPSIS

	my $xml = $repository->xml;

	$doc = $xml->parse_string( $string );
	$doc = $xml->parse_file( $filename );
	$doc = $xml->parse_url( $url );

	$utf8_string = $xml->to_string( $dom_node, %opts );

	$dom_node = $xml->clone( $dom_node ); # deep
	$dom_node = $xml->clone_node( $dom_node ); # shallow

	# clone and return child nodes
	$dom_node = $xml->contents_of( $dom_node );
	# Return text child nodes as a string
	$utf8_string = $xml->text_contents_of( $dom_node );

	$dom_node = $xml->create_element( $name, %attr );
	$dom_node = $xml->create_text_node( $value );
	$dom_node = $xml->create_comment( $value );
	$dom_node = $xml->create_document_fragment;

	$xml->dispose( $dom_node );

head1 DESCRIPTION

EPrints can use either XML::DOM, XML::LibXML or XML::GDOME modules to generate
and process XML. Some of the functionality of these modules differs so this
module abstracts such functionality so that all the module specific code is in
one place. 

=head1 METHODS

=over 4

=cut

package EPrints::XML;

#use EPrints::SystemSettings;

use Carp;

@EPrints::XML::COMPRESS_TAGS = qw/br hr img link input meta/;

if( $EPrints::SystemSettings::conf->{enable_libxml} )
{
	require EPrints::XML::LibXML;
}
elsif( $EPrints::SystemSettings::conf->{enable_gdome} )
{
	require EPrints::XML::GDOME;
}
else
{
	require EPrints::XML::DOM; 
}

use strict;

# $xml = new EPrints::XML( $repository )
#
# Contructor, should be called by Repository only.

sub new($$)
{
	my( $class, $repository, %opts ) = @_;

	my $self = bless { repository => $repository, %opts }, $class;

	if( !defined $self->{doc} )
	{
		$self->{doc} = make_document();
	}

	return $self;
}

=back

=head2 Parsing

=over 4

=cut


=item $doc = $xml->parse_string( $string, %opts )

Returns an XML document parsed from $string.

=cut

sub parse_string
{
	my( $self, $string ) = @_;
	return parse_xml_string( $string );
}

=item $doc = $xml->parse_file( $filename, %opts )

Returns an XML document parsed from the file called $filename.

	base_path - base path to load DTD files from
	no_expand - don't expand entities

=cut

sub parse_file
{
	my( $self, $filename, %opts ) = @_;
	return parse_xml( $filename, $opts{base_path}, $opts{no_expand} );
}

=item $doc = $xml->parse_url( $url, %opts )

Returns an XML document parsed from the content located at $url.

=cut

sub parse_url
{
	return _parse_url( pop(@_) );
}

=back

=head2 Node Creation

=over 4

=cut


=item $node = $xml->create_element( $name [, @attrs ] )

Returns a new XML element named $name with optional attribute pairs @attrs.

=cut

sub create_element
{
	my( $self, $name, @attrs ) = @_;

	my $node = $self->{doc}->createElement( $name );
	while(my( $key, $value ) = splice(@attrs,0,2))
	{
		next if !defined $value;
		$node->setAttribute( $key => $value );
	}

	return $node;
}

=item $node = $xml->create_cdata_section( $value )

Returns a CDATA section containing $value.

=cut

sub create_cdata_section
{
	my( $self, $value ) = @_;
	return $self->{doc}->createCDATASection( $value );
}

=item $node = $xml->create_text_node( $value )

Returns a new XML text node containing $value.

=cut

sub create_text_node
{
	my( $self, $value ) = @_;
	return $self->{doc}->createTextNode( $value );
}

=item $node = $xml->create_comment( $value )

Returns a new XML comment containing $value.

=cut

sub create_comment
{
	my( $self, $value ) = @_;
	return $self->{doc}->createComment( $value );
}

=item $node = $xml->create_document_fragment

Returns a new XML document fragment.

=cut

sub create_document_fragment
{
	my( $self ) = @_;
	return $self->{doc}->createDocumentFragment;
}

=back

=head2 Other

=over 4

=cut


=item $bool = $xml->is( $node, $type [, $type ... ] )

Returns true if $node is one of the given node types: Document, DocumentFragment, Element, Comment, Text.

=cut

sub is
{
	my( $self, $node, @types ) = @_;

	for(@types)
	{
		return 1 if substr(ref($node),-1*length($_)) eq $_;
	}

	return 0;
}

=item $node = $xml->clone( $node )

Returns a deep clone of $node. The new node(s) will be owned by this object.

=cut

sub clone
{
	my( $self, $node ) = @_;

	return $self->{doc}->importNode( $node, 1 );
}

=item $node = $xml->clone_node( $node )

Returns a clone of $node only (no children). The new node will be owned by this object.

=item $node = EPrints::XML::clone_node( $node [, $deep ] )

DEPRECATED.

=cut

sub clone_node
{
	my( $self, $node ) = @_;

	# backwards compatibility
	if( !$self->isa( "EPrints::XML" ) )
	{
		my $deep = $node;
		$node = $self;
		return $node->cloneNode( $deep );
	}

	return clone_and_own( $node, $self->{doc}, $node );

# Bug in XML::LibXML where it ignores $deep, can't easily override this
#	return $self->{doc}->importNode( $node, 0 );
}

=item $node = $xml->contents_of( $node )

Returns a document fragment containing a copy of all the children of $node.

=cut

sub contents_of
{
	my $node = pop @_;

	my $f = $node->ownerDocument->createDocumentFragment;
	foreach my $c ( $node->childNodes )
	{
		$f->appendChild( $c->cloneNode( 1 ) );
	}

	return $f;
}

=item $string = $xml->text_contents_of( $node )

TODO: Returns any text child nodes in $node.

=cut

=item $utf8_string = $xml->to_string( $node, %opts )

Serialises and returns the $node as a UTF-8 string.

To generate an XHTML string see L<EPrints::XHTML>.

Options:
	indent - if true will indent the XML tree

=cut

sub to_string
{
	if( !$_[0]->isa( "EPrints::XML" ) )
	{
		return &_to_string;
	}

	my( $self, $node, %opts ) = @_;

	my $string = $node->toString( $opts{indent} );
	utf8::decode($string) unless utf8::is_utf8($string);

	return $string;
}

######################################################################
=pod

=item $string = EPrints::XML::to_string( $node, [$enc], [$noxmlns] )

Return the given node (and its children) as a UTF8 encoded string.

$enc is only used when $node is a document.

If $stripxmlns is true then all xmlns attributes and namespace prefixes are
removed. Handy for making legal XHTML.

Papers over some cracks, specifically that XML::GDOME does not 
support toString on a DocumentFragment, and that XML::GDOME does
not insert a space before the / in tags with no children, which
confuses some browsers. Eg. <br/> vs <br />

=cut
######################################################################

sub _to_string
{
	my( $node, $enc, $noxmlns ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to to_string" );
	}

	$enc = 'utf-8' unless defined $enc;
	
	my @n = ();
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $tagname = $node->nodeName;

		if( $noxmlns )
		{
			$tagname =~ s/^.+://;
		}

		# lowercasing all tags screws up OAI.
		#$tagname = "\L$tagname";

		push @n, '<', $tagname;
		my $nnm = $node->attributes;
		my $done = {};
		foreach my $i ( 0..$nnm->length-1 )
		{
			my $attr = $nnm->item($i);
			my $name = $attr->nodeName;
			next if( $done->{$attr->nodeName} );
			$done->{$attr->nodeName} = 1;
			# cjg Should probably escape these values.
			my $value = $attr->nodeValue;
			# strip namespaces, unless it's the XHTML namespace on <html>
			if( $noxmlns && $name =~ m/^xmlns/ )
			{
				next unless $tagname eq "html" && $value =~ m#http://www\.w3\.org/1999/xhtml#;
			}
			utf8::decode($value) unless utf8::is_utf8($value);
			$value =~ s/&/&amp;/g;
			$value =~ s/</&lt;/g;
			$value =~ s/>/&gt;/g;
			$value =~ s/"/&quot;/g;
			push @n, " ", $name."=\"".$value."\"";
		}

		#cjg This is bad. It makes nodes like <div /> if 
		# they are empty. Should make <div></div> like XML::DOM
		my $compress = 0;
		foreach my $ctag ( @EPrints::XML::COMPRESS_TAGS )
		{
			$compress = 1 if( $ctag eq $tagname );
		}
		if( $node->hasChildNodes )
		{
			$compress = 0;
		}

		if( $compress )
		{
			push @n," />";
		}
		else
		{
			push @n,">";
			foreach my $kid ( $node->getChildNodes )
			{
				push @n, _to_string( $kid, $enc, $noxmlns );
			}
			push @n,"</",$tagname,">";
		}
	}
	elsif( EPrints::XML::is_dom( $node, "DocumentFragment" ) )
	{
		foreach my $kid ( $node->getChildNodes )
		{
			push @n, _to_string( $kid, $enc, $noxmlns );
		}
	}
	elsif( EPrints::XML::is_dom( $node, "Document" ) )
	{
   		#my $docType  = $node->getDoctype();
	 	#my $elem     = $node->documentElement();
		#push @n, $docType->toString, "\n";, to_string( $elem , $enc, $noxmlns);
		push @n, document_to_string( $node, $enc );
	}
	elsif( EPrints::XML::is_dom( 
			$node, 
			"Text", 
			"CDATASection", 
			"ProcessingInstruction",
			"EntityReference" ) )
	{
		push @n, $node->toString; 
		utf8::decode($n[$#n]) unless utf8::is_utf8($n[$#n]);
	}
	elsif( EPrints::XML::is_dom( $node, "Comment" ) )
	{
		push @n, "<!--",$node->getData, "-->"
	}
	else
	{
		print STDERR "EPrints::XML: Not sure how to turn node type ".$node->getNodeType."\ninto a string.\n";
	}
	return join '', @n;
}

=item $xml->dispose( $node )

Dispose and free the memory used by $node.

=cut

sub dispose
{
	my $node = pop @_;
	if( !defined $node )
	{
		EPrints::abort( "attempt to dispose an undefined dom node" );
	}
	_dispose( $node );
}

=item $doc = EPrints::XML::parse_xml( $file, $basepath, $no_expand )

Return a DOM document describing the XML file specified by $file.
With the optional root path for looking for the DTD of $basepath. If
$noexpand is true then entities will not be expanded.

If we are using GDOME then it will create an XML::GDOME document
instead.

In the event of an error in the XML file, report to STDERR and
return undef.

=cut
######################################################################

# in required dom module

######################################################################
=pod

=item event_parse( $fh, $handler )

Parses the XML from filehandle $fh, calling the appropriate events
in the handler where necessary.

=cut
######################################################################

# in required dom module
	
######################################################################
=pod

=item $boolean = is_dom( $node, @nodestrings )

 return true if node is an object of type XML::DOM/GDOME::$nodestring
 where $nodestring is any value in @nodestrings.

 if $nodestring is not defined then return true if $node is any 
 XML::DOM/GDOME object.

=cut
######################################################################

sub is_dom
{
	my( $node, @nodestrings ) = @_;

	return 1 if( scalar @nodestrings == 0 );

	my $name = ref($node);
	$name =~ s/^.*:://;
	foreach( @nodestrings )
	{
		return 1 if $name eq $_;
	}

	return 0;
}


# in required dom module


# in required dom module

######################################################################
=pod

=item $newnode = EPrints::XML::clone_and_own( $doc, $node, $deep )

This function abstracts the different ways that XML::DOM and 
XML::GDOME allow objects to be moved between documents. 

It returns a clone of $node but belonging to the document $doc no
matter what document $node belongs to. 

If $deep is true then the clone will also clone all nodes belonging
to $node, recursively.

=cut
######################################################################

# in required dom module


######################################################################
=pod

=item $document = EPrints::XML::make_document()

Create and return an empty document.

=cut
######################################################################

# in required dom module

######################################################################
=pod

=item EPrints::XML::write_xml_file( $node, $filename )

Write the given XML node $node to file $filename.

=cut
######################################################################

sub write_xml_file
{
	my( $node, $filename ) = @_;

	unless( open( XMLFILE, ">$filename" ) )
	{
		EPrints::abort( <<END );
Can't open to write to XML file: $filename
END
	}
	print XMLFILE EPrints::XML::to_string( $node, "utf-8" );
	close XMLFILE;
}

######################################################################
=pod

=item EPrints::XML::write_xhtml_file( $node, $filename )

Write the given XML node $node to file $filename with an XHTML doctype.

=cut
######################################################################

sub write_xhtml_file
{
	my( $node, $filename ) = @_;

	unless( open( XMLFILE, ">$filename" ) )
	{
		EPrints::abort( <<END );
Can't open to write to XHTML file: $filename
END
		return;
	}
	print XMLFILE <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END

	print XMLFILE EPrints::XML::to_string( $node, "utf-8", 1 );

	close XMLFILE;
}


######################################################################
=pod

=item EPrints::XML::tidy( $domtree, { collapse=>['element','element'...] }, [$indent] )

Neatly indent the DOM tree. 

Note that this should not be done to XHTML as the differenct between
white space and no white space does matter sometimes.

This method modifies the tree it is given. Possibly there should be
a version which returns a new version without modifying the tree.

Indent is the number of levels to ident by.

=cut
######################################################################

sub tidy 
{
	my( $node, $opts, $indent ) = @_;

	my $name = $node->nodeName;
	if( defined $opts->{collapse} )
	{
		foreach my $col_id ( @{$opts->{collapse}} )
		{
			return if $col_id eq $name;
		}
	}

	# tidys the node in it's own document so we don't require $session
	my $doc = $node->ownerDocument;

	$indent = $indent || 0;

	if( !defined $node )
	{
		EPrints::abort( "Attempt to call EPrints::XML::tidy on a undefined node." );
	}

	my $state = "empty";
	my $text = "";
	foreach my $c ( $node->getChildNodes )
	{
		unless( EPrints::XML::is_dom( $c, "Text", "CDATASection", "EntityReference" ) ) {
			$state = "complex";
			last;
		}

		unless( EPrints::XML::is_dom( $c, "Text" ) ) { $state = "text"; }
		next if $state eq "text";
		$text.=$c->nodeValue;
		$state = "simpletext";
	}
	if( $state eq "simpletext" )
	{
		$text =~ s/^\s*//;
		$text =~ s/\s*$//;
		foreach my $c ( $node->getChildNodes )
		{
			$node->removeChild( $c );
		}
		$node->appendChild( $doc->createTextNode( $text ) );
		return;
	}
	return if $state eq "text";
	return if $state eq "empty";
	$text = "";
	my $replacement = $doc->createDocumentFragment;
	$replacement->appendChild( $doc->createTextNode( "\n" ) );
	foreach my $c ( $node->getChildNodes )
	{
		tidy($c,$opts,$indent+1);
		$node->removeChild( $c );
		if( EPrints::XML::is_dom( $c, "Text" ) )
		{
			$text.= $c->nodeValue;
			next;
		}
		$text =~ s/^\s*//;	
		$text =~ s/\s*$//;	
		if( $text ne "" )
		{
			$replacement->appendChild( $doc->createTextNode( "  "x($indent+1) ) );
			$replacement->appendChild( $doc->createTextNode( $text ) );
			$replacement->appendChild( $doc->createTextNode( "\n" ) );
			$text = "";
		}
		$replacement->appendChild( $doc->createTextNode( "  "x($indent+1) ) );
		$replacement->appendChild( $c );
		$replacement->appendChild( $doc->createTextNode( "\n" ) );
	}
	$text =~ s/^\s*//;	
	$text =~ s/\s*$//;	
	if( $text ne "" )
	{
		$replacement->appendChild( $doc->createTextNode( "  "x($indent+1) ) );
		$replacement->appendChild( $doc->createTextNode( $text ) );
		$replacement->appendChild( $doc->createTextNode( "\n" ) );
	}
	$replacement->appendChild( $doc->createTextNode( "  "x($indent) ) );
	$node->appendChild( $replacement );
}


######################################################################
=pod

=item $namespace = EPrints::XML::namespace( $thing, $version )

Return the namespace for the given version of the eprints xml.

=cut
######################################################################

sub namespace
{
	my( $thing, $version ) = @_;

	if( $thing eq "data" )
	{
               	return "http://eprints.org/ep2/data/2.0" if( $version eq "2" );
                return "http://eprints.org/ep2/data" if( $version eq "1" );
		return undef;
	}

	return undef;
}

=item $v = EPrints::XML::version()

Returns a string description of the current XML library and version.

=cut

######################################################################
# Debug code, don't use!
######################################################################

sub debug_xml
{
	my( $node, $depth ) = @_;

	#push @{$x}, $node;
	print STDERR ">"."  "x$depth;
	print STDERR "DEBUG(".ref($node).")\n";
	if( is_dom( $node, "Document", "Element" ) )
	{
		foreach my $c ( $node->getChildNodes )
		{
			debug_xml( $c, $depth+1 );
		}
	}

	print STDERR "  "x$depth;
	print STDERR "(".ref($node).")\n";
	print STDERR "  "x$depth;
	print STDERR $node->toString."\n";
	print STDERR "<\n";
}

sub is_empty
{
	my( $node ) = @_;
	return !$node->hasChildNodes();
}

sub trim_whitespace
{
	my( $node, $inner ) = @_;

	$inner = 0 unless defined $inner;

	my $doc = $node->getOwnerDocument;
	my $text = "";
	my $first = 1;
	foreach my $child ( $node->getChildNodes )
	{
		if( EPrints::XML::is_dom( $child, "Text" ) )
		{
			$node->removeChild( $child );
			$text .= $child->nodeValue;
			next;
		}
		if( EPrints::XML::is_dom( $child, "Element" ) )
		{
			if( $text ne "" )
			{
				$text =~ s/[\s\r\n]+/ /g;
				if( $first )
				{
					$first = 0;
					$text =~ s/^ //;	
				}
				$node->insertBefore(
					$doc->createTextNode( $text ),
					$child );
				$text = "";
			}
			trim_whitespace( $child );
		}
	}

	if( $text ne "" )
	{
		$text =~ s/[\s\r\n]+/ /g;
		if( $first )
		{
			$text =~ s/^ //;	
		}
		$text =~ s/ $//;	
		$node->appendChild( $doc->createTextNode( $text ));
	}

}

# DEPRECATED
sub make_document_fragment
{
	my( $session ) = @_;
	return $session->xml->create_document_fragment;
}

1;
