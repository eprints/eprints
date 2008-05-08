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

use strict;

sub new
{
	my( $class, $session ) = @_;

	my $self = bless {}, $class;
	Scalar::Util::weaken( $self->{session} = $session );

	$self->{config} = $session->get_repository->get_storage_config( "default" );

	unless( $self->{config} )
	{
		EPrints::abort "No storage configuration available for use";
	}

	return $self;
}

sub load_all
{
	my( $path, $confhash ) = @_;

	my $file = "$path/default.xml";

	load_config_file( $file, $confhash );
}

sub load_config_file
{
	my( $file, $confhash ) = @_;

	return unless -e $file;

	my $doc = EPrints::XML::parse_xml( $file );
	$confhash->{"default"}->{storage} = $doc->documentElement();
	$confhash->{"default"}->{file} = $file;
	$confhash->{"default"}->{mtime} = EPrints::Utils::mtime( $file );

	return 1;
}

sub get_storage_config
{
	my( $id, $confhash ) = @_;

	my $file = $confhash->{$id}->{file};

	my $mtime = EPrints::Utils::mtime( $file );

	if( $mtime > $confhash->{$id}->{mtime} )
	{
		load_config_file( $file, $confhash );
	}

	return $confhash->{$id}->{storage};
}

=item $success = $store->store( $fileobj, $filehandle )

Read from and store all data from $filehandle for $fileobj.

Returns false on error.

=cut

sub store
{
	my( $self, $fileobj, $fh ) = @_;

	my $rc;

	foreach my $plugin ($self->get_plugins( $fileobj, $fh ))
	{
		$rc = $plugin->store( $fileobj, $fh );
		last if $rc;
	}

	return $rc;
}

=item $filehandle = $store->retrieve( $fileobj [, $revision ] )

Retrieve a $filehandle to the object stored for $fileobj. If no $revision is specified returns the revision in $fileobj.

=cut

sub retrieve
{
	my( $self, $fileobj, $revision ) = @_;

	my $fh;

	foreach my $plugin ($self->get_plugins( $fileobj, $revision ))
	{
		$fh = $plugin->retrieve( $fileobj, $revision );
		last if defined $fh;
	}

	return $fh;
}

=item $success = $store->delete( $fileobj [, $revision ] )

Delete the object stored for $fileobj. If no $revision is specified deletes the revision in $fileobj.

=cut

sub delete
{
	my( $self, $fileobj, $revision ) = @_;

	my $rc;

	foreach my $plugin ($self->get_plugins( $fileobj, $revision ))
	{
		$rc = $plugin->delete( $fileobj, $revision );
		last if $rc;
	}

	return $rc;
}

=item $filename = $store->get_local_copy( $fileobj [, $revision ] )

Return the name of a local copy of the file (may be a L<File::Temp> object).

Will retrieve and cache the remote object if necessary.

=cut

sub get_local_copy
{
	my( $self, $fileobj, $revision ) = @_;

	my $filename;

	foreach my $plugin ($self->get_plugins( $fileobj, $revision ))
	{
		$filename = $plugin->get_local_copy( $fileobj, $revision );
		last if defined $filename;
	}

	return $filename;
}

=item $size = $store->get_size( $fileobj [, $revision ] )

Return the $size (in bytes) of the object stored at $fileobj. If no $revision is specified returns the size of the revision in $fileobj.

=cut

sub get_size
{
	my( $self, $fileobj, $revision ) = @_;

	my $filesize;

	foreach my $plugin ($self->get_plugins( $fileobj, $revision ))
	{
		$filesize = $plugin->get_local_copy( $fileobj, $revision );
		last if defined $filesize;
	}

	return $filesize;
}

=item @revisions = $store->get_revisions( $fileobj )

Return a list of available revision numbers for $fileobj, in order from latest to oldest.

=cut

sub get_revisions
{
	my( $self, $fileobj ) = @_;

	my @revisions;

	foreach my $plugin ($self->get_plugins( $fileobj ))
	{
		@revisions = $plugin->get_local_copy( $fileobj );
		last if scalar(@revisions);
	}

	return @revisions;
}

=item @plugins = $store->get_plugins( $fileobj [, $revision ] )

Returns the L<EPrints::Plugin::Storage> plugin(s) to use for $fileobj. If more than one plugin is returned they should be used in turn until one succeeds.

=cut

sub get_plugins
{
	my( $self, $fileobj, $revision ) = @_;

	my @plugins;

	my $session = $self->{session};

	my %params;
	$params{item} = $fileobj;
	$params{current_user} = $session->current_user;
	$params{session} = $session;

	my $_plugins = EPrints::XML::EPC::process( $self->{config}, %params );

	foreach my $child ($_plugins->childNodes)
	{
		next unless( $child->nodeName eq "plugin" );
		my $pluginid = $child->getAttribute( "name" );
		my $plugin = $session->plugin( "Storage::$pluginid" );
		push @plugins, $plugin if defined $plugin;
	}

	return @plugins;
}

=back

=cut

1;
