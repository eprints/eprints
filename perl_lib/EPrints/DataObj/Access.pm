######################################################################
#
# EPrints::DataObj::Access
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


=head1 NAME

B<EPrints::DataObj::Access> - Accesses to the Web server

=head1 DESCRIPTION

Inherits from L<EPrints::DataObj>.

=head1 INSTANCE VARIABLES

=over 4

=item $obj->{ "data" }

=item $obj->{ "dataset" }

=item $obj->{handle}

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

Id of the document requested (if relevent).

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Access;

@ISA = ( 'EPrints::DataObj' );

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

	$id = EPrints::OpenArchives::to_oai_identifier( $self->{handle}->get_repository->get_conf( "oai" )->{v2}->{ "archive_id" }, $1 );

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

