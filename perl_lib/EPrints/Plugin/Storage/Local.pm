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
	my( $self, $dataobj, $bucket, $uri, $fh ) = @_;

	my $local_path = $dataobj->local_path;
	EPrints::Platform::mkdir( $local_path );

	my $out_file = $self->_uri_to_filename( $dataobj, $uri );

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

=item $filehandle = $store->retrieve( $dataobj, $bucket, $uri )

Retrieve a $filehandle to the object stored at $uri.

=cut

sub retrieve
{
	my( $self, $dataobj, $bucket, $uri ) = @_;

	my $in_file = $self->_uri_to_filename( $dataobj, $uri );

	open(my $in_fh, "<", $in_file)
		or EPrints::abort( "Unable to read from $in_file: $!" );

	return $in_fh;
}

=item $success = $store->delete( $dataobj, $bucket, $uri )

Delete the object stored at $uri.

=cut

sub delete
{
	my( $self, $dataobj, $bucket, $uri ) = @_;

	my $in_file = $self->_uri_to_filename( $dataobj, $uri );

	return unlink($in_file);
}

=item $size = $store->get_size( $dataobj, $bucket, $uri )

Return the $size (in bytes) of the object stored at $uri.

=cut

sub get_size
{
	my( $self, $dataobj, $bucket, $uri ) = @_;

	my $in_file = $self->_uri_to_filename( $dataobj, $uri );

	return -s $in_file;
}

sub _uri_to_filename
{
	my( $self, $dataobj, $uri ) = @_;

	my $local_path = $dataobj->local_path;
	$uri = URI->new( $uri );

	my( undef, undef, $obj_type, $id, $sub_type, $filename ) = split /\//, $uri->path;

	$filename = URI::Escape::uri_unescape( $filename );
	$filename =~ s/[\/\\:]//g;
	$filename =~ s/^\.+//g;

	my $in_file;

	if( $sub_type eq "bitstream" )
	{
		$in_file = "$local_path/$filename";
	}
	elsif( $sub_type eq "thumbnail" )
	{
		$local_path =~ s/(\/\d+)$/\/thumbnails$1/;
		$in_file = "$local_path/$filename";
	}
	else
	{
		EPrints::abort("Unrecognised storage sub-type '$sub_type' from URL '$uri'");
	}

	return $in_file;
}

=back

=cut

1;
