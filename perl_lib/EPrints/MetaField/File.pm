#####################################################################
#
# EPrints::MetaField::File;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Subobject> - Sub Object an object.

=head1 DESCRIPTION

This is an abstract field which represents an item, or list of items,
in another dataset, but which are a sub part of the object to which
this field belongs, and have no indepentent status.

For example: Documents are part of EPrints.

=over 4

=cut

package EPrints::MetaField::File;

use strict;
use warnings;
use EPrints::MetaField::Subobject;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Subobject );
}

######################################################################

sub get_property_defaults
{
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = "file";	
	$defaults{dataset_fieldname} = "datasetid";
	$defaults{dataobj_fieldname} = "objectid";
	$defaults{show_in_fieldlist} = 0;
	$defaults{match} = "IN";
	$defaults{thumbnails} = [];

	return %defaults;
}

=item $field->set_value( $dataobj, $value )

B<Cache> the $value in the data object. To actually update the value in the database you must commit the $value objects.

=cut

# sf2 - this is tricky for file-objects as it needs to handle the "multiple" property... 
#
# if single, a set_value if empty creates a new file dataobj
# if single, a set_value if !empty updates that file dataobj
# if single, a set_value( undef ) must delete the related file dataobj
#
# if multiple, a set_value might add new file dataobj or update existing ones (or delete ones :-))
# 
# but for a field like a "file", what should be the $value?! get_value returns the file dataobjs
#
# "file" field is a good example to see how we can generalise/abstract the MetaField methods - cos it should work like any other fields - we 
# cannot hard-code stuff in DataObj etc to make MetaField/File work differently than other MetaField/*


sub set_value
{
	my( $self, $dataobj, $value ) = @_;

	if( !defined $value )
	{
		# should delete any related file-dataobj's whether single of multiple
	}


	# don't populate changed nor perform an _equal for object caching
	$dataobj->{data}->{$self->get_name} = $value;
}

sub value
{
	my( $self, $parent, $pos ) = @_;
	
	# parent doesn't have an id defined
	return $self->property( "multiple" ) ? [] : undef
		if( !defined $parent || !EPrints::Utils::is_set( $parent->id ) );

	my $ds = $self->repository->dataset( $self->property( "datasetid" ) );
	my $searchexp = $ds->prepare_search();
	
	$searchexp->add_field(
		$ds->field( "datasetid" ),
		$parent->dataset->base_id
	);

	$searchexp->add_field(
		$ds->field( "objectid" ),
		$parent->id
	);

	$searchexp->add_field(
		$ds->field( "fieldname" ),
		$self->name
	);

	my $results = $searchexp->perform_search;

#TODO not working: (the slice with @args)	
	my @args = defined $pos ? ( $pos, 1 ) : ();
	my @records = $results->slice( @args );

	if( scalar @records && $records[0]->isa( "EPrints::DataObj::SubObject" ) )
	{
		foreach my $record (@records)
		{
			$record->set_parent( $parent );
		}
	}
	
	if( $self->get_property( "multiple" ) )
	{
		return \@records;
	}
	else
	{
		return $records[0];
	}
}


# stolen from DataObj::add_stored_file..
# a file should be stored against a field in a dataobj, not against a dataobj
sub add_stored_file
{
        my( $self, $filename, $filehandle, $filesize ) = @_;

# the "multiple" / fieldpos stuff might be tricky to handle...

        my $file = $self->get_stored_file( $filename );

        if( defined($file) )
        {
                $file->remove();
        }

        $file = $self->{repository}->dataset( "file" )->create_dataobj( {
                _parent => $self,
                _content => $filehandle,
                filename => $filename,
                filesize => $filesize,
        } );

        # something went wrong
        if( defined $file && $file->value( "filesize" ) != $filesize )
        {
                $self->{repository}->log( "Error while writing file '$filename': size mismatch between caller ($filesize) and what was written: ".$file->value( "filesize" ) );
                $file->remove;
                undef $file;
        }

        return $file;
}


sub get_stored_file
{
        my( $self, $filename ) = @_;

        my $file = EPrints::DataObj::File->new_from_filename(
                $self->{repository},
                $self,
                $filename
        );

        if( defined $file )
        {
                $file->set_parent( $self );
        }

        return $file;
}









######################################################################
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

