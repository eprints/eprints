=head1 NAME

EPrints::Plugin::Storage::LocalCompress - storage on the local disk

=head1 DESCRIPTION

See L<EPrints::Plugin::Storage> for available methods.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Storage::LocalCompress;

use strict;

use URI;
use URI::Escape;
use File::Basename;

use EPrints::Plugin::Storage::Local;

our @ISA = ( "EPrints::Plugin::Storage::Local" );

our $DISABLE = eval "use PerlIO::gzip; return 1" ? 0 : 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Compressed local disk storage";
	$self->{storage_class} = "a_local_disk_storage";

	return $self;
}

sub open_write
{
	my( $self, $fileobj ) = @_;

	my( $local_path, $out_file ) = $self->_filename( $fileobj );

	my( $name, $path, $suffix ) = File::Basename::fileparse( $out_file );

	EPrints::Platform::mkdir( $path );

	$out_file .= ".gz";

	my $out_fh;
	unless( open($out_fh, ">:gzip", $out_file) )
	{
		$self->{error} = "Unable to write to $out_file: $!";
		$self->{handle}->get_repository->log( $self->{error} );
		return 0;
	}

	$self->{_fh}->{$fileobj} = $out_fh;
	$self->{_name}->{$fileobj} = $out_file;

	return 1;
}

sub write
{
	my( $self, $fileobj, $buffer ) = @_;

	use bytes;
	use integer;

	my $fh = $self->{_fh}->{$fileobj}
		or Carp::croak "Must call open_write before write";

	unless( print $fh $buffer )
	{
		my $out_file = $self->{_name}->{$fileobj};
		unlink($out_file);
		$self->{error} = "Error writing to $out_file: $!";
		$self->{handle}->get_repository->log( $self->{error} );
		return 0;
	}

	return 1;
}

sub close_write
{
	my( $self, $fileobj ) = @_;

	delete $self->{_name}->{$fileobj};

	my $fh = delete $self->{_fh}->{$fileobj};
	close($fh);

	return $fileobj->get_value( "filename" );
}

sub retrieve
{
	my( $self, $fileobj, $sourceid, $f ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj );

	$in_file .= ".gz";

	my $in_fh;
	unless( open($in_fh, "<:gzip", $in_file) )
	{
		$self->{error} = "Unable to read from $in_file: $!";
		$self->{handle}->get_repository->log( $self->{error} );
		return undef;
	}

	my $rc = 1;

	my $buffer;
	while(read($in_fh,$buffer,4096))
	{
		$rc &&= &$f($buffer);
		last unless $rc;
	}

	close($in_fh);

	return $rc;
}

sub delete
{
	my( $self, $fileobj, $sourceid ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj );

	$in_file .= ".gz";

	return 1 unless -e $in_file;

	return unlink($in_file);
}

sub get_local_copy
{
	return &EPrints::Plugin::Storage::get_local_copy( @_ );
}

=back

=cut

1;
