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
# order method not presercved.

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

## WP1: BAD
sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
print STDERR "k:[".join(",",keys %data)."]\n";
print STDERR "SE1:[".$data{dataset}."]\n";
print STDERR "SE2:[".$data{dataset}->to_string()."]\n";
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

## WP1: BAD
sub add_field
{
	my( $self, $field, $value ) = @_;

	# Create a new searchfield
	my $searchfield = new EPrints::SearchField( $self->{session},
	                                            $self->{dataset},
	                                            $field,
	                                            $value );

	my $formname = $searchfield->get_form_name();
	if( defined $self->{searchfieldmap}->{$formname} )
	{
		# Already got a seachfield, just update the value
		$self->{searchfieldmap}->{$formname}->set_value( $value );
	}
	else
	{
		# Add it to our list
		push @{$self->{searchfields}}, $searchfield;
		# Put it in the name -> searchfield map
		$self->{searchfieldmap}->{$formname} = $searchfield;
	}
}


######################################################################
#
# clear()
#
#  Clear the search values of all search fields in the expression.
#
######################################################################

## WP1: BAD
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

## WP1: BAD
sub render_search_form
{
	my( $self, $help, $show_anyall ) = @_;

	my $form = $self->{session}->make_form( "get" );
	my $div;

	my %shown_help;
	my $sf;
	foreach $sf ( @{$self->{searchfields}} )
	{
		$div = $self->{session}->make_element( 
				"div" , 
				class => "searchfieldname" );
		$div->appendChild( $self->{session}->make_text( 
					$sf->get_display_name ) );
		$form->appendChild( $div );
		my $shelp = $sf->get_help();
		if( $help && !defined $shown_help{$shelp} )
		{
			$div = $self->{session}->make_element( 
				"div" , 
				class => "searchfieldhelp" );
			$div->appendChild( $self->{session}->make_text( $shelp ) );
			$form->appendChild( $div );
			#$shown_help{$shelp}=1;
		}

		$div = $self->{session}->make_element( 
			"div" , 
			class => "searchfieldinput" );
		$form->appendChild( $sf->to_html() );
	}

	my $menu;

	if( $show_anyall )
	{
		$menu = $self->{session}->make_option_list(
			name=>"_satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{satisfy_all} && $self->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{session}->phrase( "lib/searchexpression:all" ),
				  "ANY" => $self->{session}->phrase( "lib/searchexpression:any" )} );

		$div = $self->{session}->make_element( 
			"div" , 
			class => "searchanyall" );
		$div->appendChild( 
			$self->{session}->html_phrase( 
				"lib/searchexpression:must_fulfill",  
				anyall=>$menu ) );
		$form->appendChild( $div );	
	}

	my @tags = keys %{$self->{session}->get_archive()->get_conf(
			"order_methods",
			$self->{dataset}->confid )};
	$menu = $self->{session}->make_option_list(
		name=>"_order",
		values=>\@tags,
		default=>$self->{order},
		labels=>$self->{session}->get_order_names( 
						$self->{dataset} ) );

	$div = $self->{session}->make_element( 
		"div" , 
		class => "searchorder" );

	$div->appendChild( 
		$self->{session}->html_phrase( 
			"lib/searchexpression:order_results", 
			ordermenu => $menu  ) );

	$form->appendChild( $div );	

	$div = $self->{session}->make_element( 
		"div" , 
		class => "searchbuttons" );
	$div->appendChild( $self->{session}->make_action_buttons( 
		search => $self->{session}->phrase( "lib/searchexpression:action_search" ), 
		newsearch => $self->{session}->phrase( "lib/searchexpression:action_reset" ) ) );
	$form->appendChild( $div );	

	return( $form );
}


######################################################################
#
# $problems = from_form()
#
#  Update the search fields in this expression from the current HTML
#  form. Any problems are returned in @problems.
#
######################################################################

## WP1: BAD
sub from_form
{
	my( $self ) = @_;

	my @problems;
	my $onedefined = 0;
	
	foreach( @{$self->{searchfields}} )
	{
		my $prob = $_->from_form;
		$onedefined = 1 if( defined $_->{value} );
		
		push @problems, $prob if( defined $prob );
	}

	push @problems, $self->{session}->phrase( "lib/searchexpression:leastone" )
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
# $text_rep = to_string()
#
#  Return a text representation of the search expression, for persistent
#  storage. Doesn't store table or the order by fields, just the field
#  names, values, default order and satisfy_all.
#
######################################################################

## WP1: BAD
sub to_string
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
		$text_rep .= "\["._escape_search_string( $_->get_form_name() )."\]\[".
			( defined $_->get_value() ? _escape_search_string( $_->get_value() ) : "" )."\]";
	}
	

	return( $text_rep );
}

## WP1: BAD
sub _escape_search_string
{
	my( $string ) = @_;
	$string =~ s/[\\\[]/\\$&/g; 
	return $string;
}

## WP1: BAD
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
#  representation, previously generated by to_string(). Note that the
#  fields used must have been passed into the constructor.
#
######################################################################

## WP1: BAD
sub state_from_string
{
	my( $self, $text_rep ) = @_;
	$self->{session}->get_archive()->log( "SearchExpression state_from_string debug: $text_rep" );	

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
#	if( !defined $sf );
		$sf->set_value( $value ) if( defined $sf && defined $value && $value ne "" );
	}

}




## WP1: BAD
sub perform_search 
{
	my ( $self ) = @_;

	my @searchon = ();
	foreach( @{$self->{searchfields}} )
	{
		if ( defined $_->get_value() )
		{
			push @searchon , $_;
		}
	}
	@searchon = sort { return $a->approx_rows <=> $b->approx_rows } 
		         @searchon;

	if( scalar @searchon == 0 )
	{
		$self->{error} = undef;
		$self->{tmptable} = $self->{dataset}->get_sql_table_name();
		print STDERR "FUCK!\n";
	}
	else 
	{
		my $buffer = undef;
		$self->{ignoredwords} = [];
		my $badwords;
		foreach( @searchon )
		{
			$self->{session}->get_archive()->log( "SearchExpression perform_search debug: ".$_->{field}->{name}."--".$_->{value});
			$self->{session}->get_archive()->log( "SearchExpression perform_search debug: ".$buffer."!\n" );
			my $error;
			( $buffer , $badwords , $error) = 
				$_->do( $buffer , $self->{satisfy_all} );
	
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
		
		$self->{error} = undef;
		$self->{tmptable} = $buffer;
	print STDERR "SHIOOOK: ".$buffer."\n";
	}


}
	
## WP1: BAD
sub count 
{
	my( $self ) = @_;

	if( $self->{tmptable} )
	{
		return $self->{session}->get_db()->count_buffer( 
			$self->{tmptable} );
	}	
	#cjg ERROR to user?
	$self->{session}->get_archive()->log( "Search has not been performed" );
		
}


## WP1: BAD
sub get_records 
{
	my ( $self , $max ) = @_;
	
	if ( $self->{tmptable} )
	{
        	my( $keyfield ) = $self->{dataset}->get_key_field();
		my( $buffer, $overlimit ) = 
			$self->{session}->get_db()->distinct_and_limit( 
							$self->{tmptable}, 
							$keyfield, 
							$max );

		my @records = $self->{session}->get_db()->from_buffer( 
							$self->{dataset}, 
							$buffer );

		# We don't bother sorting if we got too many results.	
		# or no order method was specified.
		if( !$overlimit && defined $self->{order})
		{
 print STDERR "order_methods " , $self->{dataset}->confid(). " ". $self->{order} ;
print STDERR "ORDER BY: $self->{order}\n";

			my $cmpmethod = $self->{session}->get_archive()->get_conf( 
						"order_methods" , 
						$self->{dataset}->confid, 
						$self->{order} );

			@records = sort { &{$cmpmethod}($a,$b); } @records;
		}
		return @records;
	}	

#ERROR TO USER cjg
	$self->{session}->get_archive()->log( "Search not yet performed" );
		
}


######################################################################
#
# process_webpage( $title, $preamble )
#                  string  DOM
#
#  Process the search form, writing out the form and/or results.
#
######################################################################

## WP1: BAD
sub process_webpage
{
	my( $self, $title, $preamble ) = @_;
	
	my $action_button = $self->{session}->get_action_button();
	# Check if we need to do a search. We do if:
	#  a) if the Search button was pressed.
	#  b) if there are search parameters but we have no value for "submit"
	#     (i.e. the search is a direct GET from somewhere else)

	if( ( defined $action_button && $action_button eq "search" ) 
            || 
	    ( !defined $action_button && $self->{session}->have_parameters() ) )
	{
		# We need to do a search
		my $problems = $self->from_form;
		
		if( defined $problems && scalar( @$problems ) > 0 )
		{
			$self->_render_problems( 
					$title, 
					$preamble, 
					@$problems );
			return;
		}

		# Everything OK with form.
			

		my( $t1 , $t2 , $t3 , @results );

		$t1 = EPrints::Session::microtime();

		$self->perform_search();

		$t2 = EPrints::Session::microtime();

		if( defined $self->{error} ) 
		{	
			# Error with search.
			$self->_render_problems( 
					$title, 
					$preamble, 
					$self->{error} );
			return;
		}

		my $n_results = $self->count();

		# cjg this should be in site config.
		my $MAX=1000;

		@results = $self->get_records( $MAX );
		$t3 = EPrints::Session::microtime();

		my $page = $self->{session}->make_doc_fragment();

		if( $n_results > $MAX) 
		{
			my $p = $self->{session}->make_element( "p" );
			$page->appendChild( $p );
			$p->appendChild( 
				$self->{session}->html_phrase( 
							"lib/searchexpression:too_many", 
							n=>$MAX ) );
		}
	
		my $code;
		if( $n_results == 0 )
		{
			$code = "no_hits";
		}
		elsif( $n_results == 1 )
		{
			$code = "one_hit";
		}
		else
		{
			$code = "n_hits";
		}
		my $p = $self->{session}->make_element( "p" );
		$page->appendChild( $p );
       		$p->appendChild(  
			$self->{session}->html_phrase( 
				"lib/searchexpression:".$code,  
				n => $self->{session}->make_text( 
							$n_results ) ) );

		if( @{ $self->{ignoredwords} } )
		{
			my %words = ();
			$p->appendChild( $self->{session}->make_text( " " ) );
			foreach( @{$self->{ignoredwords}} ) { $words{$_}++; }
			my $words = $self->{session}->make_text( 
					join( ", ", sort keys %words ) );
			$p->appendChild(
       				$self->{session}->html_phrase( 
					"lib/searchexpression:ignored",
					words => $words ) );
		
		}

		$p->appendChild( $self->{session}->make_text( " " ) );
		$p->appendChild(
       			$self->{session}->html_phrase( 
				"lib/searchexpression:search_time", 
				searchtime=>$self->{session}->make_text($t2-$t1),
				gettime=>$self->{session}->make_text($t3-$t2) ) );

		my $form = $self->{session}->make_form( "get" );
		foreach( $self->{session}->param() )
		{
			next if( $_ =~ m/^_/ );
			$form->appendChild(
				$self->{session}->make_hidden_field( $_ ) );
		}
		$form->appendChild( $self->{session}->make_action_buttons( 
			update => $self->{session}->phrase("lib/searchexpression:action_update"), 
			newsearch => $self->{session}->phrase("lib/searchexpression:action_newsearch") ) );
		$page->appendChild( $form );
		
		foreach (@results)
		{
			$p = $self->{session}->make_element( "p" );
			$p->appendChild( $_->to_html_link() );
			$page->appendChild( $p );
		}

		$page->appendChild( $form->cloneNode( 1 ) );
			
		# Print out state stuff for a further invocation
		$self->{session}->build_page( 
			$self->{session}->phrase( 
					"lib/searchexpression:results_for", 
					title => $title ),
			$page );
		$self->{session}->send_page();
		return;
	}

	if( defined $action_button && $action_button eq "newsearch" )
	{
		# To reset the form, just reset the URL.
		my $url = $self->{session}->get_url();
		# Remove everything that's part of the query string.
print STDERR "URLURL URL URL: $url\n";
		$url =~ s/\?.*//;
		$self->{session}->redirect( $url );
		return;
	}
	
	if( defined $action_button && $action_button eq "update" )
	{
		$self->from_form();
	}

	# Just print the form...

	my $page = $self->{session}->make_doc_fragment();
	$page->appendChild( $preamble );
	$page->appendChild( $self->render_search_form( 1 , 1 ) );

	$self->{session}->build_page( $title, $page );
	$self->{session}->send_page();
}

## WP1: BAD
sub _render_problems
{
	my( $self , $title, $preamble, @problems ) = @_;	
	# Problem with search expression. Report an error, and redraw the form
		
	my $page = $self->{session}->make_doc_fragment();
	$page->appendChild( $preamble );

	my $p = $self->{session}->make_element( "p" );
	$p->appendChild( $self->{session}->html_phrase( "lib/searchexpression:form_problem" ) );
	$page->appendChild( $p );
	my $ul = $self->{session}->make_element( "ul" );
	$page->appendChild( $ul );
	foreach (@problems)
	{
		my $li = $self->{session}->make_element( 
			"li",
			class=>"problem" );
		$ul->appendChild( $li );
		$li->appendChild( $self->{session}->make_text( $_ ) );
	}
	my $hr = $self->{session}->make_element( 
			"hr", 
			noshade=>"noshade",  
			size=>2 );
	$page->appendChild( $hr );
	$page->appendChild( $self->render_search_form );
			
	$self->{session}->build_page( $title, $page );
	$self->{session}->send_page();
}


1;
