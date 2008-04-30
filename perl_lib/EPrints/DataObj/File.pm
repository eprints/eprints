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

Files have revisions but work slightly differently to other objects. A File is only revised when it's contained object data is changed, otherwise revision numbers would get out of sync.

=head1 CORE FIELDS

=over 4

=item fileid

UID for this filename.

=item rev_number (int)

The number of the current revision of this record.

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

=item filesize

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

=item $dataobj = EPrints::DataObj::File->create_from_data( $session, $data [, $dataset ] )

Create a new File record using $data. If "_filehandle" is defined in $data it will be read from and stored.

=cut

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $fh = delete $data->{_filehandle};

	my $self = $class->SUPER::create_from_data( $session, $data, $dataset );

	if( defined( $fh ) )
	{
		$session->get_storage->store( $self, $fh );
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
		{ name=>"fileid", type=>"int", required=>1, import=>0, show_in_html=>0, can_clone=>0 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0, show_in_html=>0 },

		{ name=>"datasetid", type=>"text", text_index=>0, }, 

		{ name=>"objectid", type=>"int", }, 

		{ name=>"bucket", type=>"text", },

		{ name=>"filename", type=>"text", },

		{ name=>"mime_type", type=>"text", },

		{ name=>"hash", type=>"longtext", },

		{ name=>"hash_type", type=>"text", },

		{ name=>"filesize", type=>"int", },

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

	$data->{rev_number} = 1;

	if( defined( $data->{filename} ) )
	{
		my $type = $session->get_repository->call( "guess_doc_type", $session, $data->{filename} );
		if( $type ne "other" )
		{
			$data->{mime_type} = $type;
		}
	}

	return $data;
}

######################################################################

=head2 Object Methods

=over 4

=cut

######################################################################

sub revised
{
	my( $self ) = @_;

	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );
}

sub get_mtime
{
	my( $self ) = @_;

	return $self->get_value( "mtime" );
}

=item $success = $stored->remove

Remove the stored file. Deletes all revisions of the contained object.

=cut

sub remove
{
	my( $self ) = @_;

	$self->SUPER::remove();

	foreach my $revision (1..$self->get_value( "rev_number" ))
	{
		$self->get_session->get_storage->delete( $self, $revision );
	}
}

=item $filename = $file->get_local_copy( [ $revision ] )

Return the name of a local copy of the file (may be a L<File::Temp> object).

Will retrieve and cache the remote object if necessary.

=cut

sub get_local_copy
{
	my( $self, $revision ) = @_;

	return $self->get_session->get_storage->get_local_copy( $self, $revision );
}

=item $fh = $stored->get_fh( [ $revision ] )

Retrieve a file handle to the stored file (this is a wrapper around L<EPrints::Storage>::retrieve).

=cut

sub get_fh
{
	my( $self, $revision ) = @_;

	return $self->get_session->get_storage->retrieve( $self, $revision );
}

=item $success = $file->add_file( $filepath, $filename [, $preserve_path ] )

Read and store the contents of $filepath at $filename.

If $preserve_path is untrue will strip any leading path in $filename.

=cut

sub add_file
{
	my( $self, $filepath, $filename, $preserve_path ) = @_;

	open(my $fh, "<", $filepath) or return 0;
	binmode($fh);

	my $rc = $self->upload( $fh, $filename, -s $filepath, $preserve_path );

	close($fh);

	return $rc;
}

=item $success = $file->upload( $filehandle, $filename, $filesize [, $preserve_path ] )

Read and store the data from $filehandle at $filename at the next revision number.

If $preserve_path is untrue will strip any leading path in $filename.

=cut

sub upload
{
	my( $self, $fh, $filename, $filesize, $preserve_path ) = @_;

	unless( $preserve_path )
	{
		$filename =~ s/^.*\///; # Unix
		$filename =~ s/^.*\\//; # Windows
	}

	$self->set_value( "filename", $filename );
	$self->set_value( "filesize", $filesize );
	$self->revised();

	$self->commit();

	return $self->get_session->get_storage->store( $self, $fh );
}

=item $success = $stored->write_copy( $filename [, $revision] )

Write a copy of this file to $filename.

Returns true if the written file contains the same number of bytes as the stored file.

=cut

sub write_copy
{
	my( $self, $filename, $revision ) = @_;

	open(my $out, ">", $filename) or return 0;

	my $rc = $self->write_copy_fh( $out, $revision );

	close($out);

	return $rc;
}

=item $success = $stored->write_copy_fh( $filehandle [, $revision ] )

Write a copy of this file to $filehandle.

=cut

sub write_copy_fh
{
	my( $self, $out, $revision ) = @_;

	use bytes;

	my $in = $self->get_fh( $revision ) or return 0;

	binmode($in);
	binmode($out);

	my $buffer;
	while(sysread($in,$buffer,4096))
	{
		print $out $buffer;
	}

	close($in);
	close($out);

	return 1;
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

sub update_md5
{
	my( $self ) = @_;

	my $md5 = $self->generate_md5;

	$self->set_value( "hash", $md5 );
	$self->set_value( "hash_type", "MD5" );

	$self->commit();
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

