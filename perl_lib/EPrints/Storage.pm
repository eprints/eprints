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

	$store->store(
		$eprint,			# data object
		"revision",			# bucket
		"http://example.org/id/eprint/23/revision/1", # uri
		$fh					# file handle
	);

=head1 DESCRIPTION

This module is the storage control layer which uses L<EPrints::Plugin::Storage> plugins to support various storage back-ends. It enables the storage, retrieval and deletion of data streams. The maximum size of a stream is dependent on the back-end storage mechanism.

Each data stream is located at a globally unique URI. This URI may not be externally locatable, but as with all URIs it is recommended that it is. Currently EPrints uses the Web location of data objects as their stored URI.

=head2 Multiple Storage Mediums

The storage layer may make use of multiple storage back-ends. To assist locating the correct place to store and retrieve streams the API requires the EPrints object and a "bucket" name.

The B<EPrints object> passed to the storage API may be used to choose different storage mediums or to add metadata to the stored stream (e.g. if the storage back end is another repository).

The B<bucket> is a string that identifies classes of streams. For instance L<EPrints::DataObj::Document> objects (currently) have "bitstream" and "thumbnail" buckets for storing files and thumbnails respectively.

The storage layer may not make any use of the EPrints object nor bucket - the URI must uniquely identify the stream regardless of where it came from.

=head1 METHODS

=over 4

=item $store = EPrints::Storage->new( $session )

Create a new storage object for $session. Should not be used directly, see L<EPrints::Session>.

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

=item $success = $store->store( $dataobj, $bucket, $uri, $filehandle )

Read from and store all data for $filehandle at $uri. Returns true on success.

=cut

sub store
{
	my( $self, $dataobj, $bucket, $uri, $fh ) = @_;

	return $self->{default}->store( $dataobj, $bucket, $uri, $fh );
}

=item $filehandle = $store->retrieve( $dataobj, $bucket, $uri )

Retrieve a $filehandle to the object stored at $uri.

=cut

sub retrieve
{
	my( $self, $dataobj, $bucket, $uri ) = @_;

	return $self->{default}->retrieve( $dataobj, $bucket, $uri );
}

=item $success = $store->delete( $dataobj, $bucket, $uri )

Delete the object stored at $uri.

=cut

sub delete
{
	my( $self, $dataobj, $bucket, $uri ) = @_;

	return $self->{default}->delete( $dataobj, $bucket, $uri );
}

=item $size = $store->get_size( $dataobj, $bucket, $uri )

Return the $size (in bytes) of the object stored at $uri.

=cut

sub get_size
{
	my( $self, $dataobj, $uri ) = @_;

	return $self->{default}->get_size( $dataobj, $bucket, $uri );
}

=back

=cut

1;
