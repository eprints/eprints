######################################################################
#
#  EPrints Search Form Class
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

package EPrints::SearchForm;

use EPrints::Session;
use EPrints::HTMLRender;
use EPrints::EPrint;
use EPrints::SearchField;
use EPrints::SearchExpression;


use strict;

die;
######################################################################
#
# $searchform = new( $session,
#                    $allow_blank,
#                    $tableid,
#                    $default_fields,
#                    $title,
#                    $preamble,
#                    $staff )
#
#  Create a new search form handler object.
#
#  $allow_blank    - if the searcher is allowed to leave everything
#                  - blank and retrieve everything
#  $tableid          - the database table to search
#  $default_fields - which fields to display (MetaField objects)
#  $title          - title for the form
#  $preamble       - put at the top of the page.
#  $staff          - boolean: does user have staff access?
#
######################################################################

## WP1: BAD
sub new
{
	my( $class,
	    $session,
	    $allow_blank,
	    $tableid,
	    $default_fields,
	    $title,
	    $preamble,
	    $staff ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{allow_blank} = $allow_blank;
	$self->{tableid} = $tableid;
	$self->{default_fields} = $default_fields;
	$self->{title} = $title;
	$self->{preamble} = $preamble;
	$self->{staff} = $staff;

	return( $self );
}


######################################################################
#
# process()
#
#  Process the search form, writing out the form and/or results.
#
######################################################################

## WP1: BAD
sub process
{
	my( $self ) = @_;
	
	my $submit_button = $self->{session}->{render}->param( "submit" );

	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		$self->{tableid},
		$self->{allow_blank},
		1,
		$self->{default_fields} );

	# Check if we need to do a search. We do if:
	#  a) if the Search button was pressed.
	#  b) if there are search parameters but we have no value for "submit"
	#     (i.e. the search is a direct GET from somewhere else)
	if( ( defined $submit_button && $submit_button eq $self->{session}->{lang}->phrase("F:action_search") ) || 
	    ( !defined $submit_button &&
	      $self->{session}->{render}->have_parameters() ) )
	{
		# We need to do a search
		my $problems = $searchexp->from_form();
		
		if( defined $problems && scalar (@$problems) > 0 )
		{
			$self->_render_problems( $searchexp , @$problems );
			return;
		}


		# Everything OK with form.
			
#EPrints::Log::debug( "SearchForm", $searchexp->toString() );

		my( $t1 , $t2 , $t3 , @results );

		$t1 = EPrints::Log::microtime();
		$searchexp->perform_search();
		$t2 = EPrints::Log::microtime();

		if( defined $searchexp->{error} ) 
		{	
			# Error with search.
			$self->_render_problems( $searchexp , $searchexp->{error} );
			return;
		}

		my $n_results = $searchexp->count();

		my $MAX=1000;

		@results = $searchexp->get_records( $MAX );
		$t3 = EPrints::Log::microtime();

		print $self->{session}->{render}->start_html(
			$self->{session}->{lang}->phrase( "H:results_for",
			                                  { title=>$self->{title} } ) );

		if( $n_results > $MAX) 
		{
			print "<P>";
	                print $self->{session}->{lang}->phrase( "H:too_many", 
	{ n=>"<SPAN class=\"highlight\">$MAX</SPAN>" } )."\n";
			print "</P>";
		}
	
		my $code;
		if( $n_results == 0 )
		{
			$code = "H:no_hits";
		}
		elsif( $n_results == 1 )
		{
			$code = "H:one_hit";
		}
		else
		{
			$code = "H:n_hits";
		}
		print "<P>";
       		print $self->{session}->{lang}->phrase( $code, { n=>"<SPAN class=\"highlight\">$n_results</SPAN>" } )."\n";

		if( @{ $searchexp->{ignoredwords} } )
		{
			my %words = ();
			foreach( @{$searchexp->{ignoredwords}} ) { $words{$_}++; }
       			print $self->{session}->{lang}->phrase( 
				"H:ignored",
				{ words=>"<SPAN class=\"highlight\">".join("</SPAN>, <SPAN class=\"highlight\">",sort keys %words)."</SPAN>" } );
		}
		print "</P>\n";

       		print $self->{session}->{lang}->phrase( 
			"H:search_time", 
			{ searchtime=>"<SPAN class=\"highlight\">".($t2-$t1)."</SPAN>", 
			gettime=>"<SPAN class=\"highlight\">".($t3-$t2)."</SPAN>" } ) ."\n";

		# Print results
		if( $self->{what} eq "eprint" )
		{
			
			foreach (@results)
			{
				if( $self->{staff} )
				{
					print "<P><A HREF=\"$self->{session}->{site}->{server_perl}/".
						"staff/edit_eprint?eprint_id=$_->{eprintid}\">".
						$self->{session}->{render}->render_eprint_citation(
							$_,
							1,
							0 )."</A></P>\n";
				}
				else
				{
					print "<P>".
						$self->{session}->{render}->render_eprint_citation(
							$_,
							1,
							1 )."</P>\n";
				}
			}
		}
		elsif( $self->{what} eq "user" )
		{
			
			foreach (@results)
			{
				print "<P>";
				print $self->{session}->{render}->render_user_name( $_, 1 );
				print "</P>\n";
			}
		}
		else
		{
			die "dammit";
			#cjg
		}
			
		# Print out state stuff for a further invocation
		
		print $self->{session}->{render}->start_get_form();

		$self->write_hidden_state();

		print $self->{session}->{render}->submit_buttons(
			[ $self->{session}->{lang}->phrase("F:action_update"), $self->{session}->{lang}->phrase("F:action_newsearch") ] );
		print $self->{session}->{render}->end_form();
	
		print $self->{session}->{render}->end_html();
		return;
	}

	if( defined $submit_button && ( $submit_button eq $self->{session}->{lang}->phrase("F:action_reset") || 
		$submit_button eq $self->{session}->{lang}->phrase("F:action_newsearch") ) )
	{
		# To reset the form, just reset the URL.
		my $url = $self->{session}->{render}->url();
		# Remove everything that's part of the query string.
		$url =~ s/\?.*//;
		$self->{session}->{render}->redirect( $url );
		return;
	}
	
	if( defined $submit_button && $submit_button eq $self->{session}->{lang}->phrase("F:action_update") )
	{
		$searchexp->from_form();

		print $self->{session}->{render}->start_html( $self->{title} );
		print $self->{preamble};

		$self->render_search_form( $searchexp );

		print $self->{session}->{render}->end_html();
		return;
	}

	# Just print the form...
	print $self->{session}->{render}->start_html( $self->{title} );
	print $self->{preamble};

	$self->render_search_form( $searchexp );

	print $self->{session}->{render}->end_html();
}

## WP1: BAD
sub _render_problems
{
	my( $self , $searchexp , @problems ) = @_;	
	# Problem with search expression. Report an error, and redraw the form
			
	print $self->{session}->{render}->start_html( $self->{title} );
	print $self->{preamble};

	print "<P>";
	print $self->{session}->{lang}->phrase( "H:form_problem" );
	print "</P>";
	print "<UL>\n";
	
	foreach (@problems)
	{
		print "<LI>$_</LI>\n";
	}
	
	print "</UL>\n";
	print "<HR noshade>";
	$self->render_search_form( $searchexp );
			
	print $self->{session}->{render}->end_html();
	return;
}


######################################################################
#
# _render_matchcount( $count )
#
#  Renders the number of hits the search resulted in, handling singular/
#  plural properly into HTML.
#
######################################################################

## WP1: BAD
sub _render_matchcount
{
	my( $session, $count ) = @_;

}

######################################################################
#
# render_search_form( $searchexp )
#
#  Render a for for the given search expression, using the GET method
#
######################################################################

## WP1: BAD
sub render_search_form
{
	my( $self, $searchexp ) = @_;

	print $self->{session}->{render}->start_get_form();

	print $searchexp->render_search_form( 1, 1 );
	print "<P>";
	print $self->{session}->{render}->submit_buttons( [ $self->{session}->{lang}->phrase("F:action_search"),
		                                                 $self->{session}->{lang}->phrase("F:action_reset") ] );
	print "</P>\n";

	print $self->{session}->{render}->end_form();
}


######################################################################
#
# write_hidden_state()
#
#  Write out the state of the form in hidden HTML fields.
#
######################################################################

## WP1: BAD
sub write_hidden_state
{
	my( $self ) = @_;
	
	# Call CGI directly, we want an array
	my @params = $self->{session}->{render}->param();

	foreach (@params)
	{
		print $self->{session}->{render}->hidden_field( $_ ) if( $_ ne "submit" );
	}
}

1;
