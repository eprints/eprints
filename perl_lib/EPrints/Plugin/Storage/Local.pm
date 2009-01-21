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
use File::Basename;

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

	use bytes;
	use integer;

	my $length = 0;

	my( $local_path, $out_file ) = $self->_filename( $fileobj );

	my( $name, $path, $suffix ) = File::Basename::fileparse( $out_file );

	EPrints::Platform::mkdir( $path );

	open(my $out_fh, ">", $out_file)
		or EPrints::abort( "Unable to write to $out_file: $!" );
	binmode($out_fh);

	my $buffer;
	while(sysread($fh,$buffer,4096))
	{
		$length += length($buffer);
		unless( syswrite($out_fh,$buffer) )
		{
			EPrints::abort( "Error writing to $out_file: $!" );
		}
	}

	close($out_fh);

	$fileobj->add_plugin_copy( $self, $fileobj->get_value( "filename" ) );

	return $length;
}

sub retrieve
{
	my( $self, $fileobj ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj );

	open(my $in_fh, "<", $in_file)
		or EPrints::abort( "Unable to read from $in_file: $!" );

	return $in_fh;
}

sub delete
{
	my( $self, $fileobj ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj );

	return unlink($in_file);
}

sub get_local_copy
{
	my( $self, $fileobj ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj );

	return $in_file;
}

sub get_size
{
	my( $self, $fileobj ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj );

	return -s $in_file;
}

sub _filename
{
	my( $self, $fileobj ) = @_;

	my $parent = $fileobj->get_parent();

	my $local_path;
	my $filename = $fileobj->get_value( "filename" );

	my $in_file;

	if( $parent->isa( "EPrints::DataObj::Document" ) )
	{
		$local_path = $parent->local_path;
		$in_file = "$local_path/$filename";
	}
	elsif( $parent->isa( "EPrints::DataObj::History" ) )
	{
		$local_path = $parent->get_parent->local_path."/revisions";
		$filename = $parent->get_value( "revision" ) . ".xml";
		$in_file = "$local_path/$filename";
	}
	elsif( $parent->isa( "EPrints::DataObj::EPrint" ) )
	{
		$local_path = $parent->local_path;
		$in_file = "$local_path/$filename";
	}
	else
	{
		# Gawd knows?!
	}

	return( $local_path, $in_file );
}

=back

=cut

1;
