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

=item $success = $store->store( $fileobj, $filehandle )

Read from and store all data from $filehandle for $fileobj.

Returns false on error.

=cut

=item $filehandle = $store->retrieve( $fileobj [, $revision ] )

Retrieve a $filehandle to the object stored for $fileobj. If no $revision is specified returns the revision in $fileobj.

=cut

=item $success = $store->delete( $fileobj [, $revision ] )

Delete the object stored for $fileobj. If no $revision is specified deletes the revision in $fileobj.

=cut

=item $size = $store->get_size( $fileobj [, $revision ] )

Return the $size (in bytes) of the object stored at $fileobj. If no $revision is specified returns the size of the revision in $fileobj.

=cut

=item @revisions = $store->get_revisions( $fileobj )

Return a list of available revision numbers for $fileobj, in order from latest to oldest.

=cut

sub get_revisions
{
	my( $self, $fileobj ) = @_;

	return (1); # default to storing one revision, "1"
}

1;
