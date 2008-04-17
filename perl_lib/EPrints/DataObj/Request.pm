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

		{ name=>"requestid", type=>"int", required=>1, can_clone=>1, },

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

=head2 Constructor Methods

=over 4

=cut

######################################################################

=item $thing = EPrints::DataObj::Access->new( $session, $accessid )

The data object identified by $accessid.

=cut

sub new
{
	my( $class, $session, $accessid ) = @_;

	return $session->get_database->get_single( 
			$session->get_repository->get_dataset( "request" ), 
			$accessid );
}

=item $thing = EPrints::DataObj::Access->new_from_data( $session, $known )

A new C<EPrints::DataObj::Access> object containing data $known (a hash reference).

=cut

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "request" ) );
}


######################################################################

=head2 Class Methods

=cut

######################################################################

=item EPrints::DataObj::Access::remove_all( $session )

Remove all records from the license dataset.

=cut

sub remove_all
{
	my( $class, $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "request" );
	foreach my $obj ( $session->get_database->get_all( $ds ) )
	{
		$obj->remove();
	}
	return;
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

=item $foo = $thing->remove()

Remove this record from the data set (see L<EPrints::Database>).

=cut

sub remove
{
	my( $self ) = @_;
	
	return $self->{session}->get_database->remove(
		$self->{dataset},
		$self->get_id );
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

