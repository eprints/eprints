######################################################################
#
# EPrints::DataObj::UploadProgress
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

		{ name=>"size", type=>"int", required=>1 },

		{ name=>"received", type=>"int", required=>1 },
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

	my $progressid = ($uri =~ /progress_id=([a-fA-F0-9]{32})/)[0];

	if( !$progressid )
	{
		return undef;
	}

	my $progress;

	for(1..16)
	{
		$progress = EPrints::DataObj::UploadProgress->new( $session, $progressid );
		last if defined $progress;
		select(0.250);
	}

	return $progress;
}

sub remove_expired
{
	my( $class, $session ) = @_;

	my $dataset = $session->get_repository->get_dataset( $class->get_dataset_id );

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

Update callback for use with L<CGI>.

=cut

sub update_cb
{
	my( $filename, $buffer, $bytes_read, $self ) = @_;

	$self->set_value( "received", $bytes_read );
	$self->commit;
}

=item $javascript = $progress->render_json()

Return a JSON serialisation of this object.

=cut

sub render_json
{
	my( $self ) = @_;

	my $content = sprintf('{"size":%d,"received":%d}',
		$self->get_value( "size" ),
		$self->get_value( "received" )
	);

	return $content;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

