######################################################################
#
# EPrints::DataObj::Access
#
######################################################################
#
#
######################################################################


=head1 NAME

B<EPrints::DataObj::Access> - Accesses to the Web server

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

=item accessid

Unique id for the access.

=item datestamp

Time of access.

=item requester_id

Id of the requesting user-agent (typically IP address).

=item requester_user_agent

The HTTP user agent string (useful for robots spotting).

=item requester_country

Country the request originated from.

=item requester_institution

Institution the request originated from.

=item referring_entity_id

Id of the object from which the user agent came from (i.e. HTTP referrer).

=item service_type_id

Id of the type of service requested.

=item referent_id

Id of the object requested.

=item referent_docid

Id of the document requested (if relevant).

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Access;

@ISA = ( 'EPrints::DataObj::SubObject' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::Access->get_system_field_info

Core fields contained in a Web access.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"accessid", type=>"counter", required=>1, can_clone=>0,
			sql_counter=>"accessid" },

		{ name=>"datestamp", type=>"timestamp", required=>1, },

		{ name=>"requester_id", type=>"text", required=>1, text_index=>0, },

		{ name=>"requester_user_agent", type=>"text", required=>0, text_index=>0, },

		{ name=>"requester_country", type=>"text", required=>0, text_index=>0, },

		{ name=>"requester_institution", type=>"text", required=>0, text_index=>0, },

		{ name=>"referring_entity_id", type=>"longtext", required=>0, text_index=>0, },

		{ name=>"service_type_id", type=>"text", required=>1, text_index=>0, },

		{ name=>"referent_id", type=>"int", required=>1, text_index=>0, },

		{ name=>"referent_docid", type=>"int", required=>0, text_index=>0, },
	);
}

######################################################################

=back

=head2 Class Methods

=over 4

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::Access->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "access";
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $dataobj->get_referent_id()

Return the fully qualified referent id.

=cut

sub get_referent_id
{
	my( $self ) = @_;

	my $id = $self->get_value( "referent_id" );

	$id =~ /:?(\d+)$/;

	$id = EPrints::OpenArchives::to_oai_identifier( EPrints::OpenArchives::archive_id( $self->{session} ), $1 );

	return $id;
}

=item $dataobj->get_requester_id()

Return the fully qualified requester id.

=cut

sub get_requester_id
{
	my( $self ) = @_;

	my $id = $self->get_value( "requester_id" );

	$id =~ s/^urn:ip://;

	return "urn:ip:$id";
}

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

