######################################################################
#
# EPrints::XML::EPC
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

B<EPrints::XML> - EPrints Control 

=head1 DESCRIPTION

Methods to process XML containing epc: - EPrints Control elements.

=over 4

=cut

package EPrints::XML::EPC;

use strict;


######################################################################
=pod

=item $xml = EPrints::XML::EPC::process( $xml, [%params] )

Using the given object and %params, collapse the elements <epc:phrase>
<epc:when>, <epc:if>, <epc:print> etc.

Also treats {foo} inside any attribute as if it were 
<epc:print expr="foo" />

=cut
######################################################################

sub process
{
	my( $node, %params ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to epc process" );
	}
# cjg - Potential bug if: <ifset a><ifset b></></> and ifset a is disposed
# then ifset: b is processed it will crash.
	
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->tagName;
		$name =~ s/^epc://;

		# new style
		if( $name eq "if" )
		{
			return _process_if( $node, %params );
		}
		if( $name eq "comment" )
		{
			return _process_comment( $node, %params );
		}
		if( $name eq "choose" )
		{
			return _process_choose( $node, %params );
		}
		if( $name eq "print" )
		{
			return _process_print( $node, %params );
		}
		if( $name eq "debug" )
		{
			return _process_debug( $node, %params );
		}
		if( $name eq "phrase" )
		{
			return _process_phrase( $node, %params );
		}
		if( $name eq "pin" )
		{
			return _process_pin( $node, %params );
		}
		if( $name eq "foreach" )
		{
			return _process_foreach( $node, %params );
		}

	}

	my $collapsed = $params{handle}->clone_for_me( $node );
	my $attrs = $collapsed->attributes;
	if( defined $attrs )
	{
		for( my $i = 0; $i<$attrs->length; ++$i )
		{
			my $attr = $attrs->item( $i );
			my $v = $attr->nodeValue;
			my $name = $attr->nodeName;
			my $newv = EPrints::XML::EPC::expand_attribute( $v, $name, \%params );
			if( $v ne $newv ) { $attr->setValue( $newv ); }
		}
	}

	if( $node->hasChildNodes )
	{
		$collapsed->appendChild( process_child_nodes( $node, %params ) );
	}
	return $collapsed;
}

sub expand_attribute
{
	my( $v, $name, $params ) = @_;

	return $v unless( $v =~ m/\{/ );

	my @r = EPrints::XML::EPC::split_script_attribute( $v, $name );
	my $newv='';
	for( my $i=0; $i<scalar @r; ++$i )
	{
		if( $i % 2 == 0 )
		{
			$newv.= $r[$i];
		}
		else
		{
			$newv.= EPrints::Utils::tree_to_utf8( EPrints::Script::print( $r[$i], $params ) );
		}
	}
	return $newv;
}

sub process_child_nodes
{
	my( $node, %params ) = @_;

	my $collapsed = $params{handle}->make_doc_fragment;

	foreach my $child ( $node->getChildNodes )
	{
		$collapsed->appendChild(
			process( 
				$child,
				%params ) );			
	}

	return $collapsed;
}

sub _process_pin
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "name" ) )
	{
		EPrints::abort( "In ".$params{in}.": pin element with no name attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $ref = $node->getAttribute( "name" );

	if( !defined $params{pindata}->{inserts}->{$ref} )
	{
		$params{handle}->get_repository->log(
"missing parameter \"$ref\" when making phrase \"".$params{pindata}->{phraseid}."\"" );
		return $params{handle}->make_text( "[pin missing: $ref]" );
	}
	if( !EPrints::XML::is_dom( $params{pindata}->{inserts}->{$ref},
			"DocumentFragment",
			"Text",
			"Element" ) )
	{
		$params{handle}->get_repository->log(
"parameter \"$ref\" is not an XML node when making phrase \"".$params{pindata}->{phraseid}."\"" );
		return $params{handle}->make_text( "[pin missing: $ref]" );
	}
		

	my $retnode;	
	if( $params{pindata}->{used}->{$ref} || $node->hasChildNodes )
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
		$retnode->appendChild( process_child_nodes( $node, %params ) );
	}

	return $retnode;
}


sub _process_phrase
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "ref" ) )
	{
		EPrints::abort( "In ".$params{in}.": phrase element with no ref attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $ref = EPrints::XML::EPC::expand_attribute( $node->getAttribute( "ref" ), "ref", \%params );

	my %pins = ();
	foreach my $param ( $node->getChildNodes )
	{
		my $tagname = $param->tagName;
		$tagname =~ s/^epc://;
		next unless( $tagname eq "param" );

		if( !$param->hasAttribute( "name" ) )
		{
			EPrints::abort( "In ".$params{in}.": param element in phrase with no name attribute.\n".substr( $param->toString, 0, 100 ) );
		}
		my $name = $param->getAttribute( "name" );
		
		$pins{$name} = process_child_nodes( $param, %params );
	}

	my $collapsed = $params{handle}->html_phrase( $ref, %pins );

#	print $collapsed->toString."\n";

	return $collapsed;
}

sub _process_print
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

sub _process_debug
{
	my( $node, %params ) = @_;
	
	my $result = _process_print( $node, %params );

	print STDERR EPrints::XML::to_string( $result );

	return $params{handle}->make_doc_fragment;
}

sub _process_foreach
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "expr" ) )
	{
		EPrints::abort( "In ".$params{in}.": foreach element with no expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $expr = $node->getAttribute( "expr" );
	if( $expr =~ m/^\s*$/ )
	{
		EPrints::abort( "In ".$params{in}.": foreach element with empty expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}

	if( !$node->hasAttribute( "iterator" ) )
	{
		EPrints::abort( "In ".$params{in}.": foreach element with no iterator attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $iterator = $node->getAttribute( "iterator" );
	if( $iterator !~ m/^[a-z][a-z0-9_]*$/i )
	{
		EPrints::abort( "In ".$params{in}.": foreach element with non alphanumeric iterator.\n".substr( $node->toString, 0, 100 ) );
	}

	my $result = EPrints::Script::execute( $expr, \%params );

	my $list = $result->[0];
	my $type = $result->[1];
	my $output = $params{handle}->make_doc_fragment;

	if( !EPrints::Utils::is_set( $list ) )
	{
		return $output;
	}

	if( ref( $list ) ne "ARRAY" )
	{
		$list = [ $list ];
	}

	if( ref( $type ) =~ m/EPrints::MetaField/ && $type->get_property( "multiple" ) )
	{
		$type = $type->clone;
		$type->set_property( "multiple", 0 );
	}

	foreach my $item ( @{$list} )
	{
		my %newparams = %params;
		my $thistype = $type;
		if( !defined $thistype || $thistype eq "ARRAY" )
		{
			$thistype = ref( $item );
			$thistype = "STRING" if( $thistype eq "" ); 	
			$thistype = "XHTML" if( $thistype =~ /^XML::/ );
		}
		$newparams{$iterator} = [ $item, $thistype ];
		$output->appendChild( process_child_nodes( $node, %newparams ) );
	}

	return $output;
}

sub _process_if
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

	my $collapsed = $params{handle}->make_doc_fragment;

	if( $result->[0] )
	{
		$collapsed->appendChild( process_child_nodes( $node, %params ) );
	}

	return $collapsed;
}

sub _process_comment
{
	my( $node, %params ) = @_;

	return $params{handle}->make_doc_fragment;
}

sub _process_choose
{
	my( $node, %params ) = @_;

	my $collapsed = $params{handle}->make_doc_fragment;

	# when
	foreach my $child ( $node->getChildNodes )
	{
		next unless( EPrints::XML::is_dom( $child, "Element" ) );
		my $name = $child->tagName;
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
			$collapsed->appendChild( process_child_nodes( $child, %params ) );
			return $collapsed;
		}
	}

	# otherwise
	foreach my $child ( $node->getChildNodes )
	{
		next unless( EPrints::XML::is_dom( $child, "Element" ) );
		my $name = $child->tagName;
		$name=~s/^ep://;
		$name=~s/^epc://;
		next unless $name eq "otherwise";
		
		$collapsed->appendChild( process_child_nodes( $child, %params ) );
		return $collapsed;
	}

	# no otherwise...
	return $collapsed;
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

