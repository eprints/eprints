######################################################################
#
# EPrints::Handle::Render
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Handle::Render> - Render methods for EPrints::Session

=head1 DESCRIPTION

This module provides additional methods to EPrints::Handle and is not
an object in its own right.

Look at EPrints::Handle for further information on how to access the 
Handle methods.

=head1 SYNOPSIS

	# create a simple <a> element:
	my $link = $handle->render_link( "http://www.eprints.org/", "_blank" );
	$link->appendChild( 
		$handle->make_text( "Visit the EPrints website" ) );

	# create a POST form on the current cgi script:	
	my $form = $handle->render_form( "POST" );
	$form->appendChild( 
		$handle->render_hidden_field( 
			"eprintid", 
			$eprint->get_id ) );
	$form->appendChild( 
		$handle->render_input_field( 
			"name" => "ep_input_text", 
			"id" => "ep_input_text" ) );
	$form->appendChild( 
		$handle->render_button( 
			"name" => "action_submit" ) );

	# create a message in the EPrints Screen style:
	$page->appendChild( 
		$handle->render_message( 
			"error", 
			$handle->make_text( "Error description" ), 
			1 ) );	

	# create a Toolbox in the EPrints style:	
	$page->appendChild( 
		$handle->render_toolbox( $title, $content ) );

=head1 METHODS

=cut

use strict;

package EPrints::Handle;



######################################################################
=pod

=over 4

=item $ruler = $handle->render_ruler

Return an <hr/> element. Look in ruler.xml for style definition.

=cut
######################################################################

sub render_ruler
{
	my( $self ) = @_;

	return $self->html_phrase( "ruler" );
}

######################################################################
=pod

=item $nbsp = $handle->render_nbsp

Return an XHTML &nbsp; character.

=cut
######################################################################

sub render_nbsp
{
	my( $self ) = @_;

	my $string = pack("U",160);

	return $self->make_text( $string );
}

######################################################################
=pod

=item $xhtml = $handle->render_data_element( $indent, $elementname, $value, [%opts] )

This is used to help render neat XML data. It returns a fragment 
containing an element of name $elementname containing the value
$value, the element is indented by $indent spaces.

The %opts describe any extra attributes for the element

eg.
$handle->render_data_element( 4, "foo", "bar", class=>"fred" )

would return a XML DOM object describing:
    <foo class="fred">bar</foo>

=cut
######################################################################

sub render_data_element
{
	my( $self, $indent, $elementname, $value, %opts ) = @_;

	my $f = $self->make_doc_fragment();
	my $el = $self->make_element( $elementname, %opts );
	$el->appendChild( $self->make_text( $value ) );
	$f->appendChild( $self->make_indent( $indent ) );
	$f->appendChild( $el );

	return $f;
}


######################################################################
=pod

=item $xhtml = $handle->render_link( $uri, [$target] )

Returns an HTML link to the given uri, with the optional $target if
it needs to point to a different frame or window.

=cut
######################################################################

sub render_link
{
	my( $self, $uri, $target ) = @_;

	return $self->make_element(
		"a",
		href=>$uri,
		target=>$target );
}

######################################################################
=pod

=item $table_row = $handle->render_row( $key, @values );

Return the key and values in a DOM encoded HTML table row. eg.

 <tr><th>$key:</th><td>$value[0]</td><td>...</td></tr>

=cut
######################################################################

sub render_row
{
	my( $handle, $key, @values ) = @_;

	my( $tr, $th, $td );

	$tr = $handle->make_element( "tr" );

	$th = $handle->make_element( "th", valign=>"top", class=>"ep_row" ); 
	if( !defined $key )
	{
		$th->appendChild( $handle->render_nbsp );
	}
	else
	{
		$th->appendChild( $key );
		$th->appendChild( $handle->make_text( ":" ) );
	}
	$tr->appendChild( $th );

	foreach my $value ( @values )
	{
		$td = $handle->make_element( "td", valign=>"top", class=>"ep_row" ); 
		$td->appendChild( $value );
		$tr->appendChild( $td );
	}

	return $tr;
}

# parts...
#
#        help: dom of help text
#       label: dom title of row (to go in <th>)
#       class: class for <tr>
#       field: dom content for <td>
# help_prefix: prefix for id tag of help toggle
#   no_toggle: if true, renders the help always on with no toggle
#     no_help: don't actually render help or a toggle (for rendering same styled rows in the same table)

sub render_row_with_help
{
	my( $self, %parts ) = @_;

	if( defined $parts{help} && EPrints::XML::is_empty( $parts{help} ) )
	{
		delete $parts{help};
	}


	my $tr = $self->make_element( "tr", class=>$parts{class} );

	#
	# COL 1
	#
	my $th = $self->make_element( "th", class=>"ep_multi_heading" );
	$th->appendChild( $parts{label} );
	$th->appendChild( $self->make_text( ":" ) );
	$tr->appendChild( $th );

	if( !defined $parts{help} || $parts{no_help} )
	{
		my $td = $self->make_element( "td", class=>"ep_multi_input", colspan=>"2" );
		$tr->appendChild( $td );
		$td->appendChild( $parts{field} );
		return $tr;
	}

	#
	# COL 2
	#
	
	my $inline_help_class = "ep_multi_inline_help";
	my $colspan = "2";
	if( !$parts{no_toggle} ) 
	{ 
		# ie, yes to toggle
		$inline_help_class .= " ep_no_js"; 
		$colspan = 1;
	}

	my $td = $self->make_element( "td", class=>"ep_multi_input", colspan=>$colspan, id=>$parts{help_prefix}."_outer" );
	$tr->appendChild( $td );

	my $inline_help = $self->make_element( "div", id=>$parts{help_prefix}, class=>$inline_help_class );
	my $inline_help_inner = $self->make_element( "div", id=>$parts{help_prefix}."_inner" );
	$inline_help->appendChild( $inline_help_inner );
	$inline_help_inner->appendChild( $parts{help} );
	$td->appendChild( $inline_help );

	$td->appendChild( $parts{field} );

	if( $parts{no_toggle} ) 
	{ 
		return $tr;
	}
		
	#
	# COL 3
	# help toggle
	#

	my $td2 = $self->make_element( "td", class=>"ep_multi_help ep_only_js_table_cell ep_toggle" );
	my $show_help = $self->make_element( "div", class=>"ep_sr_show_help ep_only_js", id=>$parts{help_prefix}."_show" );
	my $helplink = $self->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlide('$parts{help_prefix}',false,'block');EPJS_toggle('$parts{help_prefix}_hide',false,'block');EPJS_toggle('$parts{help_prefix}_show',true,'block');return false", href=>"#" );
	$show_help->appendChild( $self->html_phrase( "lib/session:show_help",link=>$helplink ) );
	$td2->appendChild( $show_help );

	my $hide_help = $self->make_element( "div", class=>"ep_sr_hide_help ep_hide", id=>$parts{help_prefix}."_hide" );
	my $helplink2 = $self->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlide('$parts{help_prefix}',false,'block');EPJS_toggle('$parts{help_prefix}_hide',false,'block');EPJS_toggle('$parts{help_prefix}_show',true,'block');return false", href=>"#" );
	$hide_help->appendChild( $self->html_phrase( "lib/session:hide_help",link=>$helplink2 ) );
	$td2->appendChild( $hide_help );
	$tr->appendChild( $td2 );

	return $tr;
}


# called by dynamic_template.pl
sub render_toolbar
{
	my( $self ) = @_;

	my $screen_processor = bless {
		handle => $self,
		screenid => "FirstTool",
	}, "EPrints::ScreenProcessor";

	my $screen = $screen_processor->screen;
	$screen->properties_from; 

	my $toolbar = $self->make_element( "span", class=>"ep_toolbar" );
	my $core = $self->make_element( "span", id=>"ep_user_menu_core" );
	$toolbar->appendChild( $core );

	my @core = $screen->list_items( "key_tools" );
	my @other = $screen->list_items( "other_tools" );
	my $url = $self->get_repository->get_conf( "http_cgiurl" )."/users/home";

	my $first = 1;
	foreach my $tool ( @core )
	{
		if( $first )
		{
			$first = 0;
		}
		else
		{
			$core->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );
		}
		my $a = $self->render_link( $url."?screen=".substr($tool->{screen_id},8) );
		$a->appendChild( $tool->{screen}->render_title );
		$core->appendChild( $a );
	}

	my $current_user = $self->current_user;

	if( defined $current_user && $current_user->allow( "config/edit/static" ) )
	{
		my $conffile = $self->get_static_page_conf_file;
		if( defined $conffile )
		{
			if( !$first )
			{
				$core->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );
			}
			$first = 0;
			
			# Will do odd things for non xpages
			my $a = $self->render_link( $url."?screen=Admin::Config::Edit::XPage&configfile=".$conffile );
			$a->appendChild( $self->html_phrase( "lib/session:edit_page" ) );
			$core->appendChild( $a );
		}
	}

	if( defined $current_user && $current_user->allow( "config/edit/phrase" ) )
	{
		if( !$self->{preparing_static_page} )
		{
			if( !$first )
			{
				$core->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );
			}
			$first = 0;

			my $editurl = $self->get_full_url;
			if( $editurl =~ m/\?/ )
			{
				$editurl .= "&edit_phrases=yes";
			}
			else	
			{
				$editurl .= "?edit_phrases=yes";
			}

			# Will do odd things for non xpages
			my $a = $self->render_link( $editurl );
			$a->appendChild( $self->html_phrase( "lib/session:edit_phrases" ) );
			$core->appendChild( $a );
		}
	}

	if( scalar @other == 1 )
	{
		$core->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );	
		my $tool = $other[0];
		my $a = $self->render_link( $url."?screen=".substr($tool->{screen_id},8) );
		$a->appendChild( $tool->{screen}->render_title );
		$core->appendChild( $a );
	}
	elsif( scalar @other > 1 )
	{
		my $span = $self->make_element( "span", id=>"ep_user_menu_extra", class=>"ep_no_js_inline" );
		$toolbar->appendChild( $span );

		my $nojs_divide = $self->make_element( "span", class=>"ep_no_js_inline" );
		$nojs_divide->appendChild( 
			$self->html_phrase( "Plugin/Screen:tool_divide" ) );
		$span->appendChild( $nojs_divide );
		
		my $more_bit = $self->make_element( "span", class=>"ep_only_js" );
		my $more = $self->make_element( "a", id=>"ep_user_menu_more", href=>"#", onclick => "EPJS_blur(event); EPJS_toggle_type('ep_user_menu_core',true,'inline');EPJS_toggle_type('ep_user_menu_extra',false,'inline');return false", );
		$more->appendChild( $self->html_phrase( "Plugin/Screen:more" ) );
		$more_bit->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );	
		$more_bit->appendChild( $more );
		$toolbar->appendChild( $more_bit );

		$first = 1;
		foreach my $tool ( @other )
		{
			if( $first )
			{
				$first = 0;
			}
			else
			{
				$span->appendChild( 
					$self->html_phrase( "Plugin/Screen:tool_divide" ) );
			}
			my $a = $self->render_link( $url."?screen=".substr($tool->{screen_id},8) );
			$a->appendChild( $tool->{screen}->render_title );
			$span->appendChild( $a );
		}
	
	}
		
	return $toolbar;
}


######################################################################
=pod

=item $xhtml = $handle->render_language_name( $langid ) 
Return a DOM object containing the description of the specified language
in the current default language, or failing that from languages.xml

=cut
######################################################################

sub render_language_name
{
	my( $self, $langid ) = @_;

	my $phrasename = 'languages_typename_'.$langid;

	return $self->html_phrase( $phrasename );
}

######################################################################
=pod

=item $xhtml = $handle->render_type_name( $type_set, $type ) 

Return a DOM object containing the description of the specified type
in the type set. eg. "eprint", "article"

=cut
######################################################################

sub render_type_name
{
	my( $self, $type_set, $type ) = @_;

        return $self->html_phrase( $type_set."_typename_".$type );
}

######################################################################
=pod

=item $string = $handle->get_type_name( $type_set, $type ) 

As above, but return a utf-8 string. Used in <option> elements, for
example.

=cut
######################################################################

sub get_type_name
{
	my( $self, $type_set, $type ) = @_;

        return $self->phrase( $type_set."_typename_".$type );
}

######################################################################
=pod

=item $xhtml_name = $handle->render_name( $name, [$familylast] )

$name is a ref. to a hash containing family, given etc.

Returns an XML DOM fragment with the name rendered in the manner
of the repository. Usually "John Smith".

If $familylast is set then the family and given parts are reversed, eg.
"Smith, John"

=cut
######################################################################

sub render_name
{
	my( $self, $name, $familylast ) = @_;

	my $namestr = EPrints::Utils::make_name_string( $name, $familylast );

	my $span = $self->make_element( "span", class=>"person_name" );
		
	$span->appendChild( $self->make_text( $namestr ) );

	return $span;
}

######################################################################
#=pod
#
#=item $xhtml_select = $handle->render_option_list( %params )
#
#This method renders an XHTML <select>. The options are complicated
#and may change, so it's better not to use it.
#
#=cut
######################################################################

sub render_option_list
{
	my( $self , %params ) = @_;

	#params:
	# default  : array or scalar
	# height   :
	# multiple : allow multiple selections
	# pairs    :
	# values   :
	# labels   :
	# name     :
	# checkbox :
	# defaults_at_top : move items already selected to top
	# 			of list, so they are visible.

	my %defaults = ();
	if( ref( $params{default} ) eq "ARRAY" )
	{
		foreach( @{$params{default}} )
		{
			$defaults{$_} = 1;
		}
	}
	elsif( defined $params{default} )
	{
		$defaults{$params{default}} = 1;
	}


	my $dtop = defined $params{defaults_at_top} && $params{defaults_at_top};


	my @alist = ();
	my @list = ();
	my $pairs = $params{pairs};
	if( !defined $pairs )
	{
		foreach( @{$params{values}} )
		{
			push @{$pairs}, [ $_, $params{labels}->{$_} ];
		}
	}		
						
	if( $dtop && scalar keys %defaults )
	{
		my @pairsa;
		my @pairsb;
		foreach my $pair (@{$pairs})
		{
			if( $defaults{$pair->[0]} )
			{
				push @pairsa, $pair;
			}
			else
			{
				push @pairsb, $pair;
			}
		}
		$pairs = [ @pairsa, [ '-', '----------' ], @pairsb ];
	}

	if( $params{checkbox} )
	{
		my $table = $self->make_element( "table", cellspacing=>"10", border=>"0", cellpadding=>"0" );
		my $tr = $self->make_element( "tr" );
		$table->appendChild( $tr );	
		my $td = $self->make_element( "td", valign=>"top" );
		$tr->appendChild( $td );	
		my $i = 0;
		my $len = scalar @$pairs;
		foreach my $pair ( @{$pairs} )
		{
			my $div = $self->make_element( "div" );
			my $label = $self->make_element( "label" );
			$div->appendChild( $label );
			my $box = $self->render_input_field( type=>"checkbox", name=>$params{name}, value=>$pair->[0], class=>"ep_form_checkbox" );
			$label->appendChild( $box );
			$label->appendChild( $self->make_text( " ".$pair->[1] ) );
			if( $defaults{$pair->[0]} )
			{
				$box->setAttribute( "checked" , "checked" );
			}
			$td->appendChild( $div );
			++$i;
			if( $len > 5 && int($len / 2)==$i )
			{
				$td = $self->make_element( "td", valign=>"top" );
				$tr->appendChild( $td );	
			}
		}
		return $table;
	}
		


	my $element = $self->make_element( "select" , name => $params{name}, id => $params{name} );
	if( $params{multiple} )
	{
		$element->setAttribute( "multiple" , "multiple" );
	}
	my $size = 0;
	foreach my $pair ( @{$pairs} )
	{
		$element->appendChild( 
			$self->render_single_option(
				$pair->[0],
				$pair->[1],
				$defaults{$pair->[0]} ) );
		$size++;
	}
	if( defined $params{height} )
	{
		if( $params{height} ne "ALL" )
		{
			if( $params{height} < $size )
			{
				$size = $params{height};
			}
		}
		$element->setAttribute( "size" , $size );
	}
	return $element;
}



######################################################################
#=pod
#
#=item $option = $handle->render_single_option( $key, $desc, $selected )
#
#Used by render_option_list.
#
#=cut
######################################################################

sub render_single_option
{
	my( $self, $key, $desc, $selected ) = @_;

	my $opt = $self->make_element( "option", value => $key );
	$opt->appendChild( $self->make_text( $desc ) );

	if( $selected )
	{
		$opt->setAttribute( "selected" , "selected" );
	}
	return $opt;
}


######################################################################
=pod

=item $xhtml_hidden = $handle->render_hidden_field( $name, $value )

Return the XHTML DOM describing an <input> element of type "hidden"
and name and value as specified. eg.

<input type="hidden" name="foo" value="bar" />

=cut
######################################################################

sub render_hidden_field
{
	my( $self , $name , $value ) = @_;

	if( !defined $value ) 
	{
		$value = $self->param( $name );
	}

	return $self->render_input_field( 
		name => $name,
		id => $name,
		value => $value,
		type => "hidden" );
}

######################################################################
=pod

=item $xhtml_input = $handle->render_input_field( %opts )

Return the XHTML DOM describing a generic <input> element

=cut
######################################################################
sub render_input_field
{
	my( $self, @opts ) = @_;

	return $self->make_element( "input", @opts );
}

######################################################################
=pod

=item $xhtml_input = $handle->render_noenter_input_field( %opts )

Return the XHTML DOM describing a generic <input> element. The form
will not be submitted when the user presses Enter.

=cut
######################################################################
sub render_noenter_input_field
{
	my( $self, @opts ) = @_;

	return $self->make_element( "input",
		onKeyPress => "return EPJS_block_enter( event )",
		@opts,
	);
}


######################################################################
=pod

=item $xhtml_uploda = $handle->render_upload_field( $name )

Render into XHTML DOM a file upload form button with the given name. 

eg.
<input type="file" name="foo" />

=cut
######################################################################

sub render_upload_field
{
	my( $self, $name ) = @_;

#	my $div = $self->make_element( "div" ); #no class cjg	
#	$div->appendChild( $self->make_element(
#		"input", 
#		name => $name,
#		type => "file" ) );
#	return $div;

	return $self->render_noenter_input_field(
		name => $name,
		type => "file" );

}


######################################################################
=pod

=item $dom = $handle->render_action_buttons( %buttons )

Returns a DOM object describing the set of buttons.

The keys of %buttons are the ids of the action that button will cause,
the values are UTF-8 text that should appear on the button.

Two optional additional keys may be used:

_order => [ "action1", "action2" ]

will force the buttons to appear in a set order.

_class => "my_css_class" 

will add a class attribute to the <div> containing the buttons to 
allow additional styling.

=cut
######################################################################

sub render_action_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "action" , %buttons );
}


######################################################################
=pod

=item $dom = $handle->render_internal_buttons( %buttons )

As for render_action_buttons, but creates buttons for actions which
will modify the state of the current form, not continue with whatever
process the form is part of.

eg. the "More Spaces" button and the up and down arrows on multiple
type fields.

=cut
######################################################################

sub render_internal_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "internal" , %buttons );
}


######################################################################
# 
# $dom = $handle->_render_buttons_aux( $btype, %buttons )
#
######################################################################

sub _render_buttons_aux
{
	my( $self, $btype, %buttons ) = @_;

	#my $frag = $self->make_doc_fragment();
	my $class = "";
	if( defined $buttons{_class} )
	{
		$class = $buttons{_class};
	}
	my $div = $self->make_element( "div", class=>$class );

	my @order = keys %buttons;
	if( defined $buttons{_order} )
	{
		@order = @{$buttons{_order}};
	}

	my $button_id;
	foreach $button_id ( @order )
	{
		# skip options which start with a "_" they are params
		# not buttons.
		next if( $button_id eq '_class' );
		next if( $button_id eq '_order' );
		$div->appendChild(
			$self->render_button( 
				name => "_".$btype."_".$button_id, 
				class => "ep_form_".$btype."_button",
				value => $buttons{$button_id} ) );

		# Some space between butons.
		$div->appendChild( $self->make_text( " " ) );
	}

	return( $div );
}

sub render_button
{
	my( $self, %opts ) = @_;

	if( !defined $opts{onclick} )
	{
		$opts{onclick} = "return EPJS_button_pushed( '$opts{name}' )";	
	}
	
	if( !defined $opts{class} )
	{
		$opts{class} = "ep_form_action_button";
	}
	$opts{type} = "submit";

	return $self->make_element( "input", %opts );
}

######################################################################
=pod

=item $dom = $handle->render_form( $method, $dest )

Return a DOM object describing an HTML form element. 

$method should be "get" or "post"

$dest is the target of the form. By default the current page.

eg.

$handle->render_form( "GET", "http://example.com/cgi/foo" );

returns a DOM object representing:

<form method="get" action="http://example.com/cgi/foo" accept-charset="utf-8" />

If $method is "post" then an addition attribute is set:
enctype="multipart/form-data" 

This just controls how the data is passed from the browser to the
CGI library. You don't need to worry about it.

=cut
######################################################################

sub render_form
{
	my( $self, $method, $dest ) = @_;
	
	my $form = $self->{doc}->createElement( "form" );
	$form->setAttribute( "method", "\L$method" );
	$form->setAttribute( "accept-charset", "utf-8" );
	if( !defined $dest )
	{
		$dest = $self->get_uri;
	}
	$form->setAttribute( "action", $dest );
	if( "\L$method" eq "post" )
	{
		$form->setAttribute( "enctype", "multipart/form-data" );
	}
	return $form;
}


######################################################################
=pod

=item $ul = $handle->render_subjects( $subject_list, [$baseid], [$currentid], [$linkmode], [$sizes] )

Return as XHTML DOM a nested set of <ul> and <li> tags describing
part of a subject tree.

$subject_list is a array ref of subject ids to render.

$baseid is top top level node to render the tree from. If only a single
subject is in subject_list, all subjects up to $baseid will still be
rendered. Default is the ROOT element.

If $currentid is set then the subject with that ID is rendered in
<strong>

$linkmode can 0, 1, 2 or 3.

0. Don't link the subjects.

1. Links subjects to the URL which edits them in edit_subjects.

2. Links subjects to "subjectid.html" (where subjectid is the id of 
the subject)

3. Links the subjects to "subjectid/".  $sizes must be set. Only 
subjects with a size of more than one are linked.

4. Links the subjects to "../subjectid/".  $sizes must be set. Only 
subjects with a size of more than one are linked.

$sizes may be a ref. to hash mapping the subjectid's to the number
of items in that subject which will be rendered in brackets next to
each subject.

=cut
######################################################################

sub render_subjects
{
	my( $self, $subject_list, $baseid, $currentid, $linkmode, $sizes ) = @_;

	# If sizes is defined then it contains a hash subjectid->#of subjects
	# we don't do this ourselves.

#cjg NO SUBJECT_LIST = ALL SUBJECTS under baseid!
	if( !defined $baseid )
	{
		$baseid = $EPrints::DataObj::Subject::root_subject;
	}

	my %subs = ();
	foreach( @{$subject_list}, $baseid )
	{
		$subs{$_} = EPrints::DataObj::Subject->new( $self, $_ );
	}

	return $self->_render_subjects_aux( \%subs, $baseid, $currentid, $linkmode, $sizes );
}

######################################################################
# 
# $ul = $handle->_render_subjects_aux( $subjects, $id, $currentid, $linkmode, $sizes )
#
# Recursive subroutine needed by render_subjects.
#
######################################################################

sub _render_subjects_aux
{
	my( $self, $subjects, $id, $currentid, $linkmode, $sizes ) = @_;

	my( $ul, $li, $elementx );
	$ul = $self->make_element( "ul" );
	$li = $self->make_element( "li" );
	$ul->appendChild( $li );
	if( defined $currentid && $id eq $currentid )
	{
		$elementx = $self->make_element( "strong" );
	}
	else
	{
		if( $linkmode == 1 )
		{
			$elementx = $self->render_link( "?screen=Subject::Edit&subjectid=".$id ); 
		}
		elsif( $linkmode == 2 )
		{
			$elementx = $self->render_link( 
				EPrints::Utils::escape_filename( $id ).
					".html" ); 
		}
		elsif( $linkmode == 3 )
		{
			$elementx = $self->render_link( 
				EPrints::Utils::escape_filename( $id )."/" ); 
		}
		elsif( $linkmode == 4 )
		{
			$elementx = $self->render_link( 
				"../".EPrints::Utils::escape_filename( $id )."/" ); 
		}
		else
		{
			$elementx = $self->make_element( "span" );
		}
	}
	$li->appendChild( $elementx );
	$elementx->appendChild( $subjects->{$id}->render_description() );
	if( defined $sizes && defined $sizes->{$id} && $sizes->{$id} > 0 )
	{
		$li->appendChild( $self->make_text( " (".$sizes->{$id}.")" ) );
	}
		
	foreach( $subjects->{$id}->get_children() )
	{
		my $thisid = $_->get_value( "subjectid" );
		next unless( defined $subjects->{$thisid} );
		$li->appendChild( $self->_render_subjects_aux( $subjects, $thisid, $currentid, $linkmode, $sizes ) );
	}
	
	return $ul;
}



######################################################################
=pod

=item $handle->render_error( $error_text, $back_to, $back_to_text )

Renders an error page with the given error text. A link, with the
text $back_to_text, is offered, the destination of this is $back_to,
which should take the user somewhere sensible.

=cut
######################################################################

sub render_error
{
	my( $self, $error_text, $back_to, $back_to_text ) = @_;
	
	if( !defined $back_to )
	{
		$back_to = $self->get_repository->get_conf( "frontpage" );
	}
	if( !defined $back_to_text )
	{
		$back_to_text = $self->html_phrase( "lib/session:continue");
	}

	my $textversion = '';
	$textversion.= $self->phrase( "lib/session:some_error" );
	$textversion.= EPrints::Utils::tree_to_utf8( $error_text, 76 );
	$textversion.= "\n";

	if ( $self->{offline} )
	{
		print $textversion;
		return;
	} 

	# send text version to log
	$self->get_repository->log( $textversion );

	my( $p, $page, $a );
	$page = $self->make_doc_fragment();

	$page->appendChild( $self->html_phrase( "lib/session:some_error"));

	$p = $self->make_element( "p" );
	$p->appendChild( $error_text );
	$page->appendChild( $p );

	$page->appendChild( $self->html_phrase( "lib/session:contact" ) );
				
	$p = $self->make_element( "p" );
	$a = $self->render_link( $back_to ); 
	$a->appendChild( $back_to_text );
	$p->appendChild( $a );
	$page->appendChild( $p );
	$self->prepare_page(	
		title=>$self->html_phrase( "lib/session:error_title" ),
		page=>$page,
		page_id=>"error" );

	$self->send_page();
}

my %INPUT_FORM_DEFAULTS = (
	dataset => undef,
	type	=> undef,
	fields => [],
	values => {},
	show_names => 0,
	show_help => 0,
	staff => 0,
	buttons => {},
	hidden_fields => {},
	comments => {},
	dest => undef,
	default_action => undef
);


######################################################################
=pod

=item $dom = $handle->render_input_form( %params )

Return a DOM object representing an entire input form.

%params contains the following options:

dataset: The EPrints::Dataset to which the form relates, if any.

fields: a reference to an array of EPrint::MetaField objects,
which describe the fields to be added to the form.

values: a set of default values. A reference to a hash where
the keys are ID's of fields, and the values are the default
values for those fields.

show_help: if true, show the fieldhelp phrase for each input 
field.

show_name: if true, show the fieldname phrase for each input 
field.

buttons: a description of the buttons to appear at the bottom
of the form. See render_action_buttons for details.

top_buttons: a description of the buttons to appear at the top
of the form (optional).

default_action: the id of the action to be performed by default, 
ie. if the user pushes "return" in a text field.

dest: The URL of the target for this form. If not defined then
the current URI is used.

type: if this form relates to a user or an eprint, the type of
eprint/user can effect what fields are flagged as required. This
param contains the ID of the eprint/user if any, and if relevant.

staff: if true, this form is being presented to repository staff 
(admin, or editor). This may change which fields are required.

hidden_fields: reference to a hash. The keys of which are CGI keys
and the values are the values they are set to. This causes hidden
form elements to be set, so additional information can be passed.

object: The DataObj which this form is editing, if any.

comment: not yet used.

=cut
######################################################################

sub render_input_form
{
	my( $self, %p ) = @_;

	foreach( keys %INPUT_FORM_DEFAULTS )
	{
		next if( defined $p{$_} );
		$p{$_} = $INPUT_FORM_DEFAULTS{$_};
	}

	my( $form );

	$form =	$self->render_form( "post", $p{dest} );
	if( defined $p{default_action} && $self->client() ne "LYNX" )
	{
		my $imagesurl = $self->get_repository->get_conf( "rel_path" )."/images";
		# This button will be the first on the page, so
		# if a user hits return and the browser auto-
		# submits then it will be this image button, not
		# the action buttons we look for.

		# It should be a small white on pixel PNG.
		# (a transparent GIF would be slightly better, but
		# GNU has a problem with GIF).
		# The style stops it rendering on modern broswers.
		# under lynx it looks bad. Lynx does not
		# submit when a user hits return so it's 
		# not needed anyway.
		$form->appendChild( $self->make_element( 
			"input", 
			type => "image", 
			width => 1, 
			height => 1, 
			border => 0,
			style => "display: none",
			src => "$imagesurl/whitedot.png",
			name => "_default", 
			alt => $p{buttons}->{$p{default_action}} ) );
		$form->appendChild( $self->render_hidden_field(
			"_default_action",
			$p{default_action} ) );
	}

	if( defined $p{top_buttons} )
	{
		$form->appendChild( $self->render_action_buttons( %{$p{top_buttons}} ) );
	}

	my $field;	
	foreach $field (@{$p{fields}})
	{
		$form->appendChild( $self->_render_input_form_field( 
			$field,
			$p{values}->{$field->get_name()},
			$p{show_names},
			$p{show_help},
			$p{comments}->{$field->get_name()},
			$p{dataset},
			$p{type},
			$p{staff},
			$p{hidden_fields},
			$p{object} ) );
	}

	# Hidden field, so caller can tell whether or not anything's
	# been POSTed
	$form->appendChild( $self->render_hidden_field( "_seen", "true" ) );

	foreach (keys %{$p{hidden_fields}})
	{
		$form->appendChild( $self->render_hidden_field( 
					$_, 
					$p{hidden_fields}->{$_} ) );
	}
	if( defined $p{comments}->{above_buttons} )
	{
		$form->appendChild( $p{comments}->{above_buttons} );
	}

	$form->appendChild( $self->render_action_buttons( %{$p{buttons}} ) );

	return $form;
}


######################################################################
# 
# $xhtml_field = $handle->_render_input_form_field( $field, $value, $show_names, $show_help, $comment, $dataset, $type, $staff, $hiddenfields, $object )
#
# Render a single field in a form being rendered by render_input_form
#
######################################################################

sub _render_input_form_field
{
	my( $self, $field, $value, $show_names, $show_help, $comment,
			$dataset, $type, $staff, $hidden_fields , $object) = @_;
	
	my( $div, $html, $span );

	$html = $self->make_doc_fragment();

	if( substr( $self->get_internal_button(), 0, length($field->get_name())+1 ) eq $field->get_name()."_" ) 
	{
		my $a = $self->make_element( "a", name=>"t" );
		$html->appendChild( $a );
	}

	my $req = $field->get_property( "required" );

	if( $show_names )
	{
		$div = $self->make_element( "div", class => "ep_form_field_name" );

		# Field name should have a star next to it if it is required
		# special case for booleans - even if they're required it
		# dosn't make much sense to highlight them.	

		my $label = $field->render_name( $self );
		if( $req && !$field->is_type( "boolean" ) )
		{
			$label = $self->html_phrase( "sys:ep_form_required",
				label=>$label );
		}
		$div->appendChild( $label );

		$html->appendChild( $div );
	}

	if( $show_help )
	{
		$div = $self->make_element( "div", class => "ep_form_field_help" );

		$div->appendChild( $field->render_help( $self, $type ) );
		$div->appendChild( $self->make_text( "" ) );

		$html->appendChild( $div );
	}

	$div = $self->make_element( 
		"div", 
		class => "ep_form_field_input",
		id => "inputfield_".$field->get_name );
	$div->appendChild( $field->render_input_field( 
		$self, $value, $dataset, $staff, $hidden_fields , $object ) );
	$html->appendChild( $div );
				
	return( $html );
}	

######################################################################
# 
# $xhtml = $handle->render_toolbox( $title, $content )
#
# Render a toolbox. This method will probably gain a whole bunch of new
# options.
#
# title and content are DOM objects.
#
######################################################################

sub render_toolbox
{
	my( $self, $title, $content ) = @_;

	my $div = $self->make_element( "div", class=>"ep_toolbox" );

	if( defined $title )
	{
		my $title_div = $self->make_element( "div", class=>"ep_toolbox_title" );
		$div->appendChild( $title_div );
		$title_div->appendChild( $title );
	}

	my $content_div = $self->make_element( "div", class=>"ep_toolbox_content" );
	$div->appendChild( $content_div );
	$content_div->appendChild( $content );
	return $div;
}

sub render_message
{
	my( $self, $type, $content, $show_icon ) = @_;
	
	$show_icon = 1 unless defined $show_icon;

	my $id = "m".$self->get_next_id;
	my $div = $self->make_element( "div", class=>"ep_msg_".$type, id=>$id );
	my $content_div = $self->make_element( "div", class=>"ep_msg_".$type."_content" );
	my $table = $self->make_element( "table" );
	my $tr = $self->make_element( "tr" );
	$table->appendChild( $tr );
	if( $show_icon )
	{
		my $td1 = $self->make_element( "td" );
		my $imagesurl = $self->get_repository->get_conf( "rel_path" );
		$td1->appendChild( $self->make_element( "img", class=>"ep_msg_".$type."_icon", src=>"$imagesurl/style/images/".$type.".png", alt=>$self->phrase( "Plugin/Screen:message_".$type ) ) );
		$tr->appendChild( $td1 );
	}
	my $td2 = $self->make_element( "td" );
	$tr->appendChild( $td2 );
	$td2->appendChild( $content );
	$content_div->appendChild( $table );
#	$div->appendChild( $title_div );
	$div->appendChild( $content_div );
	return $div;
}


######################################################################
# 
# $xhtml = $handle->render_tabs( %params )
#
# Render javascript tabs to switch between views. The views must be
# rendered seperately. 

# %params contains the following options:
# id_prefix: the prefix of the id attributes.
# current: the id of the current tab
# tabs: array of tab ids (in order to display them)
# labels: maps tab ids to DOM labels for each tab.
# links: maps tab ids to the URL for each view if there is no javascript.
# [icons]: maps tab ids to DOM containing a related icon
# [slow_tabs]: optional array of tabs which must always be linked
#  slowly rather than using javascript.
#
######################################################################

sub render_tabs
{
	my( $self, %params ) = @_;

	my $id_prefix = $params{id_prefix};
	my $current = $params{current};
	my $tabs = $params{tabs};
	my $labels = $params{labels};
	my $links = $params{links};
	
	my $f = $self->make_doc_fragment;
	my $st = {};
	if( defined $params{slow_tabs} )
	{
		foreach( @{$params{slow_tabs}} ) { $st->{$_} = 1; }
	}

	my $table = $self->make_element( "table", class=>"ep_tab_bar", cellspacing=>0, cellpadding=>0 );
	#my $script = $self->make_element( "script", type=>"text/javascript" );
	my $tr = $self->make_element( "tr", id=>"${id_prefix}_tabs" );
	$table->appendChild( $tr );

	my $spacer = $self->make_element( "td", class=>"ep_tab_spacer" );
	$spacer->appendChild( $self->render_nbsp );
	$tr->appendChild( $spacer );
	foreach my $tab ( @{$tabs} )
	{	
		my %a_opts = ( 
			href    => $links->{$tab},
		);
		my %td_opts = ( 
			class=>"ep_tab",
			id => "${id_prefix}_tab_$tab", 
		);
		# if the current tab is slow, or the tab we're rendering is slow then
		# don't make a javascript toggle for it.

		if( !$st->{$current} && !$st->{$tab} )
		{
			# stop the actual link from causing a reload.
			$a_opts{onclick} = "return ep_showTab('${id_prefix}','$tab' );",
		}
		elsif( $st->{$tab} )
		{
			$a_opts{onclick} = "ep_showTab('${id_prefix}','$tab' ); return true;",
		}
		if( $current eq $tab ) { $td_opts{class} = "ep_tab_selected"; }

		my $a = $self->make_element( "a", %a_opts );
		my $td = $self->make_element( "td", %td_opts );

		my $table2 = $self->make_element( "table", width=>"100%", cellpadding=>0, cellspacing=>0, border=>0 );
		my $tr2 = $self->make_element( "tr" );
		my $td2 = $self->make_element( "td", width=>"100%", style=>"text-align: center;" );
		$table2->appendChild( $tr2 );
		$tr2->appendChild( $td2 );
		$a->appendChild( $labels->{$tab} );
		$td2->appendChild( $a );
		if( defined $params{icons} )
		{
			if( defined $params{icons}->{$tab} )
			{
				my $td3 = $self->make_element( "td", style=>"text-align: right; padding-right: 4px" );
				$tr2->appendChild( $td3 );
				$td3->appendChild( $params{icons}->{$tab} );
			}
		}

		$td->appendChild( $table2 );

		$tr->appendChild( $td );

		my $spacer = $self->make_element( "td", class=>"ep_tab_spacer" );
		$spacer->appendChild( $self->render_nbsp );
		$tr->appendChild( $spacer );
	}
	$f->appendChild( $table );
	#$f->appendChild( $script );

	return $f;
}

1;
