######################################################################
#
# EPrints::Search
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search> - Represents a single search

=head1 DESCRIPTION

The Search object represents the conditions of a single 
search.

It used to also store the results of the search, but now it returns
an L<EPrints::List> object. 

A search expression can also render itself as a web-form, populate
itself with values from that web-form and render the results as a
web page.

=head1 EXAMPLES

=head2 Searching for Eprints

	$ds = $session->dataset( "archive" );

	$searchexp = EPrints::Search->new(
		satisfy_all => 1,
		session => $session,
		dataset => $ds,
	);

	# Search for an eprint with eprintid 23
	# (ought to use EPrints::DataObj::EPrint->new( SESSION, ID ))
	$searchexp->add_field( $ds->get_field( "eprintid" ), 23 );

	$searchexp->add_field( $ds->get_field( "creators" ), "John Smith" );

=head2 Getting Results

	$results = $searchexp->perform_search;

	my $count = $results->count;

	my $ids = $results->ids( 0, 10 );
	my $ids = $results->ids; # Get all matching ids

	my $info = { matches => 0 };
	sub fn {
		my( $session, $dataset, $eprint, $info ) = @_;
		$info->{matches}++;
	};
	$results->map( \&fn, $info );

	$results->dispose;

See L<EPrints::List> for more.

=head1 METHODS

=over 4

=cut

package EPrints::Search;

use URI::Escape;
use strict;

######################################################################
=pod

=item $searchexp = EPrints::Search->new( %params )

Create a new search expression.

The parameters are split into two parts. The general parameters and those
which influence how the HTML form is rendered, and the results displayed.

GENERAL PARAMETERS

=over 4

=item session (required)

The current L<EPrints::Session>

=item dataset OR dataset_id (required)

Either the L<EPrints::DataSet> to search, or the ID of it.

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

=item limit

Limit the number of matching records to limit.

=back

WEB PAGE RELATED PARAMETERS

=over 4

=item prefix (default "")

When generating the web form and reading back from the web form, the
prefix is inserted before the form names of all fields. This is useful
if you need to put two search expressions in a single form for some
reason.

=item staff (default 0)

If true then this is a "staff" search, which prevents searching unless
the user is staff, and the results link to the staff URL of an item
rather than the public URL.

=item filters

A reference to an array of filter definitions.

Filter definitions take the form of:
{ value=>"..", match=>"..", merge=>"..", id=>".." } and work much
like normal search fields except that they do not appear in the web form
so force certain search parameters on the user.

An optional parameter of describe=>0 can be set to suppress the filter
being mentioned in the description of the search.

=back

=cut
######################################################################

@EPrints::Search::OPTS = (
	"session", 	"dataset", 	"allow_blank", 	
	"satisfy_all", 	"staff", 	
	"custom_order", "keep_cache", 	"cache_id", 	
	"prefix", 	"defaults", 	"filters", 
	"search_fields","show_zero_results", "show_help",
	"limit", "offset",
);

sub new
{
	my( $class, %data ) = @_;
	
	my $self = {};
	bless $self, $class;
	# only session & table are required.
	# setup defaults for the others:
	$data{allow_blank} = 0 if ( !defined $data{allow_blank} );
	$data{satisfy_all} = 1 if ( !defined $data{satisfy_all} );
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

	# Arrays for the Search::Field objects
	$self->{searchfields} = [];
	$self->{filtersmap} = {};
	# Map for MetaField names -> corresponding EPrints::Search::Field objects
	$self->{searchfieldmap} = {};

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

		my $show_help = $self->{show_help};
		if( defined $fielddata->{show_help} )
		{
			$show_help = $fielddata->{show_help};
		}

		# Add a reference to the list
		$self->add_field( %$fielddata,
			fields => \@meta_fields,
			show_help => $show_help,
		);
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
	
		my %opts = %$filterdata;
		$opts{value} = delete $opts{default}
			if exists $opts{default};

		# Add a reference to the list
		my $sf = $self->add_field( %opts,
			fields => \@meta_fields,
			filter => 1,
			);
		$sf->set_include_in_description( $filterdata->{describe} );
	}

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
=for InternalDoc

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

=item $searchfield = $searchexp->add_field( %opts )

	fields - one or more fields to search over
	match - match type
	merge - merge type
	value - value to match against (for EX matches, NULL = is_null!)
	id - search field id, if not the name of the first field
	filter - is filter-type
	show_help - show help in search input

Adds a new search in $fields which is either a single L<EPrints::MetaField>
or a list of fields in an array ref with default $value. If a search field
already exists, the value of that field is replaced with $value.


=cut
######################################################################

sub add_field
{
	my( $self, @args ) = @_;

	# old-style argument list
	my %opts = @args % 2 == 0 ? @args : ();
	if( !exists($opts{fields}) )
	{
		@opts{qw( fields value match merge id filter show_help )} = @args;
	}
	$opts{prefix} = $self->{prefix} if !exists $opts{prefix};
	$opts{repository} = $self->{session};
	$opts{dataset} = $self->{dataset} if !exists $opts{dataset};
	my $filter = delete $opts{filter};

	# metafields may be a field OR a ref to an array of fields

	# Create a new searchfield
	my $searchfield = EPrints::Search::Field->new( %opts );

	$self->_add_field( $searchfield, $filter );

	return $searchfield;
}

sub _add_field
{
	my( $self, $sf, $filter ) = @_;

	push @{$self->{searchfields}}, $sf->get_id
		if !exists $self->{searchfieldmap}->{$sf->get_id};

	$self->{searchfieldmap}->{$sf->get_id} = $sf;
	$self->{filtersmap}->{$sf->get_id} = $sf if $filter;
}

=begin InternalDoc

=item $searchfield = $searchexp->get_searchfield( $sf_id )

Return a L<EPrints::Search::Field> belonging to this Search with
the given id. 

Return undef if not searchfield of that ID belongs to this search. 

=end InternalDoc

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
=for InternalDoc

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
=for InternalDoc

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
=for InternalDoc

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
	push @parts, $self->{custom_order};
	push @parts, $self->{dataset}->id();
	my( @fields, @filters );
	foreach my $sf_id (sort @{$self->{searchfields}})
	{
		my $fieldstring = $self->get_searchfield( $sf_id )->serialise;
		next if !defined $fieldstring;
		if( $self->{filtersmap}->{$sf_id} )
		{
			push @filters, $fieldstring;
		}
		else
		{
			push @fields, $fieldstring;
		}
	}
	# This inserts an "-" field which we use to spot the join between
	# the properties and the fields, so in a pinch we can add a new 
	# property in a later version without breaking when we upgrade.
	push @parts,
		"-",
		(@fields ? @fields : ''),
		"-",
		(@filters ? @filters : '');
	my @escapedparts;
	foreach( @parts )
	{
		# clone the string, so we can escape it without screwing
		# up the original.
		my $bit = $_;
		$bit="" unless defined( $bit );
		$bit =~ s/[\\\|]/\\$&/g; 
		push @escapedparts,$bit;
	}
	return join( "|" , @escapedparts );
}	


######################################################################
=for InternalDoc

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

	my( $pstring , $field_string, $filter_string ) = split /\|-\|/ , $string ;
	$field_string = "" unless( defined $field_string ); # avoid a warning

	my @parts = split( /\|/ , $pstring );
	$self->{satisfy_all} = $parts[1]; 
	$self->{custom_order} = $parts[2];
	delete $self->{custom_order} if( $self->{custom_order} eq "" );
	
# not overriding these bits
#	$self->{allow_blank} = $parts[0];
#	$self->{dataset} = $self->{session}->get_repository->get_dataset( $parts[3] ); 

	foreach( split /\|/ , $field_string )
	{
		my $sf = EPrints::Search::Field->unserialise(
			repository => $self->{session},
			dataset => $self->{dataset},
			string => $_,
			prefix => $self->{prefix},
		);
		next if !defined $sf; # bad serialisation

		my $id = $sf->get_id;

		# not an existing field
		next if !defined $self->{searchfieldmap}->{$id};

		# don't override filters
		next if $self->{filtersmap}->{$id};

		$self->_add_field( $sf );
	}
}


sub from_string_raw
{
	my( $self, $string ) = @_;

	return unless( EPrints::Utils::is_set( $string ) );

	my( $pstring , $field_string, $filter_string ) = split /\|-\|/ , $string ;
	$field_string = "" unless( defined $field_string ); # avoid a warning
	$filter_string = "" unless( defined $filter_string ); # avoid a warning

	my @parts = split( /\|/ , $pstring );
	$self->{satisfy_all} = $parts[1]; 
	$self->{custom_order} = $parts[2];
	delete $self->{custom_order} if( $self->{custom_order} eq "" );
# not overriding these bits
#	$self->{allow_blank} = $parts[0];
#	$self->{dataset} = $self->{session}->get_repository->get_dataset( $parts[3] ); 

	foreach( split /\|/ , $field_string )
	{
		my $sf = EPrints::Search::Field->unserialise(
			repository => $self->{session},
			dataset => $self->{dataset},
			string => $_,
			prefix => $self->{prefix},
		);
		EPrints->abort( "Failed to unserialise search field from '$_'" )
			if !defined $sf;
		$self->_add_field( $sf );
	}
	foreach( split /\|/ , $filter_string )
	{
		my $sf = EPrints::Search::Field->unserialise(
			repository => $self->{session},
			dataset => $self->{dataset},
			string => $_,
			prefix => $self->{prefix},
		);
		EPrints->abort( "Failed to unserialise filter field from '$_'" )
			if !defined $sf;
		$self->_add_field( $sf, 1 );
		$sf->set_include_in_description( 0 );
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
=for InternalDoc

=item $conditions = $searchexp->get_conditons

Return a tree of L<EPrints::Search::Condition> objects describing the
simple steps required to perform this search.

=cut
######################################################################

sub get_conditions
{
	my( $self ) = @_;

	my $any_field_set = 0;
	my @r = ();
	my @filters = ();
	foreach my $sf ( $self->get_searchfields )
	{
		my $cond = $sf->get_conditions;
		next if $cond->is_empty;
		if( $self->{filtersmap}->{$sf->get_id} )
		{
			push @filters, $cond;
		}
		elsif( $sf->is_set() )
		{
			$any_field_set = 1;
			push @r, $cond;
		}
	}

	# no terms were usable
	if( @filters == 0 && @r == 0 )
	{
		if( $self->{allow_blank} )
		{
			return EPrints::Search::Condition->new( "TRUE" );
		}
		else
		{
			return EPrints::Search::Condition->new( "FALSE" );
		}
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

	if( scalar @filters )
	{
		my $fcond;
		if( scalar @filters == 1 )
		{
			$fcond = $filters[0];
		}
		else
		{
			$fcond = EPrints::Search::Condition->new( "AND", @filters );
		}
		$cond = EPrints::Search::Condition->new( "AND", $fcond, $cond );
	}
	
	return $cond->optimise(
		session => $self->{session},
		dataset => $self->{dataset},
	);
}



######################################################################
=for InternalDoc

=item $dataset = $searchexp->get_dataset

Return the L<EPrints::DataSet> which this search relates to.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}


######################################################################
=for InternalDoc

=item $searchexp->set_dataset( $dataset )

Set the L<EPrints::DataSet> which this search relates to.

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
	$frag->appendChild( $self->{session}->make_text( ". " ) );
	$frag->appendChild( $self->render_order_description );
	$frag->appendChild( $self->{session}->make_text( ". " ) );

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
	foreach my $sf ( $self->get_non_filter_searchfields )
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

	if( scalar @bits == 0 )
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
	return $frag unless( EPrints::Utils::is_set( $self->{custom_order} ) );

	my $first = 1;
	foreach my $orderid ( split( "/", $self->{custom_order} ) )
	{
		$frag->appendChild( $self->{session}->make_text( ", " ) ) if( !$first );
		my $desc = 0;
		if( $orderid=~s/^-// ) { $desc = 1; }
		$frag->appendChild( $self->{session}->make_text( "-" ) ) if( $desc );
		my $field = EPrints::Utils::field_from_config_string( $self->{dataset}, $orderid );
		$frag->appendChild( $field->render_name( $self->{session} ) );
		$first = 0;
	}

	return $self->{session}->html_phrase(
		"lib/searchexpression:desc_order",
		order => $frag );

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
=for InternalDoc

=item @search_fields = $searchexp->get_searchfields()

Return the L<EPrints::Search::Field> objects relating to this search.

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
=for InternalDoc

=item @search_fields = $searchexp->get_non_filter_searchfields();

Return the L<EPrints::Search::Field> objects relating to this search,
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
=for InternalDoc

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
=for InternalDoc

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

Execute this search and return a L<EPrints::List> object
representing the results.

=cut
######################################################################

sub perform_search
{
	my( $self ) = @_;

	$self->{error} = undef;

	# cjg hmmm check cache still exists?
	if( defined $self->{cache_id} )
	{
		return EPrints::List->new( 
			session => $self->{session},
			dataset => $self->{dataset},
			encoded => $self->serialise,
			cache_id => $self->{cache_id}, 
			searchexp => $self,
			order => $self->{custom_order},
		);
	}


	# print STDERR $self->get_conditions->describe."\n\n";

	my $cachemap;

	if( $self->{keep_cache} )
	{
		my $userid = $self->{session}->current_user;
		$userid = $userid->get_id if defined $userid;

		$cachemap = $self->{session}->get_repository->get_dataset( "cachemap" )->create_object( $self->{session}, {
			lastused => time(),
			userid => $userid,
			searchexp => $self->serialise,
			oneshot => "TRUE",
		} );
		$cachemap->create_sql_table( $self->{dataset} );
	}

	my $unsorted_matches = $self->get_conditions->process( 
		session => $self->{session},
		cachemap => $cachemap,
		order => $self->{custom_order},
		dataset => $self->{dataset},
		limit => $self->{limit},
		offset => $self->{offset},
	);

	my $results = EPrints::List->new( 
		session => $self->{session},
		dataset => $self->{dataset},
		encoded => $self->serialise,
		keep_cache => $self->{keep_cache},
		ids => $unsorted_matches, 
		cache_id => (defined $cachemap ? $cachemap->get_id : undef ),
		searchexp => $self,
		order => $self->{custom_order},
	);

	$self->{cache_id} = $results->get_cache_id;

	return $results;
}

=item $ids_map = $searchexp->perform_distinctby( $fields )

Perform a DISTINCT on $fields to find all unique ids by value.

=cut

sub perform_distinctby
{
	my( $self, $fields ) = @_;

	# we don't do any caching of DISTINCT BY
	return $self->get_conditions->process_distinctby( 
			session => $self->{session},
			dataset => $self->{dataset},
			fields => $fields,
		);
}

=item ($values, $counts) = $searchexp->perform_groupby( $field )

Perform a SQL GROUP BY on $field based on the current search parameters.

Returns two array references, one containing a list of unique values and one a list of counts for each value.

=cut

sub perform_groupby
{
	my( $self, $field ) = @_;

	# we don't do any caching of GROUP BY
	return $self->get_conditions->process_groupby( 
			session => $self->{session},
			dataset => $self->{dataset},
			field => $field,
		);
}





######################################################################
# Legacy functions which daisy chain to the results object
# All deprecated.
######################################################################

sub cache_results
{
	my( $self ) = @_;

	EPrints->deprecated();
}

sub dispose
{
	my( $self ) = @_;

	EPrints->deprecated();
}

sub count
{
	my( $self ) = @_;

	EPrints->deprecated();

	# don't create a cachemap object
	local $self->{keep_cache} = 0;

	return $self->perform_search->count;
}

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	EPrints->deprecated();

	return $self->perform_search->slice( $offset, $count );
}

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	EPrints->deprecated();

	return $self->perform_search->ids( $offset, $count );
}

sub map
{
	my( $self, $function, $info ) = @_;	

	EPrints->deprecated();

	return $self->perform_search->map( $function, $info );
}

######################################################################
=for InternalDoc

=item $hash = $searchexp->get_ids_by_field_values( $field )

Find the ids for each unique value in $field.

=cut
######################################################################

sub get_ids_by_field_values
{
	my( $self, $field ) = @_;

	return $self->process_distinctby( [$field] );
}

=begin InternalDoc

=item $sql = $searchexp->sql

Debug method to get the SQL that will be executed, see L<EPrints::Search::Condition/sql>.

=end InternalDoc

=cut

sub sql
{
	my( $self ) = @_;

	return $self->get_conditions->sql(
		session => $self->{session},
		dataset => $self->{dataset},
	);
}


1;

######################################################################
=pod

=back

=cut


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

