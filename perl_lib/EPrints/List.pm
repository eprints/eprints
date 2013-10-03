######################################################################
#
# EPrints::List
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::List> - List of data objects, usually a L<EPrints::Search> result.

=head1 SYNOPSIS

	$list = $search->execute();

	$new_list = $list->reorder( "-creation_date" ); # makes a new list ordered by reverse order creation_date

	$new_list = $list->union( $list2, "creation_date" ) # makes a new list by adding the contents of $list to $list2. the resulting list is ordered by "creation_date"

	$new_list = $list->remainder( $list2, "title" ); # makes a new list by removing the contents of $list2 from $list orders the resulting list by title

	$n = $list->count() # returns the number of items in the list

	@dataobjs = $list->slice( 0, 20 );  #get the first 20 DataObjs from the list in an array

	$list->map( $function, $info ) # performs a function on every item in the list. This is very useful go and look at the detailed description.

	$plugin_output = $list->export( "BibTeX" ); #calls Plugin::Export::BibTeX on the list.

	$dataset = $list->get_dataset(); #returns the dataset in which the containing objects belong

=head1 DESCRIPTION

This class represents an ordered list of objects, all from the same
dataset. Usually this is the results of a search. 

=head1 SEE ALSO
	L<EPrints::Search>

=head1 METHODS

=cut
######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{session}
#     The current EPrints::Session
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
#     when the EPrints::Session terminates.
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

=pod

=item $list = EPrints::List->new( 
repository => $repository, 
dataset => $dataset,
ids => $ids, 
[order => $order] ); 

=item $list = EPrints::List->new( 
repository => $repository, 
dataset => $dataset,
[desc => $desc],
[desc_order => $desc_order],
cache_id => $cache_id );

Note the new() method will be called very rarely since lists will
usually created by an L<EPrints::Search>.

Creates a new list object in memory only. Lists will be
cached if any method requiring order is called, or an explicit 
cache() method is called.

encoded is the serialised version of the searchExpression which
created this list, if there was one.

If keep_cache is set then the cache will not be disposed of at the
end of the current $session. If cache_id is set then keep_cache is
automatically true.

=cut
######################################################################
sub new
{
	my( $class, %self ) = @_;

	$self{session} = $self{repository} if !defined $self{session};

	my $self = \%self;
#	$self->{session} = $opts{session} || $opts{repository};
#	$self->{dataset} = $opts{dataset};
#	$self->{ids} = $opts{ids};
#	$self->{order} = $opts{order};
#	$self->{encoded} = $opts{encoded};
#	$self->{cache_id} = $opts{cache_id};
#	$self->{keep_cache} = $opts{keep_cache};
#	$self->{searchexp} = $opts{searchexp};

	if( !defined $self->{cache_id} && !defined $self->{ids} ) 
	{
		EPrints::abort( "cache_id or ids must be defined in a EPrints::List->new()" );
	}
	if( !defined $self->{session} )
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

$new_list = $list->reorder( "-creation_date" ); # makes a new list ordered by reverse order creation_date

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

	my $db = $self->{session}->get_database;

	my $srctable = $db->cache_table( $self->{cache_id} );

	my $encoded = defined($self->{encoded}) ? $self->{encoded} : "";
	my $new_cache_id  = $db->cache( 
		"$encoded(reordered:$new_order)", # nb. not very neat. 
		$self->{dataset},
		$srctable,
		$new_order );

	my $new_list = EPrints::List->new( 
		session=>$self->{session},
		dataset=>$self->{dataset},
		searchexp=>$self->{searchexp},
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

$list2 - the list which is to be combined to the calling list

$order - a field which the the resulting list will be ordered on. (optional)

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
		session => $self->{session},
		order => $order,
		ids=>\@objectids );
}

######################################################################
=pod

=item $new_list = $list->remainder( $list2, [$order] );

Create a new list from $list with elements from $list2 removed. If order is not set
then this list will not be in any certain order.

Remove all items in $list2 from $list and return the result as a
new EPrints::List.

$list2 - the eprints you want to remove from the calling list

$order - the field the remaining list is to be ordered by

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
		session => $self->{session},
		order => $order,
		ids=>\@objectids );
}

######################################################################
=pod

=item $new_list = $list->intersect( $list2, [$order] );

Create a new list containing only the items which are in both lists.
If order is not set then this list will not be in any certain order.

$list2 - a list to intersect with the calling list

$order -  the field the resulting list will be ordered on

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
		session => $self->{session},
		order => $order,
		ids=>\@objectids );
}

######################################################################
=begin InternalDoc

=item $list->cache

Cause this list to be cached in the database.

=end InternalDoc

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

	my $db = $self->{session}->get_database;
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
		$self->{session}->get_database->drop_cache( $self->{cache_id} );

		$self->{cache_id} = $new_cache_id;
	}
}

######################################################################
=begin InternalDoc

=item $cache_id = $list->get_cache_id

Return the ID of the cache table for this list, or undef.

=end InternalDoc

=cut
######################################################################

sub get_cache_id
{
	my( $self ) = @_;
	
	return $self->{cache_id};
}



######################################################################
=begin InternalDoc

=item $list->dispose

Clean up the cache table if appropriate.

=end InternalDoc

=cut
######################################################################

sub dispose
{
	my( $self ) = @_;

	if( defined $self->{cache_id} && !$self->{keep_cache} )
	{
		if( !defined $self->{session}->get_database )
		{
			print STDERR "Wanted to drop cache ".$self->{cache_id}." but we've already entered clean up and closed the database connection.\n";
		}
		else
		{
			$self->{session}->get_database->drop_cache( $self->{cache_id} );
			delete $self->{cache_id};
		}
	}

	%$self = ();
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
			return $self->{dataset}->count( $self->{session} );
		}
		return( scalar @{$self->{ids}} );
	}

	if( defined $self->{cache_id} )
	{
		#cjg Should really have a way to get at the
		# cache. Maybe we should have a table object.
		return $self->{session}->get_database->count_table( 
			"cache".$self->{cache_id} );
	}

	EPrints::abort( "Called \$list->count() where there was no cache or ids." );
}

=item $dataobj = $list->item( $offset )

Returns the item at offset $offset.

Returns undef if $offset is out of range of the current list of items.

=cut

sub item
{
	my( $self, $offset ) = @_;

	return ($self->slice( $offset, 1 ))[0];
}

######################################################################
=pod

=item @dataobjs = $list->slice( [$offset], [$count] )

Returns the DataObjs in this list as an array. 
$offset - what index through the list to start from.
$count - the maximum to return.

=cut
######################################################################

sub get_records { shift->slice( @_ ) }
sub slice
{
	my( $self , $offset , $count ) = @_;
	
	return $self->_get_records( $offset , $count, 0 );
}


######################################################################
=pod

=item $ids = $list->ids( [$offset], [$count] )

Return a reference to an array containing the object ids of the items 
in the list. You can specify a range of ids using $offset and $count.
This is more efficient if you just need the ids.

$offset - what index through the list to start from.
$count - the maximum to return.

=cut
######################################################################

sub get_ids { shift->ids( @_ ) }
sub ids
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
# Method which sessions getting objects or just ids.
#
######################################################################

sub _get_records 
{
	my ( $self , $offset , $count, $justids ) = @_;

	$offset = $offset || 0;
	# $count = $count || 1; # unspec. means ALL not 1.
	$justids = $justids || 0;

	my @ids;
	if( defined $self->{ids} )
	{
		if( $offset > $#{$self->{ids}} )
		{
			@ids = ();
		}
		if( !defined $count || $offset+$count > @{$self->{ids}} )
		{
			@ids = @{$self->{ids}}[$offset..$#{$self->{ids}}];
		}
		else
		{
			@ids = @{$self->{ids}}[$offset..$offset+$count-1];
		}
	}
	else
	{
		my $cachemap = $self->{session}->get_database->get_cachemap( $self->{cache_id} );
		@ids = $self->{session}->get_database->get_cache_ids( $self->{dataset}, $cachemap, $offset, $count );
	}

	return \@ids if $justids;

# read as many items from the cache as possible...

	my @dataobjs;
	my @missing_ids;

#sf2 - would that scale?
	foreach(@ids)
	{
		if( defined( my $data = $self->{session}->cache_get( "dataobj:".$self->{dataset}->confid.":$_" ) ) )
		{
			push @dataobjs, $self->{dataset}->dataobj_class->new_from_data( $self->{session}, $data, $self->{dataset} );
			next;
		}
		push @missing_ids, $_;
	}

	foreach( $self->{session}->get_database->get_dataobjs( $self->{dataset}, @missing_ids ) )
	{
		$self->{session}->cache_set( "dataobj:".$self->{dataset}->confid.":".$_->id, $_->{data} );
		push @dataobjs, $_;
	}

	return @dataobjs;
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
 	my( $session, $dataset, $eprint, $info ) = @_;
 
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
		my @records = $self->slice( $offset, $CHUNKSIZE );
		foreach my $item ( @records )
		{
			&{$function}( 
				$self->{session}, 
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

$plugin_id - the ID of the Export plugin which is to be used to process the list. e.g. "BibTeX"

$param{"fh"} = "temp_dir/my_file.txt"; - the file the results are to be output to, useful for output too large to fit into memory.


=cut
######################################################################

sub export
{
	my( $self, $out_plugin_id, %params ) = @_;

	my $plugin_id = "Export::".$out_plugin_id;
	my $plugin = $self->{session}->plugin( $plugin_id );

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

=begin InternalDoc

=item $dataset = $list->get_dataset

Return the EPrints::DataSet which this list relates to.

=end InternalDoc

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

	my $frag = $self->{session}->make_doc_fragment;

	if( defined $self->{searchexp} )
	{
		$frag->appendChild( $self->{searchexp}->render_description );
		if( !defined $self->{order} )
		{
			$frag->appendChild( $self->{session}->make_text( " " ) );
			$frag->appendChild( $self->{searchexp}->render_order_description );
		}
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

