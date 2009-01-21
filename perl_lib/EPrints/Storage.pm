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
		$fileobj,		# file object
		"diddle.pdf",	# filename
		$fh				# file handle
	);

=head1 DESCRIPTION

This module is the storage control layer which uses L<EPrints::Plugin::Storage> plugins to support various storage back-ends. It enables the storage, retrieval and deletion of data streams. The maximum size of a stream is dependent on the back-end storage mechanism.

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
	$self->{session} = $session;
	Scalar::Util::weaken($self->{session})
		if defined &Scalar::Util::weaken;

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

=item $bytes = $store->store( $fileobj, $filehandle )

Read from and store all data from $filehandle for $fileobj.

Returns number of bytes read from $filehandle, or undef on error.

=cut

sub store
{
	my( $self, $fileobj, $fh ) = @_;

	my $length;

	foreach my $plugin ($self->get_plugins( $fileobj, $fh ))
	{
		my $rc = $plugin->store( $fileobj, $fh );
		$length = $rc if defined $rc;
	}

	# Plugins must add their local information to copies
	$fileobj->commit();

	return $length;
}

=item $filehandle = $store->retrieve( $fileobj )

Retrieve a $filehandle to the object stored for $fileobj.

=cut

sub retrieve
{
	my( $self, $fileobj ) = @_;

	my $fh;

	foreach my $plugin ($self->get_plugins( $fileobj ))
	{
		$fh = $plugin->retrieve( $fileobj );
		last if defined $fh;
	}

	return $fh;
}

=item $success = $store->delete( $fileobj )

Delete the object stored for $fileobj.

=cut

sub delete
{
	my( $self, $fileobj ) = @_;

	my $rc;

	my $copies = $fileobj->get_value( "copies" );

	foreach my $copy (@$copies)
	{
		my $plugin = $self->{session}->plugin( $copy->{pluginid} );
		if( !defined( $plugin ) )
		{
			$self->{session}->get_repository->log( "Can not remove file copy '$copy->{sourceid}' - $copy->{pluginid} not available" );
			next;
		}
		$rc = $plugin->delete( $fileobj );
	}

	return $rc;
}

=item $filename = $store->get_local_copy( $fileobj )

Return the name of a local copy of the file (may be a L<File::Temp> object).

Will retrieve and cache the remote object if necessary.

=cut

sub get_local_copy
{
	my( $self, $fileobj ) = @_;

	my $filename;

	foreach my $plugin ($self->get_plugins( $fileobj ))
	{
		$filename = $plugin->get_local_copy( $fileobj );
		last if defined $filename;
	}

	return $filename;
}

=item $size = $store->get_size( $fileobj )

UNUSED?

Return the $size (in bytes) of the object stored at $fileobj.

=cut

sub get_size
{
	my( $self, $fileobj ) = @_;

	my $filesize;

	foreach my $plugin ($self->get_plugins( $fileobj ))
	{
		$filesize = $plugin->get_local_copy( $fileobj );
		last if defined $filesize;
	}

	return $filesize;
}

=item @plugins = $store->get_plugins( $fileobj )

Returns the L<EPrints::Plugin::Storage> plugin(s) to use for $fileobj. If more than one plugin is returned they should be used in turn until one succeeds.

=cut

sub get_plugins
{
	my( $self, $fileobj ) = @_;

	my @plugins;

	my $session = $self->{session};

	my %params;
	$params{item} = $fileobj;
	$params{current_user} = $session->current_user;
	$params{session} = $session;
	$params{parent} = $fileobj->get_parent;

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
