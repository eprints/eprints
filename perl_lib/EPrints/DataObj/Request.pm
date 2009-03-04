######################################################################
#
# EPrints::DataObj::Request
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

		{ name=>"requestid", type=>"int", required=>1, can_clone=>1,
			sql_counter=>"requestid" },

		{ name=>"eprintid", type=>"itemref", 
			datasetid=>"eprint", required=>1 },

		{ name=>"docid", type=>"text", required=>0 },

		{ name=>"datestamp", type=>"time", required=>1, },

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

=item $defaults = EPrints::DataObj::Access->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	$data->{requestid} = $session->get_database->counter_next( "requestid" );

	$data->{datestamp} = EPrints::Time::get_iso_timestamp();

	return $data;
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

