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

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Box> - Class to render cute little collapsable/expandable Web 2.0ish boxes.

=head1 SYNOPSIS

	use EPrints;

	# an XHTML DOM box with a title and some content that starts rolled up.
	EPrints::Box(
		   handle => $handle,
		       id => "my_box",
		    title => $my_title_dom,
		  content => $my_content_dom,
		collapsed => 1,
	); 


=head1 DESCRIPTION

This just provides a function to render boxes in the EPrints style.

=cut

package EPrints::Box;

use strict;

######################################################################
=pod

=over 4

=item $box_xhtmldom = EPrints::Box::render( %options )

Render a collapsable/expandable box to which content can be added. The box is in keeping with the eprints style

Required Options:

=over 4

$options{handle} - Current $handle

$options{id} - ID attibute of the box i.e. <div id="my_box">

$options{title} - XHTML DOM of the title of the box. Note the exact object will be used not a clone of the object.

$options{content} - XHTML DOM of the content of the box. Note the exact object will be used not a clone of the object.

=back

Optional Options:

=over 4

%options{collapsed} - Should the box start rolled up. Default to false.

%options{content-style} - the css style to apply to the content box. For example; "overflow-y: auto; height: 300px;"

%options{show_icon_url} - the url of the icon to use instead of the [+]

%options{hide_icon_url} - the url of the icon to use instead of the [-]

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
	my $imagesurl = $session->get_repository->get_conf( "rel_path" );
	if( !defined $options{show_icon_url} ) { $options{show_icon_url} = "$imagesurl/style/images/plus.png"; }
	if( !defined $options{hide_icon_url} ) { $options{hide_icon_url} = "$imagesurl/style/images/minus.png"; }

	my $id = $options{id};
		
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

	my $collapse_bar = $session->make_element( "div", class=>"ep_only_js", id=>$colbarid );
	my $collapse_link = $session->make_element( "a", class=>"ep_box_collapse_link", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',true,'${id}');EPJS_toggle('${colbarid}',true);EPJS_toggle('${barid}',false);return false", href=>"#" );
	$collapse_link->appendChild( $session->make_element( "img", alt=>"-", src=>$options{hide_icon_url}, border=>0 ) );
	$collapse_link->appendChild( $session->make_text( " " ) );
	$collapse_link->appendChild( $session->clone_for_me( $options{title},1 ) );
	$collapse_bar->appendChild( $collapse_link );
	$div_title->appendChild( $collapse_bar );

	my $a = "true";
	my $b = "false";
	if( $options{collapsed} ) 
	{ 
		$b = "true";
		$a = "false";
	}
	my $uncollapse_bar = $session->make_element( "div", class=>"ep_only_js", id=>$barid );
	my $uncollapse_link = $session->make_element( "a", class=>"ep_box_collapse_link", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',false,'${id}');EPJS_toggle('${colbarid}',$a);EPJS_toggle('${barid}',$b);return false", href=>"#" );
	$uncollapse_link->appendChild( $session->make_element( "img", alt=>"+", src=>$options{show_icon_url}, border=>0 ) );
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
		$div_body->setAttribute( "style", "display: none" ); 
	}
	else
	{
		$uncollapse_bar->setAttribute( "style", "display: none" ); 
	}
		
	return $div;
}

1;

