######################################################################
#
# EPrints::List
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

B<EPrints::List> - List of data objects, usually a search result.

=head1 DESCRIPTION

This class represents an ordered list of objects, all from the same
dataset. Usually this is the results of a search. 

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{handle}
#     The current EPrints::Handle
#
#  $self->{dataset}
#     The EPrints::Dataset to which this list belongs.
#
#  $self->{ids} 
#     Ref to arrray. The ids of the items in the list. 
#     A special case is when this is set to [ "ALL" ] which means it
#     matches all items in the dataset.
#
#  $self->{order}
#     The order to return these items in. Is of the same format as
#     custom_order in Search.
#
#  $self->{encoded} 
#     encoded is the serialised version of the searchexpression which
#     created this list.
#
#  $self->{cache_id} 
#     The database table this list is cached in.
#
#  $self->{keep_cache}
#     If this is true then the cache will not be automatically tidied
#     when the EPrints::Handle terminates.
#
#  $self->{desc} 
#     Contains an XHTML description of what this is the iist of.
#
#  $self->{desc_order} 
#     Contains an XHTML description of how this list is ordered.
#
######################################################################

package EPrints::List;

use strict;

######################################################################
=pod

=item $list = EPrints::List->new( 
			handle => $handle,
			dataset => $dataset,
			[desc => $desc],
			[desc_order => $desc_order],
			ids => $ids,
			[encoded => $encoded],
			[keep_cache => $keep_cache],
			[order => $order] );

=item $list = EPrints::List->new( 
			handle => $handle,
			dataset => $dataset,
			[desc => $desc],
			[desc_order => $desc_order],
			cache_id => $cache_id );

Creates a new list object in memory only. Lists will be
cached if anything method requiring order is called, or an explicit 
cache() method is called.

encoded is the serialised version of the searchExpression which
created this list, if there was one.

If keep_cache is set then the cache will not be disposed of at the
end of the current $handle. If cache_id is set then keep_cache is
automatically true.

=cut
######################################################################

sub new
{
	my( $class, %opts ) = @_;

	my $self = {};
	$self->{handle} = $opts{handle};
	$self->{dataset} = $opts{dataset};
	$self->{ids} = $opts{ids};
	$self->{order} = $opts{order};
	$self->{encoded} = $opts{encoded};
	$self->{cache_id} = $opts{cache_id};
	$self->{keep_cache} = $opts{keep_cache};
	$self->{desc} = $opts{desc};
	$self->{desc_order} = $opts{desc_order};

	if( !defined $self->{cache_id} && !defined $self->{ids} ) 
	{
		EPrints::abort( "cache_id or ids must be defined in a EPrints::List->new()" );
	}
	if( !defined $self->{handle} )
	{
		EPrints::abort( "session must be defined in a EPrints::List->new()" );
	}
	if( !defined $self->{dataset} )
	{
		EPrints::abort( "dataset must be defined in a EPrints::List->new()" );
	}
	bless $self, $class;

	if( $self->{cache_id} )
	{
		$self->{keep_cache} = 1;
	}

	if( $self->{keep_cache} )
	{
		$self->cache;
	}

	return $self;
}


######################################################################
=pod

=item $new_list = $list->reorder( $new_order );

Create a new list from this one, but sorted in a new way.

=cut
######################################################################

sub reorder
{
	my( $self, $new_order ) = @_;

	# no need to order 0 or 1 length lists.
	if( $self->count < 2 )
	{
		return $self;
	}

	# must be cached to be reordered

	$self->cache;

	my $db = $self->{handle}->get_database;

	my $srctable = $db->cache_table( $self->{cache_id} );

	my $encoded = defined($self->{encoded}) ? $self->{encoded} : "";
	my $new_cache_id  = $db->cache( 
		"$encoded(reordered:$new_order)", # nb. not very neat. 
		$self->{dataset},
		$srctable,
		$new_order );

	my $new_list = EPrints::List->new( 
		handle =>$self->{handle},
		dataset=>$self->{dataset},
		desc=>$self->{desc}, # don't pass desc_order!
		order=>$new_order,
		keep_cache=>$self->{keep_cache},
		cache_id => $new_cache_id );
		
	return $new_list;
}
		
######################################################################
=pod

=item $new_list = $list->union( $list2, [$order] );

Create a new list from this one plus another one. If order is not set
then this list will not be in any certain order.

=cut
######################################################################

sub union
{
	my( $self, $list2, $order ) = @_;

	my $ids1 = $self->get_ids;
	my $ids2 = $list2->get_ids;

	my %newids = ();
	foreach( @{$ids1}, @{$ids2} ) { $newids{$_}=1; }
	my @objectids = keys %newids;

	# losing desc, although could be added later.
	return EPrints::List->new(
		dataset => $self->{dataset},
		handle => $self->{handle},
		order => $order,
		ids=>\@objectids );
}

######################################################################
=pod

=item $new_list = $list->remainder( $list2, [$order] );

Create a new list from this one minus another one. If order is not set
then this list will not be in any certain order.

Remove all items in $list2 from $list and return the result as a
new EPrints::List.

=cut
######################################################################

sub remainder
{
	my( $self, $list2, $order ) = @_;

	my $ids1 = $self->get_ids;
	my $ids2 = $list2->get_ids;

	my %newids = ();
	foreach( @{$ids1} ) { $newids{$_}=1; }
	foreach( @{$ids2} ) { delete $newids{$_}; }
	my @objectids = keys %newids;

	# losing desc, although could be added later.
	return EPrints::List->new(
		dataset => $self->{dataset},
		handle => $self->{handle},
		order => $order,
		ids=>\@objectids );
}

######################################################################
=pod

=item $new_list = $list->intersect( $list2, [$order] );

Create a new list containing only the items which are in both lists.
If order is not set then this list will not be in any certain order.

=cut
######################################################################

sub intersect
{
	my( $self, $list2, $order ) = @_;

	my $ids1 = $self->get_ids;
	my $ids2 = $list2->get_ids;

	my %n= ();
	foreach( @{$ids1} ) { $n{$_}=1; }
	my @objectids = ();
	foreach( @{$ids2} ) { next unless( $n{$_} ); push @objectids, $_; }

	# losing desc, although could be added later.
	return EPrints::List->new(
		dataset => $self->{dataset},
		handle => $self->{handle},
		order => $order,
		ids=>\@objectids );
}

######################################################################
=pod

=item $list->cache

Cause this list to be cached in the database.

=cut
######################################################################

sub cache
{
	my( $self ) = @_;

	return if( defined $self->{cache_id} );

	if( $self->_matches_none && !$self->{keep_cache} )
	{
		# not worth caching zero in a temp table!
		return;
	}

#	if( defined $self->{ids} && scalar @{$self->{ids}} < 2 )
#	{
#		# not worth caching one item either. Can't sort one
#		# item can you?
#		return;
#	}

	my $db = $self->{handle}->get_database;
	if( $self->_matches_all )
	{
		$self->{cache_id} = $db->cache( 
			$self->{encoded}, 
			$self->{dataset},
			"ALL",
			$self->{order} );
		$self->{ids} = undef;
		return;	
	}

	my $ids = $self->{ids};
	$self->{cache_id} = $db->cache( 
		$self->{encoded}, 
		$self->{dataset},
		"LIST",	
		undef,
		$ids );

	if( defined $self->{order} )
	{
		my $srctable = $db->cache_table( $self->{cache_id} );

		my $new_cache_id = $db->cache( 
			$self->{encoded},
			$self->{dataset},
			$srctable,
			$self->{order} );

		# clean up intermediate cache table
		$self->{handle}->get_database->drop_cache( $self->{cache_id} );

		$self->{cache_id} = $new_cache_id;
	}
}

######################################################################
=pod

=item $cache_id = $list->get_cache_id

Return the ID of the cache table for this list, or undef.

=cut
######################################################################

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}



######################################################################
=pod

=item $list->dispose

Clean up the cache table if appropriate.

=cut
######################################################################

sub dispose
{
	my( $self ) = @_;

	if( defined $self->{cache_id} && !$self->{keep_cache} )
	{
		if( !defined $self->{handle}->get_database )
		{
			print STDERR "Wanted to drop cache ".$self->{cache_id}." but we've already entered clean up and closed the database connection.\n";
		}
		else
		{
			$self->{handle}->get_database->drop_cache( $self->{cache_id} );
			delete $self->{cache_id};
		}
	}
}


######################################################################
=pod

=item $n = $list->count 

Return the number of values in this list.

=cut
######################################################################

sub count 
{
	my( $self ) = @_;

	if( defined $self->{ids} )
	{
		if( $self->_matches_all )
		{
			return $self->{dataset}->count( $self->{handle} );
		}
		return( scalar @{$self->{ids}} );
	}

	if( defined $self->{cache_id} )
	{
		#cjg Should really have a way to get at the
		# cache. Maybe we should have a table object.
		return $self->{handle}->get_database->count_table( 
			"cache".$self->{cache_id} );
	}

	EPrints::abort( "Called \$list->count() where there was no cache or ids." );
}


######################################################################
=pod

=item @dataobjs = $list->get_records( [$offset], [$count] )

Return the objects described by this list. $count is the maximum
to return. $offset is what index through the list to start from.

=cut
######################################################################

sub get_records
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 0 );
}


######################################################################
=pod

=item $ids = $list->get_ids( [$offset], [$count] )

Return a reference to an array containing the ids of the specified
range from the list. This is more efficient if you just need the ids.

=cut
######################################################################

sub get_ids
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 1 );
}


######################################################################
# 
# $bool = $list->_matches_none
#
######################################################################

sub _matches_none
{
	my( $self ) = @_;

	if( !defined $self->{ids} )
	{
		EPrints::abort( "Error: Calling _matches_none when {ids} not set\n" );
	}

	return( scalar @{$self->{ids}} == 0 );
}

######################################################################
# 
# $bool = $list->_matches_all
#
######################################################################

sub _matches_all
{
	my( $self ) = @_;

	if( !defined $self->{ids} )
	{
		EPrints::abort( "Error: Calling _matches_all when {ids} not set\n" );
	}

	return( 0 ) if( !defined $self->{ids}->[0] );

	return( $self->{ids}->[0] eq "ALL" );
}

######################################################################
# 
# $ids/@dataobjs = $list->_get_records ( $offset, $count, $justids )
#
# Method which handles getting objects or just ids.
#
######################################################################

sub _get_records 
{
	my ( $self , $offset , $count, $justids ) = @_;

	$offset = $offset || 0;
	# $count = $count || 1; # unspec. means ALL not 1.
	$justids = $justids || 0;

	if( defined $self->{ids} )
	{
		if( $self->_matches_none )
		{
			if( $justids )
			{
				return [];
			}
			else
			{
				return ();
			}
		}

		# quick solutions if we don't need to order anything...
		if( $offset == 0 && !defined $count && !defined $self->{order} )
		{

			if( $justids )
			{
				if( $self->_matches_all )
				{
					return $self->{dataset}->get_item_ids( $self->{handle} );
				}
				else
				{
					return $self->{ids};
				}
			}
	
			if( $self->_matches_all )
			{
				return $self->{handle}->get_database->get_all(
					$self->{dataset} );
			}
		}

		# If the above tests failed then	
		# we are returning all matches, but there's no
		# easy shortcut.

		if( !$self->_matches_all && !$justids && scalar @{$self->{ids}} <= 1 )
		{
			my @ids = @{$self->{ids}};
			my $from = $offset;
			if( !defined $count ) { $count = (scalar @ids)-$offset; }
			my $to = $offset+$count-1;
			my @range = @ids[($from..$to)];
		
			return $self->{handle}->get_database->get_single( $self->{dataset}, $range[0] );
		}	
	}
	if( !defined $self->{cache_id} )
	{
		$self->cache;
	}

	my $r = $self->{handle}->get_database->from_cache( 
			$self->{dataset}, 
			$self->{cache_id},
			$offset,
			$count,	
			$justids );

	return $r if( $justids );
		
	return @{$r};
}


######################################################################
=pod

=item $list->map( $function, $info )

Map the given function pointer to all the items in the list, in
order. This loads the items in batches of 100 to reduce memory 
requirements.

$info is a datastructure which will be passed to the function each 
time and is useful for holding or collecting state.

Example:

 my $info = { matches => 0 };
 $list->map( \&deal, $info );
 print "Matches: ".$info->{matches}."\n";


 sub deal
 {
 	my( $handle, $dataset, $eprint, $info ) = @_;
 
 	if( $eprint->get_value( "a" ) eq $eprint->get_value( "b" ) ) {
 		$info->{matches} += 1;
 	}
 }	

=cut
######################################################################

sub map
{
	my( $self, $function, $info ) = @_;	

	my $count = $self->count();

	my $CHUNKSIZE = 100;

	for( my $offset = 0; $offset < $count; $offset+=$CHUNKSIZE )
	{
		my @records = $self->get_records( $offset, $CHUNKSIZE );
		foreach my $item ( @records )
		{
			&{$function}( 
				$self->{handle}, 
				$self->{dataset}, 
				$item, 
				$info );
		}
	}
}

######################################################################
=pod

=item $plugin_output = $list->export( $plugin_id, %params )

Apply an output plugin to this list of items. If the param "fh"
is set it will send the results to a filehandle rather than return
them as a string. 

=cut
######################################################################

sub export
{
	my( $self, $out_plugin_id, %params ) = @_;

	my $plugin_id = "Export::".$out_plugin_id;
	my $plugin = $self->{handle}->plugin( $plugin_id );

	unless( defined $plugin )
	{
		EPrints::abort( "Could not find output plugin $plugin_id" );
	}

	my $req_plugin_type = "list/".$self->{dataset}->confid;

	unless( $plugin->can_accept( $req_plugin_type ) )
	{
		EPrints::abort( 
"Plugin $plugin_id can't process $req_plugin_type data." );
	}
	
	
	return $plugin->output_list( list=>$self, %params );
}

######################################################################
=pod

=item $dataset = $list->get_dataset

Return the EPrints::DataSet which this list relates to.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}

######################################################################
=pod

=item $xhtml = $list->render_description

Return a DOM XHTML description of this list, if available, or an
empty fragment.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{handle}->make_doc_fragment;

	if( defined $self->{desc} )
	{
		$frag->appendChild( $self->{handle}->clone_for_me( $self->{desc}, 1 ) );
		$frag->appendChild( $self->{handle}->make_text( " " ) );
	}
	if( defined $self->{desc_order} )
	{
		$frag->appendChild( $self->{handle}->clone_for_me( $self->{desc_order}, 1 ) );
	}

	return $frag;
}

######################################################################
#
# Clean up any caches and XML belonging to this object.
#
######################################################################

sub DESTROY
{
	my( $self ) = @_;
	
	$self->dispose;
	if( defined $self->{desc} ) { EPrints::XML::dispose( $self->{desc} ); }
	if( defined $self->{desc_order} ) { EPrints::XML::dispose( $self->{desc_order} ); }
}

1;

######################################################################
=pod

=back

=cut

