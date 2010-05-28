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
