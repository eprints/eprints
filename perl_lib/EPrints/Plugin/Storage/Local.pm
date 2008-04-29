=head1 NAME

EPrints::Plugin::Storage::Local - storage on the local disk

=head1 DESCRIPTION

See L<EPrints::Plugin::Storage> for available methods.

=head1 METHODS

=over 4

=cut

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

sub store
{
	my( $self, $fileobj, $fh ) = @_;

	my( $local_path, $out_file ) = $self->_filename( $fileobj );

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

sub retrieve
{
	my( $self, $fileobj, $revision ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj, $revision );

	open(my $in_fh, "<", $in_file)
		or EPrints::abort( "Unable to read from $in_file: $!" );

	return $in_fh;
}

sub delete
{
	my( $self, $fileobj, $revision ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj, $revision );

	return unlink($in_file);
}

sub get_size
{
	my( $self, $fileobj, $revision ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj, $revision );

	return -s $in_file;
}

sub _filename
{
	my( $self, $fileobj, $revision ) = @_;

	my $doc = $fileobj->get_parent();
	my $local_path = $doc->local_path;

	$revision ||= $fileobj->get_value( "rev_number" );
	my $bucket = $fileobj->get_value( "bucket" );
	my $filename = $fileobj->get_value( "filename" );

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
	elsif( $bucket eq "revision" )
	{
		$local_path .= "/revisions";
		$filename =~ s/^eprint/$revision/;
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
