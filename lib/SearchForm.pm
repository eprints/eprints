######################################################################
#
#  EPrints Search Form Class
#
######################################################################
#
#  20/03/2000 - Created by Robert Tansley
#  $Id$
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

my $action_search    = "Search";
my $action_reset     = "Reset the form";
my $action_newsearch = "Start new search";
my $action_update    = "Update the search";


######################################################################
#
# $searchform = new( $session,
#                    $what,
#                    $table,
#                    $allow_blank,
#                    $default_fields,
#                    $title,
#                    $preamble,
#                    $order_methods,
#                    $default_order )
#
#  Create a new search form handler object.
#
#  $what           - if "eprints", the search form will search for eprints.
#                    if "user",  will search for users.
#  $table          - the database table to search
#  $allow_blank    - if the searcher is allowed to leave everything
#                  - blank and retrieve everything
#  $default_fields - which fields to display (MetaField objects)
#  $title          - title for the form
#  $preamble       - put at the top of the page.
#  $order_methods  - map description of ordering to SQL clause
#  $default_order  - default order (key to order_methods)
#
######################################################################

sub new
{
	my( $class,
	    $session,
	    $what,
	    $allow_blank,
	    $table,
	    $default_fields,
	    $title,
		 $preamble,
	    $order_methods,
	    $default_order ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{what} = $what;
	$self->{allow_blank} = $allow_blank;
	$self->{table} = $table;
	$self->{default_fields} = $default_fields;
	$self->{title} = $title;
	$self->{preamble} = $preamble;
	$self->{order_methods} = $order_methods;
	$self->{default_order} = $default_order;

	return( undef ) unless( $what eq "users" || $what eq "eprints" );
	
	return( $self );
}


######################################################################
#
# process()
#
#  Process the search form, writing out the form and/or results.
#
######################################################################

sub process
{
	my( $self ) = @_;
	
	my $submit_button = $self->{session}->{render}->param( "submit" );

	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		$self->{table},
		$self->{allow_blank},
		1,
		$self->{default_fields},
		$self->{order_methods},
		$self->{default_order} );

	if( defined $submit_button && $submit_button eq $action_search )
	{
		# We need to do a search
		my $problems = $searchexp->from_form();
		
		if( defined $problems && scalar (@$problems) > 0 )
		{
			# Problem with search expression. Report an error, and redraw the form
			
			print $self->{session}->{render}->start_html( $self->{title} );
			print $self->{preamble};

			print "<p>There's a problem with the form:</p>\n";
			print "<UL>\n";
			
			foreach (@$problems)
			{
				print "<LI>$_</LI>\n";
			}
			
			print "</UL>\n";

			$self->render_search_form( $searchexp );
			
			print $self->{session}->{render}->end_html();
		}
		else
		{
			# Everything OK.
			
#EPrints::Log::debug( "SearchForm", $searchexp->to_string() );

			print $self->{session}->{render}->start_html(
				"Results for ".$self->{title} );
			
			# Print results

			if( $self->{what} eq "eprints" )
			{
				my @eprints = $searchexp->do_eprint_search();
				
				_print_matchcount( defined @eprints ? scalar @eprints : 0 );


				foreach (@eprints)
				{
					print "<P>".$self->{session}->{render}->render_eprint_citation(
						$_,
						1,
						1 )."</P>\n";
				}
			}
			elsif( $self->{what} eq "users" )
			{
				my @users = $searchexp->do_user_search();
				
				_print_matchcount( defined @users ? scalar @users : 0 );

				foreach (@users)
				{
					print "<P>";
					print $self->{session}->{render}->render_user_name( $_, 1 );
					print "</P>\n";
				}
			}
			
			# Print out state stuff for a further invocation
			print "<CENTER><P>";
			print $self->{session}->{render}->start_get_form();

			$self->write_hidden_state();

			print $self->{session}->{render}->submit_buttons(
				[ $action_update, $action_newsearch ] );
			print "</P></CENTER>\n";

			print $self->{session}->{render}->end_form();


			print $self->{session}->{render}->end_html();
		}
	}
	elsif( defined $submit_button && ( $submit_button eq $action_reset || 
		$submit_button eq $action_newsearch ) )
	{
		# To reset the form, just reset the URL.
		my $url = $self->{session}->{render}->url();
		# Remove everything that's part of the query string.
		$url =~ s/\?.*//;
		$self->{session}->{render}->redirect( $url );
	}
	elsif( defined $submit_button && $submit_button eq $action_update )
	{
		$searchexp->from_form();

		print $self->{session}->{render}->start_html( $self->{title} );
		print $self->{preamble};

		$self->render_search_form( $searchexp );

		print $self->{session}->{render}->end_html();
	}
	else
	{
		# Just print the form...
		print $self->{session}->{render}->start_html( $self->{title} );
		print $self->{preamble};

		$self->render_search_form( $searchexp );

		print $self->{session}->{render}->end_html();
	}		
}
	

######################################################################
#
# _print_matchcount( $count )
#
#  Prints the number of hits the search resulted in, handling singular/
#  plural properly.
#
######################################################################

sub _print_matchcount
{
	my( $count ) = @_;
	
	print "<CENTER><P>Retrieved ";
	if( $count==0 )
	{
		print "no hits.";
	}
	elsif( $count==1 )
	{
		print "<STRONG>1</STRONG> hit.";
	}
	else
	{
		print "<STRONG>".$count."</STRONG> hits";
	}
	print "</P></CENTER>\n";
}


######################################################################
#
# render_search_form( $searchexp )
#
#  Render a for for the given search expression, using the GET method
#
######################################################################

sub render_search_form
{
	my( $self, $searchexp ) = @_;

	print $self->{session}->{render}->start_get_form();

	print $searchexp->render_search_form( 1 );
	print "<CENTER><P>";
	print $self->{session}->{render}->submit_buttons( [ $action_search,
		                                                 $action_reset ] );
	print "</P></CENTER>\n";

	print $self->{session}->{render}->end_form();
}


######################################################################
#
# write_hidden_state()
#
#  Write out the state of the form in hidden HTML fields.
#
######################################################################

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
