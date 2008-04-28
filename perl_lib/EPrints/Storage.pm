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
		$eprint,		# data object
		"revision",		# bucket
		"diddle.pdf",	# filename
		$fh				# file handle
	);

=head1 DESCRIPTION

This module is the storage control layer which uses L<EPrints::Plugin::Storage> plugins to support various storage back-ends. It enables the storage, retrieval and deletion of data streams. The maximum size of a stream is dependent on the back-end storage mechanism.

Each data stream is located at a repository unique location constructed from the data object id, bucket name and file name. This may be turned into a URI by the storage layer to achieve global uniqueness (e.g. by using the repository's hostname).

=head2 Multiple Storage Mediums

The storage layer may make use of multiple storage back-ends. To assist locating the correct place to store and retrieve streams the API requires the EPrints object and a "bucket" name.

The B<EPrints object> passed to the storage API may be used to choose different storage mediums or to add metadata to the stored stream (e.g. if the storage back end is another repository).

The B<bucket> is a string that identifies classes of streams. For instance L<EPrints::DataObj::Document> objects (currently) have "data" and "thumbnail" buckets for storing files and thumbnails respectively.

=head2 Revisions

The storage layer may store multiple revisions located at the same filename.

If the storage medium supports revisioning it is expected that repeated store() calls to the same location will result in multiple revisions. A retrieve() call without any revision will always return the data stored in the last store() call.

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

=item $success = $store->store( $dataobj, $bucket, $filename, $filehandle )

Read from and store all data for $filehandle. Returns true on success.

=cut

sub store
{
	my( $self, $dataobj, $bucket, $filename, $fh ) = @_;

	return $self->{default}->store( $dataobj, $bucket, $filename, $fh );
}

=item $filehandle = $store->retrieve( $dataobj, $bucket, $filename [, $revision ] )

Retrieve a $filehandle to the object stored at $filename. If no $revision is specified returns the latest revision.

=cut

sub retrieve
{
	my( $self, $dataobj, $bucket, $filename, $revision ) = @_;

	return $self->{default}->retrieve( $dataobj, $bucket, $filename, $revision );
}

=item $success = $store->delete( $dataobj, $bucket, $filename [, $revision ] )

Delete the object stored at $filename. If no $revision is specified deletes the latest revision.

=cut

sub delete
{
	my( $self, $dataobj, $bucket, $filename, $revision ) = @_;

	return $self->{default}->delete( $dataobj, $bucket, $filename, $revision );
}

=item $size = $store->get_size( $dataobj, $bucket, $filename [, $revision ] )

Return the $size (in bytes) of the object stored at $filename. If no $revision is specified returns the size of the latest revision.

=cut

sub get_size
{
	my( $self, $dataobj, $bucket, $filename, $revision ) = @_;

	return $self->{default}->get_size( $dataobj, $bucket, $filename, $revision );
}

=item @revisions = $store->get_revisions( $dataobj, $bucket, $filename )

Return a list of revision numbers for $filename, in order from oldest to latest.

=cut

sub get_revisions
{
	my( $dataobj, $bucket, $filename ) = @_;

	return $self->{default}->get_revisions( $dataobj, $bucket, $filename );
}

=back

=cut

1;
