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

=item $success = $store->store( $dataobj, $bucket, $uri, $filehandle )

Read and store all data from $filehandle at $uri. Returns true on success.

=cut

=item $filehandle = $store->retrieve( $dataobj, $bucket, $uri )

Retrieve a $filehandle to the object stored at $uri.

=cut

=item $success = $store->delete( $dataobj, $bucket, $uri )

Delete the object stored at $uri.

=cut

=item $size = $store->get_size( $dataobj, $bucket, $uri )

Return the $size (in bytes) of the object stored at $uri.

=cut

1;
