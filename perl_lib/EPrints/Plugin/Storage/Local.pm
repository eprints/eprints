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
use Fcntl qw( SEEK_SET :DEFAULT );

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
	my( $self, $fileobj, $offset ) = @_;

	my( $path, $fn ) = $self->_filename( $fileobj );

	return undef if !defined $path;

	# filename may contain directory components
	my $filepath = "$path/$fn";
	$filepath =~ s/[^\\\/]+$//;

	EPrints->system->mkdir( $filepath );

	my $mode = O_WRONLY|O_CREAT;
	$mode |= O_TRUNC if !defined $offset;

	my $fh;
	unless( sysopen($fh, "$path/$fn", $mode) )
	{
		$self->{error} = "Unable to write to $path/$fn: $!";
		$self->{session}->get_repository->log( $self->{error} );
		return 0;
	}

	sysseek($fh, $offset, 0) if defined $offset;

	$self->{_fh}->{$fileobj} = $fh;
	$self->{_path}->{$fileobj} = $path;
	$self->{_name}->{$fileobj} = $fn;

	return 1;
}

sub write
{
	my( $self, $fileobj, $buffer ) = @_;

	use bytes;

	my $fh = $self->{_fh}->{$fileobj}
		or Carp::croak "Must call open_write before write";
	
	$self->repository->debug_log( "storage", "writing file %s", $fileobj->internal_uri );

	my $rc = syswrite($fh, $buffer);
	if( !defined $rc || $rc != length($buffer) )
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

sub close_write
{
	my( $self, $fileobj ) = @_;

	delete $self->{_path}->{$fileobj};

	my $fh = delete $self->{_fh}->{$fileobj};
	close($fh);

	return delete $self->{_name}->{$fileobj};
}

sub open_read
{
	my( $self, $fileobj, $sourceid, $f ) = @_;

	my( $path, $fn ) = $self->_filename( $fileobj, $sourceid );

	return undef if !defined $path;

	my $in_fh;
	if( !open($in_fh, "<", "$path/$fn") )
	{
		$self->{error} = "Unable to read from $path/$fn: $!";
		$self->{session}->get_repository->log( $self->{error} );
		return undef;
	}
	binmode($in_fh);

	$self->{_fh}->{$fileobj} = $in_fh;

	return 1;
}

sub retrieve
{
	my( $self, $fileobj, $sourceid, $offset, $n, $f ) = @_;

	return 0 if !$self->open_read( $fileobj, $sourceid, $f );
	my( $path, $fn ) = $self->_filename( $fileobj, $sourceid );

	return undef if !defined $path;
	
	$self->repository->debug_log( "storage", "reading file %s (%s/%s)", $fileobj->internal_uri, $path, $fn );

	my $fh = $self->{_fh}->{$fileobj};

	my $rc = 1;

	sysseek($fh, $offset, SEEK_SET);

	my $buffer;
	my $bsize = $n > 65536 ? 65536 : $n;
	while(sysread($fh,$buffer,$bsize))
	{
		$rc &&= &$f($buffer);
		last unless $rc;
		$n -= $bsize;
		$bsize = $n if $bsize > $n;
	}

	$self->close_read( $fileobj, $sourceid, $f );

	return $rc;
}

sub close_read
{
	my( $self, $fileobj, $sourceid, $f ) = @_;

	my $fh = delete $self->{_fh}->{$fileobj};
	close($fh);
}

sub delete
{
	my( $self, $fileobj, $sourceid ) = @_;

	my( $path, $fn ) = $self->_filename( $fileobj, $sourceid );

	return undef if !defined $path;

	return 1 if !-e "$path/$fn";

	return 0 if !unlink("$path/$fn");
	
	$self->repository->debug_log( "storage", "removing file %s (%s/%s)", $fileobj->internal_uri, $path, $fn );

	my @parts = split /\//, $fn;
	pop @parts;

	# remove empty leaf directories (e.g. document dir)
	for(reverse 0..$#parts)
	{
		my $dir = join '/', $path, @parts[0..$_];
		last if !rmdir($dir);
	}
	rmdir($path);

	return 1;
}

sub get_local_copy
{
	my( $self, $fileobj, $sourceid ) = @_;

	my( $path, $fn ) = $self->_filename( $fileobj, $sourceid );

	return undef if !defined $path;

	return -r "$path/$fn" ? "$path/$fn" : undef;
}

sub _filename
{
	my( $self, $fileobj, $filename ) = @_;

	my $local_path;

	if( !defined $filename )
	{
		$filename = $fileobj->value( "filename" );
		$filename = escape_filename( $filename );
	}

	$local_path = join( "/", 
		$self->{repository}->config( 'archiveroot' ),
		"storage",
		$fileobj->dataset->id,
		$self->dataobjid_to_path( $fileobj->id )
	);

	if( !-d $local_path )
	{
		EPrints->system->mkdir( $local_path );
	}

	return( $local_path, $filename );
}

sub dataobjid_to_path
{
        my( $self, $id ) = @_;

        my $path = sprintf("%08d", $id);
        $path =~ s#(..)#/$1#g;
        substr($path,0,1) = '';

        return $path;
}



sub escape_filename
{
	my( $filename ) = @_;

	# $filename is UTF-8
	$filename =~ s# /\.+ #/_#xg; # don't allow hiddens
	$filename =~ s# //+ #/#xg;
	$filename =~ s# ([:;'"\\=]) #sprintf("=%04x", ord($1))#xeg;

	return $filename;
}

=back

=cut

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

