package EPrints::Plugin::Storage;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Storage::DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Storage abstraction layer: this plugin should have been subclassed";

	return $self;
}

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
	my( $self, $f ) = @_;

	undef;
}

=item $success = $store->retrieve( $fileobj, $sourceid, CALLBACK )

Retrieve an object using CALLBACK.

=cut

sub retrieve
{
	my( $self, $fileobj, $sourceid, $f ) = @_;

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

1;
