######################################################################
#
# EPrints::Box
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

=head1 NAME

B<EPrints::Box> - Class to render cute little Web 2.0ish boxes.

=head1 DESCRIPTION

This just provides a function to render boxes in the EPrints style.

=cut

package EPrints::Box;

use strict;

######################################################################
=pod

=item $box_xhtmldom = EPrints::Box::render( %options )

Render a cute box.

Options:

=over 4

=item session: Current $session (required)

=item id: XML ID of box (required)

=item title: XHTML DOM of title (required). Nb. Will not be cloned.

=item content: XHTML DOM of content (required). Nb. Will not be cloned.

=item collapsed: boolean. Default to false.

=item content-style: the css style to apply to the content box. For example; "overflow-y: auto; height: 300px;"

=back

=cut
######################################################################

sub EPrints::Box::render
{
	my( %options ) = @_;

	if( !defined $options{id} ) { EPrints::abort( "EPrints::Box::render called without a id. Bad bad bad." ); }
	if( !defined $options{title} ) { EPrints::abort( "EPrints::Box::render called without a title. Bad bad bad." ); }
	if( !defined $options{content} ) { EPrints::abort( "EPrints::Box::render called without a content. Bad bad bad." ); }
	if( !defined $options{session} ) { EPrints::abort( "EPrints::Box::render called without a session. Bad bad bad." ); }

	my $session = $options{session};
	my $id = $options{id};
		
	my $imagesurl = $session->get_repository->get_conf( "rel_path" );
	my $contentid = $id."_content";
	my $colbarid = $id."_colbar";
	my $barid = $id."_bar";

	my $div = $session->make_element( "div", class=>"ep_summary_box", id=>$id );

	# Title
	my $div_title = $session->make_element( "div", class=>"ep_summary_box_title" );
	$div->appendChild( $div_title );

	my $nojstitle = $session->make_element( "div", class=>"ep_no_js" );
	$nojstitle->appendChild( $session->clone_for_me( $options{title},1 ) );
	$div_title->appendChild( $nojstitle );

	my $collapse_bar = $session->make_element( "div", class=>"ep_js_only", id=>$colbarid );
	my $collapse_link = $session->make_element( "a", class=>"ep_box_collapse_link", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',true,'${id}');EPJS_toggle('${colbarid}',true);EPJS_toggle('${barid}',false);return false", href=>"#" );
	$collapse_link->appendChild( $session->make_element( "img", alt=>"-", src=>"$imagesurl/style/images/minus.png", border=>0 ) );
	$collapse_link->appendChild( $session->make_text( " " ) );
	$collapse_link->appendChild( $session->clone_for_me( $options{title},1 ) );
	$collapse_bar->appendChild( $collapse_link );
	$div_title->appendChild( $collapse_bar );
		
	my $uncollapse_bar = $session->make_element( "div", class=>"ep_js_only", id=>$barid );
	my $uncollapse_link = $session->make_element( "a", id=>$barid, class=>"ep_box_collapse_link", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',false,'${id}');EPJS_toggle('${colbarid}',true);EPJS_toggle('${barid}',false);return false", href=>"#" );
	$uncollapse_link->appendChild( $session->make_element( "img", alt=>"+", src=>"$imagesurl/style/images/plus.png", border=>0 ) );
	$uncollapse_link->appendChild( $session->make_text( " " ) );
	$uncollapse_link->appendChild( $session->clone_for_me( $options{title},1 ) );
	$uncollapse_bar->appendChild( $uncollapse_link );
	$div_title->appendChild( $uncollapse_bar );
	
	# Body	
	my $div_body = $session->make_element( "div", class=>"ep_summary_box_body", id=>$contentid );
	my $div_body_inner = $session->make_element( "div", id=>$contentid."_inner", style=>$options{content_style} );
	$div_body->appendChild( $div_body_inner );
	$div->appendChild( $div_body );
	$div_body_inner->appendChild( $options{content} );

	if( $options{collapsed} ) 
	{ 
		$collapse_bar->setAttribute( "style", "display: none" ); 
		$uncollapse_bar->setAttribute( "style", "display: block" ); 
		$div_body->setAttribute( "style", "display: none" ); 
	}
	else
	{
		$uncollapse_bar->setAttribute( "style", "display: none" ); 
		$collapse_bar->setAttribute( "style", "display: block" ); 
	}
		
	return $div;
}

1;

