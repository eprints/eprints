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
		$self->{session}->get_archive()->get_conf( "thread_citation_specs" )->{$field->{name}};

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
		$html .= $self->{session}->phrase( "lib/session:curr_disp" );
		$html .= "]</strong>";
	}
	
	# Are there any later versions in the thread?
	my @later = $eprint->later_in_thread( $field );
	if( scalar @later > 0 )
	{
		# if there are, start a new list
		$html .= "\n<UL>\n";
		my $version;
		foreach $version (@later)
		{
			$html .= $self->_write_version_thread_aux(
				$version,
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
		$self->{session}->phrase( "lib/session:eprint_gone_title" ) );
	
	$html .= "<P>";
	$html .= $self->{session}->phrase( "lib/session:eprint_gone" );
	$html .= "</P>\n";
	
	if( defined $replacement_eprint )
	{
		$html .= "<P>";
		$html .= $self->{session}->phrase( "lib/session:later_version" );
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
