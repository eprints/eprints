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

=item $success = $store->store( $dataobj, $bucket, $filename, $filehandle )

Read and store all data from $filehandle at $filename. Returns true on success.

=cut

=item $filehandle = $store->retrieve( $dataobj, $bucket, $filename )

Retrieve a $filehandle to the object stored at $filename.

=cut

=item $success = $store->delete( $dataobj, $bucket, $filename )

Delete the object stored at $filename.

=cut

=item $size = $store->get_size( $dataobj, $bucket, $filename )

Return the $size (in bytes) of the object stored at $filename.

=cut

=item @revisions = $store->get_revisions( $dataobj, $bucket, $filename )

Return a list of revision numbers for $filename, in order from oldest to latest.

=cut

sub get_revisions
{
	my( $dataobj, $bucket, $filename ) = @_;

	return (1); # default to storing one revision, "1"
}

1;
