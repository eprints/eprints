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

$EPrints::SearchExpression::CustomOrder = "_CUSTOM_";

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

sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
	# only session & table are required.
	# setup defaults for the others:
	$data{allow_blank} = 0 if ( !defined $data{allow_blank} );
	$data{use_cache} = 0 if ( !defined $data{use_cache} );
	$data{satisfy_all} = 1 if ( !defined $data{satisfy_all} );
	$data{fieldnames} = [] if ( !defined $data{fieldnames} );

	# 
	foreach( qw/ session dataset allow_blank satisfy_all fieldnames staff order use_cache custom_order use_oneshot_cache use_private_cache cache_id / )
	{
		$self->{$_} = $data{$_};
	}

	if( defined $self->{custom_order} ) 
	{ 
		$self->{order} = $EPrints::SearchExpression::CustomOrder;
		# can't cache a search with a custom ordering.
		$self->{use_cache} = 0;
		$self->{use_oneshot_cache} = 1;
	}

	# Array for the SearchField objects
	$self->{searchfields} = [];
	# Map for MetaField names -> corresponding SearchField objects
	$self->{searchfieldmap} = {};

	# tmptable represents cached results table.	
	$self->{tmptable} = undef;

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
				push @multiple_fields, EPrints::Utils::field_from_config_string( $self->{dataset}, $_ );
			}
			
			# Add a reference to the list
			$self->add_field( \@multiple_fields );
		}
		else
		{
			# Single field
			$self->add_field( EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname ) );
		}
	}

	if( defined $self->{cache_id} )
	{
		my $string = $self->{session}->get_db()->cache_exp( $self->{cache_id} );
		return undef if( !defined $string );
		$self->_unserialise_aux( $string );
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

	#field may be a field OR a ref to an array of fields

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

sub get_searchfield
{
	my( $self, $formname ) = @_;
	
	return $self->{searchfieldmap}->{$formname};
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

	my $form = $self->{session}->render_form( "get" );

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
		$form->appendChild( $sf->render() );
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
		_order => [ "search", "newsearch" ],
		newsearch => $self->{session}->phrase( "lib/searchexpression:action_reset" ),
		search => $self->{session}->phrase( "lib/searchexpression:action_search" ) )
 	);
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

sub get_order
{
	my( $self ) = @_;
	return $self->{order};
}

sub get_satisfy_all
{
	my( $self ) = @_;
	return $self->{satisfy_all};
}

sub from_form
{
	my( $self ) = @_;

	my $exp = $self->{session}->param( "_exp" );
	if( defined $exp )
	{
		my $fromexp = EPrints::SearchExpression->unserialise( $self->{session}, $exp );
		$self->{order} = $fromexp->get_order();
		$self->{satisfy_all} = $fromexp->get_satisfy_all();
		my $search_field;
		foreach $search_field ( @{$self->{searchfields}} )
		{
			my $formname = $search_field->get_form_name();
			my $sf = $fromexp->get_searchfield( $formname );
			if( defined $sf )
			{
				$self->add_field( $sf->get_fields() , $sf->get_value() );
			}
		}
		return;
	}

	my @problems;
	my $onedefined = 0;
	my $search_field;
	foreach $search_field ( @{$self->{searchfields}} )
	{
		my $prob = $search_field->from_form();
		$onedefined = 1 if( defined $search_field->{value} );
		
		push @problems, $prob if( defined $prob );
	}
	my $anyall = $self->{session}->param( "_satisfyall" );

	if( defined $anyall )
	{
		$self->{satisfy_all} = ( $anyall eq "ALL" );
	}
	
	$self->{order} = $self->{session}->param( "_order" );

	push @problems, $self->{session}->phrase( "lib/searchexpression:least_one" )
		unless( $self->{allow_blank} || $onedefined );

	
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

	# nb. We don't serialise 'staff mode' as that does not affect the
	# results of a search, only how it is represented.

	my @parts;
	push @parts, $self->{allow_blank}?1:0;
	push @parts, $self->{satisfy_all}?1:0;
	push @parts, $self->{order};
	push @parts, $self->{dataset}->id();
	# This inserts an "-" field which we use to spot the join between
	# the properties and the fields, so in a pinch we can add a new 
	# property in a later version without breaking when we upgrade.
	push @parts, "-";
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
		$bit="" unless defined( $bit );
		$bit =~ s/[\\\|]/\\$&/g; 
		push @escapedparts,$bit;
	}
	return join( "|" , @escapedparts );
}	

sub unserialise
{
	my( $class, $session, $string, %opts ) = @_;

	my $searchexp = $class->new( session=>$session, %opts );
	$searchexp->_unserialise_aux( $string );
	return $searchexp;
}

sub _unserialise_aux
{
	my( $self, $string ) = @_;

	my( $pstring , $fstring ) = split /\|-\|/ , $string ;

	my @parts = split( /\|/ , $pstring );
	$self->{allow_blank} = $parts[0];
	$self->{satisfy_all} = $parts[1];
	$self->{order} = $parts[2];
	$self->{dataset} = $self->{session}->get_archive()->get_dataset( $parts[3] );
	$self->{searchfields} = [];
	$self->{searchfieldmap} = {};
#######
	foreach( split /\|/ , $fstring )
	{
		my $searchfield = EPrints::SearchField->unserialise(
			$self->{session}, $self->{dataset}, $_ );

		# Add it to our list
		push @{$self->{searchfields}}, $searchfield;
		# Put it in the name -> searchfield map
		my $formname = $searchfield->get_form_name();
		$self->{searchfieldmap}->{$formname} = $searchfield;
		
	}
}

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}

sub perform_search
{
	my( $self ) = @_;
	$self->{ignoredwords} = [];
	$self->{error} = undef;

	if( $self->{use_cache} && !defined $self->{cache_id} )
	{
		$self->{cache_id} = $self->{session}->get_db()->cache_id( $self->serialise() );
	}

	if( defined $self->{cache_id} )
	{
		return;
	}


	my $matches = [];
	my $firstpass = 1;
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

	my $srctable;
	if( $self->{tmptable} eq "ALL" )
	{
		$srctable = $self->{dataset}->get_sql_table_name();
	}
	else
	{
		$srctable = $self->{tmptable};
	}
	
	if( $self->{use_cache} || $self->{use_oneshot_cache} || $self->{use_private_cache} )
	{
		my $order;
		if( defined $self->{order} )
		{
			if( $self->{order} eq $EPrints::SearchExpression::CustomOrder )
			{
				$order = $self->{custom_order};
			}
			else
			{
				$order = $self->{session}->get_archive()->get_conf( 
						"order_methods" , 
						$self->{dataset}->confid() ,
						$self->{order} );
			}
		}

		$self->{cache_id} = $self->{session}->get_db()->cache( 
			$self->serialise(), 
			$self->{dataset},
			$srctable,
			$order,
			!$self->{use_cache} ); # only public if use_cache
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

	#my $sstring = $self->serialise();

	if( $self->{tmptable} ne "ALL" && $self->{tmptable} ne "NONE" )
	{
		$self->{session}->get_db()->dispose_buffer( $self->{tmptable} );
	}
	#cjg drop_cache/dispose_buffer : should be one or the other.
	if( defined $self->{cache_id} && !$self->{use_cache} && !$self->{use_private_cache} )
	{
		$self->{session}->get_db()->drop_cache( $self->{cache_id} );
	}
}

# Note, is number returned, not number of matches.(!! what does that mean?)
sub count 
{
	my( $self ) = @_;

	#cjg special with cache!
	if( defined $self->{cache_id} )
	{
		#cjg Hmm. Would rather use func to make cache name.
		return $self->{session}->get_db()->count_table( "cache".$self->{cache_id} );
	}

	if( $self->{use_cache} && $self->{session}->get_db()->is_cached( $self->serialise() ) )
	{
		return $self->{session}->get_db()->count_cache( $self->serialise() );
	}

	if( defined $self->{tmptable} )
	{
		if( $self->{tmptable} eq "NONE" )
		{
			return 0;
		}

		if( $self->{tmptable} eq "ALL" )
		{
			return $self->{dataset}->count( $self->{session} );
		}

		return $self->{session}->get_db()->count_table( 
			$self->{tmptable} );
	}	
	#cjg ERROR to user?
	$self->{session}->get_archive()->log( "Search has not been performed" );
		
}

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 0 );
}

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 1 );
}

sub _get_records 
{
	my ( $self , $offset , $count, $justids ) = @_;

	if( defined $self->{cache_id} )
	{
		return $self->{session}->get_db()->from_cache( 
							$self->{dataset}, 
							undef,
							$self->{cache_id},
							$offset,
							$count,	
							$justids );
	}
		
	if( !defined $self->{tmptable} )
	{
		#ERROR TO USER cjg
		$self->{session}->get_archive()->log( "Search not yet performed" );
		return ();
	}

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

	return $self->{session}->get_db()->from_buffer( 
					$self->{dataset}, 
					$srctable );
}

sub map
{
	my( $self, $function, $info ) = @_;	

	my $count = $self->count();

	my $CHUNKSIZE = 512;

	my $offset;
	for( $offset = 0; $offset < $count; $offset+=$CHUNKSIZE )
	{
		my @records = $self->get_records( $offset, $CHUNKSIZE );
		my $item;
		foreach $item ( @records )
		{
			&{$function}( $self->{session}, $self->{dataset}, $item, $info );
		}
	}
}

######################################################################
#
# process_webpage( $title, $preamble )
#                  string  DOM
#
#  Process the search form, writing out the form and/or results.
#
######################################################################

sub process_webpage
{
	my( $self, $title, $preamble ) = @_;

	#cjg ONLY SHOW time and badwords on first page.

	my $pagesize = $self->{session}->get_archive()->get_conf( "results_page_size" );

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

		my $offset = $self->{session}->param( "_offset" ) + 0;

		@results = $self->get_records( $offset , $pagesize );
		$t3 = EPrints::Session::microtime();
		$self->dispose();

		my $page = $self->{session}->make_doc_fragment();

		my $plast = $offset + $pagesize;
		$plast = $n_results if $n_results< $plast;
		my $p = $self->{session}->make_element( "p", class=>"resultsinfo" );
		$page->appendChild( $p );
		if( scalar $n_results > 0 )
		{
       			$p->appendChild(  
				$self->{session}->html_phrase( 
					"lib/searchexpression:results",
					from => $self->{session}->make_text( $offset+1 ),
					to => $self->{session}->make_text( $plast ),
					n => $self->{session}->make_text( $n_results )  
				) );
		}
		else
		{
       			$p->appendChild(  
				$self->{session}->html_phrase( 
					"lib/searchexpression:noresults" ) );
		}

		if( @{ $self->{ignoredwords} } )
		{
			my %words = ();
			$p->appendChild( $self->{session}->make_text( " " ) );
			foreach( @{$self->{ignoredwords}} ) { $words{$_}++; }
			my $words = $self->{session}->make_doc_fragment();
			my $first = 1;
			foreach( sort keys %words )
			{
				unless( $first )
				{
					$words->appendChild( 
						$self->{session}->make_text( ", " ) );
				}
				my $span = $self->{session}->make_element( "span", class=>"ignoredword" );
				$words->appendChild( $span );
				$span->appendChild( 
					$self->{session}->make_text( $_ ) );
				$first = 0;
			}
			$p->appendChild(
       				$self->{session}->html_phrase( 
					"lib/searchexpression:ignored",
					words => $words ) );
		
		}

		$p->appendChild( $self->{session}->make_text( " " ) );
		$p->appendChild(
       			$self->{session}->html_phrase( 
				"lib/searchexpression:search_time", 
				searchtime=>$self->{session}->make_text($t3-$t1) ) );

		my $links = $self->{session}->make_doc_fragment();
		my $controls = $self->{session}->make_element( "p", class=>"searchcontrols" );
		my $url = $self->{session}->get_url();
		#cjg escape URL'ify urls in this bit... (4 of them?)
		my $escexp = $self->serialise();	
		$escexp =~ s/ /+/g; # not great way...
		my $a;
		if( $offset > 0 ) 
		{
			my $bk = $offset-$pagesize;
			my $href = "$url?_exp=$escexp&_offset=".($bk<0?0:$bk);
			$a = $self->{session}->make_element( "a", href=>$href );
			my $pn = $pagesize>$offset?$offset:$pagesize;
			$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:prev",
						n=>$self->{session}->make_text( $pn ) ) );
			$controls->appendChild( $a );
			$controls->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );
			$links->appendChild( $self->{session}->make_element( "link",
							rel=>"Prev",
							href=>$href ) );
		}

		$a = $self->{session}->make_element( "a", href=>"$url?_exp=$escexp&_action_update=1" );
		$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:refine" ) );
		$controls->appendChild( $a );
		$controls->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );

		$a = $self->{session}->make_element( "a", href=>$url );
		$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:new" ) );
		$controls->appendChild( $a );

		if( $offset + $pagesize < $n_results )
		{
			my $href="$url?_exp=$escexp&_offset=".($offset+$pagesize);
			$a = $self->{session}->make_element( "a", href=>$href );
			my $nn = $n_results - $offset - $pagesize;
			$nn = $pagesize if( $pagesize < $nn);
			$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:next",
						n=>$self->{session}->make_text( $nn ) ) );
			$controls->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );
			$controls->appendChild( $a );
			$links->appendChild( $self->{session}->make_element( "link",
							rel=>"Next",
							href=>$href ) );
		}

		$page->appendChild( $controls );

		my $result;
		foreach $result (@results)
		{
			$p = $self->{session}->make_element( "p" );
			$p->appendChild( $result->render_citation_link( undef, $self->{staff} ) );
			$page->appendChild( $p );
		}
		

		if( scalar $n_results > 0 )
		{
			# Only print a second set of controls if there are matches.
			$page->appendChild( $controls->cloneNode( 1 ) );
		}


			
		$self->{session}->build_page( 
			$self->{session}->html_phrase( 
					"lib/searchexpression:results_for", 
					title => $title ),
			$page,
			$links );
		$self->{session}->send_page();
		return;
	}

	if( defined $action_button && $action_button eq "newsearch" )
	{
		# To reset the form, just reset the URL.
		my $url = $self->{session}->get_url();
		# Remove everything that's part of the query string.
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
	$page->appendChild( $self->render_search_form( 1 , 1 ) );
			
	$self->{session}->build_page( $title, $page );
	$self->{session}->send_page();
}

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}

sub set_dataset
{
	my( $self, $dataset ) = @_;

	$self->{dataset} = $dataset;
	foreach (@{$self->{searchfields}})
	{
		$_->set_dataset( $dataset );
	}
}

1;
