######################################################################
#
# EPrints::DataObj::Request
#
######################################################################
#
#
######################################################################


=head1 NAME

B<EPrints::DataObj::Request> - Log document requests and responses (for request document button)

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Request;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::DocRequest->get_system_field_info

Core fields contained in a document request.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return (

		{ name=>"requestid", type=>"counter", required=>1, can_clone=>1,
			sql_counter=>"requestid" },

		{ name=>"eprintid", type=>"itemref", 
			datasetid=>"eprint", required=>1 },

		{ name=>"docid", type=>"text", required=>0 },

		{ name=>"datestamp", type=>"timestamp", required=>1, },

		{ name=>"userid", type=>"itemref", 
			datasetid=>"user", required=>0 },

		{ name=>"email", type=>"text", required=>1 },

		{ name=>"requester_email", type=>"text", required=>1 },

		{ name=>"reason", type=>"longtext", required=>0 },

	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::Request->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "request";
}

######################################################################

=head2 Object Methods

=cut

######################################################################

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

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

