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

	my $store = $handle->get_storage();

	$store->store(
		$fileobj,		# file object
		"diddle.pdf",	# filename
		$fh				# file handle
	);

=head1 DESCRIPTION

This module is the storage control layer which uses L<EPrints::Plugin::Storage> plugins to support various storage back-ends. It enables the storage, retrieval and deletion of data streams. The maximum size of a stream is dependent on the back-end storage mechanism.

=head1 METHODS

=over 4

=item $store = EPrints::Storage->new( $handle )

Create a new storage object for $handle. Should not be used directly, see L<EPrints::Handle>.

=cut

package EPrints::Storage;

use URI;
use URI::Escape;

use strict;

sub new
{
	my( $class, $handle ) = @_;

	my $self = bless { _opened => {}, handle => $handle }, $class;
	Scalar::Util::weaken($self->{handle})
		if defined &Scalar::Util::weaken;

	$self->{config} = $handle->get_repository->get_storage_config( "default" );

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

=item $len = $store->store( $fileobj, CODEREF )

Read from and store all data from CODEREF for $fileobj. The B<filesize> field in $fileobj must be set at the expected number of bytes to read from CODEREF.

Returns undef if the file couldn't be stored, otherwise the number of bytes read.

=cut

sub store
{
	my( $self, $fileobj, $f ) = @_;

	use bytes;
	use integer;

	my $rlen = 0;

	return 0 unless $self->open_write( $fileobj );

	# copy the input data to each writable plugin
	my( $buffer, $c );
	while(($c = length($buffer = &$f)) > 0)
	{
		$rlen += $c;
		$self->write( $fileobj, $buffer );
	}

	return 0 unless $self->close_write( $fileobj );

	return $rlen == $fileobj->get_value( "filesize" ) ? $rlen : undef;
}

=item $success = $store->retrieve( $fileobj, CALLBACK )

=cut

sub retrieve
{
	my( $self, $fileobj, $f ) = @_;

	my $rc = 0;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{handle}->plugin( $copy->{pluginid} );
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

	my $rc = 1;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{handle}->plugin( $copy->{pluginid} );
		unless( $plugin )
		{
			$self->{handle}->get_repository->log( "Can not remove file copy '$copy->{sourceid}' - $copy->{pluginid} not available" );
			next;
		}
		$rc &= $plugin->delete( $fileobj, $copy->{sourceid} );
	}

	return $rc;
}

=item $ok = $store->delete_copy( $plugin, $fileobj )

Delete the copy of this file stored in $plugin.

=cut

sub delete_copy
{
	my( $self, $target, $fileobj ) = @_;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		next unless $copy->{pluginid} eq $target->get_id;

		return 0 unless $target->delete( $fileobj, $copy->{sourceid} );

		$fileobj->remove_plugin_copy( $target );

		last;
	}

	return 1;
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
		my $plugin = $self->{handle}->plugin( $copy->{pluginid} );
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
		my $plugin = $self->{handle}->plugin( $copy->{pluginid} );
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

	my $handle = $self->{handle};

	my %params;
	$params{item} = $fileobj;
	$params{current_user} = $handle->current_user;
	$params{handle} = $handle;
	$params{parent} = $fileobj->get_parent;

	my $_plugins = EPrints::XML::EPC::process( $self->{config}, %params );

	foreach my $child ($_plugins->childNodes)
	{
		next unless( $child->nodeName eq "plugin" );
		my $pluginid = $child->getAttribute( "name" );
		my $plugin = $handle->plugin( "Storage::$pluginid" );
		push @plugins, $plugin if defined $plugin;
	}

	return @plugins;
}

=item $ok = $store->copy( $plugin, $fileobj )

Copy the contents of $fileobj into another storage $plugin.

Returns 1 on success, 0 on failure and -1 if a copy already exists in $plugin.

=cut

sub copy
{
	my( $self, $target, $fileobj ) = @_;

	my $ok = 1;

	foreach my $copy (@{$fileobj->get_value( "copies_pluginid" )})
	{
		return -1 if $copy eq $target->get_id;
	}

	$ok = $target->open_write( $fileobj );

	return $ok unless $ok;
	
	$ok = $self->retrieve( $fileobj, sub {
		$target->write( $fileobj, $_[0] );
	} );

	my $sourceid = $target->close_write( $fileobj );

	if( $ok )
	{
		$fileobj->add_plugin_copy( $target, $sourceid );
	}

	return $ok;
}

=item $ok = $storage->open_write( $fileobj )

Start a write session for $fileobj. $fileobj must have at least the "filesize" property set (which is the number of bytes that will be written).

=cut

sub open_write
{
	my( $self, $fileobj ) = @_;

	if( !$fileobj->is_set( "filesize" ) )
	{
		EPrints::abort( "filesize must be set before calling open_write" );
	}

	my( @writable, @errored );

	# open a write for each plugin, record any plugins that error
	foreach my $plugin ($self->get_plugins( $fileobj ))
	{
		if( $plugin->open_write( $fileobj ) )
		{
			push @writable, $plugin;
		}
		else
		{
			push @errored, $plugin;
		}
	}

	return 0 unless scalar @writable;

	$self->{_opened}->{$fileobj} = \@writable;

	return 1;
}

=item $ok = $storage->write( $fileobj, $buffer )

Write $buffer to the storage plugin(s).

=cut

sub write
{
	my( $self, $fileobj, $buffer ) = @_;

	my( @writable );

	# write the buffer to each plugin
	# on error close the write to the plugin
	for(@{$self->{_opened}->{$fileobj}})
	{
		push(@writable, $_), next if $_->write( $fileobj, $buffer );

		$_->close_write( $fileobj );
	}

	$self->{_opened}->{$fileobj} = \@writable;

	return scalar( @writable ) > 1;
}

=item $ok = $storage->close_write( $fileobj );

Finish writing to the storage plugin(s) for $fileobj.

=cut

sub close_write
{
	my( $self, $fileobj ) = @_;

	my $rc = scalar @{$self->{_opened}->{$fileobj}};

	for(@{$self->{_opened}->{$fileobj}})
	{
		my $sourceid = $_->close_write( $fileobj );
		if( defined $sourceid )
		{
			$fileobj->add_plugin_copy( $_, $sourceid );
		}
		else
		{
			$rc = 0;
		}
	}

	delete $self->{_opened}->{$fileobj};

	return $rc;
}

=back

=cut

1;
