######################################################################
#
# EPrints::Search
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

=pod

=head1 NAME

B<EPrints::Search> - Represents a single search

=head1 DESCRIPTION

The Search object represents the conditions of a single 
search.

It used to also store the results of the search, but now it returns
an EPrints::List object. 

A search expression can also render itself as a web-form, populate
itself with values from that web-form and render the results as a
web page.

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

package EPrints::Search;

use URI::Escape;
use strict;

$EPrints::Search::CustomOrder = "_CUSTOM_";

######################################################################
=pod

=item $searchexp = EPrints::Search->new( %params )

Create a new search expression.

The parameters are split into two parts. The general parameters and those
which influence how the HTML form is rendered, and the results displayed.

GENERAL PARAMETERS

=over 4

=item session (required)

The current EPrints::Session 

=item dataset OR dataset_id (required)

Either the EPrints::DataSet to search, or the ID of it.

=item allow_blank (default 0)

Unless this is set, a search with no conditions will return zero records 
rather than all records.

=item satisfy_all (default 1)

If this is true than all search-fields much be satisfied, if false then 
results matching any search-field will be returned.

=item search_fields

A reference to an array of search field configuration structures. Each 
takes the form { id=>"...", default=>"..", meta_fields=>"..." } where
the meaning is the same as for search configuration in ArchiveConfig.

Search fields can also be added to the search expression after it has
been constructed.

=item order

The order the results should be returned. This is a key to the list
of orders available to this dataset, defined in ArchiveConfig.pm

=item custom_order

"order" limits you to the orders specified in ArchiveConfig, and is
usually used by the web page based searching. custom_order allows
you to specify any order you like. The format is 
foo/-bar. This means that the results will be sorted
by foo and then any with equal foo values will be reverse sorted
by bar. More than 2 fields can be specified.

=item keep_cache

If true then the search results produced will be stored in the database
even after the current script ends. This is useful for speeding up 
page 2 onwards of a search.

keep_cache may get set to true anyway for various reasons, but setting
the parameter makes certain of it.

=item cache_id

The ID of a cached search. The cache contains both the results of the
search, and the parameters used for the search.

If the cache still exists, it will set the default values of the 
search fields, and when the search is performed it will skip the 
search and build a search results object directly from the cache.

=item defaults

A reference to a hash defining default values for search fields. The
keys should be the "id" properties of search fields.

=item fieldnames (default []) 

Deprecated.

=back

WEB PAGE RELATED PARAMETERS

=over 4

=item prefix (default "")

When generating the web form and reading back from the web form, the
prefix is inserted before the form names of all fields. This is useful
if you need to put two search expressions in a single form for some
reason.

=item preamble_phrase

The phrase ID of the XHTML phrase to put at the top of the search form.

=item title_phrase

The phrase ID of the XHTML phrase which is to be used as the title for
the search page.

=item staff (default 0)

If true then this is a "staff" search, which prevents searching unless
the user is staff, and the results link to the staff URL of an item
rather than the public URL.

=item default_order

The ID of a sort order (from ArchiveConfig) which will be the default
option when the search form is rendered.

=item order_methods

An optional hash mapping order id to a custom order definition.
Only required for Searches generating a web interface. If not specified
then the default for the dataset is used.

=item controls ( default {top=>0, bottom=>1} )

A hash containing two values: top and bottom. If top is true then
the search control buttons appear at the top of the search. If bottom
is true they appear at the bottom. Both may be true.

=item citation

A citation format to use to render results, instead of the default for 
each item type.

=item page_size (default: results_page_size opt. in ArchiveConfig.pm)

How many records to return per page.

=item filters

A reference to an array of filter definitions.

Filter definitions take the form of:
{ value=>"..", match=>"..", merge=>"..", id=>".." } and work much
like normal search fields except that they do not appear in the web form
so force certain search parameters on the user.

An optional parameter of describe=>0 can be set to supress the filter
being mentioned in the description of the search.

=back

=cut
######################################################################

@EPrints::Search::OPTS = (
	"session", 	"dataset", 	"allow_blank", 	"satisfy_all", 	
	"fieldnames", 	"staff", 	"order", 	"custom_order",
	"keep_cache", 	"cache_id", 	"prefix", 	"defaults",
	"citation", 	"page_size", 	"filters", 	"default_order",
	"preamble_phrase", 		"title_phrase", "search_fields",
	"controls",	"order_methods" );

sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
	# only session & table are required.
	# setup defaults for the others:
	$data{allow_blank} = 0 if ( !defined $data{allow_blank} );
	$data{satisfy_all} = 1 if ( !defined $data{satisfy_all} );
	$data{fieldnames} = [] if ( !defined $data{fieldnames} );
	$data{prefix} = "" if ( !defined $data{prefix} );

	if( 
		defined $data{use_cache} || 
		defined $data{use_oneshot_cache} || 
		defined $data{use_private_cache} )
	{
		my ($package, $filename, $line) = caller;
		print STDERR <<END;
-----------------------------------------------------------------------
EPRINTS WARNING: The old cache parameters to Search have been
deprecated. Everything will probably work as expected, but you should 
maybe check your scripts. (if it's in the core code, please email 
support\@eprints.org

Deprecated: use_oneshot_cache use_private_cache use_cache

Please use instead: keep_cache

All cache's are now private. oneshot caches will be created and
destroyed automatically if "order" or "custom_order" is set or if a 
range of results is requested.
-----------------------------------------------------------------------
The deprecated parameter was passed to Search->new from
$filename line $line
-----------------------------------------------------------------------
END

	}

	foreach( @EPrints::Search::OPTS )
	{
		$self->{$_} = $data{$_};
	}

	if( defined $data{"dataset_id"} )
	{
		$self->{"dataset"} = $self->{"session"}->get_repository->get_dataset( $data{"dataset_id"} );
	}

	if( defined $self->{custom_order} ) 
	{ 
		$self->{order} = $EPrints::Search::CustomOrder;
		# can't cache a search with a custom ordering.
	}

	if( !defined $self->{defaults} ) 
	{ 
		$self->{defaults} = {};
	}

	# no order now means "do not order" rather than "use default order"
#	if( !defined $self->{order} && defined $self->{dataset})
#	{
#		# Get {order} from {dataset} if possible.
#
#		$self->{order} = $self->{session}->get_repository->get_conf( 
#					"default_order", 
#					$self->{dataset}->confid );
#	}
	

	# Arrays for the Search::Field objects
	$self->{searchfields} = [];
	$self->{filterfields} = {};
	# Map for MetaField names -> corresponding EPrints::Search::Field objects
	$self->{searchfieldmap} = {};

	# Little hack to solve the problem of not knowing what
	# the fields in the subscription spec are until we load
	# the config.
	if( $self->{fieldnames} eq "subscriptionfields" )
	{
		$self->{fieldnames} = $self->{session}->get_repository->get_conf(
			"subscription_fields" );
	}

	if( $self->{fieldnames} eq "editpermfields" )
	{
		$self->{fieldnames} = $self->{session}->get_repository->get_conf(
			"editor_limit_fields" );
	}

	# CONVERT FROM OLD SEARCH CONFIG 
	if( !defined $self->{search_fields} )
	{
		$self->{search_fields} = [];
		foreach my $fieldname (@{$self->{fieldnames}})
		{
			# If the fieldname contains a /, it's a 
			# "search >1 at once" entry
			my $f = {};
				
			if( $fieldname =~ m/^!(.*)$/ )
			{
				# "extra" field - one not in the current 
				# dataset. HACK - do not use!
				$f->{id} = $1;
				$f->{default} = $self->{defaults}->{$1};
				$f->{meta_fields} = $fieldname;
			}
			else
			{
				$f->{default}=$self->{defaults}->{$fieldname};

				# Split up the fieldnames
				my @f = split( /\//, $fieldname );
				$f->{meta_fields} = \@f;
				$f->{id} = join( '/', sort @f );

			}
			push @{$self->{search_fields}}, $f;
		}
	}

	if( !defined $self->{"default_order"} )
	{
		$self->{"default_order"} = 
			$self->{session}->get_repository->get_conf( 
				"default_order",
				"eprint" );
	}

	if( !defined $self->{"page_size"} )
	{
		$self->{"page_size"} = 
			$self->{session}->get_repository->get_conf( 
				"results_page_size" );
	}

	foreach my $fielddata (@{$self->{search_fields}})
	{
		my @meta_fields;
		foreach my $fieldname ( @{$fielddata->{meta_fields}} )
		{
			# Put the MetaFields in a list
			push @meta_fields, 
	EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname );
		}

		my $id =  $fielddata->{id};
		if( !defined $id )
		{
			$id = join( 
				"/", 
				@{$fielddata->{meta_fields}} );
		}

		# Add a reference to the list
		my $sf = $self->add_field( 
			\@meta_fields, 
			$fielddata->{default},
			undef,
			undef,
			$fielddata->{id},
			0 );
	}
	$self->{filters} = [] unless defined $self->{filters};
	my @filters = @{$self->{filters}};
	push @filters, $self->{dataset}->get_filters;
	foreach my $filterdata (@filters)
	{
		my @meta_fields;
		foreach my $fieldname ( @{$filterdata->{meta_fields}} )
		{
			# Put the MetaFields in a list
			push @meta_fields, 
	EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname );
		}
	
		# Add a reference to the list
		my $sf = $self->add_field(
			\@meta_fields, 
			$filterdata->{value},
			$filterdata->{match},
			$filterdata->{merge},
			$filterdata->{id},
			1 );
		$sf->set_include_in_description( $filterdata->{describe} );
	}

	$self->{controls} = {} unless( defined $self->{controls} );
	$self->{controls}->{top} = 0 unless( defined $self->{controls}->{top} );
	$self->{controls}->{bottom} = 1 unless( defined $self->{controls}->{bottom} );

	if( defined $self->{cache_id} )
	{
		unless( $self->from_cache( $self->{cache_id} ) )
		{
			return; #cache gone 
		}
	}
	
	return( $self );
}


######################################################################
=pod

=item $ok = $thing->from_cache( $id )

Populate this search expression with values from the given cache.

Return false if the cache does not exist.

=cut
######################################################################

sub from_cache
{
	my( $self, $id ) = @_;

	my $string = $self->{session}->get_database->cache_exp( $id );

	return( 0 ) if( !defined $string );
	$self->from_string( $string );
	$self->{keep_cache} = 1;
	$self->{cache_id} = $id;
	return( 1 );
}


######################################################################
=pod

=item $searchfield = $searchexp->add_field( $metafields, $value, $match, $merge, $id, $filter )

Adds a new search field for the MetaField $field, or list of fields
if $metafields is an array ref, with default $value. If a search field
already exist, the value of that field is replaced with $value.


=cut
######################################################################

sub add_field
{
	my( $self, $metafields, $value, $match, $merge, $id, $filter ) = @_;

	# metafields may be a field OR a ref to an array of fields

	# Create a new searchfield
	my $searchfield = EPrints::Search::Field->new( 
					$self->{session},
					$self->{dataset},
					$metafields,
					$value,
					$match,
					$merge,
					$self->{prefix},
					$id );

	my $sf_id = $searchfield->get_id();
	unless( defined $self->{searchfieldmap}->{$sf_id} )
	{
		push @{$self->{searchfields}}, $sf_id;
	}
	# Put it in the name -> searchfield map
	# (possibly replacing an old one)
	$self->{searchfieldmap}->{$sf_id} = $searchfield;

	if( $filter )
	{
		$self->{filtersmap}->{$sf_id} = $searchfield;
	}

	return $searchfield;
}



######################################################################
=pod

=item $searchfield = $searchexp->get_searchfield( $sf_id )

Return a EPrints::Search::Field belonging to this Search with
the given id. 

Return undef if not searchfield of that ID belongs to this search. 

=cut
######################################################################

sub get_searchfield
{
	my( $self, $sf_id ) = @_;

	return $self->{searchfieldmap}->{$sf_id};
}

######################################################################
=pod

=item $searchexp->clear

Clear the search values of all search fields in the expression.

Resets satisfy_all to true.

=cut
######################################################################

sub clear
{
	my( $self ) = @_;
	
	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		$sf->clear();
	}
	
	$self->{satisfy_all} = 1;
}



######################################################################
=pod

=item $xhtml = $searchexp->render_search_fields( [$help] )

Renders the search fields for this search expression for inclusion
in a form. If $help is true then this also renders the help for
each search field.

Skips filter fields.

=cut
######################################################################

sub render_search_fields
{
	my( $self, $help ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		my $div = $self->{session}->make_element( 
				"div" , 
				class => "ep_search_field_name" );
		$div->appendChild( $sf->render_name );
		$frag->appendChild( $div );
		if( $help )
		{
			$div = $self->{session}->make_element( 
				"div" , 
				class => "ep_search_field_help" );
			$div->appendChild( $sf->render_help );
			$frag->appendChild( $div );
		}

		$div = $self->{session}->make_element( 
			"div" , 
			class => "ep_search_field_input" );
		$frag->appendChild( $sf->render() );
	}

	return $frag;
}


######################################################################
=pod

=item $xhtml = $searchexp->render_search_form( $help, $show_anyall )

Return XHTML DOM describing this search expression as a HTML form.

If $help is true then show the field help in addition to the field 
names.

If $show_anyall is false then the any-of-these-fields / 
all-of-these-fields selector is not shown.

=cut
######################################################################

sub render_search_form
{
	my( $self, $help, $show_anyall ) = @_;

	my $form = $self->{session}->render_form( "get" );
	if( $self->{controls}->{top} )
	{
		$form->appendChild( $self->render_controls );
	}
	$form->appendChild( $self->render_search_fields( $help ) );

	my @sfields = $self->get_non_filter_searchfields;
	if( $show_anyall && (scalar @sfields) > 1)
	{
		my $menu = $self->{session}->render_option_list(
			name=>$self->{prefix}."_satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{satisfy_all} && $self->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{session}->phrase( 
						"lib/searchexpression:all" ),
				  "ANY" => $self->{session}->phrase( 
						"lib/searchexpression:any" )} );

		my $div = $self->{session}->make_element( 
			"div" , 
			class => "ep_search_anyall" );
		$div->appendChild( 
			$self->{session}->html_phrase( 
				"lib/searchexpression:must_fulfill",  
				anyall=>$menu ) );
		$form->appendChild( $div );	
	}

	$form->appendChild( $self->render_order_menu );

	if( $self->{controls}->{bottom} )
	{
		$form->appendChild( $self->render_controls );
	}

	return( $form );
}

sub render_controls
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( 
		"div" , 
		class => "ep_search_buttons" );
	$div->appendChild( $self->{session}->render_action_buttons( 
		_order => [ "search", "newsearch" ],
		newsearch => $self->{session}->phrase( "lib/searchexpression:action_reset" ),
		search => $self->{session}->phrase( "lib/searchexpression:action_search" ) )
 	);
	return $div;
}


######################################################################
=pod

=item $xhtml = $searchexp->render_order_menu

Render the XHTML DOM describing the options of how to order this 
search.

=cut
######################################################################

sub render_order_menu
{
	my( $self ) = @_;

	my $order = $self->{order};

	if( !defined $order )
	{
		$order = $self->{default_order};
	}

	my $methods = $self->order_methods;

	my %labels = ();
	foreach( keys %$methods )
	{
                $labels{$_} = $self->{session}->phrase(
                	"ordername_".$self->{dataset}->confid() . "_" . $_ );
        }

	my $menu = $self->{session}->render_option_list(
		name=>$self->{prefix}."_order",
		values=>[keys %{$methods}],
		default=>$order,
		labels=>\%labels );

	my $div = $self->{session}->make_element( 
		"div" , 
		class => "ep_search_ordermenu" );
	$div->appendChild( 
		$self->{session}->html_phrase( 
			"lib/searchexpression:order_results", 
			ordermenu => $menu  ) );

	return $div;
}

# $method_map = $searche->order_methods
# 
# Return the available orderings for this search, using the default
# for the dataset if needed.


sub order_methods
{
	my( $self ) = @_;

	if( !defined $self->{order_methods} )
	{
		$self->{order_methods} = $self->{session}->get_repository->get_conf(
			"order_methods",
			$self->{dataset}->confid );
	}

	return $self->{order_methods};
}
	
######################################################################
=pod

=item $order_id = $searchexp->get_order

Return the id string of the type of ordering. This will be a value
in the search configuration.

=cut
######################################################################

sub get_order
{
	my( $self ) = @_;
	return $self->{order};
}


######################################################################
=pod

=item $bool = $searchexp->get_satisfy_all

Return true if this search requires that all the search fields with
values are satisfied. 

=cut
######################################################################

sub get_satisfy_all
{
	my( $self ) = @_;

	return $self->{satisfy_all};
}


######################################################################
=pod

=item @problems = $searchexp->from_form

Populate the conditions of this search based on parameters taken
from the CGI interface.

Return an array containg XHTML descriptions of any problems.

=cut
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $id = $self->{session}->param( "_cache" );
	if( defined $id )
	{
		return if( $self->from_cache( $id ) );
		# cache expired...
	}

	my $exp = $self->{session}->param( "_exp" );
	if( defined $exp )
	{
		$self->from_string( $exp );
		return;
		# cache expired...
	}

	my @problems;
	foreach my $sf ( $self->get_non_filter_searchfields )
	{
                next if( $self->{filtersmap}->{$sf->get_id} );
		my $prob = $sf->from_form();
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

If any field is set to "exact" then it can never count as unset.

=cut
######################################################################

sub is_blank
{
	my( $self ) = @_;

	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		next unless( $sf->is_set );
		return( 0 ) ;
	}

	return( 1 );
}


######################################################################
=pod

=item $string = $searchexp->serialise

Return a text representation of the search expression, for persistent
storage. Doesn't store table or the order by fields, just the field
names, values, default order and satisfy_all.

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
	foreach my $sf_id (sort @{$self->{searchfields}})
	{
		my $search_field = $self->get_searchfield( $sf_id );
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

	return unless( EPrints::Utils::is_set( $string ) );

	my( $pstring , $fstring ) = split /\|-\|/ , $string ;
	$fstring = "" unless( defined $fstring ); # avoid a warning

	my @parts = split( /\|/ , $pstring );
	$self->{satisfy_all} = $parts[1]; 
	$self->{order} = $parts[2];
# not overriding these bits
#	$self->{allow_blank} = $parts[0];
#	$self->{dataset} = $self->{session}->get_repository->get_dataset( $parts[3] ); 

	my $sf_data = {};
	foreach( split /\|/ , $fstring )
	{
		my $data = EPrints::Search::Field->unserialise( $_ );
		$sf_data->{$data->{"id"}} = $data;	
	}

	foreach my $sf ( $self->get_non_filter_searchfields )
	{
		my $data = $sf_data->{$sf->get_id};
		$self->add_field( 
			$sf->get_fields(), 
			$data->{"value"},
			$data->{"match"},
			$data->{"merge"},
			$sf->get_id() );
	}
}



######################################################################
=pod

=item $newsearchexp = $searchexp->clone

Return a new search expression which is a duplicate of this one.

=cut
######################################################################

sub clone
{
	my( $self ) = @_;

	my $clone = EPrints::Search->new( %{$self} );
	
	foreach my $sf_id ( keys %{$self->{searchfieldmap}} )
	{
		my $sf = $self->{searchfieldmap}->{$sf_id};
		$clone->add_field(
			$sf->get_fields,
			$sf->get_value,
			$sf->get_match,
			$sf->get_merge,
			$sf->get_id );
	}

	return $clone;
}




######################################################################
=pod

=item $conditions = $searchexp->get_conditons

Return a tree of EPrints::Search::Condition objects describing the
simple steps required to perform this search.

=cut
######################################################################

sub get_conditions
{
	my( $self ) = @_;

	my $any_field_set = 0;
	my @r = ();
	foreach my $sf ( $self->get_searchfields )
	{
		next unless( $sf->is_set() );
		$any_field_set = 1;

		push @r, $sf->get_conditions;
	}

	my $cond;
	if( $any_field_set )
	{
		if( $self->{satisfy_all} )
		{
			$cond = EPrints::Search::Condition->new( "AND", @r );
		}
		else
		{
			$cond = EPrints::Search::Condition->new( "OR", @r );
		}
	}
	else
	{
		if( $self->{allow_blank} )
		{
			$cond = EPrints::Search::Condition->new( "TRUE" );
		}
		else
		{
			$cond = EPrints::Search::Condition->new( "FALSE" );
		}
	}
		
	$cond->optimise;

	return $cond;
}


######################################################################
=pod

=item $searchexp->process_webpage()

Look at data from the CGI interface and return a webpage. This is
the core of the search UI.

=cut
######################################################################

sub process_webpage
{
	my( $self ) = @_;

	if( $self->{staff} && !$self->{session}->auth_check( "staff-view" ) )
	{
		$self->{session}->terminate();
		exit( 0 );
	}

	my $action_button = $self->{session}->get_action_button();

	# Check if we need to do a search. We do if:
	#  a) if the Search button was pressed.
	#  b) if there are search parameters but we have no value for "submit"
	#     (i.e. the search is a direct GET from somewhere else)

	if( defined $action_button && $action_button eq "search" ) 
	{
		$self->_dopage_results();
		return;
	}

	if( defined $action_button && $action_button eq "export_redir" ) 
	{
		$self->_dopage_export_redir();
		return;
	}

	if( defined $action_button && $action_button eq "export" ) 
	{
		$self->_dopage_export();
		return;
	}

	if( !defined $action_button && $self->{session}->have_parameters() ) 
	{
		# a internal button, probably
		$self->_dopage_results();
		return;
	}

	if( defined $action_button && $action_button eq "newsearch" )
	{
		# To reset the form, just reset the URL.
		my $url = $self->{session}->get_uri();
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
	$page->appendChild( $self->_render_preamble );
	$page->appendChild( $self->render_search_form( 1 , 1 ) );

	$self->{session}->build_page( $self->_render_title, $page, "search_form" );
	$self->{session}->send_page();
}

######################################################################
# 
# $searchexp->_dopage_export_redir
#
# Redirect to the neat export URL for the requested export format.
#
######################################################################

sub _dopage_export_redir
{
	my( $self ) = @_;

	my $exp = $self->{session}->param( "_exp" );
	my $cacheid = $self->{session}->param( "_cache" );
	my $format = $self->{session}->param( "_output" );
	my $plugin = $self->{session}->plugin( "Export::".$format );

	my $url = $self->{session}->get_uri();
	#cjg escape URL'ify urls in this bit... (4 of them?)
	my $escexp = $exp;
	$escexp =~ s/ /+/g; # not great way...
	my $fullurl = "$url/export_".$self->{session}->get_repository->get_id."_".$format.$plugin->param("suffix")."?_exp=$escexp&_output=$format&_action_export=1&_cache=$cacheid";

	$self->{session}->redirect( $fullurl );
}

######################################################################
# 
# $searchexp->_dopage_export
#
# Export the search results using the specified output plugin.
#
######################################################################

sub _dopage_export
{
	my( $self ) = @_;

	my $format = $self->{session}->param( "_output" );

	$self->from_form;
	my $results = $self->perform_search;

	if( !defined $results ) {
		$self->{session}->build_page( 
			$self->{session}->html_phrase( "lib/searchexpression:export_error_title" ),
			$self->{session}->html_phrase( "lib/searchexpression:export_error_search" ),
			"export_error" );
		$self->{session}->send_page;
		return;
	}

	my @plugins = $self->{session}->plugin_list( 
		type=>"Export",
		can_accept=>"list/eprint", 
		is_visible=>$self->_vis_level );

	my $ok = 0;
	foreach( @plugins ) { if( $_ eq "Export::$format" ) { $ok = 1; last; } }
	unless( $ok ) {
		$self->{session}->build_page( 
			$self->{session}->html_phrase( "lib/searchexpression:export_error_title" ),
			$self->{session}->html_phrase( "lib/searchexpression:export_error_format" ),
			"export_error" );
		$self->{session}->send_page;
		return;
	}

	my $plugin = $self->{session}->plugin( "Export::$format" );
	$self->{session}->send_http_header( "content_type"=>$plugin->param("mimetype") );
	print $results->export( $format );	
}

######################################################################
# $min_vis_level = $searchexp->_vis_level
######################################################################

sub _vis_level
{
	my( $self ) = @_;

	return "staff" if $self->{staff};

	return "all";
}	

######################################################################
# 
# $searchexp->_dopage_results
#
# Send the results of this search page
#
######################################################################

sub _dopage_results
{
	my( $self ) = @_;

	# We need to do a search
	my $problems = $self->from_form;
	
	if( defined $problems && scalar( @$problems ) > 0 )
	{
		$self->_dopage_problems( @$problems );
		return;
	}

	# Everything OK with form.
		

	my( $t1 , $t2 , $t3 , @results );

	#$t1 = EPrints::Session::microtime();

	my $list = $self->perform_search();

	#$t2 = EPrints::Session::microtime();

	if( defined $self->{error} ) 
	{	
		# Error with search.
		$self->_dopage_problems( $self->{error} );
		return;
	}

	$self->dispose();

	my %bits = ();

	my @plugins = $self->{session}->plugin_list( 
					type=>"Export",
					can_accept=>"list/".$self->{dataset}->confid, 
					is_visible=>$self->_vis_level );
	$bits{export} = $self->{session}->make_doc_fragment;
	if( scalar @plugins > 0 ) {
		my $select = $self->{session}->make_element( "select", name=>"_output" );
		foreach my $plugin_id ( @plugins ) {
			$plugin_id =~ m/^[^:]+::(.*)$/;
			my $option = $self->{session}->make_element( "option", value=>$1 );
			my $plugin = $self->{session}->plugin( $plugin_id );
			$option->appendChild( $plugin->render_name );
			$select->appendChild( $option );
		}
		my $button = $self->{session}->make_doc_fragment;
		$button->appendChild( $self->{session}->make_element( 
				"input", 
				type=>"submit", 
				name=>"_action_export_redir", 
				value=>$self->{session}->phrase( "lib/searchexpression:export_button" ) ) );
		$button->appendChild( 
			$self->{session}->make_element( 
				"input", 
				type=>"hidden", 
				name=>"_cache", 
				value=>$self->{cache_id} ) );
		$button->appendChild( 
			$self->{session}->make_element( 
				"input", 
				type=>"hidden", 
				name=>"_exp", 
				value=>$self->serialise ) );
		$bits{export} = $self->{session}->html_phrase( "lib/searchexpression:export_section",
					menu => $select,
					button => $button );
	}
	

	$bits{time} = $self->{session}->make_doc_fragment;


	my $links = $self->{session}->make_doc_fragment(); # TODO: links in document header?

	my $cacheid = $self->{cache_id};
	my $escexp = $self->serialise;
	my @controls_before = (
		{
			url => $self->{session}->get_uri . "?_cache=$cacheid&_exp=$escexp&_action_update=1",
			label => $self->{session}->html_phrase( "lib/searchexpression:refine" ),
		},
		{
			url => $self->{session}->get_uri,
			label => $self->{session}->html_phrase( "lib/searchexpression:new" ),
		}
	);

	my %opts = (
		pins => \%bits,
		controls_before => \@controls_before,
		phrase => "lib/searchexpression:results_page",
		params => { 
			_cache => $cacheid,
			_exp => $escexp,
		},
		render_result => sub {
			my( $session, $result, $searchexp ) = @_;
			my $div = $session->make_element( "div", class=>"ep_search_result" );
			$div->appendChild( 
				$result->render_citation_link(
					$searchexp->{citation},  #undef unless specified
					$searchexp->{staff} ) );
			return $div;
		},
		render_result_params => $self,
	);

	my $page = $self->{session}->render_form( "GET" );
	$page->appendChild( EPrints::Paginate->paginate_list( $self->{session}, "_search", $list, %opts ) );

	$self->{session}->build_page( 
		$self->{session}->html_phrase( 
				"lib/searchexpression:results_for", 
				title => $self->_render_title ),
		$page,
		"search_results",
		$links );
	$self->{session}->send_page();
}


######################################################################
# 
# $searchexp->_render_title
#
# Return the title for the search page
#
######################################################################

sub _render_title
{
	my( $self ) = @_;

	return $self->{"session"}->html_phrase( $self->{"title_phrase"} );
}

######################################################################
# 
# $searchexp->_render_preamble
#
# Return the preamble for the search page
#
######################################################################

sub _render_preamble
{
	my( $self ) = @_;

	if( defined $self->{"preamble_phrase"} )
	{
		return $self->{"session"}->html_phrase(
				$self->{"preamble_phrase"} );
	}
	return $self->{"session"}->make_doc_fragment;
}

######################################################################
# 
# $searchexp->_dopage_problems( @problems )
#
# Output a page which explains any problems with a search expression.
# Such as searching for the years "2001-20FISH"
#
######################################################################

sub _dopage_problems
{
	my( $self , @problems ) = @_;	
	# Problem with search expression. Report an error, and redraw the form
		
	my $page = $self->{session}->make_doc_fragment();
	$page->appendChild( $self->_render_preamble );

	my $problem_box = $self->{session}->make_element( 
				"div",
				class=>"ep_search_problems" );
	$problem_box->appendChild( $self->{session}->html_phrase( "lib/searchexpression:form_problem" ) );

	# List the problem(s)
	my $ul = $self->{session}->make_element( "ul" );
	$page->appendChild( $ul );
	my $problem;
	foreach $problem (@problems)
	{
		my $li = $self->{session}->make_element( 
			"li",
			class=>"ep_search_proble" );
		$ul->appendChild( $li );
		$li->appendChild( $self->{session}->make_text( $problem ) );
	}
	$problem_box->appendChild( $ul );
	$page->appendChild( $problem_box );
	$page->appendChild( $self->render_search_form( 1 , 1 ) );
			
	$self->{session}->build_page( $self->_render_title, $page, "search_problems" );
	$self->{session}->send_page();
}


######################################################################
=pod

=item $dataset = $searchexp->get_dataset

Return the EPrints::DataSet which this search relates to.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}


######################################################################
=pod

=item $searchexp->set_dataset( $dataset )

Set the EPrints::DataSet which this search relates to.

=cut
######################################################################

sub set_dataset
{
	my( $self, $dataset ) = @_;

	# Any cache is now meaningless...
	$self->dispose; # clean up cache if it's not shared.
	delete $self->{cache_id}; # forget about it even if it is shared.

	$self->{dataset} = $dataset;
	foreach my $sf ( $self->get_searchfields )
	{
		$sf->set_dataset( $dataset );
	}
}


######################################################################
=pod

=item $xhtml = $searchexp->render_description

Return an XHTML DOM description of this search expressions current
parameters.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	$frag->appendChild( $self->render_conditions_description );
	$frag->appendChild( $self->{session}->make_text( " " ) );
	$frag->appendChild( $self->render_order_description );

	return $frag;
}

######################################################################
=pod

=item $xhtml = $searchexp->render_conditions_description

Return an XHTML DOM description of this search expressions conditions.
ie title is "foo" 

=cut
######################################################################

sub render_conditions_description
{
	my( $self ) = @_;

	my @bits = ();
	foreach my $sf ( $self->get_searchfields )
	{
		next unless( $sf->is_set );
		next unless( $sf->get_include_in_description );
		push @bits, $sf->render_description;
	}

	my $joinphraseid = "lib/searchexpression:desc_or";
	if( $self->{satisfy_all} )
	{
		$joinphraseid = "lib/searchexpression:desc_and";
	}

	my $frag = $self->{session}->make_doc_fragment;

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

	return $frag;
}


######################################################################
=pod

=item $xhtml = $searchexp->render_order_description

Return an XHTML DOM description of how this search is ordered.

=cut
######################################################################

sub render_order_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	# empty if there is no order.
	return $frag unless( EPrints::Utils::is_set( $self->{order} ) );

	# empty if it's a custom ordering
	return $frag if( $self->{"order"} eq $EPrints::Search::CustomOrder );

	$frag->appendChild( $self->{session}->html_phrase(
		"lib/searchexpression:desc_order",
		order => $self->{session}->make_text(
			$self->{session}->get_order_name(
				$self->{dataset},
				$self->{order} ) ) ) );

	return $frag;
}
	

######################################################################
=pod

=item $searchexp->set_property( $property, $value );

Set any single property of this search, such as the order.

=cut
######################################################################

sub set_property
{
	my( $self, $property, $value ) = @_;

	$self->{$property} = $value;
}



######################################################################
=pod

=item @search_fields = $searchexp->get_searchfields()

Return the EPrints::Search::Field objects relating to this search.

=cut
######################################################################

sub get_searchfields
{
	my( $self ) = @_;

	my @search_fields = ();
	foreach my $id ( @{$self->{searchfields}} ) 
	{ 
		push @search_fields, $self->get_searchfield( $id ); 
	}
	
	return @search_fields;
}

######################################################################
=pod

=item @search_fields = $searchexp->get_non_filter_searchfields();

Return the EPrints::Search::Field objects relating to this search,
which are normal search fields, and not "filters".

=cut
######################################################################

sub get_non_filter_searchfields
{
	my( $self ) = @_;

	my @search_fields = ();
	foreach my $id ( @{$self->{searchfields};} ) 
	{ 
                next if( $self->{filtersmap}->{$id} );
		push @search_fields, $self->get_searchfield( $id ); 
	}
	
	return @search_fields;
}





######################################################################
=pod

=item @search_fields = $searchexp->get_set_searchfields

Return the searchfields belonging to this search expression which
have a value set. 

=cut
######################################################################

sub get_set_searchfields
{
	my( $self ) = @_;

	my @set_fields = ();
	foreach my $sf ( $self->get_searchfields )
	{
		next unless( $sf->is_set() );
		push @set_fields , $sf;
	}
	return @set_fields;
}




 ######################################################################
 ##
 ##
 ##  SEARCH THE DATABASE AND CACHE CODE
 ##
 ##
 ######################################################################


#
# Search related instance variables
#   {cache_id}  - the ID of the table the results are cached & 
#			ordered in.
#
#   {results}  - the EPrints::List object which describes the results.
#	





######################################################################
=pod

=item $cache_id = $searchexp->get_cache_id

Return the ID of the cache containing the results of this search,
if known.

=cut
######################################################################

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}

######################################################################
=pod

=item $results = $searchexp->perform_search

Execute this search and return a EPrints::List object
representing the results.

=cut
######################################################################

sub perform_search
{
	my( $self ) = @_;
	$self->{error} = undef;

	if( defined $self->{results} )
	{
		return $self->{results};
	}

	# cjg hmmm check cache still exists?
	if( defined $self->{cache_id} )
	{
		$self->{results} = EPrints::List->new( 
			session => $self->{session},
			dataset => $self->{dataset},
			encoded => $self->serialise,
			cache_id => $self->{cache_id}, 
			desc => $self->render_conditions_description,
			desc_order => $self->render_order_description,
		);
		return $self->{results};
	}

	my $order;
	if( defined $self->{order} )
	{
		if( $self->{order} eq $EPrints::Search::CustomOrder )
		{
			$order = $self->{custom_order};
		}
		else
		{
			my $methods = $self->order_methods;
			$order = $methods->{ $self->{order} };
		}
	}

	#my $conditions = $self->get_conditions;
	#print STDERR $conditions->describe."\n\n";

	my $unsorted_matches = $self->get_conditions->process( 
						$self->{session} );

	$self->{results} = EPrints::List->new( 
		session => $self->{session},
		dataset => $self->{dataset},
		order => $order,
		encoded => $self->serialise,
		keep_cache => $self->{keep_cache},
		ids => $unsorted_matches, 
		desc => $self->render_conditions_description,
		desc_order => $self->render_order_description,
	);

	$self->{cache_id} = $self->{results}->get_cache_id;

	return $self->{results};
}



 ######################################################################
 # Legacy functions which daisy chain to the results object
 # All deprecated.
 ######################################################################


sub cache_results
{
	my( $self ) = @_;

	if( !defined $self->{result} )
	{
		$self->{session}->get_repository->log( "\$searchexp->cache_results() : Search has not been performed" );
		return;
	}

	$self->{results}->cache;
}

sub dispose
{
	my( $self ) = @_;

	return unless defined $self->{results};

	$self->{results}->dispose;
}

sub count
{
	my( $self ) = @_;

	return unless defined $self->{results};

	$self->{results}->count;
}

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	return $self->{results}->get_records( $offset , $count );
}

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	return $self->{results}->get_ids( $offset , $count );
}

sub map
{
	my( $self, $function, $info ) = @_;	

	return $self->{results}->map( $function, $info );
}





1;

######################################################################
=pod

=back

=cut

