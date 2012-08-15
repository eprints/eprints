=head1 NAME

EPrints::DataObj::ImportCache - caching import session

=head1 DESCRIPTION

Inherits from L<EPrints::DataObj>.

=head1 INSTANCE VARIABLES

=over 4

=item $obj->{ "data" }

=item $obj->{ "dataset" }

=item $obj->{ "session" }

=back

=head1 CORE FIELDS

=over 4

=item importid

Unique id for the import.

=item datestamp

Time import record was created.

=item userid

Id of the user responsible for causing the import.

=item source_repository

Source entity from which this import came.

=item url

Location of the imported content (e.g. the file name).

=item description

Human-readable description of the import.

=item last_run

Time the import was last started.

=item last_success

Time the import was last successfully completed.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::CacheDataobj;

use base EPrints::DataObj::SubObject;

use strict;

=item $thing = EPrints::DataObj::CacheDataobj->get_system_field_info

Core fields contained in a Web import.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"cache_dataobj_id", type=>"counter", required=>1, sql_counter=>"cache_dataobj_id", },

		{ name=>"cache_dataobj_map_id", type=>"itemref", required=>1, datasetid=>"cache_dataobj_map", },

		{ name=>"pos", type=>"int", required=>1, },

		{ name=>"datasetid", type=>"id", required=>1, },

		{ name=>"epdata", type=>"storable", required=>1, },
	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################
=pod

=item $dataset = EPrints::DataObj::Import->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "cache_dataobj";
}

sub create_from_data
{
	my( $class, $session, $epdata, $dataset ) = @_;

	my $parent = $epdata->{_parent};
	$epdata->{cache_dataobj_map_id} = $parent->id if defined $parent;
	
	# avoid SubObject clobbering "datasetid"
	return $class->EPrints::DataObj::create_from_data( $session, $epdata, $dataset );
}

######################################################################

=head2 Object Methods

=cut

######################################################################

1;

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

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

