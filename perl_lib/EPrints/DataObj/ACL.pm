######################################################################
#
# EPrints::DataObj::ACL
#
######################################################################
#
#
######################################################################

package EPrints::DataObj::ACL;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;


######################################################################
=pod

=item $field_info = EPrints::DataObj::User->get_system_field_info

Return an array describing the system metadata of the this 
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"aclid", type=>"counter", required=>1, import=>0, can_clone=>1,
			sql_counter=>"aclid" },

		{ name=>"userid", type=>"id", required=>1 },

		{ name => "priv", type => "id", required => 1 },
		{ name => "action", type => "id", required => 1 },
		{ name => "context", type => "id", required => 1 },
		{ name => "datasetid", type => "id", required => 1 },
		{ name => "dataobjid", type => "id", required => 1 },
	)
};



sub new_from_data
{
	my( $class, $repository, $known ) = @_;

	return $class->SUPER::new_from_data(
			$repository,
			$known,
			$repository->dataset( "acl" ) );
}

sub get_dataset_id
{
	return "acl";
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

