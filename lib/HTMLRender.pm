######################################################################
#
# EPrints HTML Renderer Module
#
#   Renders common HTML components
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

package EPrints::HTMLRender;

use EPrints::Name;

use strict;

use CGI;

# Width of text fields
$EPrints::HTMLRender::form_width = 60;
$EPrints::HTMLRender::search_form_width = 40;

# Width of name fields
$EPrints::HTMLRender::form_name_width = 20;

# Width of username fields
$EPrints::HTMLRender::form_username_width = 10;

# Max number of chars in (single-line) text fields
$EPrints::HTMLRender::field_max = 255;

# Max height of scrolling list
$EPrints::HTMLRender::list_height_max = 20;

# Number of extra spaces for names to add when user clicks on "More Spaces"
$EPrints::HTMLRender::add_boxes = 3;





######################################################################
#
# new( $session, $offline)
#
#  Create an HTML Renderer. If $offline is true, won't try to read
#  form values.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class, $session, $offline, $query ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{offline} = $offline;
	$self->{query} = $query;

	$self->{session} = $session;

	# Get name & username boxcount stuff

	$self->{internalbuttonpressed} = 0;

	$self->{nameinfo} = {};
	$self->{usernameinfo} = {};

	my @params = $self->{query}->param();
	my $n;

	foreach $n (@params)
	{
		$self->{nameinfo}->{$n} = $self->{query}->param( $n )
			if( substr($n, 0, 5) eq "name_" );
		
		$self->{internalbuttonpressed} = 1 if( substr($n, 0, 10) eq "name_more_" );
		$self->{usernameinfo}->{$n} = $self->{query}->param( $n )
			if( substr($n, 0, 9) eq "username_" );
		
		$self->{internalbuttonpressed} = 1 if( substr($n, 0, 14) eq "username_more_" );
	}
	
	

	return( $self );
}



######################################################################
#
# $url = absolute url()
#
#  Returns the absolute URL of the current script (no http:// or
#  query string)
#
######################################################################

## WP1: BAD
sub absolute_url
{
	my( $self ) = @_;
	
	return( $self->{query}->url( -absolute=>1 ) );
}


######################################################################
#
# $consumed = internal_button_pressed()
#
#  Important function: if this returns true, then the button pressed on
#  the form was an internal form state button, so whatever form you
#  rendered should be re-rendered to show the updated state info.
#
######################################################################




######################################################################
#
# $html = input_field( $field, $value )
#
#  Returns the HTML to produce an input field. $field is a reference
#  to the usual metadata field, and $value is the initial value.
#
######################################################################

######################################################################
#
# $html = named_submit_button( $name, $value )
#
#  Returns HTML for a single submit button with a given name and value
#
######################################################################

## WP1: BAD
sub named_submit_button
{
	my( $self, $name, $value ) = @_;
	
	return( $self->{query}->submit( -name=>$name, -value=>$value ) );
}


######################################################################
#
# $html = start_form( $dest )
#
#  Return (multipart) form preamble.
#
######################################################################

## WP1: BAD
sub start_form
{
	my( $self, $dest ) = @_;
	
	if( defined $dest )
	{
		return( $self->{query}->start_multipart_form( -action=>$dest ) );
	}
	else
	{
		return( $self->{query}->start_multipart_form() );
	}
}




######################################################################
#
# $html = hidden_field( $name, $value )
#
#  Insert a hidden field, for passing around state information. If
#  $value is undefined, the hidden field will inherit the value from
#  the last script invocation.
#
######################################################################

## WP1: BAD
sub hidden_field
{
	my( $self, $name, $value ) = @_;
die"nope";
	
	return( $self->{query}->hidden( -name=>$name,
	                                -default=>$value,
	                                -override=>1 ) ) if( defined $value );

	return( $self->{query}->hidden( -name=>$name ) );
}


######################################################################
#
# $html = upload_field( $name )
#
#  Return the HTML for a file upload field with the given name.
#
######################################################################

## WP1: BAD
sub upload_field
{
	my( $self, $name ) = @_;
	
	return( $self->{query}->filefield(
		-name=>$name,
		-default=>"",
		-size=>$EPrints::HTMLRender::form_width,
		-maxlength=>$EPrints::HTMLRender::field_max ) );
}

######################################################################
#
# $seen = seen_form()
#
#  Returns 1 if form data has been posted; i.e. if the script has already
#  been called and the user has entered data and clicked "submit."
#
######################################################################






######################################################################
#
# set_param( $name, $value )
#
#  Set a query parameter, in case you want to change the default
#  for a form.
#
######################################################################

## WP1: BAD
sub set_param
{
	my( $self, $name, $value ) = @_;

	$self->{query}->param( -name=>$name, -value=>$value );
}




######################################################################
#
# clear()
#
#  Clears the form data.
#
######################################################################

## WP1: BAD
sub clear
{
	my( $self ) = @_;
	
	$self->{query}->delete_all();
}





######################################################################
#
# $citation = render_eprint_citation( $eprint, $html, $linked )
#
#  Render a citation for the given EPrint. If $html is non-zero, the 
#  citation will be rendered in HTML, otherwise it will just be plain
#  text. If $linked and $html are non-zero, the citation will be
#  rendered as a link to the static page.
#
######################################################################


######################################################################
#
# $html = render_user( $user, $public )
#
#  Render a user as HTML. if $public==1, only public fields
#  will be shown.
#
######################################################################

## WP1: BAD
sub render_user
{
	my( $self, $user, $public ) = @_;

	return( $self->{session}->{site}->user_render_full( $user, $public ) );
}



######################################################################
#
#  $html = write_version_thread( $eprint, $field )
#
#   Returns HTML that writes a nice threaded display of previous versions
#   and future ones.
#
######################################################################

## WP1: BAD
sub write_version_thread
{
	my( $self, $eprint, $field ) = @_;

	my $html;

	my $first_version = $eprint->first_in_thread( $field );
	
	$html .= "<UL>\n";
	$html .= $self->_write_version_thread_aux( $first_version, $field, $eprint );
	$html .= "</UL>\n";
	
	return( $html );
}

## WP1: BAD
sub _write_version_thread_aux
{
	my( $self, $eprint, $field, $eprint_shown ) = @_;
	
	my $html = "<LI>";

	# Only write a link if this isn't the current
	$html .= "<A HREF=\"".$eprint->static_page_url()."\">"
		if( $eprint->{eprintid} ne $eprint_shown->{eprintid} );
	
	# Write the citation
	my $citation_spec =
		$self->{session}->{site}->{thread_citation_specs}->{$field->{name}};

	$html .= EPrints::Citation::render_citation( $eprint->{session},
	                                             $citation_spec,
	                                             $eprint,
	                                             1 );

	# End of the link if appropriate
	$html .= "</A>" if( $eprint->{eprintid} ne $eprint_shown->{eprintid} );

	# Show the current
	if( $eprint->{eprintid} eq $eprint_shown->{eprintid} ) 
	{
		$html .= " <strong>[";
		$html .= $self->{session}->phrase( "H:curr_disp" );
		$html .= "]</strong>";
	}
	
	# Are there any later versions in the thread?
	my @later = $eprint->later_in_thread( $field );
	if( scalar @later > 0 )
	{
		# if there are, start a new list
		$html .= "\n<UL>\n";
		foreach (@later)
		{
			$html .= $self->_write_version_thread_aux(
				$_,
				$field,
				$eprint_shown );
		}
		$html .= "</UL>\n";
	}
	$html .= "</LI>\n";
	
	return( $html );
}


######################################################################
#
# $html = render_deleted_eprint( $deletion_record )
#
#  Render an appropriate error saying that the eprint the user is
#  trying to access has been removed, and to point to the replacement
#  if one exists.
#
######################################################################

## WP1: BAD
sub render_deleted_eprint
{
	my( $self, $deletion_record ) = @_;
	
	my $replacement_eprint;
	
	$replacement_eprint = new EPrints::EPrint(
		$self->{session},
		EPrints::Database::table_name( "archive" ),
		$deletion_record->{replacement} )
		if( defined $deletion_record->{replacement} );
	
	my $html = $self->start_html( 
		$self->{session}->phrase( "H:eprint_gone_title" ) );
	
	$html .= "<P>";
	$html .= $self->{session}->phrase( "H:eprint_gone" );
	$html .= "</P>\n";
	
	if( defined $replacement_eprint )
	{
		$html .= "<P>";
		$html .= $self->{session}->phrase( "H:later_version" );
		$html .= "</P>\n";
		$html .= "<P ALIGN=CENTER>";

		$html .= $self->render_eprint_citation(
			$replacement_eprint,
			1,
			1 );
		
		$html .= "</P>\n";
	}
	
	$html .= $self->end_html();

	return( $html );
}



1; # For use/require success
