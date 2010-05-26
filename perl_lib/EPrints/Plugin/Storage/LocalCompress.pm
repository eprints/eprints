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

use EPrints::Plugin::Storage::Local;

use constant BUF_SIZE => 65536;

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

	return 0 if !$self->SUPER::open_write( $fileobj );

	my $fh = $self->{_fh}->{$fileobj};
	binmode( $fh, ":gzip" ) or die "Setting gzip IO layer failed: $!";

	return 1;
}

sub write
{
	my( $self, $fileobj, $buffer ) = @_;

	use bytes;
	use integer;

	my $fh = $self->{_fh}->{$fileobj}
		or Carp::croak "Must call open_write before write";

	if( !print $fh $buffer ) # sysread ignores gzip layer
	{
		my $path = $self->{_path}->{$fileobj};
		my $fn = $self->{_name}->{$fileobj};
		unlink("$path/$fn");
		$self->{error} = "Error writing to $path/$fn: $!";
		$self->{session}->get_repository->log( $self->{error} );
		return 0;
	}

	return 1;
}

sub open_read
{
	my( $self, $fileobj, $sourceid, $f ) = @_;

	return 0 if !$self->SUPER::open_read( $fileobj, $sourceid, $f );

	my $fh = $self->{_fh}->{$fileobj};
	binmode( $fh, ":gzip" ) or die "Setting gzip IO layer failed: $!";

	return 1;
}

sub retrieve
{
	my( $self, $fileobj, $sourceid, $offset, $n, $f ) = @_;

	return 0 if !$self->open_read( $fileobj, $sourceid, $f );
	my( $path, $fn ) = $self->_filename( $fileobj, $sourceid );

	my $fh = $self->{_fh}->{$fileobj};

	my $rc = 1;

	my $buffer;

	# sysread ignores gzip layer

	# sequentially move file position to $offset
	while($rc && $offset >= BUF_SIZE)
	{
		$offset -= BUF_SIZE;
		$rc &&= read($fh,$buffer,BUF_SIZE);
	}
	if( $offset )
	{
		$rc &&= read($fh,$buffer,$offset);
	}

	# read the requested chunk
	while($rc && $n >= BUF_SIZE && read($fh,$buffer,BUF_SIZE))
	{
		$n -= BUF_SIZE;
		$rc &&= &$f($buffer);
	}
	if($rc && read($fh,$buffer,$n))
	{
		$rc &&= &$f($buffer);
	}

	$self->close_read( $fileobj, $sourceid, $f );

	return $rc;
}

sub get_local_copy
{
	return &EPrints::Plugin::Storage::get_local_copy( @_ );
}

sub _filename
{
	my( $self, $fileobj, $sourceid ) = @_;

	my( $path, $fn ) = $self->SUPER::_filename( $fileobj, $sourceid );

	if( !defined $sourceid ) # file creation only
	{
		$fn .= '.gz';
	}

	return( $path, $fn );
}

=back

=cut

1;
