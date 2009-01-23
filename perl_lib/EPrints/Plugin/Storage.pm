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

=item $success = $store->store( $fileobj, CALLBACK )

Store an object using data from CALLBACK.

If the plugin was successful it must use $fileobj->add_plugin_copy( $plugin, $sourceid) to record the new copy.

Returns undef on error.

=cut

=item $success = $store->retrieve( $fileobj, $sourceid, CALLBACK )

Retrieve an object using CALLBACK.

=cut

=item $success = $store->delete( $fileobj, $sourceid )

Delete the object stored for $fileobj.

=cut

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
