######################################################################
#
# EPrints::DataObj::File
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

B<EPrints::DataObj::File> - a stored file

=head1 DESCRIPTION

=head1 CORE FIELDS

=over 4

=item fileid

UID for this filename.

=item datasetid

Dataset the file belongs to.

=item objectid

Object the file belongs to.

=item bucket

Bucket the file belongs to.

=item filename

Name of the file.

=item mime_type

MIME type of the file (e.g. "image/png").

=item hash

Check sum of the file.

=item hash_type

Type of check sum used (e.g. "MD5").

=item size

Size of the file in bytes.

=item mtime

Last modification time of the file.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::File;

@ISA = ( 'EPrints::DataObj::SubObject' );

use EPrints;
use Digest::MD5;

use strict;

######################################################################

=head2 Constructor Methods

=cut

######################################################################

=item $dataobj = EPrints::DataObj::File->new_from_filename( $session, $dataobj, $bucket, $filename )

Convenience method to get an existing File object for $filename stored in the $bucket in $dataobj.

Returns undef if no such record exists.

=cut

sub new_from_filename
{
	my( $class, $session, $dataobj, $bucket, $filename ) = @_;
	
	my $ds = $session->get_repository->get_dataset( $class->get_dataset_id );

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$ds );

	$searchexp->add_field(
		$ds->get_field( "datasetid" ),
		$dataobj->get_dataset->confid );
	$searchexp->add_field(
		$ds->get_field( "objectid" ),
		$dataobj->get_id );
	$searchexp->add_field(
		$ds->get_field( "bucket" ),
		$bucket );
	$searchexp->add_field(
		$ds->get_field( "filename" ),
		$filename );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records(0,1);
	$searchexp->dispose();
	
	return $records[0];
}

=item $dataobj = EPrints::DataObj::File->create_from_filename( $session, $dataobj, $bucket, $filename [, $fh ] )

Convenience method to create a File object for $filename stored in the $bucket in $dataobj. If $fh is defined will read and store the data from $fh in the storage layer.

Returns undef on error.

=cut

sub create_from_filename
{
	my( $class, $session, $dataobj, $bucket, $filename, $fh ) = @_;

	if( defined( $fh ) )
	{
		return unless
			$session->get_storage->store( $dataobj, $bucket, $filename, $fh );
	}

	my $self = $class->new_from_filename( @_[1..$#_] );
	if( !defined( $self ) )
	{
		$self = $class->create_from_data( $session, {
			datasetid => $dataobj->get_dataset->confid,
			objectid => $dataobj->get_id,
			bucket => $bucket,
			filename => $filename,
			size => $session->get_storage->get_size( $dataobj, $bucket, $filename ),
		} );
	}
	else
	{
		$self->set_value( "size", $session->get_storage->get_size( $dataobj, $bucket, $filename ) );
		$self->commit;
	}

	return $self;
}

######################################################################

=head2 Class Methods

=cut

######################################################################

=item $thing = EPrints::DataObj::File->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"fileid", type=>"int", }, 

		{ name=>"datasetid", type=>"text", text_index=>0, }, 

		{ name=>"objectid", type=>"int", }, 

		{ name=>"bucket", type=>"text", },

		{ name=>"filename", type=>"text", },

		{ name=>"mime_type", type=>"text", },

		{ name=>"hash", type=>"longtext", },

		{ name=>"hash_type", type=>"text", },

		{ name=>"size", type=>"int", },

		{ name=>"mtime", type=>"time", },
	);
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::File->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "file";
}

######################################################################

=item $defaults = EPrints::DataObj::File->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;
	
	if( !defined $data->{fileid} )
	{ 
		my $new_id = $session->get_database->counter_next( "fileid" );
		$data->{fileid} = $new_id;
	}

	$data->{mtime} = EPrints::Time::get_iso_timestamp();

	return $data;
}

######################################################################

=head2 Object Methods

=over 4

=cut

######################################################################

sub get_mtime
{
	my( $self ) = @_;

	return $self->get_value( "mtime" );
}

=item $success = $stored->remove

Remove the stored file.

=cut

sub remove
{
	my( $self ) = @_;

	$self->SUPER::remove();

	$self->get_session->get_storage->delete(
		$self->get_parent,
		$self->get_value( "bucket" ),
		$self->get_value( "filename" )
	);
}

=item $fh = $stored->get_fh

Retrieve a file handle to the stored file (this is a wrapper around L<EPrints::Storage>::retrieve).

=cut

sub get_fh
{
	my( $self ) = @_;

	return $self->get_session->get_storage->retrieve(
		$self->get_parent,
		$self->get_value( "bucket" ),
		$self->get_value( "filename" )
	);
}

=item $success = $stored->write_copy( $filename )

Write a copy of this file to $filename.

Returns true if the written file contains the same number of bytes as the stored file.

=cut

sub write_copy
{
	my( $self, $filename ) = @_;

	open(my $out, ">", $filename) or return 0;

	$self->write_copy_fh( $out );

	close($out);

	return $self->get_value( "size" ) == -s $filename;
}

=item $success = $stored->write_copy_fh( $filehandle )

Write a copy of this file to $filehandle.

=cut

sub write_copy_fh
{
	my( $self, $out ) = @_;

	use bytes;

	my $in = $self->get_fh;

	binmode($in);
	binmode($out);

	my $buffer;
	while(sysread($in,$buffer,4096))
	{
		print $out $buffer;
	}

	close($in);
	close($out);
}

=item $md5 = $stored->generate_md5

Calculates and returns the MD5 for this file.

=cut

sub generate_md5
{
	my( $self ) = @_;

	my $md5 = Digest::MD5->new;

	$md5->addfile( $self->get_fh );

	return $md5->hexdigest;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

