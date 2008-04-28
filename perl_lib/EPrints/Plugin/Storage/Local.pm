package EPrints::Plugin::Storage::Local;

use URI;
use URI::Escape;

use EPrints::Plugin::Storage;

@ISA = ( "EPrints::Plugin::Storage" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Local disk storage";

	return $self;
}

=item $success = $store->store( $dataobj, $bucket, $uri, $filehandle )

Read and store all data from $filehandle at $uri. Returns true on success.

=cut

sub store
{
	my( $self, $dataobj, $bucket, $filename, $fh ) = @_;

	if( !EPrints::Utils::is_set( $filename ) )
	{
		EPrints::abort( "Requires filename argument" );
	}

	my( $local_path, $out_file ) = $self->_filename( $dataobj, $bucket, $filename );

	EPrints::Platform::mkdir( $local_path );

	open(my $out_fh, ">", $out_file)
		or EPrints::abort( "Unable to write to $out_file: $!" );
	binmode($out_fh);

	my $buffer;
	while(sysread($fh,$buffer,4096))
	{
		print $out_fh $buffer;
	}

	close($out_fh);

	return 1;
}

=item $filehandle = $store->retrieve( $dataobj, $bucket, $filename )

Retrieve a $filehandle to the object stored at $filename.

=cut

sub retrieve
{
	my( $self, $dataobj, $bucket, $filename ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $dataobj, $bucket, $filename );

	open(my $in_fh, "<", $in_file)
		or EPrints::abort( "Unable to read from $in_file: $!" );

	return $in_fh;
}

=item $success = $store->delete( $dataobj, $bucket, $filename )

Delete the object stored at $filename.

=cut

sub delete
{
	my( $self, $dataobj, $bucket, $filename ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $dataobj, $bucket, $filename );

	return unlink($in_file);
}

=item $size = $store->get_size( $dataobj, $bucket, $filename )

Return the $size (in bytes) of the object stored at $filename.

=cut

sub get_size
{
	my( $self, $dataobj, $bucket, $filename ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $dataobj, $bucket, $filename );

	return -s $in_file;
}

sub _filename
{
	my( $self, $dataobj, $bucket, $filename ) = @_;

	my $local_path = $dataobj->local_path;

	my $in_file;

	if( $bucket eq "data" )
	{
		$in_file = "$local_path/$filename";
	}
	elsif( $bucket eq "thumbnail" )
	{
		$local_path =~ s/(\/\d+)$/\/thumbnails$1/;
		$in_file = "$local_path/$filename";
	}
	else
	{
		EPrints::abort("Unrecognised storage bucket '$bucket'");
	}

	return( $local_path, $in_file );
}

=back

=cut

1;
