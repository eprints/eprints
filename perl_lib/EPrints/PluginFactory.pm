######################################################################
#
# EPrints::PluginFactory
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

B<EPrints::PluginFactory> - Load and access plugins

=head1 DESCRIPTION

The plugin factory loads Plugin classes and enables them to be instantiated. It
also allows plugins to be located by "matching" the list of registered plugins
against a set of restrictions.

=head1 METHODS

=head2 Class Methods

=over 4

=cut

package EPrints::PluginFactory;

use strict;
use warnings;

use File::Find qw();

# lookup-table of system plugin types
my %SYSTEM_PLUGINS;

=item $plugins = EPrints::PluginFactory->new( $repository )

Create a new plugin factory using settings from $repository.

=cut

sub new
{
	my( $class, $repository ) = @_;

	my $self = bless {}, $class;

	# we need repository for logging errors
	$self->{repository} = $repository;
	if( defined &Scalar::Util::weaken )
	{
		Scalar::Util::weaken( $repository );
	}

	$self->{alias} = $repository->get_conf( "plugin_alias_map" );
	$self->{alias} = {} unless defined $self->{alias};

	$self->{data} = \%SYSTEM_PLUGINS;

	$self->{repository_data} = {};

	my $dir;

	# system plugins (only load once)
	$dir = $repository->get_conf( "base_path" )."/perl_lib";
	if( defined $dir && !scalar keys %SYSTEM_PLUGINS )
	{
		$class->_load_dir( $self->{data}, $repository, $dir );
	}

	# repository-specific plugins
	$dir = $repository->get_conf( "config_path" )."/plugins";
	if( defined $dir )
	{
		$self->_load_dir( $self->{repository_data}, $repository, $dir );
	}

	$self->{disabled} = {};

	# build a cheat-sheet of config-disabled plugins
	foreach my $plugin ($self->get_plugins)
	{
		my $pluginid = $plugin->get_id();
		if( $repository->get_conf( "plugins", $pluginid, "params", "disable" ) )
		{
			$self->{disabled}->{$pluginid} = 1;
		}
	}

	return $self;
}

sub _load_dir
{
	my( $self, $data, $repository, $base_dir ) = @_;

	return unless -d $base_dir;

	local @INC = ($base_dir, @INC);

	$base_dir .= "/EPrints/Plugin";

	File::Find::find({
		wanted => sub {
			return if $_ =~ m/^\./;
			return if $_ eq "CVS";
			return unless $_ =~ m/\.pm$/;
			return unless -f $File::Find::name;
			my $class = $File::Find::name;
			substr($class,0,length($base_dir)) = "";
			$class =~ s#^/+##;
			$class =~ s#/#::#g;
			$class =~ s/\.pm$//;
			$class = "EPrints::Plugin::$class";
			$self->_load_plugin( $data, $repository, $File::Find::name, $class );
		},
		no_chdir => 1,
		},
		$base_dir
	);
}

sub _load_plugin
{
	my( $self, $data, $repository, $fn, $class ) = @_;

	eval "use $class; 1";
	if( $@ ne "" )
	{
		$repository->log( "Problem loading plugin $class [$fn]:\n$@" );
		return;
	}

	my $plugin = $class->new();

	# disabled by class-global?
	no strict "refs";
	my $disvar = $class.'::DISABLE';
	my $disable = ${$disvar};
	$disable = ${$disvar}; # supress "only once" warning
	#my %defaults = $class->defaults();
	use strict "refs";
	return if( $disable );

	$self->register_plugin( $plugin );
}

=item $ok = EPrints::PluginFactory->register_plugin( $plugin )

Register a new plugin with all repositories.

=cut

=back

=head2 Methods

=over 4

=cut

=item $plugin = $plugins->get_plugin( $id, %opts )

Returns a new plugin object identified by $id, initialised with %opts.

=cut

sub get_plugin
{
	my( $self, $id, %opts ) = @_;

	if( $self->{disabled}->{$id} )
	{
		return;
	}

	if( exists $self->{alias}->{$id} )
	{
		$opts{id} = $id;
		$id = $self->{alias}->{$id};
	}
	return unless defined $id;

	my $class = $self->get_plugin_class( $id );
	if( !defined $class )
	{
		$self->{repository}->log( "Plugin '$id' not found." );
		return undef;
	}

	my $plugin = $class->new( %opts );

	return $plugin;
}

=item $class = $plugins->get_plugin_class( $id )

Returns the plugin class name for $id.

=cut

sub get_plugin_class
{
	my( $self, $id ) = @_;

	my $class = $self->{repository_data}->{"_class_"}->{$id};
	if( !defined $class )
	{
		$class = $self->{data}->{"_class_"}->{$id};
	}

	return $class;
}

=item @plugins = $plugins->get_plugins( $restrictions, %opts )

Returns a list of plugin objects that conform to $restrictions. Initialises the plugins using %opts.

If $restrictions is undefined returns all plugins.

=cut

sub get_plugins
{
	my( $self, $restrictions, %opts ) = @_;

	$restrictions ||= {};

	my %plugins;

	$self->_list( \%plugins, $self->{repository_data}, $restrictions, \%opts );
	$self->_list( \%plugins, $self->{data}, $restrictions, \%opts );

	my @matches;
	# filter plugins for restrictions
	foreach my $plugin (values %plugins)
	{
		next unless defined $plugin;
		my $ok = 1;
		foreach my $k (keys %$restrictions)
		{
			$ok = 0, last unless $plugin->matches( $k, $restrictions->{$k} );
		}
		push @matches, $plugin if $ok;
	}

	return @matches;
}

sub _list
{
	my( $self, $found, $data, $restrictions, $opts ) = @_;

	# this is an efficiency tweak - 99% of the time we'll want plugins
	# by type, so lets support doing that quickly
	my $type = $restrictions->{type};
	if( defined $type )
	{
		foreach my $id (@{$data->{$type}||[]})
		{
			next if exists $found->{$id};
			$found->{$id} = $self->get_plugin( $id, %$opts );
		}
	}
	else
	{
		foreach $type (keys %$data)
		{
			next if $type eq "_class_";
			$self->_list( $found, $data, $opts, {
				%$restrictions,
				type => $type
			} );
		}
	}
}

=item $ok = $plugins->register_plugin( $plugin )

Register a new plugin $plugin with just the current repository.

=cut

sub register_plugin
{
	my( $self, $plugin ) = @_;

	my $id = $plugin->get_id;
	my $type = $plugin->get_type;
	my $class = ref($plugin);

	my $data = ref($self) ? $self->{data} : \%SYSTEM_PLUGINS;

	push @{$data->{$type}||=[]}, $id;
	$data->{"_class_"}->{$id} = $class;
}

1;
