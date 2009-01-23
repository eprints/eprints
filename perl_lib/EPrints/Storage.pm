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
		EPrints::abort( "No storage configuration available for use" );
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

=item $success = $store->store( $fileobj, CODEREF )

Read from and store all data from CODEREF for $fileobj. The B<filesize> field in $fileobj must be set at the expected number of bytes to read from CODEREF.

=cut

sub store
{
	my( $self, $fileobj, $f ) = @_;

	if( !$fileobj->is_set( "filesize" ) )
	{
		EPrints::abort( "filesize must be set before storing" );
	}

	my $rc = 0;

	foreach my $plugin ($self->get_plugins( $fileobj ))
	{
		if( defined(my $sourceid = $plugin->store( $fileobj, $f )) )
		{
			$rc = 1;
			$fileobj->add_plugin_copy( $plugin, $sourceid );
		}
		last; # TODO: store in multiple locations
	}

	return $rc;
}

=item $success = $store->retrieve( $fileobj, CALLBACK )

=cut

sub retrieve
{
	my( $self, $fileobj, $f ) = @_;

	my $rc = 0;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{session}->plugin( $copy->{pluginid} );
		next unless defined $plugin;
		$rc = $plugin->retrieve( $fileobj, $copy->{sourceid}, $f );
		last if $rc;
	}

	return $rc;
}

=item $success = $store->delete( $fileobj )

Delete all object copies stored for $fileobj.

=cut

sub delete
{
	my( $self, $fileobj ) = @_;

	my $rc;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{session}->plugin( $copy->{pluginid} );
		unless( $plugin )
		{
			$self->{session}->get_repository->log( "Can not remove file copy '$copy->{sourceid}' - $copy->{pluginid} not available" );
			next;
		}
		$rc &= $plugin->delete( $fileobj );
	}

	return $rc;
}

=item $filename = $store->get_local_copy( $fileobj )

Return the name of a local copy of the file.

Will retrieve and cache the remote object using L<File::Temp> if necessary.

Returns undef if retrieval failed.

=cut

sub get_local_copy
{
	my( $self, $fileobj ) = @_;

	my $filename;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{session}->plugin( $copy->{pluginid} );
		next unless defined $plugin;
		$filename = $plugin->get_local_copy( $fileobj );
		last if defined $filename;
	}

	if( !defined $filename )
	{
		$filename = File::Temp->new;
		binmode($filename);

		my $rc = $self->retrieve( $fileobj, sub {
			return defined syswrite($filename,$_[0])
		} );
		seek($filename,0,0);

		undef $filename unless $rc;
	}

	return $filename;
}

=item $url = $store->get_remote_copy( $fileobj )

Returns a URL from which this file can be accessed.

Returns undef if this file is not available via another service.

=cut

sub get_remote_copy
{
	my( $self, $fileobj ) = @_;

	my $url;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{session}->plugin( $copy->{pluginid} );
		next unless defined $plugin;
		$url = $plugin->get_remote_copy( $fileobj, $copy->{sourceid} );
		last if defined $url;
	}

	return $url;
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
