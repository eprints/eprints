=for Pod2Wiki

=head1 NAME

EPrints::Plugin::Storage

=head1 SYNOPSIS

=for verbatim_lang perl

	$plugin = $repo->plugin('Storage::Local');
	$plugin->open_write($fileobj) or die;
	$plugin->write('Hello, World!');
	$plugin->close_write() or die;

=head1 DESCRIPTION

See L<EPrints::Storage> for information on using the storage layer.

You shouldn't need to use a storage plugin directly.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Storage;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Storage::DISABLE = 1;

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "is_available" )
	{
		return( $self->is_available() );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}

sub is_available
{
	my( $self ) = @_;

	return 1;
}

=item $sourceid = $store->store( $fileobj, CALLBACK )

Store an object using data from CALLBACK.

If successful returns the source id used to retrieve this object.

Returns undef on error.

=cut

sub store
{
	my( $self, $fileobj, $f, $croak ) = @_;

	EPrints->abort( ref($self)." appears not to have subclassed store() or open_write() - at least one must be implemented" )
		if $croak;

	return unless $self->open_write( $fileobj, 1 );

	while(length(my $buffer = &$f))
	{
		last unless $self->write( $fileobj, $buffer );
	}

	return $self->close_write( $fileobj );
}

=item $success = $store->retrieve( $fileobj, $sourceid, $offset, $len, CALLBACK )

Retrieve $n bytes of data starting at $offset from the data stored for $fileobj identified by $sourceid.

CALLBACK = $rc = &f( BYTES )

Note: this API may change in future to reflect the open_write/write/close_write mechanism.

=cut

sub retrieve
{
	my( $self, $fileobj, $sourceid, $offset, $n, $f ) = @_;

	undef;
}

=item $success = $store->delete( $fileobj, $sourceid )

Delete the object stored for $fileobj.

=cut

sub delete
{
	my( $self, $fileobj, $sourceid ) = @_;

	undef;
}

=item $filename = $store->get_local_copy( $fileobj, $sourceid )

Return the name of a local copy of the file (may be a L<File::Temp> object).

Returns undef if no local copy is available.

=cut

sub get_local_copy
{
	my( $self, $fileobj, $sourceid ) = @_;

	return undef;
}

=item $url = $store->get_remote_copy( $fileobj, $sourceid )

Returns an alternative URL for this file (must be publicly accessible).

Returns undef if no such copy is available.

=cut

sub get_remote_copy
{
	my( $self, $fileobj, $sourceid ) = @_;

	return undef;
}

=item $ok = $store->open_write( $fileobj )

Initialise a new write based on $fileobj.

=cut

sub open_write
{
	my( $self, $fileobj, $croak ) = @_;

	EPrints->abort( ref($self)." appears not to have subclassed store() or open_write() - at least one must be implemented" )
		if $croak;

	$self->{_fh}->{$fileobj} = File::Temp->new;

	return 1;
}

=item $ok = $store->write( $fileobj, $buffer )

Write $buffer. Will croak if $fileobj was not previously opened for writing with open_write().

=cut

sub write
{
	my( $self, $fileobj, $buffer ) = @_;

	syswrite($self->{_fh}->{$fileobj}, $buffer);
}

=item $sourceid = $store->close_write( $fileobj )

Finish writing to $fileobj. Returns the sourceid or undef on failure.

=cut

sub close_write
{
	my( $self, $fileobj ) = @_;

	my $fh = $self->{_fh}->{$fileobj};
	sysseek($fh, 0, 0);

	my $buffer;
	my $f = sub { sysread($fh, $buffer, 4096); return $buffer };
	my $ok = $self->store( $fileobj, $f, 1 );

	delete $self->{_fh}->{$fileobj};

	return $ok;
}

1;

=back

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

