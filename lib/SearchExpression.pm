######################################################################
#
# EPrints::SearchExpression
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


# SHOULD HAVE SOME KIND OF cache setting if order is specified or we
# plan to map!

=pod

=head1 NAME

B<EPrints::SearchExpression> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
#  Search Expression
#
#   Represents a whole set of search fields.
#
######################################################################
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

use URI::Escape;
use strict;
# order method not presercved.

$EPrints::SearchExpression::CustomOrder = "_CUSTOM_";


#cjg non user defined sort methods => pass comparator method my reference
# eg. for later_in_thread


######################################################################
=pod

=item $thing = EPrints::SearchExpression->new( %data )

undocumented

=cut
######################################################################

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
	$data{prefix} = "" if ( !defined $data{prefix} );

	# 
	foreach( qw/ session dataset allow_blank satisfy_all fieldnames staff order use_cache custom_order use_oneshot_cache use_private_cache cache_id prefix defaults / )
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
	if( !defined $self->{defaults} ) 
	{ 
		$self->{defaults} = {};
	}


	# Array for the SearchField objects
	$self->{searchfields} = [];
	# Map for MetaField names -> corresponding SearchField objects
	$self->{searchfieldmap} = {};

	$self->{allfields} = [];

	# tmptable represents cached results table.	
	$self->{tmptable} = undef;

	# Little hack to solve the problem of not knowing what
	# the fields in the subscription spec are until we load
	# the config.
	if( $self->{fieldnames} eq "subscriptionfields" )
	{
		$self->{fieldnames} = $self->{session}->get_archive->get_conf(
			"subscription_fields" );
	}
	if( $self->{fieldnames} eq "editpermfields" )
	{
		$self->{fieldnames} = $self->{session}->get_archive->get_conf(
			"editor_limit_fields" );
#cjg
	}

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
			$self->add_field( \@multiple_fields, $self->{defaults}->{$fieldname} );
		}
		elsif( $fieldname =~ m/^!(.*)$/ )
		{
			# "extra" field - one not in the current dataset.
			$self->add_extrafield( $data{extrafields}->{$1}, $self->{defaults}->{$fieldname} );
		}
		else
		{
			# Single field
			
			$self->add_field( EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname ), $self->{defaults}->{$fieldname} );
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


######################################################################
=pod

=item $foo = $thing->add_field( $field, $value, $match, $merge, $extra )

undocumented

=cut
######################################################################

sub add_field
{
	my( $self, $field, $value, $match, $merge, $extra ) = @_;

	#field may be a field OR a ref to an array of fields

	# Create a new searchfield
	my $searchfield = EPrints::SearchField->new( $self->{session},
	                                             $self->{dataset},
	                                             $field,
	                                             $value,
	                                             $match,
	                                             $merge,
                                                     $self->{prefix} );

	my $sf_id = $searchfield->get_id();
	unless( defined $self->{searchfieldmap}->{$sf_id} )
	{
		# Add it to our list
		# if it's "extra" then it's not a searchfield
		# but will still appear on the form.

		unless( $extra )
		{
			push @{$self->{searchfields}}, $sf_id;
		}
		push @{$self->{allfields}}, $sf_id;
	}
	# Put it in the name -> searchfield map
	# (possibly replacing an old one)
	$self->{searchfieldmap}->{$sf_id} = $searchfield;
}


######################################################################
=pod

=item $foo = $thing->add_extrafield( $field, $value, $match, $merge )

undocumented

=cut
######################################################################

sub add_extrafield
{
	my( $self, $field, $value, $match, $merge ) = @_;

	$self->add_field( $field, $value, $match, $merge, 1 );
}


######################################################################
=pod

=item $foo = $thing->get_searchfield( $sf_id )

undocumented

=cut
######################################################################

sub get_searchfield
{
	my( $self, $sf_id ) = @_;
	
	return $self->{searchfieldmap}->{$sf_id};
}

######################################################################
#
# clear()
#
#  Clear the search values of all search fields in the expression.
#
######################################################################


######################################################################
=pod

=item $foo = $thing->clear

undocumented

=cut
######################################################################

sub clear
{
	my( $self ) = @_;
	
	foreach (@{$self->{searchfields}})
	{
		$self->get_searchfield($_)->clear();
	}
	
	$self->{satisfy_all} = 1;
}



######################################################################
=pod

=item $xhtml = $thing->render_search_fields( [$help] )

Renders the search fields for this search expression for inclusion
in a form. If $help is true then this also renders the help for
each search field.

=cut
######################################################################

sub render_search_fields
{
	my( $self, $help ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	my %shown_help;
	foreach ( @{$self->{allfields}} )
	{
		my $sf = $self->get_searchfield( $_ );
		my $div = $self->{session}->make_element( 
				"div" , 
				class => "searchfieldname" );
		$div->appendChild( $self->{session}->make_text( 
					$sf->get_display_name ) );
		$frag->appendChild( $div );
		my $shelp = $sf->get_help();
		if( $help && !defined $shown_help{$shelp} )
		{
			$div = $self->{session}->make_element( 
				"div" , 
				class => "searchfieldhelp" );
			$div->appendChild( $self->{session}->make_text( $shelp ) );
			$frag->appendChild( $div );
			#$shown_help{$shelp}=1;
		}

		$div = $self->{session}->make_element( 
			"div" , 
			class => "searchfieldinput" );
		$frag->appendChild( $sf->render() );
	}

	return $frag;
}


######################################################################
=pod

=item $foo = $thing->render_search_form( $help, $show_anyall )

undocumented

=cut
######################################################################

sub render_search_form
{
	my( $self, $help, $show_anyall ) = @_;

	my $form = $self->{session}->render_form( "get" );
	$form->appendChild( $self->render_search_fields( $help ) );

	my $div;
	my $menu;

	if( $show_anyall )
	{
		$menu = $self->{session}->render_option_list(
			name=>$self->{prefix}."_satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{satisfy_all} && $self->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{session}->phrase( "lib/searchexpression:all" ),
				  "ANY" => $self->{session}->phrase( "lib/searchexpression:any" )} );

		my $div = $self->{session}->make_element( 
			"div" , 
			class => "searchanyall" );
		$div->appendChild( 
			$self->{session}->html_phrase( 
				"lib/searchexpression:must_fulfill",  
				anyall=>$menu ) );
		$form->appendChild( $div );	
	}

	$form->appendChild( $self->render_order_menu );

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
=pod

=item $foo = $thing->render_order_menu

undocumented

=cut
######################################################################

sub render_order_menu
{
	my( $self ) = @_;

	my @tags = keys %{$self->{session}->get_archive()->get_conf(
			"order_methods",
			$self->{dataset}->confid )};
	my $menu = $self->{session}->render_option_list(
		name=>$self->{prefix}."_order",
		values=>\@tags,
		default=>$self->{order},
		labels=>$self->{session}->get_order_names( 
						$self->{dataset} ) );
	my $div = $self->{session}->make_element( 
		"div" , 
		class => "searchorder" );
	$div->appendChild( 
		$self->{session}->html_phrase( 
			"lib/searchexpression:order_results", 
			ordermenu => $menu  ) );

	return $div;
}



######################################################################
=pod

=item $foo = $thing->get_order

undocumented

=cut
######################################################################

sub get_order
{
	my( $self ) = @_;
	return $self->{order};
}


######################################################################
=pod

=item $foo = $thing->get_satisfy_all

undocumented

=cut
######################################################################

sub get_satisfy_all
{
	my( $self ) = @_;
	return $self->{satisfy_all};
}


######################################################################
=pod

=item $foo = $thing->from_form

undocumented

=cut
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $exp = $self->{session}->param( "_exp" );
	if( defined $exp )
	{
		$self->from_string( $exp );
		return;
	}

	my @problems;
	foreach( @{$self->{searchfields}} )
	{
		my $search_field = $self->get_searchfield( $_ );
		my $prob = $search_field->from_form();
		push @problems, $prob if( defined $prob );
	}
	my $anyall = $self->{session}->param( $self->{prefix}."_satisfyall" );

	if( defined $anyall )
	{
		$self->{satisfy_all} = ( $anyall eq "ALL" );
	}
	
	$self->{order} = $self->{session}->param( $self->{prefix}."_order" );

	if( $self->is_blank && ! $self->{allow_blank} )
	{
		push @problems, $self->{session}->phrase( 
			"lib/searchexpression:least_one" );
	}
	
	return( scalar @problems > 0 ? \@problems : undef );
}


######################################################################
=pod

=item $boolean = $searchexp->is_blank

Return true is this searchexpression has no conditions set, otherwise
true.

=cut
######################################################################

sub is_blank
{
	my( $self ) = @_;

	foreach( @{$self->{searchfields}} )
	{
		my $search_field = $self->get_searchfield( $_ );
		return 0 if( defined $search_field->get_value() );
	}
	return 1;
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


######################################################################
=pod

=item $foo = $thing->serialise

undocumented

=cut
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
	foreach (sort @{$self->{searchfields}})
	{
		my $search_field = $self->get_searchfield( $_ );
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

######################################################################
=pod

=item $searchexp->from_string( $string )

Unserialises the contents of $string but only into the fields alrdeady
existing in $searchexp. Set the order and satisfy_all mode but do not 
affect the dataset or allow blank.

=cut
######################################################################

sub from_string
{
	my( $self, $string ) = @_;

	my $fromexp = EPrints::SearchExpression->unserialise( 
			$self->{session}, $string );
	$self->{order} = $fromexp->get_order();
	$self->{satisfy_all} = $fromexp->get_satisfy_all();
	my $search_field;
	foreach ( @{$self->{searchfields}} )
	{
		my $search_field = $self->get_searchfield( $_ );

		my $sf_id = $search_field->get_id();
		my $sf = $fromexp->get_searchfield( $sf_id );
		if( defined $sf )
		{
			$self->add_field( 
				$sf->get_fields(), 
				$sf->get_value(),
				$sf->get_match(),  
				$sf->get_merge() );
		}
	}
}

######################################################################
=pod

=item $thing = EPrints::SearchExpression->unserialise( $session, $string, %opts )

undocumented

=cut
######################################################################

sub unserialise
{
	my( $class, $session, $string, %opts ) = @_;

	my $searchexp = $class->new( session=>$session, %opts );
	$searchexp->_unserialise_aux( $string );
	return $searchexp;
}

######################################################################
# 
# $foo = $thing->_unserialise_aux( $string )
#
# undocumented
#
######################################################################

sub _unserialise_aux
{
	my( $self, $string ) = @_;

	return unless( EPrints::Utils::is_set( $string ) );

	my( $pstring , $fstring ) = split /\|-\|/ , $string ;
	$fstring = "" unless( defined $fstring ); # avoid a warning

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

		my $sf_id = $searchfield->get_id();
		# Add it to our list
		push @{$self->{searchfields}}, $sf_id;
		# Put it in the name -> searchfield map
		$self->{searchfieldmap}->{$sf_id} = $searchfield;
		
	}
}


######################################################################
=pod

=item $foo = $thing->get_cache_id

undocumented

=cut
######################################################################

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}


######################################################################
=pod

=item $foo = $thing->perform_search

undocumented

=cut
######################################################################

sub perform_search
{
	my( $self ) = @_;
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
	foreach ( @{$self->{searchfields}} )
	{
		$search_field = $self->get_searchfield( $_ );
		if( $search_field->is_set() )
		{
			push @searchon , $search_field;
		}
	}
	foreach $search_field ( @searchon )
	{
		my ( $results, $error) = $search_field->do();

		if( defined $error )
		{
			$self->{tmptable} = undef;
			$self->{error} = $error;
			return;
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

######################################################################
# 
# EPrints::SearchExpression::_merge( $a, $b, $and )
#
# undocumented
#
######################################################################

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


######################################################################
=pod

=item $foo = $thing->dispose

undocumented

=cut
######################################################################

sub dispose
{
	my( $self ) = @_;

	#my $sstring = $self->serialise();

	if( 
		defined $self->{tmptable} && 
		$self->{tmptable} ne "ALL" && 
		$self->{tmptable} ne "NONE" )
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

######################################################################
=pod

=item $foo = $thing->count 

undocumented

=cut
######################################################################

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


######################################################################
=pod

=item $foo = $thing->get_records( $offset, $count )

undocumented

=cut
######################################################################

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 0 );
}


######################################################################
=pod

=item $foo = $thing->get_ids( $offset, $count )

undocumented

=cut
######################################################################

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 1 );
}

######################################################################
# 
# $foo = $thing->_get_records ( $offset, $count, $justids )
#
# undocumented
#
######################################################################

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
					$srctable,
					$offset,
					$count,
					$justids );
}


######################################################################
=pod

=item $foo = $thing->map( $function, $info )

undocumented

=cut
######################################################################

sub map
{
	my( $self, $function, $info ) = @_;	

	my $count = $self->count();

	my $CHUNKSIZE = 100;

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


######################################################################
=pod

=item $foo = $thing->process_webpage( $title, $preamble )

undocumented

=cut
######################################################################

sub process_webpage
{
	my( $self, $title, $preamble ) = @_;

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

		my $plast = $offset + $pagesize;
		$plast = $n_results if $n_results< $plast;

		my %bits = ();
		
		if( scalar $n_results > 0 )
		{
			$bits{matches} = 
				$self->{session}->html_phrase( 
					"lib/searchexpression:results",
					from => $self->{session}->make_text( $offset+1 ),
					to => $self->{session}->make_text( $plast ),
					n => $self->{session}->make_text( $n_results )  
				);
		}
		else
		{
			$bits{matches} = 
				$self->{session}->html_phrase( 
					"lib/searchexpression:noresults" );
		}

		$bits{time} = $self->{session}->html_phrase( 
			"lib/searchexpression:search_time", 
			searchtime => $self->{session}->make_text($t3-$t1) );

		$bits{searchdesc} = $self->render_description;

		my $links = $self->{session}->make_doc_fragment();
		$bits{controls} = $self->{session}->make_element( "p", class=>"searchcontrols" );
		my $url = $self->{session}->get_url();
		#cjg escape URL'ify urls in this bit... (4 of them?)
		my $escexp = $self->serialise();	
		$escexp =~ s/ /+/g; # not great way...
		my $a;
		if( $offset > 0 ) 
		{
			my $bk = $offset-$pagesize;
			my $fullurl = "$url?_exp=$escexp&_offset=".($bk<0?0:$bk);
			$a = $self->{session}->render_link( $fullurl );
			my $pn = $pagesize>$offset?$offset:$pagesize;
			$a->appendChild( 
				$self->{session}->html_phrase( 
					"lib/searchexpression:prev",
					n=>$self->{session}->make_text( $pn ) ) );
			$bits{controls}->appendChild( $a );
			$bits{controls}->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );
			$links->appendChild( $self->{session}->make_element( "link",
							rel=>"Prev",
							href=>EPrints::Utils::url_escape( $fullurl ) ) );
		}

		$a = $self->{session}->render_link( "$url?_exp=$escexp&_action_update=1" );
		$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:refine" ) );
		$bits{controls}->appendChild( $a );
		$bits{controls}->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );

		$a = $self->{session}->render_link( $url );
		$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:new" ) );
		$bits{controls}->appendChild( $a );

		if( $offset + $pagesize < $n_results )
		{
			my $fullurl="$url?_exp=$escexp&_offset=".($offset+$pagesize);
			$a = $self->{session}->render_link( $fullurl );
			my $nn = $n_results - $offset - $pagesize;
			$nn = $pagesize if( $pagesize < $nn);
			$a->appendChild( $self->{session}->html_phrase( "lib/searchexpression:next",
						n=>$self->{session}->make_text( $nn ) ) );
			$bits{controls}->appendChild( $self->{session}->html_phrase( "lib/searchexpression:seperator" ) );
			$bits{controls}->appendChild( $a );
			$links->appendChild( $self->{session}->make_element( "link",
							rel=>"Next",
							href=>EPrints::Utils::url_escape( $fullurl ) ) );
		}

		$bits{results} = $self->{session}->make_doc_fragment;
		foreach my $result ( @results )
		{
			my $p = $self->{session}->make_element( "p" );
			$p->appendChild( 
				$result->render_citation_link( 
					undef, 
					$self->{staff} ) );
			$bits{results}->appendChild( $p );
		}
		

		if( scalar $n_results > 0 )
		{
			# Only print a second set of controls if 
			# there are matches.
			$bits{controls_if_matches} = 
				EPrints::XML::clone_node( $bits{controls}, 1 );
		}
		else
		{
			$bits{controls_if_matches} = 
				$self->{session}->make_doc_fragment;
		}

		my $page = $self->{session}->html_phrase(
			"lib/searchexpression:results_page",
			%bits );
	
		$self->{session}->build_page( 
			$self->{session}->html_phrase( 
					"lib/searchexpression:results_for", 
					title => $title ),
			$page,
			"search_results",
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

	$self->{session}->build_page( $title, $page, "search_form" );
	$self->{session}->send_page();
}

######################################################################
# 
# $foo = $thing->_render_problems( $title, $preamble, @problems )
#
# undocumented
#
######################################################################

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
			
	$self->{session}->build_page( $title, $page, "search_problems" );
	$self->{session}->send_page();
}


######################################################################
=pod

=item $foo = $thing->get_dataset

undocumented

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}


######################################################################
=pod

=item $foo = $thing->set_dataset( $dataset )

undocumented

=cut
######################################################################

sub set_dataset
{
	my( $self, $dataset ) = @_;

	$self->{dataset} = $dataset;
	foreach (@{$self->{searchfields}})
	{
		$self->get_searchfield( $_ )->set_dataset( $dataset );
	}
}


######################################################################
=pod

=item $xhtml = $thing->render_description

Return an XHTML DOM description of this search expressions current
parameters.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	my @bits = ();
	foreach( keys %{$self->{searchfieldmap}} )
	{
		my $sf = $self->{searchfieldmap}->{$_};
		next unless( EPrints::Utils::is_set( $sf->get_value ) );
		push @bits, $sf->render_description;
	}

	my $joinphraseid = "lib/searchexpression:desc_or";
	if( $self->{satisfy_all} )
	{
		$joinphraseid = "lib/searchexpression:desc_and";
	}

	for( my $i=0; $i<scalar @bits; ++$i )
	{
		if( $i>0 )
		{
			$frag->appendChild( $self->{session}->html_phrase( 
				$joinphraseid ) );
		}
		$frag->appendChild( $bits[$i] );
	}

	if( scalar @bits > 0 )
	{
		$frag->appendChild( $self->{session}->make_text( "." ) );
	}
	else
	{
		$frag->appendChild( $self->{session}->html_phrase(
			"lib/searchexpression:desc_no_conditions" ) );
	}

	if( EPrints::Utils::is_set( $self->{order} ) )
	{
		$frag->appendChild( $self->{session}->make_text( " " ) );
		$frag->appendChild( $self->{session}->html_phrase(
			"lib/searchexpression:desc_order",
			order => $self->{session}->make_text(
				$self->{session}->get_order_name(
					$self->{dataset},
					$self->{order} ) ) ) );
	} 

	return $frag;
}
	

######################################################################
=pod

=item $thing->set_property( $property, $value );

undocumented

=cut
######################################################################

sub set_property
{
	my( $self, $property, $value ) = @_;

	$self->{$property} = $value;
}


######################################################################
=pod

=item $boolean = $thing->item_matches( $item );

undocumented

=cut
######################################################################

sub item_matches
{
	my( $self, $item ) = @_;

	my @searchon = ();
	foreach my $searchfieldname ( @{$self->{searchfields}} )
	{
		my $search_field = $self->get_searchfield( $searchfieldname );
		if( $search_field->is_set() )
		{
			push @searchon , $search_field;
		}
	}

	if( $self->{satisfy_all} )
	{
		foreach my $searchfield ( @searchon )
		{
			unless( $searchfield->item_matches( $item ) )
			{
				return 0;
			}
		}
		return 1;
	}

	# satisfy any
	foreach my $searchfield ( @searchon )
	{
		if( $searchfield->item_matches( $item ) )
		{
			return 1;
		}
	}
	return 0;
}




1;

######################################################################
=pod

=back

=cut

