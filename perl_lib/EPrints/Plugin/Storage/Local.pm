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
	my( $self, $fileobj, $f ) = @_;

	use bytes;
	use integer;

	my( $local_path, $out_file ) = $self->_filename( $fileobj );

	my( $name, $path, $suffix ) = File::Basename::fileparse( $out_file );

	EPrints::Platform::mkdir( $path );

	my $out_fh;
	unless( open($out_fh, ">", $out_file) )
	{
		$self->{error} = "Unable to write to $out_file: $!";
		$self->{session}->get_repository->log( $self->{error} );
		return undef;
	}
	binmode($out_fh);

	my $rc;
	while($rc = syswrite($out_fh,&$f()))
	{
	}

	close($out_fh);

	unless( defined($rc) )
	{
		unlink($out_file);
		$self->{error} = "Error writing to $out_file: $!";
		$self->{session}->get_repository->log( $self->{error} );
		return undef;
	}

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

	return unlink($in_file);
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
