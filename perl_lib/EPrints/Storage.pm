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

=item $len = $store->store( $fileobj, CODEREF )

Read from and store all data from CODEREF for $fileobj. The B<filesize> field in $fileobj must be set at the expected number of bytes to read from CODEREF.

Returns undef if the file couldn't be stored, otherwise the number of bytes read.

=cut

sub store
{
	my( $self, $fileobj, $f ) = @_;

	use bytes;
	use integer;

	my $rc = 0;
	my $rlen = 0;

	if( !$fileobj->is_set( "filesize" ) )
	{
		EPrints::abort( "filesize must be set before storing" );
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

	# nothing to do, so don't bother reading input data
	return undef unless scalar @writable;

	# copy the input data to each writable plugin
	my( $buffer, $c );
	while(($c = length($buffer = &$f)) > 0)
	{
		$rlen += $c;
		foreach my $plugin (@writable)
		{
			next if $plugin->write( $fileobj, $buffer );

			# a write error occurred, close and remove this plugin
			$plugin->close_write( $fileobj );
			@writable = grep { $_ ne $plugin } @writable;
			push @errored, $plugin;
		}
	}

	# close writing to each plugin
	foreach my $plugin (@writable)
	{
		if( defined(my $sourceid = $plugin->close_write( $fileobj )) )
		{
			++$rc;
			$fileobj->add_plugin_copy( $plugin, $sourceid );
		}
		else
		{
			push @errored, $plugin;
		}
	}

	return $rc ? $rlen : undef;
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

	my $rc = 1;

	foreach my $copy (@{$fileobj->get_value( "copies" )})
	{
		my $plugin = $self->{session}->plugin( $copy->{pluginid} );
		unless( $plugin )
		{
			$self->{session}->get_repository->log( "Can not remove file copy '$copy->{sourceid}' - $copy->{pluginid} not available" );
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

=back

=cut

1;
