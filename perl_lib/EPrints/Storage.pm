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

	my $store = $repository->storage();

	$store->store(
		$fileobj,		# file object
		"diddle.pdf",	# filename
		$fh				# file handle
	);

=head1 DESCRIPTION

This module is the storage control layer which uses L<EPrints::Plugin::Storage> plugins to support various storage back-ends. It enables the storage, retrieval and deletion of data streams. The maximum size of a stream is dependent on the back-end storage mechanism.

=head1 METHODS

=over 4

=item $store = EPrints::Storage->new( $repository )

Create a new storage object for $repository. Should not be used directly, see L<EPrints::Session>.

=cut

package EPrints::Storage;

use URI;
use URI::Escape;

use strict;

sub new
{
	my( $class, $repository ) = @_;

	my $self = bless {
			_opened => {},
			config => {},
			repository => $repository
		}, $class;
	Scalar::Util::weaken($self->{repository})
		if defined &Scalar::Util::weaken;

	$self->_load_all(
			$repository->config( "lib_path" )."/storage",
			$repository->config( "config_path" )."/storage",
		);

	if( !scalar keys %{$self->{config}} )
	{
		EPrints::abort( "No storage configuration available for use" );
	}

	return $self;
}

sub _load_all
{
	my( $self, @paths ) = @_;

	foreach my $id (qw( default ))
	{
		foreach my $path ( @paths )
		{
			my $file = "$path/$id.xml";
			next if !-e $file;

			$self->_load_config_file(
				$file,
				$self->{config}->{$id} = {}
			);
		}
	}
}

sub _load_config_file
{
	my( $self, $file, $confhash ) = @_;

	my $doc = $self->{repository}->parse_xml( $file );
	$confhash->{xml} = $doc->documentElement();
	$confhash->{file} = $file;
	$confhash->{mtime} = EPrints::Utils::mtime( $file );

	return 1;
}

sub _config
{
	my( $self, $id ) = @_;

	my $config = $self->{config}->{$id};

	my $file = $config->{file};
	my $mtime = EPrints::Utils::mtime( $file );
	if( $mtime > $config->{mtime} )
	{
		EPrints::XML::dispose( $config->{xml} );
		%$config = ();
		$self->load_config_file( $file, $config );
	}

	return $config->{xml};
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

	return undef unless $self->open_write( $fileobj );

	# copy the input data to each writable plugin
	my( $buffer, $c );
	while(($c = length($buffer = &$f)) > 0)
	{
		$rlen += $c;
		$self->write( $fileobj, $buffer );
	}

	return undef unless $self->close_write( $fileobj );

	return $rlen;
}

=item $success = $store->retrieve( $fileobj, CALLBACK )

=cut

sub retrieve
{
	my( $self, $fileobj, $f ) = @_;

	my $rc = 0;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{repository}->plugin( $copy->{pluginid} );
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
		my $plugin = $self->{repository}->plugin( $copy->{pluginid} );
		unless( $plugin )
		{
			$self->{repository}->get_repository->log( "Can not remove file copy '$copy->{sourceid}' - $copy->{pluginid} not available" );
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
		my $plugin = $self->{repository}->plugin( $copy->{pluginid} );
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
		my $plugin = $self->{repository}->plugin( $copy->{pluginid} );
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

	my $repository = $self->{repository};

	my %params;
	$params{item} = $fileobj;
	$params{current_user} = $repository->current_user;
	$params{session} = $repository;
	$params{parent} = $fileobj->get_parent;

	my $epc = $self->_config( "default" );

	my $_plugins = EPrints::XML::EPC::process( $epc, %params );

	foreach my $child ($_plugins->childNodes)
	{
		next unless( $child->nodeName eq "plugin" );
		my $pluginid = $child->getAttribute( "name" );
		my $plugin = $repository->plugin( "Storage::$pluginid" );
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

	if( @writable == 0 )
	{
		$self->{repository}->log( ref($self).": No plugins available to store file/".$fileobj->id );
		return 0;
	}

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

		$self->{repository}->log( ref($self).": ".$_->get_name." failed while storing file/".$fileobj->id );

		$_->close_write( $fileobj );
	}

	$self->{_opened}->{$fileobj} = \@writable;

	return scalar( @writable ) > 0;
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
			$rc--;
		}
	}

	delete $self->{_opened}->{$fileobj};

	if( $rc == 0 )
	{
		$self->{repository}->log( ref($self).": Failed to store file/".$fileobj->id );
	}

	return $rc;
}

=back

=cut

1;
