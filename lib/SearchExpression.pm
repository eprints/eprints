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

#cjg non user defined sort methods => pass comparator method my reference
# eg. for later_in_thread

## WP1: BAD
sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
#print STDERR "k:[".join(",",keys %data)."]\n";
#print STDERR "SE1:[".$data{dataset}."]\n";
#print STDERR "SE2:[".$data{dataset}->confid()."]\n";
	# only session & table are required.
	# setup defaults for the others:
	$data{allow_blank} = 0 if ( !defined $data{allow_blank} );
	$data{satisfy_all} = 1 if ( !defined $data{satisfy_all} );
	$data{fieldnames} = [] if ( !defined $data{fieldnames} );

	foreach( qw/ session dataset allow_blank satisfy_all fieldnames staff / )
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
#print STDERR "FN: ".join(",",@{$self->{fieldnames}})."\n";
	my $fieldname;
	foreach $fieldname (@{$self->{fieldnames}})
	{
		# If the fieldname contains a /, it's a 
		# "search >1 at once" entry
		if( $fieldname =~ /\// )
		{
			# Split up the fieldnames
			my @multiple_names = split /\//, $fieldname;
			my @multiple_fields;
			
			# Put the MetaFields in a list
			foreach (@multiple_names)
			{
				push @multiple_fields, _searching_field( $self->{dataset}, $_ ); 
			}
			
			# Add a reference to the list
			$self->add_field( \@multiple_fields );
		}
		else
		{
			# Single field
			$self->add_field( _searching_field( $self->{dataset}, $fieldname ) );
		}
	}
	
	
	return( $self );
}

sub _searching_field
{
	my( $dataset, $fieldname ) = @_;

	my $useid = ( $fieldname=~s/\.id$// );
	# use id side of a field if the fieldname
	# ends in .id (and strip the .id)
#print STDERR "FN: ($fieldname)\n";
	my $field = $dataset->get_field( $fieldname );
	if( $field->get_property( "hasid" ) )
	{
		if( $useid )
		{
			$field = $field->get_id_field();
		}
		else
		{
			$field = $field->get_main_field();
		
		}
	}
	
	return $field;
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

	my $form = $self->{session}->render_form( "get" );
	my $div;

	my %shown_help;
	my $sf;
	foreach $sf ( @{$self->{searchfields}} )
	{
		$div = $self->{session}->make_element( 
				"div" , 
				class => "searchfieldname" );
		# cjg HMMM. This needs some sortings out 
		# It's not rendered from phrases so not INTL
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
		$menu = $self->{session}->render_option_list(
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
	$menu = $self->{session}->render_option_list(
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
	$div->appendChild( $self->{session}->render_action_buttons( 
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
	my $search_field;
	foreach $search_field ( @{$self->{searchfields}} )
	{
		my $prob = $search_field->from_form();
		$onedefined = 1 if( defined $search_field->{value} );
		
		push @problems, $prob if( defined $prob );
	}

	push @problems, $self->{session}->phrase( "lib/searchexpression:least_one" )
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

sub serialise
{
	my( $self ) = @_;

	my @parts;
	push @parts, $self->{allow_blank};
	push @parts, $self->{satisfy_all};
	push @parts, $self->{order};
	push @parts, $self->{dataset}->id();

	my $search_field;
	foreach $search_field (sort {$a->get_form_name() cmp $b->get_form_name()} @{$self->{searchfields}})
	{
		my $fieldstring = $search_field->serialise();
		next unless( defined $fieldstring );
		push @parts, $fieldstring;
	}
	my @escapedparts;
	foreach( @parts )
	{
		# clone the string, so we can escape it without screwing
		# up the origional.
		my $bit = $_;
		$bit =~ s/[\\\|]/\\$&/g; 
		push @escapedparts,$bit;
	}
	return join( "|" , @escapedparts );
}	

sub unserialise
{
	#foreach( qw/ session dataset allow_blank satisfy_all fieldnames staff / )
}
	


sub perform_search
{
	my( $self ) = @_;

	my $matches = [];
	my $firstpass = 1;
	$self->{ignoredwords} = [];
	$self->{error} = undef;
	my @searchon = ();
	my $search_field;
	foreach $search_field ( @{$self->{searchfields}} )
	{
		if( $search_field->is_set() )
		{
			push @searchon , $search_field;
		}
	}
	foreach $search_field ( @searchon )
	{
		my ( $results , $badwords , $error) = $search_field->do();
	
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
		if( $firstpass )
		{
			$matches = $results;
		}
		else
		{
			$matches = &_merge( $matches, $results, $self->{satisfy_all} );
		}

		$firstpass = 0;
	}
	if( scalar @searchon == 0 )
	{
		$self->{tmptable} = ( $self->{allow_blank} ? "ALL" : "NONE" );
	}
	else
	{
		$self->{tmptable} = $self->{session}->get_db()->make_buffer( $self->{dataset}->get_key_field()->get_name(), $matches );
	}
}

sub _merge
{
	my( $a, $b, $and ) = @_;

	my @c;
	if ($and) {
		my (%MARK);
		grep($MARK{$_}++,@{$a});
		@c = grep($MARK{$_},@{$b});
	} else {
		my (%MARK);
		foreach(@{$a}, @{$b}) {
			$MARK{$_}++;
		}
		@c = keys %MARK;
	}
	return \@c;
}

sub dispose
{
	my( $self ) = @_;

	print STDERR "Disposing:\n".$self->serialise()."\n";

	if( $self->{tmptable} ne "ALL" && $self->{tmptable} ne "NONE" )
	{
		$self->{session}->get_db()->dispose_buffer( $self->{tmptable} );
	}
}

## WP1: BAD
sub count 
{
	my( $self ) = @_;

	if( defined $self->{tmptable} )
	{
		if( $self->{tmptable} eq "NONE" )
		{
			return 0;
		}

		if( $self->{tmptable} eq "ALL" )
		{
			return $self->{dataset}->count();
		}

		return $self->{session}->get_db()->count_table( 
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
		if( $self->{tmptable} eq "NONE" )
		{
			return ();
		}
		my $srctable;
		if( $self->{tmptable} eq "ALL" )
		{
			$srctable = $self->{dataset}->get_sql_table_name();
		}
		else
		{
			$srctable = $self->{tmptable};
		}
		

        	my( $keyfield ) = $self->{dataset}->get_key_field();
		my( $buffer, $overlimit ) = 
			$self->{session}->get_db()->distinct_and_limit( 
							$srctable,
							$keyfield, 
							$max );

		my @records = $self->{session}->get_db()->from_buffer( 
							$self->{dataset}, 
							$buffer );

		# We don't bother sorting if we got too many results.	
		# or no order method was specified.
		if( !$overlimit && defined $self->{order})
		{
 #print STDERR "order_methods " , $self->{dataset}->confid(). " ". $self->{order} ;
#print STDERR "ORDER BY: $self->{order}\n";

			my $cmpmethod = $self->{session}->get_archive()->get_conf( 
						"order_methods" , 
						$self->{dataset}->confid, 
						$self->{order} );

			@records = sort { &{$cmpmethod}($a,$b); } @records;
		}
		#cjg Don't erase this buffer if we need it later...
		# in fact it should not be temporary!
		$self->{session}->get_db()->dispose_buffer( $buffer );
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
		$self->dispose();

		my $page = $self->{session}->make_doc_fragment();

		if( $n_results > $MAX) 
		{
			$page->appendChild( 
				$self->{session}->html_phrase( 
							"lib/searchexpression:too_many", 
							n=>$self->{session}->make_text( $MAX ) ) );
		}
	
		my $p = $self->{session}->make_element( "p" );
		$page->appendChild( $p );
       		$p->appendChild(  
			$self->{session}->html_phrase( 
				"lib/searchexpression:results_found",
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

		my $form = $self->{session}->render_form( "get" );
		foreach( $self->{session}->param() )
		{
			next if( $_ =~ m/^_/ );
			$form->appendChild(
				$self->{session}->render_hidden_field( $_ ) );
		}
		$form->appendChild( $self->{session}->render_action_buttons( 
			update => $self->{session}->phrase("lib/searchexpression:action_update"), 
			newsearch => $self->{session}->phrase("lib/searchexpression:action_newsearch") ) );
		$page->appendChild( $form );

		my $result;
		foreach $result (@results)
		{
			$p = $self->{session}->make_element( "p" );
			$p->appendChild( $result->render_citation_link( undef, $self->{staff} ) );
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
#print STDERR "URLURL URL URL: $url\n";
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

	$page->appendChild( $self->{session}->html_phrase( "lib/searchexpression:form_problem" ) );
	my $ul = $self->{session}->make_element( "ul" );
	$page->appendChild( $ul );
	my $problem;
	foreach $problem (@problems)
	{
		my $li = $self->{session}->make_element( 
			"li",
			class=>"problem" );
		$ul->appendChild( $li );
		$li->appendChild( $self->{session}->make_text( $problem ) );
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
