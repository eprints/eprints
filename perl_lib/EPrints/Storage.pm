######################################################################
#
# EPrints::Storage
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Storage> - store and retrieve objects in the storage engine

=head1 SYNOPSIS

	my $store = $session->get_storage();

	$store->store( $eprint, "doi:xxx:yyy:123", $fh );

=head1 DESCRIPTION

This module is the storage control layer under which storage plugins allow a number of storage back-ends to be used with EPrints.

=head1 METHODS

=over 4

=cut

package EPrints::Storage;

use URI;
use URI::Escape;

sub new
{
	my( $class, $session ) = @_;

	my $self = bless {}, $class;
	Scalar::Util::weaken( $self->{session} = $session );

	my @plugins = $session->plugin_list( type => "Storage" );

	unless( @plugins )
	{
		EPrints::abort( "No storage plugins available for use" );
	}

	my $plugin = $session->plugin( $plugins[0] );

	$self->{default} = $plugin;

	return $self;
}

=item $success = $store->store( $dataobj, $uri, $filehandle )

Read and store all data from $filehandle at $uri. Returns true on success.

=cut

sub store
{
	my( $self, $dataobj, $uri, $fh ) = @_;

	return $self->{default}->store( $dataobj, $uri, $fh );
}

=item $filehandle = $store->retrieve( $dataobj, $uri )

Retrieve a $filehandle to the object stored at $uri.

=cut

sub retrieve
{
	my( $self, $dataobj, $uri ) = @_;

	return $self->{default}->retrieve( $dataobj, $uri );
}

=item $success = $store->delete( $dataobj, $uri )

Delete the object stored at $uri.

=cut

sub delete
{
	my( $self, $dataobj, $uri ) = @_;

	return $self->{default}->delete( $dataobj, $uri );
}

=item $size = $store->get_size( $dataobj, $uri )

Return the $size (in bytes) of the object stored at $uri.

=cut

sub get_size
{
	my( $self, $dataobj, $uri ) = @_;

	return $self->{default}->get_size( $dataobj, $uri );
}

=back

=cut

1;
