######################################################################
#
# EPrints::DataObj::Issue
#
######################################################################
#
#
######################################################################


=head1 NAME

B<EPrints::DataObj::Issue> - a dataobj issue/problem

=head1 DESCRIPTION

Inherits from L<EPrints::SubObject>.

=head1 CORE FIELDS

=over 4

=item issueid

Unique id for the issue.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Issue;

use EPrints::DataObj::SubObject;
@ISA = ( 'EPrints::DataObj::SubObject' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::Issue->get_system_field_info

Core fields for an issue.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"issueid", type=>"id", required=>1, can_clone=>0, },

		{ name=>"datasetid", type=>"id", can_clone=>0, import=>0, },
		{ name=>"objectid", type=>"int", can_clone=>0, import=>0, },
		{ name=>"parent", type=>"parent", },

		{ name=>"type", type=>"id", },
		{ name=>"timestamp", type=>"timestamp", },
		{ name=>"status", type=>"set", options=>
			[qw/ discovered reported ignored autoresolved resolved /],
		},
		{ name=>"reported_by", type=>"itemref", datasetid=>"user", },
		{ name=>"resolved_by", type=>"itemref", datasetid=>"user", },
		{ name=>"description", type=>"longtext", render_single_value=>"EPrints::Extras::render_xhtml_field", },
		{ name=>"comment", type=>"longtext", render_single_value=>"EPrints::Extras::render_xhtml_field", },
	);
}

######################################################################

=back

=head2 Class Methods

=over 4

=cut

######################################################################

sub get_dataset_id
{
	return "issue";
}

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;

	$data->{issueid} = Digest::MD5::md5_hex(join(':',
		$data->{datasetid},
		$data->{objectid},
		$data->{type},
	));

	$data->{status} = "discovered";

	return $data;
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=cut


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

