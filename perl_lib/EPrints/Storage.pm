=for Pod2Wiki {{API:Unstable}}

=head1 NAME

EPrints::Storage - manage data streams in storage devices (storage layer)

=head1 SYNOPSIS

=for verbatim_lang perl

	my $store = $repository->storage();
	
	$str = "Hello, World!";
	open(my $fh, "<", \$str);
	$f = sub {
		read($fh, my $buffer, 6); # just to demonstrate!
		return $buffer;
	};
	$store->store(
		$fileobj,		# file object
		$f,				# callback
		1024,			# offset
	);

=head1 DESCRIPTION

Unless you are directly manipulating how data streams are stored you should use the methods for retrieving and writing data available from L<EPrints::DataObj::File>.

This module is the storage control layer which uses L<EPrints::Plugin::Storage> plugins to support various storage back-ends. It enables the storage, retrieval and deletion of data streams. The maximum size of a stream is dependent on the back-end storage mechanism.

Storage works on L<EPrints::DataObj::File> objects, which record the size of the data stream and where it has been stored. Unless a specific storage back-end is used, where a file is stored depends on the storage policy which is located in F<lib/storage/default.xml>:

=for verbatim_lang xml

	<store xmlns="http://eprints.org/ep3/storage" xmlns:epc="http://eprints.org/ep3/control">
	<epc:choose>
		<epc:when test="datasetid = 'document'">
			<plugin name="Local"/>
		</epc:when>
		<epc:otherwise>
			<plugin name="Local"/>
		</epc:otherwise>
	</epc:choose>
	</store>

The storage policy is a EP-script file that resolves to a list of one or more "plugin" elements. When storing, all matching plugins will be given the data stream to store (i.e. multiple copies). When retrieving, the first plugin to be successfully opened for reading will be used. The item context used when the storage policy is evaluated is the L<EPrints::DataObj::File>.

=head2 Callbacks

Writing to and retrieving from data streams makes use of callback functions. This allows data to be streamed (to avoid memory overheads) and for flexibility in where data is going.

For details on the callback API see L<EPrints::DataObj::File/get_file> and L<EPrints::DataObj::File/set_file> for retrieving and writing respectively.

=head1 METHODS

=over 4

=item $store = EPrints::Storage->new( $repository )

Create a new storage object for $repository. Should not be used directly, see L<EPrints::Session>.

=cut

package EPrints::Storage;

use URI;
use URI::Escape;
use File::Temp qw();

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
		$self->_load_config_file( $file, $config );
	}

	return $config->{xml};
}

=item $len = $store->store( $fileobj, CODEREF [, $offset ] )

Read from and store all data from CODEREF for $fileobj. If $offset is given starts writing from that point onwards.

Behaviour is undefined if an attempt is made to write beyond $fileobj's B<filesize>.

Returns the number of bytes written or undef if an error occurred.

=cut

sub store
{
	my( $self, $fileobj, $f, $offset ) = @_;

	use bytes;

	my $rlen = 0;

	return undef unless $self->open_write( $fileobj, $offset );

	# copy the input data to each writable plugin
	my( $buffer, $c );
	while(($c = length($buffer = &$f)) > 0)
	{
		$rlen += $c;
		$offset += $c if defined $offset;
		$self->write( $fileobj, $buffer );
	}

	return undef unless $self->close_write( $fileobj );

	return $rlen;
}

=item $success = $store->retrieve( $fileobj, $offset, $n, CALLBACK )

Retrieve the contents of the $fileobj starting at $offset for $n bytes.

CALLBACK = $rc = &f( BUFFER )

=cut

sub retrieve
{
	my( $self, $fileobj, $offset, $n, $f ) = @_;

	my $rc = 0;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{repository}->plugin( $copy->{pluginid} );
		next unless defined $plugin;
		$rc = $plugin->retrieve( $fileobj, $copy->{sourceid}, $offset, $n, $f );
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
		if( !$plugin )
		{
			$self->{repository}->get_repository->log( "Can not remove file copy '$copy->{sourceid}' - $copy->{pluginid} not available" );
		}
		elsif( $plugin->delete( $fileobj, $copy->{sourceid} ) )
		{
			$fileobj->remove_plugin_copy( $plugin );
		}
		else
		{
			$rc = 0;
		}
	}

	return $rc;
}

=item $ok = $store->delete_copy( $plugin, $fileobj )

Delete the copy of this file stored in the storage layer L<$plugin|EPrints::Plugin::Storage>.

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

=item $fh = $store->get_local_copy( $fileobj )

Return a local copy of the file. Potentially expensive if the file has to be retrieved.

Stringifying $fh will give the full path to the local file, which may be useful for calling external tools (see L<File::Temp>).

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

	if( UNIVERSAL::isa( $filename, "File::Temp" ) )
	{
		# no further action required
	}
	elsif( defined $filename )
	{
		# see File::Temp::new
		# by doing this calling code can treat the return in a consistent way
		open(my $fh, "<", $filename) or return undef;
		${*$fh} = $filename;
		bless $fh, "File::Temp";
		$fh->unlink_on_destroy( 0 );
		$filename = $fh;
	}
	else
	{
		# try retrieving it
		my $ext = EPrints->system->file_extension( $fileobj->value( "filename" ) );
		$filename = File::Temp->new( SUFFIX => $ext );
		binmode($filename);

		my $rc = $self->retrieve( $fileobj, 0, $fileobj->value( "filesize" ),
			sub {
				return defined syswrite($filename,$_[0])
			} );
		sysseek($filename,0,0);

		undef $filename unless $rc;
	}

	return $filename;
}

=item $url = $store->get_remote_copy( $fileobj )

Some storage back-ends may provide direct Web access to the data stream (e.g. Amazon S3). If the back-end supports this, a user can be redirected to the storage back-end rather than downloading the file from EPrints. Internally, EPrints will always use the L</retrieve> method.

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

Returns the L<EPrints::Plugin::Storage> plugin(s) available to use for $fileobj, based on the storage policy. If more than one plugin is returned they should be used in turn until one succeeds.

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

Copy the contents of $fileobj into another storage $plugin. This uses L</retrieve> and L</store>.

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
	
	$ok = $self->retrieve( $fileobj, 0, $fileobj->value( "filesize" ), sub {
		$target->write( $fileobj, $_[0] );
	} );

	my $sourceid = $target->close_write( $fileobj );

	if( $ok )
	{
		$fileobj->add_plugin_copy( $target, $sourceid );
	}

	return $ok;
}

=item $ok = $storage->open_write( $fileobj [, $offset ] )

Start a write session for $fileobj. $fileobj must have at least the "filesize" property set (which is the total number of bytes that will be written).

Don't forget to L</close_write> otherwise the handle to the write will be left open.

=cut

sub open_write
{
	my( $self, $fileobj, $offset ) = @_;

	if( !$fileobj->is_set( "filesize" ) )
	{
		EPrints::abort( "filesize must be set before calling open_write" );
	}

	my( @writable, @errored );

	# open a write for each plugin, record any plugins that error
	foreach my $plugin ($self->get_plugins( $fileobj ))
	{
		if( $plugin->open_write( $fileobj, $offset ) )
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

Write $buffer to the storage plugin(s), starting from the previously written data.

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

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

