######################################################################
#
# EPrints::DataObj::SubObject
#
######################################################################
#
#
######################################################################


=head1 NAME

B<EPrints::DataObj::SubObject> - virtual class to support sub-objects

=head1 DESCRIPTION

This virtual class provides some utility methods to objects that are sub-objects of other data objects.

It expects to find "datasetid" and "objectid" fields to identify the parent object with.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::SubObject;

@ISA = qw( EPrints::DataObj );

use strict;

=item $dataobj = EPrints::DataObj::File->new_from_data( $session, $data [, $dataset ] )

Looks for a special B<_parent> element in $data and uses it to set the parent object, if defined.

=cut

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $parent = delete $data->{_parent};

	my $self = $class->SUPER::new_from_data( $session, $data, $dataset );

	if( defined $parent )
	{
		$self->set_parent( $parent );
	}

	return $self;
}

=item $dataobj = EPrints::DataObj::File->create_from_data( $session, $data [, $dataset ] )

Looks for a special B<_parent> element in $data and uses it to create default values for B<datasetid> and B<objectid> if parent is available and those fields exist on the object.

=cut

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $parent = $data->{_parent};
	if( defined( $parent ) )
	{
		if( $dataset->has_field( "datasetid" ) ) 
		{
			$data->{datasetid} = $parent->dataset->base_id;
		}
		if( $dataset->has_field( "objectid" ) )
		{
			$data->{objectid} = $parent->id;
		}
	}

	return $class->SUPER::create_from_data( $session, $data, $dataset );
}

=item $dataobj = $dataobj->get_parent( [ $datasetid [, $objectid ] ] )

Get and cache the parent data object. If $datasetid and/or $objectid are specified will use these values rather than the stored values.

Subsequent calls to get_parent will return the cached object, regardless of $datasetid and $objectid.

=cut

sub parent { shift->get_parent( @_ ) }
sub get_parent
{
	my( $self, $datasetid, $objectid ) = @_;

	return $self->{_parent} if defined( $self->{_parent} );

	my $session = $self->get_session;

	$datasetid = $self->get_value( "datasetid" ) unless defined $datasetid;
	$objectid = $self->get_value( "objectid" ) unless defined $objectid;

	my $ds = $session->dataset( $datasetid );

	my $parent = $ds->get_object( $session, $objectid );
	$self->set_parent( $parent );

	return $parent;
}

sub set_parent
{
	my( $self, $parent ) = @_;

	$self->{_parent} = $parent;
}

=item $id = $dataobj->get_parent_dataset_id()

Returns the id of the dataset that the parent object belongs to.

=cut

sub get_parent_dataset_id
{
	my( $self ) = @_;

	return $self->get_value( "datasetid" );
}

=item $id = $dataobj->get_parent_id()

Returns the id of the parent data object.

=cut

sub get_parent_id
{
	my( $self ) = @_;

	return $self->get_value( "objectid" );
}

1;

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

