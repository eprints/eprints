######################################################################
#
# EPrints::DataObj::History
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::DataObj::History> - An element in the history of the arcvhive.

=head1 DESCRIPTION

This class describes a single item in the history dataset. A history
object describes a single action taken on a single item in another
dataset.

Changes to document are considered part of changes to the eprint it
belongs to.

=head1 METADATA

=over 4

=item historyid (int)

The unique numerical ID of this history event. 

=item userid (itemref)

The id of the user who caused this event. A value of zero or undefined
indicates that there was no user responsible (ie. a script did it). 

=item datasetid (text)

The name of the dataset to which the modified item belongs. "eprint"
is used for eprints, rather than the inbox, buffer etc.

=item objectid (int)

The numerical ID of the object in the dataset. 

=item object_revision (int)

The revision of the object. This is the revision number after the
action occured. Not all actions increase the revision number.

=item action (set)

The type of event. Provisionally, this is a subset of the new list
of privilages.

=item details (longtext)

If this is a "rejection" then the details contain the message sent
to the user. 

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::History;

@ISA = ( 'EPrints::DataObj::File' );

use EPrints;

use strict;


######################################################################
=pod

=item $field_info = EPrints::DataObj::History->get_system_field_info

Return the metadata field configuration for this object.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"historyid", type=>"counter", required=>1, can_clone=>0,
			sql_counter=>"historyid" }, 

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>0 },

		{ name=>"actor", type=>"text", text_index=>0, },
	
		# should maybe be a set?
		{ name=>"datasetid", type=>"id", text_index=>0, }, 

		# is this required?
		{ name=>"objectid", type=>"int", }, 

		# note: that's the revision of the target dataobj!
		{ name=>"object_revision", type=>"int", },

		# TODO should be a set when I know what the actions will be
		{ name=>"action", type=>"set", text_index=>0, options=>[qw/
				create 
				modify 
				mail_owner 
				move_inbox_to_buffer 
				move_buffer_to_archive 
				move_buffer_to_inbox 
				move_archive_to_deletion 
				move_archive_to_buffer 
				move_deletion_to_archive
				destroy
				removal_request 
				reject_request
				accept_request
				note
				other
				/], },
		# sf2 - from File
		
		{ name=>"fieldname", type=>"id", import=>0, export => 0,can_clone=>0 }, 
		
		{ name=>"filename", type=>"id", },

		{ name=>"mime_type", type=>"id", sql_index=>0, export => 0 },

		{ name=>"hash", type=>"id", maxlength=>64, export => 0 },

		{ name=>"hash_type", type=>"id", maxlength=>32, export => 0 },

		{ name=>"filesize", type=>"bigint", sql_index=>0 },

		{ name=>"url", type=>"url", virtual=>1 },

		{ name=>"data", type=>"base64", virtual=>1 },

		{
			name=>"copies", type=>"compound", multiple=>1, export => 0,
			fields=>[{
				name=>"pluginid",
				type=>"id",
			},{
				name=>"sourceid",
				type=>"id",
			}],
		},
	);
}



######################################################################
# =pod
# 
# =item EPrints::DataObj::History::create( $session, $data );
# 
# Create a new history object from this data. Unlike other create
# methods this one does not return the new object as it's never 
# needed, and would increase the load of modifying items.
# 
# Also, this does not queue the fields for indexing.
# 
# =cut
######################################################################

sub create
{
	my( $session, $data ) = @_;

	return EPrints::DataObj::History->create_from_data( 
		$session, 
		$data,
		$session->dataset( "history" ) );
}

sub create_from_data
{
	my( $class, $repository, $data, $dataset ) = @_;

	my $content = delete $data->{_content} || delete $data->{_filehandle};
	my $filepath = delete $data->{_filepath};

	# if things go wrong later filesize will be zero
	my $filesize = $data->{filesize};
	$data->{filesize} = 0;

	$data->{mime_type} ||= 'application/json';

	$data->{repository} = $repository;

	# note: we don't call $class->SUPER (SUPER = DataObj::File here) coz 
	# this would call $self->commit and that's not allowed
	my $self = EPrints::DataObj::create_from_data( $class, $repository, $data, $dataset );
	return if !defined $self;

	# content write failed
	if( !defined $self->set_file( $content, $filesize ) )
	{
		return undef;
	}

	return $self;
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::History->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $repository, $data, $dataset ) = @_;
	
	$class->SUPER::get_defaults( $repository, $data, $dataset );

	my $user;
	if( defined $data->{userid} )
	{
		$user = $repository->dataset( 'user' )->dataobj( $data->{userid} );
	}
	else
	{
		$user = $repository->current_user;
	}

	if( defined $user ) 
	{
		$data->{actor} = $user->internal_uri;
	}
	else
	{
		# command line or not logged in. Store script name.
		$data->{actor} = $0;
	}

	my $parent = $data->{_parent};

	$data->{datasetid} ||= $parent->dataset->id;
	$data->{objectid} ||= $parent->id;
	$data->{object_revision} ||= ( $parent->revision - 1 );

	return $data;
}

######################################################################
=pod

=item $object = $history->get_dataobj

Returns the object to which this history event relates.

=cut
######################################################################

sub get_dataobj
{
	my( $self ) = @_;

	return unless( $self->is_set( "datasetid" ) );
	my $ds = $self->{session}->get_repository->get_dataset( $self->get_value( "datasetid" ) );
	return $ds->get_object( $self->{session}, $self->get_value( "objectid" ) );
}

######################################################################
=pod

=item $user = $history->get_user

Returns the user object of the user who caused this event.

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	return undef unless $self->is_set( "userid" );

	if( defined($self->{user}) )
	{
		# check we still have the same owner
		if( $self->{user}->get_id eq $self->get_value( "userid" ) )
		{
			return $self->{user};
		}
	}

	$self->{user} = EPrints::DataObj::User->new( 
		$self->{session}, 
		$self->get_value( "userid" ) );

	return $self->{user};
}

=item $history = $history->get_previous()

Returns the previous event for the object parent of this event.

Returns undef if no such event exists.

=cut

sub get_previous
{
	my( $self ) = @_;

	return $self->{_previous} if exists( $self->{_previous} );

	my $dataset = $self->get_dataset;

	my $revision = $self->get_value( "revision" ) - 1;
	
	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [ "datasetid" ],
				value => $self->value( "datasetid" ),
			},
			{
				meta_fields => [ "objectid" ],
				value => $self->value( "objectid" ),
			},
			{
				meta_fields => [ "revision" ],
				value => $revision,
			}
		]);

	return $self->{_previous} = $results->item( 0 );
}


######################################################################
#
# $boolean = EPrints::DataObj::History::empty_tree( $domtree )
#
# return true if there is no text in the tree other than
# whitespace,
#
# Will maybe be moved to XML or Utils
#
######################################################################

sub empty_tree
{
	my( $domtree ) = @_;

	return 1 unless defined $domtree;

	if( EPrints::XML::is_dom( $domtree, "Text" ) )
	{
		my $v = $domtree->nodeValue;
		
		if( $v=~m/^[\s\r\n]*$/ )
		{
			return 1;
		}
		return 0;
	}

	if( EPrints::XML::is_dom( $domtree, "Element" ) )
	{
		foreach my $cnode ( $domtree->getChildNodes )
		{
			unless( empty_tree( $cnode ) )
			{
				return 0;
			}
		}
		return 1;
	}

	return 1;
}


######################################################################
#
# $boolean = EPrints::DataObj::History::diff( $tree1, $tree2 )
#
# Return true if the XML trees are not the same, otherwise false.
#
######################################################################

sub diff
{
	my( $a, $b ) = @_;

	if( defined $a && !defined $b )
	{
		return 1;
	}
	if( !defined $a && defined $b )
	{
		return 1;
	}
	if( ref( $a ) ne ref( $b ) )
	{
		return 1;
	}
		
	if( $a->nodeName ne $b->nodeName )
	{
		return 1;
	}
		

	
	if( EPrints::XML::is_dom( $a, "Text" ) )
	{
		my $va = $a->nodeValue;
		my $vb = $b->nodeValue;

		# both empty
		if( $va=~m/^[\s\r\n]*$/ && $vb=~m/^[\s\r\n]*$/ )
		{
			return 0;
		}

		if( $va eq $vb )	
		{
			return 0;
		}

		return 1;
	}

	if( EPrints::XML::is_dom( $a, "Element" ) )
	{
		my @alist = $a->getChildNodes;
		my @blist = $b->getChildNodes;
		return( 1 ) if( scalar @alist != scalar @blist );
		for( my $i=0;$i<scalar @alist;++$i )
		{
			return 1 if diff( $alist[$i], $blist[$i] );
		}
		return 0;
	}

	return 0;
}

######################################################################
#
# @lines = EPrints::DataObj::History::_mktext( $session, $text, $offset, $endw, $width )
#
# Return the $text string broken into lines which are $width long, or
# less.
#
# Inserts a 90 degree arrow at the end of each broken line to indicate
# that it has been broken.
#
######################################################################

sub _mktext
{
	my( $session, $text, $offset, $endw, $width ) = @_;

	return () unless length( $text );

	my $lb = chr(8626);
	my @bits = split(/[\r\n]/, $text );
	my @b2 = ();
	
	foreach my $t2 ( @bits )
	{
		while( $offset+length( $t2 ) > $width )
		{
			my $cut = $width-1-$offset;
			push @b2, substr( $t2, 0, $cut ).$lb;
			$t2 = substr( $t2, $cut );
			$offset = 0;
		}
		if( $offset+$endw+length( $t2 ) > $width )
		{
			push @b2, $t2.$lb, "";
		}
		else
		{
			push @b2, $t2;
		}
	}

	return @b2;
}

######################################################################
#
# $boolean = EPrints::DataObj::History::diff( $tree1, $tree2 )
#
# Return true if the XML trees are not the same, otherwise false.
# render $text into wrapped XML DOM.
#
######################################################################

sub mktext
{
	my( $session, $text, $offset, $endw, $width ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw, $width );

	return $session->make_text( join( "\n", @bits ) );
}

######################################################################
#
# $xhtml = EPrints::DataObj::History::mkpad( $session, $text, $offset, $endw, $width )
#
# Return DOM of vertical padding equiv. to the lines that would
# be needed to render $text.
#
######################################################################


sub mkpad
{
	my( $session, $text, $offset, $endw, $width ) = @_;

	my @bits = _mktext( $session, $text, $offset, $endw, $width );

	return $session->make_text( "\n"x((scalar @bits)-1) );
}

sub commit
{
	my( $self, $force ) = @_;

	# cannot call "comit" on SUPER nor on the parent dataobj
	# coz history objects are created from the parent "commit"
	# method - that'd create an infinite loop
	
	$self->EPrints::DataObj::commit( $force );
}

sub diff_data
{
	my( $self ) = @_;

	my $json = "";
	$self->get_file( sub { $json .= $_[0] } );

	if( $json )
	{
		my $epdata;
		eval {
			$epdata = JSON->new->utf8(1)->decode( $json );
		};
		if( $@ )
		{
			$self->repository->log( "Failed to parse json.diff: $@" );
			return;
		}
		return $epdata;
	}

	return;
}

######################################################################
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

