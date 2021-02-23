######################################################################
#
# EPrints::XML
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

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

=head1 DESCRIPTION

EPrints can use either XML::DOM, XML::LibXML or XML::GDOME modules to generate
and process XML. Some of the functionality of these modules differs so this
module abstracts such functionality so that all the module specific code is in
one place. 

=head1 METHODS

=over 4

=cut

package EPrints::XML;

use Carp;

$EPrints::XML::CLASS = undef;

@EPrints::XML::COMPRESS_TAGS = qw/br hr img link input meta/;

sub init
{
	my $c = $EPrints::SystemSettings::conf;
	my $disable_libxml = exists $c->{enable_libxml} && !$c->{enable_libxml};
	my $disable_gdome = exists $c->{enable_gdome} && !$c->{enable_gdome};

	if( !$disable_libxml )
	{
		eval "use EPrints::XML::LibXML; 1";
		return 1 if !$@;
	}

	if( !$disable_gdome )
	{
		eval "use EPrints::XML::GDOME; 1";
		return 1 if !$@;
	}

	require EPrints::XML::DOM; 
}

use strict;

# $xml = new EPrints::XML( $repository )
#
# Contructor, should be called by Repository only.

sub new($$)
{
	my( $class, $repository, %opts ) = @_;

	$class = $EPrints::XML::CLASS;

	my $self = bless { repository => $repository, %opts }, $class;

	Scalar::Util::weaken( $self->{repository} )
		if defined &Scalar::Util::weaken;

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
	my( $self, $string, %opts ) = @_;
	return parse_xml_string( $string, %opts );
}

=item $doc_frag = parse_frag_string( $string )

Parse $string and return it as a new DOM Document Fragment.

=cut

sub parse_frag_string
{
	my( $self, $string ) = @_;
	return parse_xml_frag_string( $string );
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

=item $node = $xml->create_data_element( $name, $value [, @attrs ] )

Returns a new XML element named $name with $value for contents and optional attribute pairs @attrs.

$value may be undef, an XML tree or an array ref of children, otherwise it is stringified and appended as a text node. Child entries are passed de-referenced to L</create_data_element>.

	$xml->create_data_element(
		"html",
		[
			[ "head" ],
			[ "body",
				[ [ "div", undef, id => "contents" ] ]
			],
		],
		xmlns => "http://www.w3.org/1999/xhtml"
	);

=cut

sub create_data_element
{
	my( $self, $name, $value, @attrs ) = @_;

	my $node = $self->create_element( $name, @attrs );
	return $node if !defined $value;

	if( ref($value) eq "ARRAY" )
	{
		foreach my $child (@$value)
		{
			$node->appendChild( $self->create_data_element( @$child ) );
		}
	}
	elsif( UNIVERSAL::can( $value, "hasChildNodes" ) ) # supported by all libraries
	{
		$node->appendChild( $value );
	}
	else
	{
		$node->appendChild( $self->create_text_node( $value ) );
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

=begin InternalDoc

=item $node = EPrints::XML::clone_node( $node [, $deep ] )

DEPRECATED.

=end InternalDoc

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

	my $clone = $node->cloneNode( 0 );
	$clone->setOwnerDocument( $self->{doc} );

	return $clone;
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

Returns the concantenated value of all text nodes in $node (or the value of $node if $node is a text node).

=cut

sub text_contents_of
{
	my( $self, $node ) = @_;

	my $str = "";
	if( $self->is( $node, "Text" ) )
	{
		$str = $node->toString;
		utf8::decode($str) unless utf8::is_utf8($str);
	}
	elsif( $node->hasChildNodes )
	{
		for($node->childNodes)
		{
			$str .= $self->text_contents_of( $_ );
		}
	}

	return $str;
}

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

	my $string = $node->toString( defined $opts{indent} ? $opts{indent} : 0 );
	utf8::decode($string) unless utf8::is_utf8($string);

	return $string;
}

######################################################################
=pod

=begin InternalDoc

=item $string = EPrints::XML::to_string( $node, [$enc], [$noxmlns] )

Return the given node (and its children) as a UTF8 encoded string.

$enc is only used when $node is a document.

If $stripxmlns is true then all xmlns attributes and namespace prefixes are
removed. Handy for making legal XHTML.

Papers over some cracks, specifically that XML::GDOME does not 
support toString on a DocumentFragment, and that XML::GDOME does
not insert a space before the / in tags with no children, which
confuses some browsers. Eg. <br/> vs <br />

=end InternalDoc

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

=begin InternalDoc

=item $doc = EPrints::XML::parse_xml( $file, $basepath, $no_expand )

Return a DOM document describing the XML file specified by $file.
With the optional root path for looking for the DTD of $basepath. If
$noexpand is true then entities will not be expanded.

If we are using GDOME then it will create an XML::GDOME document
instead.

In the event of an error in the XML file, report to STDERR and
return undef.

=end InternalDoc

=cut
######################################################################

# in required dom module

######################################################################
=pod

=begin InternalDoc

=item event_parse( $fh, $handler )

Parses the XML from filehandle $fh, calling the appropriate events
in the handler where necessary.

=end InternalDoc

=cut
######################################################################

# in required dom module
	
######################################################################
=pod

=begin InternalDoc

=item $boolean = is_dom( $node, @nodestrings )

 return true if node is an object of type XML::DOM/GDOME::$nodestring
 where $nodestring is any value in @nodestrings.

 if $nodestring is not defined then return true if $node is any 
 XML::DOM/GDOME object.

=end InternalDoc

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

=begin InternalDoc

=item $newnode = EPrints::XML::clone_and_own( $doc, $node, $deep )

This function abstracts the different ways that XML::DOM and 
XML::GDOME allow objects to be moved between documents. 

It returns a clone of $node but belonging to the document $doc no
matter what document $node belongs to. 

If $deep is true then the clone will also clone all nodes belonging
to $node, recursively.

=end InternalDoc

=cut
######################################################################

# in required dom module


######################################################################
=pod

=begin InternalDoc

=item $document = EPrints::XML::make_document()

Create and return an empty document.

=end InternalDoc

=cut
######################################################################

# in required dom module

######################################################################
=pod

=begin InternalDoc

=item EPrints::XML::write_xml_file( $node, $filename )

Write the given XML node $node to file $filename.

=end InternalDoc

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

=begin InternalDoc

=item EPrints::XML::write_xhtml_file( $node, $filename )

Write the given XML node $node to file $filename with an XHTML doctype.

=end InternalDoc

=cut
######################################################################

sub write_xhtml_file
{
	my( $node, $filename, %options ) = @_;

	EPrints::Utils::process_parameters( \%options, {
		   add_doctype => 1,
	});

	unless( open( XMLFILE, ">$filename" ) )
	{
		EPrints::abort( <<END );
Can't open to write to XHTML file: $filename
END
		return;
	}

	binmode( XMLFILE, ":utf8" );

	if( $options{add_doctype} )
	{
		print XMLFILE <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
	}

	print XMLFILE EPrints::XML::to_string( $node, "utf-8", 1 );

	close XMLFILE;
}


######################################################################
=pod

=begin InternalDoc

=item EPrints::XML::tidy( $domtree, { collapse=>['element','element'...] }, [$indent] )

Neatly indent the DOM tree. 

Note that this should not be done to XHTML as the differenct between
white space and no white space does matter sometimes.

This method modifies the tree it is given. Possibly there should be
a version which returns a new version without modifying the tree.

Indent is the number of levels to ident by.

=end InternalDoc

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

=begin InternalDoc

=item $namespace = EPrints::XML::namespace( $thing, $version )

Return the namespace for the given version of the eprints xml.

=end InternalDoc

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

=begin InternalDoc

=item $v = EPrints::XML::version()

Returns a string description of the current XML library and version.

=end InternalDoc

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

# DEPRECATED, do not use
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

sub add_to_xml
{
	my ($filename,$node,$id) = @_;
	
	my $xml = EPrints::XML::parse_xml( $filename );

	$xml = _remove_blank_nodes($xml);

	my $main_node;

	foreach my $element ($xml->getChildNodes()) {
		next if ($element->nodeName() eq "#text" or $element->nodeName() eq "#comment");
		$main_node = $element;
		last;
	}
	
	return 1 if (!defined $main_node);

	my $ret;

	unless (ref($node) eq "XML::LibXML::Element") {
		my $in_xml = EPrints::XML::parse_string( undef, $node );
		$in_xml = EPrints::XML::_remove_blank_nodes($in_xml);
		$node = $in_xml->getFirstChild();
	}

	foreach my $child ( $node->getChildNodes() ) {
		$ret = _add_node_to_xml( $main_node, $child, $id, 0 );
	}

	$ret = _write_xml($xml,$filename);
	
	return $ret;
}

sub remove_package_from_xml
{
	my( $filename, $id ) = @_;
	
	my $xml = EPrints::XML::parse_xml( $filename );

	$xml = _remove_blank_nodes($xml);

	my $main_node;

	foreach my $element ($xml->getChildNodes()) {
		next if ($element->nodeName() eq "#text" or $element->nodeName() eq "#comment");
		$main_node = $element;
		last;
	}
	
	return 1 if (!defined $main_node);

	$main_node = _remove_required_nodes($main_node,$id);
	$main_node = _remove_orphaned_chooses($main_node);
	$main_node = _enable_disabled_nodes($main_node,$id);
	
	my $ret = _write_xml($xml,$filename);
	
	return $ret;
}

sub _add_node_to_xml
{
	my ( $xml, $node, $id, $depth ) = @_;

	my $ret = 0;
	
	my @attrs = $node->getAttributes();
	my $count = scalar @attrs;

	foreach my $element ($xml->getChildNodes())
	{
#print STDERR "$depth : Element NAME " . $element->nodeName() . " VALUE " . $element->nodeValue() . "\n";
#print STDERR "$depth : NODE NAME " . $node->nodeName() . " VALUE " . $node->nodeValue() . "\n";
		
		next unless (defined $element->nodeName);
		next unless ($element->nodeName eq $node->nodeName);
		my $match_count = 0;
		my $match_type = undef;
		foreach my $at (@attrs)
		{
#print STDERR $at->getName() . " : " . $at->getValue() . "\n";
			if ($at->getName eq "operation") {
				$match_type = $at->getValue();
				$count--;
				next;
			}
			next unless ($element->getAttribute($at->getName()) eq $at->getValue());
			$match_count++;
		}
		next unless ($match_count == $count);
		next unless (_trim($element->nodeValue) eq _trim($node->nodeValue));
#print STDERR "HERE\n\n";
		if ($match_type eq "replace") {
			$element->setAttribute("disabled",1);
			$element->setAttribute("disabled_by",$id);
			$node->setAttribute("required_by",$id);
			($element->parentNode())->insertAfter($node,$element);
			return 1;
		}
		if ($match_type eq "disable") {
			$element->setAttribute("disabled",1);
			$element->setAttribute("disabled_by",$id);
			$node->setAttribute("required_by",$id);
			return 1;
		}
		
		$depth++;
		if (!$node->hasChildNodes) {
			return 1 if ($element->nodeName eq "#text" or $element->nodeName eq "#comment");
			if ($element->hasAttribute("required_by")) {
				my $id_string = _get_id_string($element,$id);
				$element->setAttribute("required_by",$id_string);
				return 1;
			} else {
				return 1;
			}
		} 
		foreach my $child_node ( $node->getChildNodes ) {
#print STDERR "CALLING WITH \n\n\n\n\n" . $child_node->toString() . "\n\n\n\n\n";
			$ret = _add_node_to_xml($element,$child_node,$id,$depth);
			if ($ret == 2) {
				if ($element->hasAttribute("required_by")) {
					my $id_string = _get_id_string($element,$id);
					$element->setAttribute("required_by",$id_string);
					return 1;
				} else {
					return 2;
				}
			}
		}
		
	}
	if ($ret == 2) {
		if ($node->hasAttribute("required_by")) {
			my $id_string = _get_id_string($node,$id);
			$node->setAttribute("required_by",$id_string);
		} else {
			return 1;
		}
	}

	#if ($depth > 0 and $ret < 1) {
	if ($ret < 1) {
		if (!($node->nodeName() eq "#comment") and !($node->nodeName() eq "#text")) {
#print STDERR "ADDING REQUIRED BY \n\n";
			$node->setAttribute("required_by",$id);
		}
#print STDERR "ADDING CHILD " . $node->nodeName() . "\n\n";
		$xml->addChild($node);
		return 1;
	}

	return $ret;
}

sub _trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub _remove_blank_nodes
{
	my ( $node ) = @_;

	foreach my $element ( $node->getChildNodes ) {
	 	$node->removeChild($element);
		my $name = $element->nodeName();
		my $value = $element->nodeValue();
		unless (_trim($name) eq "#text" && _trim($value) eq "") {
			$node->appendChild($element);
		}
		next if (_trim($name) eq "#text");
		if ($element->hasChildNodes) 
		{
			$node->appendChild(_remove_blank_nodes($element));
		}
	}
	return $node;
}

sub _write_xml 
{
	my( $xml_in, $filename ) = @_;

	$xml_in = _remove_blank_nodes($xml_in);

	open(my $fh, ">", $filename) or return 0;

	print $fh EPrints::XML::to_string( $xml_in );

	close($fh);

	return 1;
}

sub _enable_disabled_nodes
{
	my ( $xml, $id ) = @_;
	foreach my $element ( $xml->getChildNodes ) {
		my $name = $element->nodeName();
		if ($element->hasAttributes) {
			my @attrs = $element->getAttributes();
			foreach my $at (@attrs) 
			{
				if ($at->getName() eq "disabled_by")
				{
					my $id_string = $at->getValue();
					my @ids = split(/ /,$id_string);
					my $flag = 1;
					my $out_ids;
					foreach my $sids(@ids)
					{
						if (!($sids eq $id)) 
						{
							$out_ids .= $sids . " ";	
							$flag = 0;
						}
					}
					if ($flag == 1) {
						$element->removeAttribute("disabled_by");
						$element->removeAttribute("disabled");
					} else {
						$element->setAttribute("disabled_by",_trim($out_ids));
					}
				}
			}
		}
		if ($element->hasChildNodes) 
		{
			$element = _enable_disabled_nodes($element,$id);
		}
	}

	return $xml;
}

sub _remove_required_nodes
{
	my ( $xml, $id ) = @_;
	
	my $found = 0;
	foreach my $element ( $xml->getChildNodes ) {
		my $name = $element->nodeName();
		if ($element->hasAttributes) {
			my @attrs = $element->getAttributes();
			foreach my $at (@attrs) 
			{
				if ($at->getName() eq "required_by")
				{
					my $id_string = $at->getValue();
					my @ids = split(/ /,$id_string);
					my $flag = 1;
					my $out_ids;
					foreach my $sids(@ids)
					{
						if (!($sids eq $id)) 
						{
							$out_ids .= $sids . " ";	
							$flag = 0;
						}
					}
					if ($flag == 1) {
						$xml->removeChild($element);
					} else {
						$element->setAttribute("required_by",_trim($out_ids));
					}
				}
			}
		}
		if ($element->hasChildNodes) 
		{
			$element = _remove_required_nodes($element,$id);
		}
	}

	return $xml;

}

sub _remove_orphaned_chooses
{
	my ( $xml ) = @_;
	
	$xml = _remove_blank_nodes($xml);
	
	foreach my $element ( $xml->getChildNodes ) {
		my $name = $element->nodeName;
		my @preserve_nodes;
		if ($name eq "epc:choose") {
			if ($element->firstChild->nodeName eq "epc:otherwise")
			{
				foreach my $child ($element->firstChild->getChildNodes) 
				{
					$xml->appendChild($child);
				}
				$xml->removeChild($element);
			}
		}
		if ($element->hasChildNodes) 
		{
			$element = _remove_orphaned_chooses($element);
		}
	}

	return $xml;

}

sub _get_id_string 
{
	my ( $element, $id ) = @_;

	my $id_string = $element->getAttribute("required_by");
	my @ids = split(/ /,$id_string);
	my $flag = 1;
	my $out_ids;
	foreach my $sids(@ids)
	{
		if ($sids eq $id) 
		{
			$flag = 0;
		}
	}
	if ($flag > 0) 
	{
		$id_string .= " $id";
	}
	return $id_string;
}

# DEPRECATED
sub make_document_fragment
{
	my( $session ) = @_;
	return $session->xml->create_document_fragment;
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

