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

=head1 DESCRIPTION

EPrints can use either XML::DOM or XML::GDOME modules to generate
and process XML. Some of the functionality of these modules differs
so this module abstracts such functionality so that all the module
specific code is in one place. 

=over 4

=cut

package EPrints::XML;

use EPrints::SystemSettings;

use Unicode::String qw(utf8 latin1);
use strict;
use Carp;


my $gdome = ( 
	 defined $EPrints::SystemSettings::conf->{enable_gdome} &&
	 $EPrints::SystemSettings::conf->{enable_gdome} );

if( $gdome )
{
	require XML::GDOME;
}
else
{
	require XML::DOM; 
	# DOM runs really slowly if it checks all it's data is
	# valid...
	$XML::DOM::SafeMode = 0;
	XML::DOM::setTagCompression( \&_xmldom_tag_compression );
}





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
	return 2 if $tag =~ /^(br|hr|img|link|input|meta)$/;

	# Print other empty tags like this: <empty></empty>
	return 1;
}

######################################################################
=pod

=item $doc = EPrints::XML::parse_xml_string( $string );

Return a DOM document describing the XML string %string.

If we are using GDOME then it will create an XML::GDOME document
instead.

In the event of an error in the XML file, report to STDERR and
return undef.

=cut
######################################################################

sub parse_xml_string
{
	my( $string ) = @_;

#	print "Loading XML: $file\n";

	my $doc;
	if( $gdome )
	{
		# For some reason the GDOME constants give an error,
		# using their values instead (could cause a problem if
		# they change in a subsequent version).

		my $opts = 8; #GDOME_LOAD_COMPLETE_ATTRS
		#unless( $no_expand )
		#{
			#$opts += 4; #GDOME_LOAD_SUBSTITUTE_ENTITIES
		#}
		$doc = XML::GDOME->createDocFromString( $string, $opts );
	}
	else
	{

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
			print STDERR "Error parsing XML $string";
			return;
		}
	}
	return $doc;
}

	

######################################################################
=pod

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

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

#	print "Loading XML: $file\n";

	my $doc;
	if( $gdome )
	{
		my $tmpfile = $file;
		if( defined $basepath )
		{	
			$tmpfile =~ s#/#_#g;
			$tmpfile = $basepath."/.".$tmpfile;
			symlink( $file, $tmpfile );
		}

		# For some reason the GDOME constants give an error,
		# using their values instead (could cause a problem if
		# they change in a subsequent version).

		my $opts = 8; #GDOME_LOAD_COMPLETE_ATTRS
		unless( $no_expand )
		{
			$opts += 4; #GDOME_LOAD_SUBSTITUTE_ENTITIES
		}
		$doc = XML::GDOME->createDocFromURI( $tmpfile, $opts );
	}
	else
	{

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
		$doc = eval { $parser->parse( *XML ); };
		close XML;
		if( $@ )
		{
			my $err = $@;
			$err =~ s# at /.*##;
			print STDERR "Error parsing XML $file ($err)";
			return;
		}
	}
	return $doc;
}

	
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

	my $s;
	if( $gdome )
	{
		$s ="XML::GDOME::";
	}
	else
	{
		$s ="XML::DOM::";
	}

	return 1 if( scalar @nodestrings == 0 );

	foreach( @nodestrings )
	{
		my $v = $s.$_;
		return 1 if( substr( ref($node), 0, length( $v ) ) eq $v );
	}

	return 0;
}


######################################################################
=pod

=item EPrints::XML::dispose( $node )

Dispose of this node if needed. Only XML::DOM nodes need to be
disposed as they have cyclic references. XML::GDOME nodes are C structs.

=cut
######################################################################

sub dispose
{
	my( $node ) = @_;

	if( !defined $node )
	{
		confess "attempt to dispose an undefined dom node";
	}

	if( !$gdome )
	{
		$node->dispose;
	}
}

######################################################################
=pod

=item $newnode = EPrints::XML::clone_node( $node, $deep )

Clone the given DOM node and return the new node. Always does a deep
copy.

This function does different things for XML::DOM & XML::GDOME
but the result should be the same.

=cut
######################################################################

sub clone_node
{
	my( $node, $deep ) = @_;

	if( !defined $node )
	{
		# ey!
		confess;
	}

	# XML::DOM is easy
	if( !$gdome )
	{
		return $node->cloneNode( $deep );
	}

	if( is_dom( $node, "DocumentFragment" ) )
	{
		my $doc = $node->getOwnerDocument;
		my $f = $doc->createDocumentFragment;
		return $f unless $deep;
		
		foreach my $c ( $node->getChildNodes )
		{
			$f->appendChild( $c->cloneNode( 1 ) );
		}
		return $f;
	}
	my $doc = $node->getOwnerDocument;
	my $newnode = $node->cloneNode( 1 );
	$doc->importNode( $newnode, 1 );
	return $newnode;

}

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

sub clone_and_own
{
	my( $node, $doc, $deep ) = @_;

	my $newnode;
	$deep = 0 unless defined $deep;

	if( $gdome )
	{
		# XML::GDOME
		if( is_dom( $node, "DocumentFragment" ) )
		{
			$newnode = $doc->createDocumentFragment;

			if( $deep )
			{	
				foreach my $c ( $node->getChildNodes )
				{
					$newnode->appendChild( 
						$doc->importNode( $c, 1 ) );
				}
			}
		}
		else
		{
			$newnode = $doc->importNode( $node, $deep );
			# bug in importNode NOT being deep that it does
			# not appear to clone attributes, so lets work
			# around it!

			my $attrs = $node->getAttributes;
			if( $attrs )
			{
				for my $i ( 0..$attrs->getLength-1 )
				{
					my $attr = $attrs->item( $i );
					my $k = $attr->getName;
					my $v = $attr->getValue;
					$newnode->setAttribute( $k, $v );
				}
			}
		}

	}
	else
	{
		# XML::DOM 
		$newnode = $node->cloneNode( $deep );
		$newnode->setOwnerDocument( $doc );
	}
	return $newnode;
}

######################################################################
=pod

=item $string = EPrints::XML::to_string( $node, [$enc] )

Return the given node (and its children) as a UTF8 encoded string.

$enc is only used when $node is a document.

Papers over some cracks, specifically that XML::GDOME does not 
support toString on a DocumentFragment, and that XML::GDOME does
not insert a space before the / in tags with no children, which
confuses some browsers. Eg. <br/> vs <br />

=cut
######################################################################

sub to_string
{
	my( $node, $enc ) = @_;

	$enc = 'utf-8' unless defined $enc;
	
	my @n = ();
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		push @n, '<', $node->getTagName, ' ';
		#foreach my $attr ( $node->getChildNodes )

		my $nnm = $node->getAttributes;
		my $done = {};
		foreach my $i ( 0..$nnm->getLength-1 )
		{
			my $attr = $nnm->item($i);
			next if $done->{$attr->getName};
			$done->{$attr->getName} = 1;
			push @n, " ",$attr->toString;
		}

		if( $node->hasChildNodes )
		{
			push @n,">";
			foreach my $kid ( $node->getChildNodes )
			{
				push @n, to_string( $kid );
			}
			push @n,"</",$node->getTagName,">";
		}
		else
		{
			push @n," />";
		}
	}
	elsif( is_dom( $node, "DocumentFragment" ) )
	{
		foreach my $kid ( $node->getChildNodes )
		{
			push @n, to_string( $kid );
		}
	}
	elsif( EPrints::XML::is_dom( $node, "Document" ) )
	{
   		#my $docType  = $node->getDoctype();
	 	#my $elem     = $node->getDocumentElement();
		#push @n, $docType->toString, "\n";, to_string( $elem );
		push @n, $node->toStringEnc( $enc );
	}
	elsif( EPrints::XML::is_dom( 
			$node, 
			"Text", 
			"CDATASection", 
			"EntityReference", 
			"Comment" ) )
	{
		push @n, $node->toString;
	}
	else
	{
		print STDERR "EPrints::XML: Not sure how to turn node type ".$node->getNodeType."\ninto a string.\n";
	}

	return join '', @n;
}

######################################################################
#=pod
#
#=item $document = EPrints::XML::make_xhtml_document()
#
#Create and return an empty XHTML document.
#
#=cut
#######################################################################
#
#sub make_xhtml_document
#{
#	# no params
#
#	my @doctdata = (
#				"html",
#				"DTD/xhtml1-transitional.dtd",
#				"-//W3C//DTD XHTML 1.0 Transitional//EN" );
#	my $doc;
#
#	if( $gdome )
#	{
#		# XML::GDOME
#		my $dtd = XML::GDOME->createDocumentType( @doctdata );
#		$doc = XML::GDOME->createDocument( undef, "html", $dtd );
#		my $html = ($doc->getElementsByTagName( "html" ))[0];
#		$doc->removeChild( $html );
#	}
#	else
#	{
#		# XML::DOM
#		$doc = new XML::DOM::Document();
#	
#		my $doctype = $doc->createDocumentType( @doctdata );
#		$doc->setDoctype( $doctype );
#	
#		my $xmldecl = $doc->createXMLDecl( "1.0", "UTF-8", "yes" );
#		$doc->setXMLDecl( $xmldecl );
#	}
#	
#
#
#	return $doc;
#}

######################################################################
=pod

=item $document = EPrints::XML::make_document()

Create and return an empty document.

=cut
######################################################################

sub make_document
{
	# no params

	# XML::DOM
	if( !$gdome )
	{
		my $doc = new XML::DOM::Document();
	
		return $doc;
	}
	
	# XML::GDOME
	my $doc = XML::GDOME->createDocument( undef, "thing", undef );
	$doc->removeChild( $doc->getFirstChild );

	return $doc;
}

######################################################################
=pod

=item EPrints::XML::write_xml_file( $node, $filename )

Write the given XML node $node to file $filename.

=cut
######################################################################

sub write_xml_file
{
	my( $node, $filename ) = @_;

	if( $gdome )
	{
		unless( open( XMLFILE, ">$filename" ) )
		{
			EPrints::Config::abort( <<END );
Can't open to write to XML file: $filename
END
		}
#		print XMLFILE $node->toStringEnc("utf8",0);
		print XMLFILE EPrints::XML::to_string( $node, "utf-8" );
		close XMLFILE;
	}
	else
	{
        	$node->printToFile( $filename );
	}
}

######################################################################
=pod

=item $elements = EPrints::XML::find_elements( $node, @list )

Return the first occurence of each of the elemnts named in the @list
within $node. Will not look inside named elements. Returns a reference
to a hash.

=cut
######################################################################

sub find_elements
{
	my( $node, @list ) = @_;

	my $found = {};

	foreach( @list ) { $found->{$_} = "no"; }

	&_find_elements2( $node, $found );

	foreach( keys %{$found} ) 
	{
		delete $found->{$_} if $found->{$_} eq "no";
	}
	return $found;
}

sub _find_elements2
{
	my( $node, $found ) = @_;
	if( is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^ep://;
		if( defined $found->{$name} )
		{
			if( $found->{$name} eq "no" )
			{
				$found->{$name} = $node;
			}
			return;
		}
	}
	if( $node->hasChildNodes )
	{
		foreach my $c ( $node->getChildNodes )
		{
			_find_elements2( $c, $found );
		}
	}
}


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

######################################################################
1;
######################################################################
=pod

=back

=cut
######################################################################
