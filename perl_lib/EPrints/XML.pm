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

#use EPrints::SystemSettings;

use Unicode::String qw(utf8 latin1);
use Carp;

@EPrints::XML::COMPRESS_TAGS = qw/br hr img link input meta/;

my $gdome = ( 
	 defined $EPrints::SystemSettings::conf->{enable_gdome} &&
	 $EPrints::SystemSettings::conf->{enable_gdome} );

if( $gdome )
{
	require EPrints::XML::GDOME;
}
else
{
	require EPrints::XML::DOM; 
}

use strict;
use bytes;


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

# in DOM specific module
	

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

	foreach( @nodestrings )
	{
		my $v = $EPrints::XML::PREFIX.$_;
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

# in required dom module


######################################################################
=pod

=item $newnode = EPrints::XML::clone_node( $node, $deep )

Clone the given DOM node and return the new node. Always does a deep
copy.

This function does different things for XML::DOM & XML::GDOME
but the result should be the same.

=cut
######################################################################

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

=item $string = EPrints::XML::to_string( $node, [$enc], [$noxmlns] )

Return the given node (and its children) as a UTF8 encoded string.

$enc is only used when $node is a document.

If $stripxmlns is true then all xmlns attributes are removed. Handy
for making legal XHTML.

Papers over some cracks, specifically that XML::GDOME does not 
support toString on a DocumentFragment, and that XML::GDOME does
not insert a space before the / in tags with no children, which
confuses some browsers. Eg. <br/> vs <br />

=cut
######################################################################

sub to_string
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
		my $tagname = $node->getTagName;

		# lowercasing all tags screws up OAI.
		#$tagname = "\L$tagname";

		push @n, '<', $tagname;

		my $nnm = $node->getAttributes;
		my $done = {};
		foreach my $i ( 0..$nnm->getLength-1 )
		{
			my $attr = $nnm->item($i);
			my $name = $attr->getName;
			next if( $noxmlns && $name =~ m/^xmlns/ );
			next if( $done->{$attr->getName} );
			$done->{$attr->getName} = 1;
			# cjg Should probably escape these values.
			my $value = $attr->getValue;
			$value =~ s/&/&amp;/g;
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
				push @n, to_string( $kid, $enc, $noxmlns );
			}
			push @n,"</",$tagname,">";
		}
	}
	elsif( is_dom( $node, "DocumentFragment" ) )
	{
		foreach my $kid ( $node->getChildNodes )
		{
			push @n, to_string( $kid, $enc, $noxmlns );
		}
	}
	elsif( EPrints::XML::is_dom( $node, "Document" ) )
	{
   		#my $docType  = $node->getDoctype();
	 	#my $elem     = $node->getDocumentElement();
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
		EPrints::Config::abort( <<END );
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
		EPrints::Config::abort( <<END );
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
		$name =~ s/^epc://;
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

	my $name = $node->getNodeName;
	if( defined $opts->{collapse} )
	{
		foreach my $col_id ( @{$opts->{collapse}} )
		{
			return if $col_id eq $name;
		}
	}

	# tidys the node in it's own document so we don't require $session
	my $doc = $node->getOwnerDocument;

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
=pod

=item $xml = EPrints::Utils::collapse_conditions( $xml, [%params] )

Using the given object and %params, collapse the <ep:ifset>,
<ep:ifnotset>, <ep:ifmatch> and <ep:ifnotmatch>
elements in XML and return the result.

The name attribute in ifset etc. refer to the field name in $object,
unless the are prefixed with a asterisk (*) in which case they are keys
to values in %params.

=cut
######################################################################

sub collapse_conditions
{
	my( $node, %params ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to collapse_conditions" );
	}
# cjg - Potential bug if: <ifset a><ifset b></></> and ifset a is disposed
# then ifset: b is processed it will crash.
	
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^epc://;

		# old style
		if( $name =~ m/^ifset|ifnotset|ifmatch|ifnotmatch$/ )
		{
			return _collapse_condition( $node, %params );
		}

		# new style
		if( $name eq "if" )
		{
			return _collapse_if( $node, %params );
		}
		if( $name eq "choose" )
		{
			return _collapse_choose( $node, %params );
		}
		if( $name eq "print" )
		{
			return _collapse_print( $node, %params );
		}
		if( $name eq "phrase" )
		{
			return _collapse_phrase( $node, %params );
		}
		if( $name eq "pin" )
		{
			return _collapse_pin( $node, %params );
		}

	}

	my $collapsed = $params{session}->clone_for_me( $node );
	my $attrs = $collapsed->getAttributes;
	if( defined $attrs )
	{
		for( my $i = 0; $i<$attrs->getLength; ++$i )
		{
			my $attr = $attrs->item( $i );
			my $v = $attr->getValue;
			next unless( $v =~ m/\{/ );
			my $name = $attr->getName;
			my @r = EPrints::XML::split_script_attribute( $v, $name );
			my $newv='';
			for( my $i=0; $i<scalar @r; ++$i )
			{
				if( $i % 2 == 0 )
				{
					$newv.= $r[$i];
				}
				else
				{
					$newv.=EPrints::Script::print( $r[$i], \%params )->toString;
				}
			}
			$attr->setValue( $newv );
		}
	}

	$collapsed->appendChild( collapse_child_nodes( $node, %params ) );

	return $collapsed;
}

sub collapse_child_nodes
{
	my( $node, %params ) = @_;

	my $collapsed = $params{session}->make_doc_fragment;

	foreach my $child ( $node->getChildNodes )
	{
		$collapsed->appendChild(
			collapse_conditions( 
				$child,
				%params ) );			
	}

	return $collapsed;
}

sub _collapse_pin
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "name" ) )
	{
		EPrints::abort( "In ".$params{in}.": pin element with no ref attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $ref = $node->getAttribute( "name" );

	if( !defined $params{pindata}->{inserts}->{$ref} )
	{
		$params{session}->get_repository->log(
"missing parameter \"$ref\" when making phrase \"".$params{pindata}->{phraseid}."\"" );
		return $params{session}->make_text( "[pin missing: $ref]" );
	}

	my $retnode;	
	if( $params{pindata}->{used}->{$ref} )
	{
		$retnode = EPrints::XML::clone_node( 
				$params{pindata}->{inserts}->{$ref}, 1 );
	}
	else
	{
		$retnode = $params{pindata}->{inserts}->{$ref};
		$params{pindata}->{used}->{$ref} = 1;
	}

	if( $node->hasChildNodes )
	{	
		$retnode->appendChild( collapse_child_nodes( $node, %params ) );
	}

	return $retnode;
}


sub _collapse_phrase
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "ref" ) )
	{
		EPrints::abort( "In ".$params{in}.": phrase element with no ref attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $ref = $node->getAttribute( "ref" );

	my %pins = ();
	foreach my $param ( $node->getChildNodes )
	{
		next unless( $param->getTagName eq "param" );

		if( !$param->hasAttribute( "name" ) )
		{
			EPrints::abort( "In ".$params{in}.": param element in phrase with no name attribute.\n".substr( $param->toString, 0, 100 ) );
		}
		my $name = $param->getAttribute( "name" );
		
		$pins{$name} = collapse_child_nodes( $param, %params );
	}

	my $collapsed = $params{session}->html_phrase( $ref, %pins );

#	print $collapsed->toString."\n";

	return $collapsed;
}

sub _collapse_print
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "expr" ) )
	{
		EPrints::abort( "In ".$params{in}.": print element with no expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $expr = $node->getAttribute( "expr" );
	if( $expr =~ m/^\s*$/ )
	{
		EPrints::abort( "In ".$params{in}.": print element with empty expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}

	my $opts = "";
	# apply any render opts
	if( $node->hasAttribute( "opts" ) )
	{
		$opts = $node->getAttribute( "opts" );
	}

	return EPrints::Script::print( $expr, \%params, $opts );
}	

sub _collapse_if
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "test" ) )
	{
		EPrints::abort( "In ".$params{in}.": if element with no test attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $test = $node->getAttribute( "test" );
	if( $test =~ m/^\s*$/ )
	{
		EPrints::abort( "In ".$params{in}.": if element with empty test attribute.\n".substr( $node->toString, 0, 100 ) );
	}

	my $result = EPrints::Script::execute( $test, \%params );
#	print STDERR  "IFTEST:::".$test." == $result\n";

	my $collapsed = $params{session}->make_doc_fragment;

	if( $result->[0] )
	{
		$collapsed->appendChild( collapse_child_nodes( $node, %params ) );
	}

	return $collapsed;
}

sub _collapse_choose
{
	my( $node, %params ) = @_;

	my $collapsed = $params{session}->make_doc_fragment;

	# when
	foreach my $child ( $node->getChildNodes )
	{
		next unless( EPrints::XML::is_dom( $child, "Element" ) );
		my $name = $child->getTagName;
		$name=~s/^ep://;
		$name=~s/^epc://;
		next unless $name eq "when";
		
		if( !$child->hasAttribute( "test" ) )
		{
			EPrints::abort( "In ".$params{in}.": when element with no test attribute.\n".substr( $child->toString, 0, 100 ) );
		}
		my $test = $child->getAttribute( "test" );
		if( $test =~ m/^\s*$/ )
		{
			EPrints::abort( "In ".$params{in}.": when element with empty test attribute.\n".substr( $child->toString, 0, 100 ) );
		}
		my $result = EPrints::Script::execute( $test, \%params );
#		print STDERR  "WHENTEST:::".$test." == $result\n";
		if( $result->[0] )
		{
			$collapsed->appendChild( collapse_child_nodes( $child, %params ) );
			return $collapsed;
		}
	}

	# otherwise
	foreach my $child ( $node->getChildNodes )
	{
		next unless( EPrints::XML::is_dom( $child, "Element" ) );
		my $name = $child->getTagName;
		$name=~s/^ep://;
		$name=~s/^epc://;
		next unless $name eq "otherwise";
		
		$collapsed->appendChild( collapse_child_nodes( $child, %params ) );
		return $collapsed;
	}

	# no otherwise...
	return $collapsed;
}



sub _collapse_condition
{
	my( $node, %params ) = @_;

	my $fieldname = $node->getAttribute( "name" );
	my $element_name = $node->getTagName;
	$element_name =~ s/^ep://;

	my $param;
	my $obj;
	if( $fieldname =~ s/^\$// )
	{
		# fieldname started with $
		if( $fieldname =~ s/^([^.]+.)// )
		{
			# fieldname is property of an object
			$obj = $param;
		}
		else
		{
			# fieldname is a simple field
			$param = $params{$fieldname};
		}
	}
	else
	{
		# fieldname in item object
		$obj = $params{item};
	}

	my $result = 0;

	if( $element_name eq "ifset" || $element_name eq "ifnotset" )
	{
		if( defined $obj )
		{
			$result = $obj->is_set( $fieldname );
		}
		else
		{
			$result = defined $params{$fieldname};
		}
	}

	if( $element_name eq "ifmatch" || $element_name eq "ifnotmatch" )
	{
		if( defined $obj )
		{
			my $dataset = $obj->get_dataset;
	
			my $merge = $node->getAttribute( "merge" );
			my $value = $node->getAttribute( "value" );
			my $match = $node->getAttribute( "match" );

			my @multiple_names = split /\//, $fieldname;
			my @multiple_fields;
			
			# Put the MetaFields in a list
			foreach (@multiple_names)
			{
				push @multiple_fields, EPrints::Utils::field_from_config_string( $dataset, $_ );
			}
	
			my $sf = EPrints::Search::Field->new( 
				$params{session}, 
				$dataset, 
				\@multiple_fields,
				$value,	
				$match,
				$merge );
	
			$result = $sf->get_conditions->item_matches( $obj );
		}
		else
		{
			my $value = $node->getAttribute( "value" );
			foreach( split( /\s+/,$value ) )
			{
				$result = 1 if( $_ eq $params{$fieldname} );
			}
		}
	}

	if( $element_name eq "ifnotmatch" || $element_name eq "ifnotset" )
	{
		$result = !$result;
	}

	if( $result )
	{
		return collapse_child_nodes( $node, %params );
	}

	return $params{session}->make_doc_fragment;
}


sub split_script_attribute
{
	my( $value, $what ) = @_;

	my @r = ();

	# outer loop when in text.
	my $depth = 0;
	OUTCODE: while( length( $value ) )
	{
		$value=~s/^([^{]*)//;
		push @r, $1;
		last unless $value=~s/^\{//;
		$depth = 1;
		my $c = ""; 
		INCODE: while( $depth>0 && length( $value ) )
		{
			if( $value=~s/^\{// )
			{
				++$depth;
				$c.="{";
				next INCODE;
			}
			if( $value=~s/^\}// )
			{
				--$depth;
				$c.="}" if( $depth>0 );
				next INCODE;
			}
			if( $value=~s/^('[^']*')// )
			{
				$c.=$1;
				next INCODE;
			}
			if( $value=~s/^("[^"]*")// )
			{
				$c.=$1;
				next INCODE;
			}
			unless( $value=~s/^([^"'\{\}]+)// )
			{
				print STDERR "Error parsing attribute $what near: $value\n";
				last OUTCODE;
			}
			$c.=$1;
		}
		push @r, $c;
	}

	return @r;
}
















######################################################################
1;
######################################################################
=pod

=back

=cut
######################################################################

