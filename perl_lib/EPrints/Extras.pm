######################################################################
#
# EPrints::Extras;
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

B<EPrints::Extras> - Alternate versions of certain methods.

=head1 DESCRIPTION

This module contains methods provided as alternates to the
default render or input methods.

=head1 METHODS

=over 4

=cut 

package EPrints::Extras;

use warnings;
use strict;



######################################################################
=pod

=item $xhtml = EPrints::Extras::render_xhtml_field( $handle, $field,
$value )

Return an XHTML DOM object of the contents of $value. In the case of
an error parsing the XML in $value return an XHTML DOM object 
describing the problem.

This is intented to be used by the render_single_value metadata 
field option, as an alternative to the default text renderer. 

This allows through any XML element, so could cause problems if
people start using SCRIPT to make pop-up windows. A later version
may allow a limited set of elements only.

=cut
######################################################################

sub render_xhtml_field
{
	my( $handle , $field , $value ) = @_;

	if( !defined $value ) { return $handle->make_doc_fragment; }
        my( %c ) = (
                ParseParamEnt => 0,
                ErrorContext => 2,
                NoLWP => 1 );

		local $SIG{__DIE__};
        my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".$value."</fragment>" ); };
        if( $@ )
        {
                my $err = $@;
                $err =~ s# at /.*##;
		my $pre = $handle->make_element( "pre" );
		$pre->appendChild( $handle->make_text( "Error parsing XML in render_xhtml_field: ".$err ) );
		return $pre;
        }
	my $fragment = $handle->make_doc_fragment;
	my $top = ($doc->getElementsByTagName( "fragment" ))[0];
	foreach my $node ( $top->getChildNodes )
	{
		$fragment->appendChild(
			$handle->clone_for_me( $node, 1 ) );
	}
	EPrints::XML::dispose( $doc );
		
	return $fragment;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_preformatted_field( $handle, $field, $value )

Return an XHTML DOM object of the contents of $value.

The contents of $value will be rendered in an HTML <pre>
element. 

=cut
######################################################################

sub render_preformatted_field
{
	my( $handle , $field , $value ) = @_;

	my $pre = $handle->make_element( "pre" );
	$value =~ s/\r\n/\n/g;
	$pre->appendChild( $handle->make_text( $value ) );
		
	return $pre;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_hightlighted_field( $handle, $field, $value )

Return an XHTML DOM object of the contents of $value.

The contents of $value will be rendered in an HTML <pre>
element. 

=cut
######################################################################

sub render_highlighted_field
{
	my( $handle , $field , $value, $alllangs, $nolink, $object ) = @_;

	my $div = $handle->make_element( "div", class=>"ep_highlight" );
	my $v=$field->render_value_actual( $handle, $value, $alllangs, $nolink, $object );
	$div->appendChild( $v );	
	return $div;
}

sub render_lookup_list
{
	my( $handle, $rows ) = @_;

	my $ul = $handle->make_element( "ul" );

	my $first = 1;
	foreach my $row (@$rows)
	{
		my $li = $handle->make_element( "li" );
		$ul->appendChild( $li );
		if( $first )
		{
			$li->setAttribute( "class", "ep_first" );
			$first = 0;
		}
		if( defined($row->{xhtml}) )
		{
			$li->appendChild( $row->{xhtml} );
		}
		elsif( defined($row->{desc}) )
		{
			$li->appendChild( $handle->make_text( $row->{desc} ) );
		}
		my @values = @{$row->{values}};
		my $ul = $handle->make_element( "ul" );
		$li->appendChild( $ul );
		for(my $i = 0; $i < @values; $i+=2)
		{
			my( $name, $value ) = @values[$i,$i+1];
			my $li = $handle->make_element( "li", id => $name );
			$ul->appendChild( $li );
			$li->appendChild( $handle->make_text( $value ) );
		}
	}

	return $ul;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_url_truncate_end( $handle, $field, $value )

Hyper link the URL but truncate the end part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_url_truncate_end
{
	my( $handle, $field, $value ) = @_;

	my $len = 50;	
	my $link = $handle->render_link( $value );
	my $text = $value;
	if( length( $value ) > $len )
	{
		$text = substr( $value, 0, $len )."...";
	}
	$link->appendChild( $handle->make_text( $text ) );
	return $link
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_url_truncate_middle( $handle, $field, $value )

Hyper link the URL but truncate the middle part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_url_truncate_middle
{
	my( $handle, $field, $value ) = @_;

	my $len = 50;	
	my $link = $handle->render_link( $value );
	my $text = $value;
	if( length( $value ) > $len )
	{
		$text = substr( $value, 0, $len/2 )."...".substr( $value, -$len/2, -1 );
	}
	$link->appendChild( $handle->make_text( $text ) );
	return $link
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_related_url( $handle, $field, $value )

Hyper link the URL but truncate the middle part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_related_url
{
	my( $handle, $field, $value ) = @_;

	my $f = $field->get_property( "fields_cache" );
	my $fmap = {};	
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $field = $field->{dataset}->get_field( $fieldname );
		$fmap->{$field_conf->{sub_name}} = $field;
	}

	my $ul = $handle->make_element( "ul" );
	foreach my $row ( @{$value} )
	{
		my $li = $handle->make_element( "li" );
		my $link = $handle->render_link( $row->{url} );
		if( defined $row->{type} )
		{
			$link->appendChild( $fmap->{type}->render_single_value( $handle, $row->{type} ) );
		}
		else
		{
			my $text = $row->{url};
			if( length( $text ) > 40 ) { $text = substr( $text, 0, 40 )."..."; }
			$link->appendChild( $handle->make_text( $text ) );
		}
		$li->appendChild( $link );
		$ul->appendChild( $li );
	}

	return $ul;
}

######################################################################
=pod

=item $orderkey = EPrints::Extras::english_title_orderkey( $field, $value, $dataset )

Strip the leading a/an/the and any non alpha numerics from the start of a orderkey
value. Suitable for make_single_value_orderkey on the title field.

=cut
######################################################################

sub english_title_orderkey 
{
        my( $field, $value, $dataset ) = @_;

        $value =~ s/^[^a-z0-9]+//gi;
        if( $value =~ s/^(a|an|the) [^a-z0-9]*//i ) { $value .= ", $1"; }

        return $value;
}

######################################################################
=pod

=item $xhtml_dom = EPrints::Extras::render_possible_doi( $field, $value, $dataset )

If the field looks like it contains a DOI then link it.

=cut
######################################################################

sub render_possible_doi
{
	my( $handle, $field, $value ) = @_; 

	$value = "" unless defined $value;

	if( $value !~ /^(doi:)?10\.\d\d\d\d\// ) { return $handle->make_text( $value ); }
	
	$value =~ s/^doi://;

	my $url = "http://dx.doi.org/$value";
	my $link = $handle->render_link( $url );
	$link->appendChild( $handle->make_text( $value ) );
	return $link; 
}


######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

