######################################################################
#
# EPrints::XML::EPC
#
######################################################################
#
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

		return $params{repository}->xml->create_document_fragment
			if $node->hasAttribute( "disabled" ) && $node->getAttribute( "disabled" );

		if( $name=~m/^(if|comment|choose|print|debug|phrase|pin|foreach|set)$/ )
		{
			my $fn = "_process_$name";
			no strict "refs";
			my $r = eval { &{$fn}( $node, %params ); };
			use strict "refs";
			if( $@ )
			{
				$params{repository}->log( "EPScript error: $@" );
				return $params{repository}->html_phrase( "XML/EPC:script_error" );
			}
			return $r;
		}
	}

	my $collapsed = $params{repository}->clone_for_me( $node );
	my $attrs = $collapsed->attributes;
	if( defined $attrs )
	{
		for( my $i = 0; $i<$attrs->length; ++$i )
		{
			my $attr = $attrs->item( $i );
			my $v = $attr->nodeValue;
			my $name = $attr->nodeName;
			my $newv = eval { EPrints::XML::EPC::expand_attribute( $v, $name, \%params ); };
			if( $@ )
			{
				$params{repository}->log( "EPScript error: $@" );
				$newv = $params{repository}->phrase( "XML/EPC:script_error" );
			}
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

	return $v if( $v =~ m/\{\{/ );		# AngularJS format
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
	
	my $collapsed = $params{repository}->xml->create_document_fragment;

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
		$params{repository}->log(
"missing parameter \"$ref\" when making phrase \"".$params{pindata}->{phraseid}."\"" );
		return $params{repository}->make_text( "[pin missing: $ref]" );
	}
	if( !EPrints::XML::is_dom( $params{pindata}->{inserts}->{$ref},
			"DocumentFragment",
			"Text",
			"Element" ) )
	{
		$params{repository}->log(
"parameter \"$ref\" is not an XML node when making phrase \"".$params{pindata}->{phraseid}."\"" );
		return $params{repository}->make_text( "[pin missing: $ref]" );
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
	        next if( EPrints::XML::is_dom( $param, "Text" ) || EPrints::XML::is_dom( $param, "CDataSection" ) );

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

	my $collapsed;
	if( $node->hasAttribute( "textonly" ) && $node->getAttribute( "textonly" ) eq 'yes' )
	{
		$collapsed = $params{repository}->make_text( $params{repository}->phrase( $ref, %pins ) );
	}
	else
	{
		$collapsed = $params{repository}->html_phrase( $ref, %pins );
	}

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

	return $params{repository}->make_doc_fragment;
}

sub _process_set
{
	my( $node, %params ) = @_;

	if( !$node->hasAttribute( "expr" ) )
	{
		EPrints::abort( "In ".$params{in}.": set element with no expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $expr = $node->getAttribute( "expr" );
	if( $expr =~ m/^\s*$/ )
	{
		EPrints::abort( "In ".$params{in}.": set element with empty expr attribute.\n".substr( $node->toString, 0, 100 ) );
	}

	if( !$node->hasAttribute( "name" ) )
	{
		EPrints::abort( "In ".$params{in}.": set element with no name attribute.\n".substr( $node->toString, 0, 100 ) );
	}
	my $name = $node->getAttribute( "name" );
	if( $name !~ m/^[a-z][a-z0-9_]*$/i )
	{
		EPrints::abort( "In ".$params{in}.": set element with non alphanumeric name attribute.\n".substr( $node->toString, 0, 100 ) );
	}

	my $result = EPrints::Script::execute( $expr, \%params );

	my %newparams = %params;
	$newparams{$name} = $result;

	return process_child_nodes( $node, %newparams );
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
	my $limit = $node->getAttribute( "limit" );
	$limit = "" if !defined $limit;
	if( $limit ne "" && $limit !~ m/^\d+$/i )
	{
		EPrints::abort( "In ".$params{in}.": foreach element with non integer limit.\n".substr( $node->toString, 0, 100 ) );
	}

	my $result = EPrints::Script::execute( $expr, \%params );

	my $list = $result->[0];
	my $type = $result->[1];
	my $output = $params{repository}->make_doc_fragment;

	if( !EPrints::Utils::is_set( $list ) )
	{
		return $output;
	}

	if( ref( $list ) ne "ARRAY" )
	{
		$list = [ $list ];
	}

	if( UNIVERSAL::isa( $type, "EPrints::MetaField" ) && $type->get_property( "multiple" ) )
	{
		$type = $type->clone;
		$type->set_property( "multiple", 0 );
	}

	my $index = 0;
	foreach my $item ( @{$list} )
	{
		my %newparams = %params;
		my $thistype = $type;
		if( !defined $thistype || $thistype eq "ARRAY" )
		{
			$thistype = ref( $item ) =~ /^XML::/ ? "XHTML" : "STRING";
		}
		$newparams{"index"} = [ $index, "INTEGER" ];
		$newparams{$iterator} = [ $item, $thistype ];
		$output->appendChild( process_child_nodes( $node, %newparams ) );
		$index++;
		last if( $limit ne "" && $index >= $limit );
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

	my $collapsed = $params{repository}->make_doc_fragment;

	if( $result->[0] )
	{
		$collapsed->appendChild( process_child_nodes( $node, %params ) );
	}

	return $collapsed;
}

sub _process_comment
{
	my( $node, %params ) = @_;

	return $params{repository}->make_doc_fragment;
}

sub _process_choose
{
	my( $node, %params ) = @_;

	my $collapsed = $params{repository}->xml->create_document_fragment;

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
		# sf2 - not to annoy AngularJS/Mustache code:
		if( $value =~ /\{\{/ )
		{
			return ();
		}
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

