######################################################################
#
# EPrints::DataObj::Cachemap
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

B<EPrints::DataObj::Cachemap> - cache tables

=head1 DESCRIPTION

This is an internal class that shouldn't be used outside L<EPrints::Database>.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Cachemap;

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
		{ name=>"cachemapid", type=>"int", required=>1, can_clone=>0 },

		{ name=>"created", type=>"int", required=>1, text_index=>0 },

		{ name=>"lastused", type=>"int", required=>0, text_index=>0 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>0, text_index=>0 },

		{ name=>"searchexp", type=>"text", required=>0, text_index=>0 },

		{ name=>"oneshot", type=>"boolean", required=>0, text_index=>0 },
	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::Cachemap->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "cachemap";
}

######################################################################

=item $defaults = EPrints::DataObj::Cachemap->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	if( !defined $data->{cachemapid} )
	{ 
		my $new_id = $session->get_database->counter_next( "cachemapid" );
		$data->{cachemapid} = $new_id;
	}

	$data->{created} = time();

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
	
	my $rc = 1;
	
	my $database = $self->{session}->get_database;

	$rc &&= $database->remove(
		$self->{dataset},
		$self->get_id );

	my $table = $database->cache_table( $self->get_id );

	$rc &&= $database->drop_table( $table );

	return $rc;
}

sub get_sql_table_name
{
	my( $self ) = @_;

	return "cache" . $self->get_id;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

