######################################################################
#
# EPrints::DataObj::UploadProgress
#
######################################################################
#
#
######################################################################


=head1 NAME

B<EPrints::DataObj::UploadProgress> - uploads-in-progress state

=head1 DESCRIPTION

This is an internal class.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::UploadProgress;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::UploadProgress->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"progressid", type=>"text", required=>1 },

		{ name=>"expires", type=>"int", required=>1 },

		{ name=>"size", type=>"bigint", required=>1 },

		{ name=>"received", type=>"bigint", required=>1 },
	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::UploadProgress->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "upload_progress";
}

=item $progress = EPrints::DataObj::UploadProgress->new_from_request( $session )

Create a new $progress object based on the current request.

Returns undef if no file upload is pointed to by this request.

=cut

sub new_from_request
{
	my( $class, $session ) = @_;

	my $uri = $session->get_request->unparsed_uri;

	my $progressid = ($uri =~ /progress_?id=([a-fA-F0-9]{32})/)[0];

	if( !$progressid )
	{
		return undef;
	}

	my $progress;

	for(1..16)
	{
		$progress = EPrints::DataObj::UploadProgress->new( $session, $progressid );
		last if defined $progress;
		select(undef, undef, undef, 0.250);
	}

	return $progress;
}

sub remove_expired
{
	my( $class, $session ) = @_;

	my $dataset = $session->dataset( $class->get_dataset_id );

	my $dbh = $session->get_database;

	my $Q_table = $dbh->quote_identifier( $dataset->get_sql_table_name() );
	my $Q_expires = $dbh->quote_identifier( "expires" );
	my $Q_time = $dbh->quote_int( time() );

	$dbh->do( "DELETE FROM $Q_table WHERE $Q_expires <= $Q_time" );
}

######################################################################

=item $defaults = EPrints::DataObj::UploadProgress->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	$data->{expires} = time() + 60*60*24*7; # 1 week

	return $data;
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $progress->update_cb( FILENAME, BUFFER, BYTES_READ, PROGRESS )

Update callback for use with L<CGI>. Limits database writes to a minimum of 1 seconds between updates.

=cut

sub update_cb
{
	my( $filename, $buffer, $bytes_read, $self ) = @_;

	$self->set_value( "received", $bytes_read );
	if( !defined( $self->{_mtime} ) || (time() - $self->{_mtime}) > 0 )
	{
		$self->commit;
		$self->{_mtime} = time();
	}
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

