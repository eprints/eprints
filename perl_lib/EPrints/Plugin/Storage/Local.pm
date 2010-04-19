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
	$self->{storage_class} = "a_local_disk_storage";
	$self->{position} = 1;

	return $self;
}

sub open_write
{
	my( $self, $fileobj ) = @_;

	my( $local_path, $out_file ) = $self->_filename( $fileobj );

	my( $name, $path, $suffix ) = File::Basename::fileparse( $out_file );

	EPrints::Platform::mkdir( $path );

	my $out_fh;
	unless( open($out_fh, ">", $out_file) )
	{
		$self->{error} = "Unable to write to $out_file: $!";
		$self->{session}->get_repository->log( $self->{error} );
		return 0;
	}
	binmode($out_fh);

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

	my $rc = syswrite($fh, $buffer);
	if( !defined $rc || $rc != length($buffer) )
	{
		my $out_file = $self->{_name}->{$fileobj};
		unlink($out_file);
		$self->{error} = "Error writing to $out_file: $!";
		$self->{session}->get_repository->log( $self->{error} );
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

	my $in_fh;
	unless( open($in_fh, "<", $in_file) )
	{
		$self->{error} = "Unable to read from $in_file: $!";
		$self->{session}->get_repository->log( $self->{error} );
		return undef;
	}

	my $rc = 1;

	my $buffer;
	while(sysread($in_fh,$buffer,4096))
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

	return 1 unless -e $in_file;

	return 0 unless unlink($in_file);

	# remove empty leaf directories (e.g. document dir)
	opendir(my $dh, $local_path) or return 1;
	my @files = readdir($dh);
	closedir($dh);

	if( scalar( grep { !/^\.\.?$/ } @files) == 0 )
	{
		rmdir($local_path);
	}

	return 1;
}

sub get_local_copy
{
	my( $self, $fileobj, $sourceid ) = @_;

	my( $local_path, $in_file ) = $self->_filename( $fileobj );

	return -r $in_file ? $in_file : undef;
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
