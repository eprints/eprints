######################################################################
#
#  Search Expression
#
#   Represents a whole set of search fields.
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

package EPrints::SearchExpression;

use EPrints::SearchField;
use EPrints::Session;
use EPrints::EPrint;
use EPrints::Database;
use EPrints::Language;

use strict;


######################################################################
#
# $exp = new( $session,
#             $dataset,
#             $allow_blank,
#             $satisfy_all,
#             $fields )
#
#  Create a new search expression, to search $table for the MetaField's
#  in $fields (an array ref.) Blank SearchExpressions are made for each
#  of these fields.
#
#  If $allowblank is non-zero, the searcher can leave all fields blank
#  in order to retrieve everything. In some cases this might be a bad
#  idea, for instance letting someone retrieve every eprint in the
#  archive might be a bit silly and lead to performance problems...
#
#  If $satisfyall is non-zero, then a retrieved eprint must satisy
#  all of the conditions set out in the search fields. Otherwise it
#  can satisfy any single specified condition.
#
#  $orderby specifies the possibilities for ordering the expressions,
#  in the form of a hash ref. This maps a text description of the ordering
#  to the SQL clause that will have the appropriate result.
#   e.g.  "by year (newest first)" => "year ASC, author, title"
#
#  Use from_form() to update with terms from a search form (or URL).
#
#  Use add_field() to add new SearchFields. You can't have more than
#  one SearchField for any single MetaField, though - add_field() will
#  wipe over the old SearchField in that case.
#
######################################################################

sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
print STDERR "SE:[".$data{dataset}->toString()."]\n";
	# only session & table are required.
	# setup defaults for the others:
	$data{allow_blank} = 0 if ( !defined $data{allow_blank} );
	$data{satisfy_all} = 1 if ( !defined $data{satisfy_all} );
	$data{fieldnames} = [] if ( !defined $data{fieldnames} );

	foreach( qw/ session dataset allow_blank satisfy_all fieldnames / )
	{
		$self->{$_} = $data{$_};
	}
	$self->{order} = $self->{dataset}->default_order(); 

	# Array for the SearchField objects
	$self->{searchfields} = [];
	# Map for MetaField names -> corresponding SearchField objects
	$self->{searchfieldmap} = {};

	# tmptable represents cached results table.	
	$self->{tmptable} = undef;
print STDERR "FN: ".join(",",@{$self->{fieldnames}})."\n";
	foreach (@{$self->{fieldnames}})
	{
		# If the fieldname contains a /, it's a 
		# "search >1 at once" entry
		if( /\// )
		{
			# Split up the fieldnames
			my @multiple_names = split /\//, $_;
			my @multiple_fields;
			
			# Put the MetaFields in a list
			foreach (@multiple_names)
			{
				push @multiple_fields, 
					$self->{dataset}->get_field( $_ );
			}
			
			# Add a reference to the list
			$self->add_field( \@multiple_fields );
		}
		else
		{
			# Single field
			$self->add_field( $self->{dataset}->get_field( $_ ) );
		}
	}
	
	
	return( $self );
}


######################################################################
#
# add_field( $field, $value )
#
#  Adds a new search field for the MetaField $field, or list of fields
#  if $field is an array ref, with default $value. If a search field
#  already exist, the value of that field is replaced with $value.
#
######################################################################

sub add_field
{
	my( $self, $field, $value ) = @_;

	# Create a new searchfield
	my $searchfield = new EPrints::SearchField( $self->{session},
	                                            $self->{dataset},
	                                            $field,
	                                            $value );
	if( defined $self->{searchfieldmap}->{$searchfield->{formname}} )
	{
		# Already got a seachfield, just update the value
		$self->{searchfieldmap}->{$searchfield->{formname}}->set_value( $value );
	}
	else
	{
		# Add it to our list
		push @{$self->{searchfields}}, $searchfield;
		# Put it in the name -> searchfield map
		$self->{searchfieldmap}->{$searchfield->{formname}} = $searchfield;
	}
}


######################################################################
#
# clear()
#
#  Clear the search values of all search fields in the expression.
#
######################################################################

sub clear
{
	my( $self ) = @_;
	
	foreach (@{$self->{searchfields}})
	{
		$_->set_value( "" );
	}
	
	$self->{satisfy_all} = 1;
}


######################################################################
#
# $html = render_search_form( $help, $show_anyall )
#
#  Render the search form. If $help is 1, then help is written with
#  the search fields. If $show_anyall is 1, then the "must satisfy any/
#  all" field is shown at the bottom of the form.
#
######################################################################

sub render_search_form
{
	my( $self, $help, $show_anyall ) = @_;

	my $query = $self->{session}->get_query();
	my $lang = $self->{session}->get_lang();
	
	my %shown_help;

	my $html ="" ;

	my $menu;

	$html = $self->{session}->start_get_form();

	$html .= "<P><TABLE BORDER=\"0\">\n";
	
	my $sf;
	foreach $sf (@{$self->{searchfields}})
	{
		my $shelp = $sf->get_field()->search_help( $self->{session}->get_lang() );
		if( $help && !defined $shown_help{$shelp} )
		{
			$html .= "<TR><TD COLSPAN=\"2\">";
			$html .= $shelp;
			$html .= "</TD></TR>\n";
			$shown_help{$shelp}=1;
		}
		
		$html .= "<TR><TD>$sf->{displayname}</TD><TD>";
		$html .= $sf->render_html();
		$html .= "</TD></TR>\n";

		$html .= "<TR><TD COLSPAN=\"2\">&nbsp;</TD></TR>\n";
	}
	
	$html .= "</TABLE></P>\n";

	if( $show_anyall )
	{
		$menu = $query->popup_menu(
			-name=>"_satisfyall",
			-values=>[ "ALL", "ANY" ],
			-default=>( defined $self->{satisfy_all} && $self->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			-labels=>{ "ALL" => $lang->phrase("F:all"),
				   "ANY" => $lang->phrase("F:any") } );
		$html .= "<P>";
		$html .= $lang->phrase( "H:mustfulfill", { anyall=>$menu } );
		$html .= "</P>\n";
	}


			print STDERR "zz".$self->{dataset}->toString() ;
print STDERR $self->{session}->getSite()."!!\n";
	print STDERR ">>>".$self->{session}->getSite()->getConf(
			"order_methods",
			$self->{dataset}->toString() )."\n";
	my @tags = keys %{$self->{session}->getSite()->getConf(
			"order_methods",
			$self->{dataset}->toString() )};
print STDERR "foo\n";
	$menu = $query->popup_menu(
		-name=>"_order",
		-values=>\@tags,
		-default=>$self->{order},
		-labels=>$self->{session}->get_order_names( 
						$self->{dataset} ) );
	$html .= "<P>";
	$html .= $lang->phrase( 
			"H:orderresults", 
			{ ordermenu=>$menu } );
	$html .= "</P>\n";
	$html .= "<P>";
	$html .= $self->{session}->render_submit_buttons( 
			[ $lang->phrase("F:action_search"),
		          $lang->phrase("F:action_reset") ] );
	$html .= "</P>\n";

	$html .= $self->{session}->end_form();


	return( $html );
}


######################################################################
#
# $problems = from_form()
#
#  Update the search fields in this expression from the current HTML
#  form. Any problems are returned in @problems.
#
######################################################################

sub from_form
{
	my( $self ) = @_;

	my @problems;
	my $onedefined = 0;
	
	foreach( @{$self->{searchfields}} )
	{
		my $prob = $_->from_form();
		$onedefined = 1 if( defined $_->{value} );
		
		push @problems, $prob if( defined $prob );
	}

	push @problems, $self->{session}->{lang}->phrase("H:leastone")
		unless( $self->{allow_blank} || $onedefined );

	my $anyall = $self->{session}->param( "_satisfyall" );

	if( defined $anyall )
	{
		$self->{satisfy_all} = ( $anyall eq "ALL" );
	}
	
	$self->{order} = $self->{session}->param( "_order" );
	
	return( scalar @problems > 0 ? \@problems : undef );
}



######################################################################
#
# $text_rep = toString()
#
#  Return a text representation of the search expression, for persistent
#  storage. Doesn't store table or the order by fields, just the field
#  names, values, default order and satisfy_all.
#
######################################################################

sub toString
{
	my( $self ) = @_;

	# Start with satisfy all
	my $text_rep = "\[".( defined $self->{satisfy_all} &&
	                      $self->{satisfy_all}==0 ? "ANY" : "ALL" )."\]";

	# default order
	$text_rep .= "\[";
	$text_rep .= _escape_search_string( $self->{order} ) if( defined $self->{order} );
	$text_rep .= "\]";
	
	foreach (@{$self->{searchfields}})
	{
		$text_rep .= "\["._escape_search_string( $_->{formname} )."\]\[".
			( defined $_->{value} ? _escape_search_string( $_->{value} ) : "" )."\]";
	}
	
#EPrints::Log::debug( "SearchExpression", "Text rep is >>>$text_rep<<<" );

	return( $text_rep );
}

sub _escape_search_string
{
	my( $string ) = @_;
	$string =~ s/[\\\[]/\\$&/g; 
	return $string;
}

sub _unescape_search_string
{
	my( $string ) = @_;
	$string =~ s/\\(.)/$1/g; 
	return $string;
}

######################################################################
#
# state_from_string( $text_rep )
#
#  reinstate the search expression's values from the given text
#  representation, previously generated by toString(). Note that the
#  fields used must have been passed into the constructor.
#
######################################################################

sub state_from_string
{
	my( $self, $text_rep ) = @_;
	
EPrints::Log::debug( "SearchExpression", "state_from_string ($text_rep)" );

	# Split everything up

	my @elements = ();
	while( $text_rep =~ s/\[((\\\[|[^\]])*)\]//i )
	{
		push @elements, _unescape_search_string( $1 );
		print STDERR "el ($1)\n";
	}
	
	my $satisfyall = shift @elements;

	# Satisfy all?
	$self->{satisfy_all} = ( defined $satisfyall && $satisfyall eq "ANY" ? 0
	                                                                     : 1 );
	
	# Get the order
	my $order = shift @elements;
	$self->{order} = $order if( defined $order && $order ne "" );

	# Get the field values
	while( $#elements > 0 )
	{
		my $formname = shift @elements;
		my $value = shift @elements;
	
		my $sf = $self->{searchfieldmap}->{$formname};
#EPrints::Log::debug( "SearchExpression", "Eep! $formname not in searchmap!" )
#	if( !defined $sf );
		$sf->set_value( $value ) if( defined $sf && defined $value && $value ne "" );
	}

#EPrints::Log::debug( "SearchExpression", "new text rep: (".$self->toString().")" );
}




sub perform_search 
{
	my ( $self ) = @_;

	my @searchon = ();
	foreach( @{$self->{searchfields}} )
	{
		if ( defined $_->{value} )
		{
			push @searchon , $_;
		}
	}
	@searchon = sort { return $a->approx_rows() <=> $b->approx_rows() } 
		         @searchon;

#EPrints::Log::debug("optimised order:");

	my $buffer = undef;
	$self->{ignoredwords} = [];
	my $badwords;
	foreach( @searchon )
	{
		EPrints::Log::debug($_->{field}->{name}."--".$_->{value});
		my $error;
		( $buffer , $badwords , $error) = 
			$_->do($buffer , $self->{satisfy_all} );

		if( defined $error )
		{
			$self->{tmptable} = undef;
			$self->{error} = $error;
			return;
		}
		if( defined $badwords )
		{
			push @{$self->{ignoredwords}},@{$badwords};
		}
	}
	
        my @fields = $self->{session}->{metainfo}->get_fields( $self->{dataset} );
        my $keyfield = $fields[0];
	$self->{error} = undef;
	$self->{tmptable} = $buffer;

}
	
sub count 
{
	my ( $self ) = @_;

	if ( $self->{tmptable} )
	{
		return $self->{session}->{database}->count_buffer( 
			$self->{tmptable} );
	}	

	EPrints::Log::log_entry( "L:not_cached" );
		
}


sub get_records 
{
	my ( $self , $max ) = @_;
	
	if ( $self->{tmptable} )
	{
        	my @fields = $self->{session}->{metainfo}->get_fields( $self->{dataset} );
        	my $keyfield = $fields[0];

		my ( $buffer, $overlimit ) = $self->{session}->{database}->distinct_and_limit( 
							$self->{tmptable}, 
							$keyfield, 
							$max );

		my @records = $self->{session}->{database}->from_buffer( $self->{dataset}, $buffer );
		if( !$overlimit )
		{
print STDERR "ORDER BY: $self->{order}\n";
			@records = sort 
				{ &{$self->{session}->{site}->{order_methods}->{$self->{dataset}}->{$self->{order}}}($a,$b); }
				@records;
		}
		return @records;
	}	

	EPrints::Log::log_entry( "L:not_cached" );
		
}


######################################################################
#
# process_webpage()
#
#  Process the search form, writing out the form and/or results.
#
######################################################################

sub process_webpage
{
	my( $self, $title, $preamble ) = @_;
	
	my $submit_button = $self->{session}->param( "submit" );

	# Check if we need to do a search. We do if:
	#  a) if the Search button was pressed.
	#  b) if there are search parameters but we have no value for "submit"
	#     (i.e. the search is a direct GET from somewhere else)
	if( ( defined $submit_button && $submit_button eq $self->{session}->{lang}->phrase("F:action_search") ) || 
	    ( !defined $submit_button &&
	      $self->{session}->have_parameters() ) )
	{
		# We need to do a search
		my $problems = $self->from_form();
		
		if( defined $problems && scalar (@$problems) > 0 )
		{
			$self->_render_problems( @$problems );
			return;
		}


		# Everything OK with form.
			
#EPrints::Log::debug( "SearchForm", $self->toString() );

		my( $t1 , $t2 , $t3 , @results );

		$t1 = EPrints::Log::microtime();
		$self->perform_search();
		$t2 = EPrints::Log::microtime();

		if( defined $self->{error} ) 
		{	
			# Error with search.
			$self->_render_problems( $self->{error} );
			return;
		}

		my $n_results = $self->count();

		my $MAX=1000;

		@results = $self->get_records( $MAX );
		$t3 = EPrints::Log::microtime();

		print $self->{session}->start_html(
			$self->{session}->{lang}->phrase( "H:results_for",
			                                  { title=>$title } ) );

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

		if( @{ $self->{ignoredwords} } )
		{
			my %words = ();
			foreach( @{$self->{ignoredwords}} ) { $words{$_}++; }
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
		
		print $self->{session}->start_get_form();

		$self->write_hidden_state();

		print $self->{session}->{render}->submit_buttons(
			[ $self->{session}->{lang}->phrase("F:action_update"), $self->{session}->{lang}->phrase("F:action_newsearch") ] );
		print $self->{session}->{render}->end_form();
	
		print $self->{session}->end_html();
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
		$self->from_form();

		print $self->{session}->start_html( $title );
		print $preamble;

		print $self->render_search_form( $self );

		print $self->{session}->end_html();
		return;
	}

	# Just print the form...
	print $self->{session}->start_html( $title );
	print $preamble;

	print $self->render_search_form( $self );

	print $self->{session}->end_html();
}

sub _render_problems
{
	my( $self , @problems ) = @_;	
	# Problem with search expression. Report an error, and redraw the form
			
	print $self->{session}->start_html( $self->{title} );
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
	print $self->render_search_form();
			
	print $self->{session}->end_html();
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

sub _render_matchcount
{
	my( $session, $count ) = @_;

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
	my @params = $self->{session}->param();

	foreach (@params)
	{
		print $self->{session}->{render}->hidden_field( $_ ) if( $_ ne "submit" );
	}
}

1;
