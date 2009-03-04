######################################################################
#
# EPrints::DataObj::Message
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

B<EPrints::DataObj::Message> - user system message

=head1 DESCRIPTION

This is an internal class that shouldn't be used outside L<EPrints::Database>.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Message;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::Access->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"messageid", type=>"int", required=>1, can_clone=>0,
			sql_counter=>"messageid" },

		{ name=>"datestamp", type=>"time", required=>1, text_index=>0 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>1, text_index=>0 },

		{ name=>"type", type=>"set", required=>1, text_index=>0,
			options => [qw/ message warning error /] },

		{ name=>"message", type=>"longtext", required=>1, text_index=>0 },

	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::Message->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "message";
}

######################################################################

=item $defaults = EPrints::DataObj::Message->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	if( !defined $data->{messageid} )
	{ 
		my $new_id = $session->get_database->counter_next( "messageid" );
		$data->{messageid} = $new_id;
	}

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

