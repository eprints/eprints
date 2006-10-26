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

=item $xhtml = EPrints::Extras::subject_browser_input(...)

This is an alternate input renderer for "subject" fields. It is 
intended to be passed by reference to the render_input parameter
of such a field.

Due to the way this works, it is recommended that the "subjects"
type field it is used for is by itself on the metadata input page.

=cut
######################################################################

sub subject_browser_input
{
	my( $field, $session, $value, $dataset, $type, $staff, $hidden_fields ) = @_;

	my $values;
	if( !defined $value )
	{
		$values = [];
	}
	elsif( !$field->get_property( "multiple" ) )
	{
		$values = [ $value ]; 
	}
	else
	{
		$values = $value; 
	}

	my $topsubj = $field->get_top_subject( $session );
 	my $subject = $topsubj;

	my $html = $session->make_doc_fragment;

	my $search;
	if( $session->internal_button_pressed )
	{
		my $button = $session->get_internal_button();
		my $rexp;
		$rexp = $field->get_name."_view_";
		if( $button =~ m/^$rexp(.*)$/ )
		{
			$subject = EPrints::DataObj::Subject->new( $session, $1 );
			if( !defined $subject ) 
			{ 
				$subject = $topsubj; 
			}
		}
		if( $button eq $field->get_name."_search" )
		{
			$search = $session->param( "_internal_".$field->get_name."_search" );
		}
	}

	my @param_pairs = ( "_default_action=null" );
	foreach( keys %{$hidden_fields} )
	{
		push @param_pairs, $_.'='.$hidden_fields->{$_};
	}
	my $baseurl = '?'.join( '&', @param_pairs );

	my( %bits );

	$bits{selections} = $session->make_doc_fragment;

	foreach my $s_id ( sort @{$values} )
	{
		my $s = EPrints::DataObj::Subject->new( $session, $s_id );
		next if( !defined $s );

		$html->appendChild( 
			$session->render_hidden_field(
				$field->get_name,
				$s_id ) );

		my $div = $session->make_element( "div" );
		$div->appendChild( $s->render_description );

		my $url = $baseurl.'&_internal_'.$field->get_name.'_view_'.$subject->get_id.'=1'.$field->get_name.'='.$s->get_id;
		foreach my $v ( @{$values} )
		{
			next if( $v eq $s_id );
			$url.= '&'.$field->get_name.'='.$v;
		}
		$url .= '#t';

		$div->appendChild(  $session->html_phrase(
                        "lib/extras:subject_browser_remove",
			link=>$session->make_element( "a", href=>$url ) ) );
		$bits{selections}->appendChild( $div );
	}

	if( scalar @{$values} == 0 )
	{	
		my $div = $session->make_element( "div" );
		$div->appendChild( $session->html_phrase(
			"lib/extras:subject_browser_none" ) );
		$bits{selections}->appendChild( $div );
	}

	my @paths = $subject->get_paths( $session );
	my %expanded = ();
	foreach my $path ( @paths )
	{
		my $div = $session->make_element( "div" );
		my $first = 1;
		foreach my $s ( @{$path} )
		{
			$expanded{$s->get_id}=1;
		}
		$bits{selections}->appendChild( $div );
	}	

	$bits{search} = $session->html_phrase(
			"lib/extras:subject_browser_search",
			input=>$session->make_element( "input", name=>"_internal_".$field->get_name."_search" ),
			button=>$session->make_element( "input", type=>"submit", name=>"_null", 
				value=>$session->phrase( "lib/extras:subject_browser_search_button" ) ) );
	$bits{topsubj} = $topsubj->render_description;

	if( defined $search ) 
	{
		my $subject_ds = $session->get_repository->get_dataset( "subject" );

		my $searchexp = new EPrints::Search(
			session=>$session,
			dataset=>$subject_ds );
	
		$searchexp->add_field(
			$subject_ds->get_field( "name" ),
			$search,
			"IN",
			"ALL" );
		$searchexp->add_field(
			$subject_ds->get_field( "ancestors" ),
			$topsubj->get_id,
			"EQ" );

		my $searchid = $searchexp->perform_search;

		my @records = $searchexp->get_records;
		$searchexp->dispose();

		my $results;
		if( scalar @records )
		{
			$results = $session->make_element( "ul" );
			foreach my $s ( @records )
			{
				$results->appendChild( 
					_subject_browser_input_aux(
						$field,
						$session,
						$s,
						$subject,
						\%expanded,
						$baseurl,
						$values ) );
			}
		}	
		else
		{
			$results = $session->html_phrase( 
                        "lib/extras:subject_browser_no_matches" );
		}

		my $url = $baseurl.'&_internal_'.$field->get_name.'_view_'.$subject->get_id.'=1'.$field->get_name.'='.$subject->get_id;
		foreach my $v ( @{$values} )
		{
			$url.= '&'.$field->get_name.'='.$v;
		}
		$url .= '#t';

		$bits{opts} = $session->html_phrase( 
			"lib/extras:subject_browser_search_results", 
			results=>$results,
			browse=>$session->render_link( $url ) );
	}
	else
	{	
		my $ul = $session->make_element( "ul" );
		foreach my $s ( $topsubj->get_children() )
		{
			$ul->appendChild( 
				_subject_browser_input_aux( 
					$field,
					$session,
					$s,
					$subject,
					\%expanded,
					$baseurl,
					$values ) );
		}
		$bits{opts} = $ul;
	}

	$html->appendChild( $session->html_phrase( 
			"lib/extras:subject_browser",
			%bits ) );

	return $html;
}


sub _subject_browser_input_aux
{
	my( $field, $session, $subject, $current_subj, $expanded, $baseurl, $values ) = @_;

	my $addurl = $baseurl;
	foreach my $v ( @{$values} )
	{
		$addurl.= '&'.$field->get_name.'='.$v;
	}

	my $li = $session->make_element( "li" );

	my $n_kids = scalar $subject->get_children();
	my $exp = 0;
	if( $n_kids > 0 )
	{
		if( $expanded->{$subject->get_id} )
		#if( $expanded->{$subject->get_id} || $n_kids < 3)
		{
			$exp = 1;
		}
		else
		{
			$exp = -1;
		}
	}
	my $selected = 0;
	foreach my $v ( @{$values} )
	{
		$selected = 1 if( $v eq $subject->get_id );
	}
	if( $exp == -1 )
	{
		my $url = $addurl.'&_internal_'.$field->get_name.'_view_'.$subject->get_id.'=1#t';
		my $a = $session->make_element( "a", href=>$url );
		$a->appendChild( $subject->render_description );
		$li->appendChild( $a );
		$li->appendChild( $session->html_phrase(
                       	"lib/extras:subject_browser_expandable" ) );
	}
	else
	{
		my $span = $session->make_element( 
			"span", 
			class=>"subject_browser_".($selected?"":"un")."selected" );
		$span->appendChild( $subject->render_description );
		$li->appendChild( $span );
	}
	if( $subject->can_post && $exp != -1 && !$selected )
	{
		my $ibutton = '_internal_'.$field->get_name.'_view_'.$current_subj->get_id.'=1';
		if( $session->internal_button_pressed )
		{
			my $intact = '_internal_'.$session->get_internal_button();
			$ibutton = $intact.'='.$session->param( $intact );
		}

		my $url = $addurl.'&'.$ibutton.'&'.$field->get_name.'='.$subject->get_id.'#t';
		$li->appendChild(  $session->html_phrase(
                       	"lib/extras:subject_browser_add",
			link=>$session->make_element( "a", href=>$url ) ) );
	}
	if( $exp == 1 )
	{
		$li->appendChild( $session->make_element( "br" ));

		my $ul = $session->make_element( "ul" );
		foreach my $s ( $subject->get_children() )
		{
				$ul->appendChild( _subject_browser_input_aux(
					$field,
					$session, 
					$s, 
					$current_subj,
					$expanded, 
					$baseurl,
					$values ) );
		}
		$li->appendChild( $ul );
	}

	return $li;
}


######################################################################
=pod

=item $xhtml = EPrints::Extras::render_xhtml_field( $session, $field,
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
	my( $session , $field , $value ) = @_;

	if( !defined $value ) { return $session->make_doc_fragment; }
        my( %c ) = (
                ParseParamEnt => 0,
                ErrorContext => 2,
                NoLWP => 1 );

        my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".$value."</fragment>" ); };
        if( $@ )
        {
                my $err = $@;
                $err =~ s# at /.*##;
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( "Error parsing XML: ".$err ) );
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


######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

