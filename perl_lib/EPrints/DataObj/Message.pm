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
		{ name=>"messageid", type=>"int", required=>1, can_clone=>0 },

		{ name=>"datestamp", type=>"time", required=>1, text_index=>0 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>1, text_index=>0 },

		{ name=>"type", type=>"set", required=>1, text_index=>0,
			options => [qw/ message warning error /] },

		{ name=>"message", type=>"longtext", required=>1, text_index=>0 },

	);
}

######################################################################

=back

=head2 Constructor Methods

=over 4

=cut

######################################################################

=item $thing = EPrints::DataObj::Message->new( $session, $id )

The data object identified by $id.

=cut

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_database->get_single( 
			$session->get_repository->get_dataset( "message" ),
			$id );
}

=item $thing = EPrints::DataObj::Message->new_from_data( $session, $known )

A new C<EPrints::DataObj::Message> object containing data $known (a hash reference).

=cut

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "message" ) );
}

######################################################################

=head2 Class Methods

=cut

######################################################################

=item EPrints::DataObj::Message::remove_all( $session )

Remove all records from the message dataset.

=cut

sub remove_all
{
	my( $class, $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "message" );
	foreach my $obj ( $session->get_database->get_all( $ds ) )
	{
		$obj->remove();
	}
	return;
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

=item ($tags,$labels) = EPrints::DataObj::Message::tags_and_labels( $session, $dataset )

Returns the tags and labels for all records in this dataset.

=cut

sub tags_and_labels
{
	my( $class, $session, $ds ) = @_;

	my $searchexp = EPrints::Search->new(
		allow_blank => 1,
		custom_order => "messageid",
		session => $session,
		dataset => $ds );

	$searchexp->perform_search();
	
	my( @tags, %labels );
	foreach my $l ( $searchexp->get_records() )
	{
		push @tags, my $id = $l->get_value( "messageid" );
		$labels{$id} = $l->get_label();
	}

	$searchexp->dispose();

	return( \@tags, \%labels );
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
	
	my $rc = 1;
	
	my $database = $self->{session}->get_database;

	$rc &&= $database->remove(
		$self->{dataset},
		$self->get_id );

	return $rc;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

