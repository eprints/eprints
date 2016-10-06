######################################################################
#
# EPrints::Extras;
#
######################################################################
#
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

=item $xhtml = EPrints::Extras::render_xhtml_field( $session, $field,
$value )

Return an XHTML DOM object of the contents of $value. In the case of
an error parsing the XML in $value return an XHTML DOM object 
describing the problem.

This is intended to be used by the render_single_value metadata
field option, as an alternative to the default text renderer. 

This allows through any XML element, so could cause problems if
people start using SCRIPT to make pop-up windows. A later version
may allow a limited set of elements only.

=cut
######################################################################

sub render_xhtml_field
{
	my( $session , $field , $value ) = @_;

	if( !defined $value ) { return $session->make_doc_fragment; }
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
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( "Error parsing XML in render_xhtml_field: ".$err ) );
		return $pre;
        }
	my $fragment = $session->make_doc_fragment;
	my $top = ($doc->getElementsByTagName( "fragment" ))[0];
	foreach my $node ( $top->getChildNodes )
	{
		$fragment->appendChild(
			$session->clone_for_me( $node, 1 ) );
	}
	EPrints::XML::dispose( $doc );
		
	return $fragment;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_preformatted_field( $session, $field, $value )

Return an XHTML DOM object of the contents of $value.

The contents of $value will be rendered in an HTML <pre>
element. 

=cut
######################################################################

sub render_preformatted_field
{
	my( $session , $field , $value ) = @_;

	my $pre = $session->make_element( "pre" );
	$value =~ s/\r\n/\n/g;
	$pre->appendChild( $session->make_text( $value ) );
		
	return $pre;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_hightlighted_field( $session, $field, $value )

Return an XHTML DOM object of the contents of $value.

The contents of $value will be rendered in an HTML <pre>
element. 

=cut
######################################################################

sub render_highlighted_field
{
	my( $session , $field , $value, $alllangs, $nolink, $object ) = @_;

	my $div = $session->make_element( "div", class=>"ep_highlight" );
	my $v=$field->render_value_actual( $session, $value, $alllangs, $nolink, $object );
	$div->appendChild( $v );	
	return $div;
}

sub render_lookup_list
{
	my( $session, $rows ) = @_;

	my $ul = $session->make_element( "ul" );

	my $first = 1;
	foreach my $row (@$rows)
	{
		my $li = $session->make_element( "li" );
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
			$li->appendChild( $session->make_text( $row->{desc} ) );
		}
		my @values = @{$row->{values}};
		my $ul = $session->make_element( "ul" );
		$li->appendChild( $ul );
		for(my $i = 0; $i < @values; $i+=2)
		{
			my( $name, $value ) = @values[$i,$i+1];
			my $li = $session->make_element( "li", id => $name );
			$ul->appendChild( $li );
			$li->appendChild( $session->make_text( $value ) );
		}
	}

	return $ul;
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_url_truncate_end( $session, $field, $value )

Hyper link the URL but truncate the end part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_url_truncate_end
{
	my( $session, $field, $value ) = @_;

	my $len = 50;	
	my $link = $session->render_link( $value );
	my $text = $value;
	if( length( $value ) > $len )
	{
		$text = substr( $value, 0, $len )."...";
	}
	$link->appendChild( $session->make_text( $text ) );
	return $link
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_url_truncate_middle( $session, $field, $value )

Hyper link the URL but truncate the middle part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_url_truncate_middle
{
	my( $session, $field, $value ) = @_;

	my $len = 50;	
	my $link = $session->render_link( $value );
	my $text = $value;
	if( length( $value ) > $len )
	{
		$text = substr( $value, 0, $len/2 )."...".substr( $value, -$len/2, -1 );
	}
	$link->appendChild( $session->make_text( $text ) );
	return $link
}

######################################################################
=pod

=item $xhtml = EPrints::Extras::render_related_url( $session, $field, $value )

Hyper link the URL but truncate the middle part if it gets longer 
than 50 characters.

=cut
######################################################################

sub render_related_url
{
	my( $session, $field, $value ) = @_;

	my $f = $field->get_property( "fields_cache" );
	my $fmap = {};	
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $field = $field->{dataset}->get_field( $fieldname );
		$fmap->{$field_conf->{sub_name}} = $field;
	}

	my $ul = $session->make_element( "ul" );
	foreach my $row ( @{$value} )
	{
		my $li = $session->make_element( "li" );
		my $link = $session->render_link( $row->{url} );
		if( defined $row->{type} )
		{
			$link->appendChild( $fmap->{type}->render_single_value( $session, $row->{type} ) );
		}
		else
		{
			my $text = $row->{url};
			if( length( $text ) > 40 ) { $text = substr( $text, 0, 40 )."..."; }
			$link->appendChild( $session->make_text( $text ) );
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
	my( $session, $field, $value ) = @_; 

	$value = "" unless defined $value;
	if( $value =~ m!^
			(?:https?://(?:dx\.)?doi\.org/)?  # add this again later anyway
			(?:doi:?\s*)?                   # don't need any namespace stuff
			(10(\.[^./]+)+/.+)              # the actual DOI => $1
		!ix )
	{
		# The only part we care about is the actual DOI.
		$value = $1;
	}
	else
	{
		# Doesn't look like a DOI we can turn into a link,
		# so just render it as-is.
		return $session->make_text( $value );
	}

	my $url = "https://doi.org/$value";
	my $link = $session->render_link( $url, "_blank" ); 
	$link->appendChild( $session->make_text( $url ) );
	return $link; 
}


######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success


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

