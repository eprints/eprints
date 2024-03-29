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
use Time::Local 'timegm_nocheck';

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

		{ name=>"email", type=>"email", required=>1 },

		{ name=>"requester_email", type=>"email", required=>1 },

		{ name=>"reason", type=>"longtext", required=>0 },

		{ name=>"expiry_date", type=>"time", required=>0 },

		{ name=>"code", type=>"text", required=>0 },

		{ name=>"pin", type=>"text", required=>0 },
	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $request = EPrints::DataObj::Request->request_with_pin( $repository, $pin )

Return the Request object with the given pin, or undef if one is not
found.

QUT addition for pin-based request security.

=cut
######################################################################

sub request_with_pin
{
	my( $repo, $pin ) = @_;

	my $dataset = $repo->dataset( 'request' );

	my $searchexp = EPrints::Search->new(
					 satisfy_all => 1,
					 session => $repo,
					 dataset => $dataset,
					);

	$searchexp->add_field( $dataset->get_field( 'pin' ),
			   $pin,
			   'EQ',
			   'ALL'
			 );

	my $results = $searchexp->perform_search;

	return $results->item( 0 );
}

######################################################################
=pod

=item $dataobj = EPrints::DataObj->new_from_data( $session, $data, $dataset )

Construct a new EPrints::DataObj object based on the $data hash
reference of metadata.

Used to create an object from the data retrieved from the database.

Create a new object of this type in the database.

Just calls the L<EPrints::DataObj> method but if the
use_request_copy_pin_security option is set it ensures that the pin
is set.

QUT addition for pin-based request security.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	$dataset = $dataset || undef;

	my $dataobj = $class->SUPER::new_from_data( $session, $data, $dataset );

	if ( $session->config( 'use_request_copy_pin_security' ) )
	{
		$dataobj->set_pin;
	}

	return $dataobj;
}

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

sub new_from_code
{
	my( $class, $session, $code ) = @_;
	
	return unless( defined $code );

	return $session->dataset( $class->get_dataset_id )->search(
                filters => [
                        { meta_fields => [ 'code' ], value => "$code", match => 'EX' },
                ])->item( 0 );
}

sub has_expired
{
	my( $self ) = @_;

	my $expiry = $self->get_value( "expiry_date" );
	return 1 unless( defined $expiry );

	my( $year,$mon,$day,$hour,$min,$sec ) = split /[- :]/, $expiry;
	my $t = timegm_nocheck $sec||0,$min||0,$hour,$day,$mon-1,$year-1900;

	return 1 if( !defined $t ||  $t <= time );

	return 0;
}

######################################################################
=pod

=item $pin = EPrints::DataObj::Request->set_pin

Sets the pin field of this L<EPrints::DataObj::Request> and returns the value.

QUT addition for pin-based request security.

=cut
######################################################################

sub set_pin
{
    my( $self ) = @_;
    # Generate a random unique pin by using a random string prefixed
    # by the (unique and sequential) request ID
    my $pin = ($self->get_id() // '') . EPrints::Utils::generate_password();
    $self->set_value( 'pin', $pin );
    return $pin;
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

