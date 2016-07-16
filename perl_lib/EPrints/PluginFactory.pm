######################################################################
#
# EPrints::PluginFactory
#
######################################################################
#
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

use EPrints;
use EPrints::Const qw( :namespace );

use strict;

use File::Find qw();

# lookup-table of system plugin types
my %SYSTEM_PLUGINS;

# list of plugins that should be disabled by default
my @PLUGINS_TO_DISABLE;

=item $plugins = EPrints::PluginFactory->new( $repository )

Create a new plugin factory using settings from $repository.

=cut

sub new
{
	my( $class, $repository ) = @_;

	my $self = bless {}, $class;

	# we need repository for logging errors
	$self->{repository} = $repository;

	Scalar::Util::weaken( $self->{repository} )
		if defined &Scalar::Util::weaken;

	$self->{alias} = $repository->get_conf( "plugin_alias_map" );
	$self->{alias} = {} unless defined $self->{alias};

	$self->{data} = \%SYSTEM_PLUGINS;

	$self->{repository_data} = {};

	$self->{xslt} = {};

	$self->{disabled} = {};

	my $dir;

	my $use_xslt =
		$EPrints::XML::CLASS eq "EPrints::XML::LibXML" &&
		EPrints::Utils::require_if_exists( "XML::LibXSLT" );

	# system plugins (don't reload)
	if( !scalar keys %SYSTEM_PLUGINS )
	{
		$dir = $repository->config( "base_path" )."/perl_lib";
		$self->_load_dir( \%SYSTEM_PLUGINS, $repository, $dir );
		if( $use_xslt )
		{
			$self->_load_xslt_dir( \%SYSTEM_PLUGINS, $repository, $dir );
		}

		# extension plugins
		$dir = $repository->config( "base_path" )."/lib/plugins";
		push @PLUGINS_TO_DISABLE, map { $_->get_id } $self->_load_dir( \%SYSTEM_PLUGINS, $repository, $dir );
		if( $use_xslt )
		{
			push @PLUGINS_TO_DISABLE,
				map { $_->get_id }
				$self->_load_xslt_dir( \%SYSTEM_PLUGINS, $repository, $dir );
		}

		# /site_lib/ extensions plugins - we want those enabled by default
		$dir = $repository->config( "base_path" )."/site_lib/plugins";
		$self->_load_dir( \%SYSTEM_PLUGINS, $repository, $dir );
		if( $use_xslt )
		{
			$self->_load_xslt_dir( \%SYSTEM_PLUGINS, $repository, $dir );
		}
	}

	# repository-specific plugins
	$dir = $repository->get_conf( "config_path" )."/plugins";
	$self->_load_dir( $self->{repository_data}, $repository, $dir );
	if( $use_xslt )
	{
		$self->_load_xslt_dir( $self->{repository_data}, $repository, $dir );
	}

	if( scalar @PLUGINS_TO_DISABLE )
	{
		# default to disabled
		my $conf = $repository->config( "plugins" );
		foreach my $pluginid (@PLUGINS_TO_DISABLE)
		{
			my $plugin = $self->get_plugin( $pluginid );
			if( defined $plugin && !defined $plugin->param( "disable" ) )
			{
				$conf->{$pluginid}{params}{disable} = 1;
			}
		}
	}

	foreach my $plugin ($self->get_plugins)
	{
		# build a cheat-sheet of config-disabled plugins
		my $pluginid = $plugin->get_id();
		$self->{disabled}->{$pluginid} = $plugin->param( "disable" );
		# plugin-defined aliases
		if( !$plugin->param( "disable" ) )
		{
			foreach my $alias (@{$plugin->param( "alias" )||[]})
			{
				$self->{alias}->{$alias} = $pluginid;
			}
		}
	}

	return $self;
}

=begin InternalDoc

=item $v = $plugins->cache( $k [, $v ] )

Cache a value in the PluginFactory. This is a convenient way to cache information about plugins that will automatically get reset if plugins are reloaded.

=end InternalDoc

=cut

sub cache
{
	my( $self, $key, $value ) = @_;

	return $self->{_cache}->{$key} if @_ == 2;
	return $self->{_cache}->{$key} = $value;
}

sub reset
{
	my( $self ) = @_;

	%SYSTEM_PLUGINS = ();
}

sub _load_dir
{
	my( $self, $data, $repository, $base_dir ) = @_;

	if( !grep { $_ eq $base_dir } @INC )
	{
		@INC = ($base_dir, @INC);
	}

	$base_dir .= "/EPrints/Plugin";

	return unless -d $base_dir;

	my @plugins;

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
			my $plugin = $self->_load_plugin( $data, $repository, $File::Find::name, $class );
			push @plugins, $plugin if defined $plugin;
		},
		no_chdir => 1,
		follow => 1,
		},
		$base_dir
	);

	return @plugins;
}

sub _load_xslt_dir
{
	my( $self, $data, $repository, $base_dir ) = @_;

	$base_dir .= "/EPrints/Plugin";

	return unless -d $base_dir;

	my @plugins;

	File::Find::find({
		wanted => sub {
			return if $_ =~ m/^\./;
			return if $_ eq "CVS";
			return unless $_ =~ m/\.xslt?$/;
			return unless -f $File::Find::name;
			my $class = $File::Find::name;
			substr($class,0,length($base_dir)) = "";
			$class =~ s#^/+##;
			$class =~ s#/#::#g;
			$class =~ s/\.xslt?$//;
			$class = "EPrints::Plugin::$class";
			my $plugin = $self->_load_xslt( $data, $repository, $File::Find::name, $class );
			push @plugins, $plugin if defined $plugin;
		},
		no_chdir => 1,
		follow => 1,
		},
		$base_dir
	);

	return @plugins;
}

sub _load_plugin
{
	my( $self, $data, $repository, $fn, $class ) = @_;

	local $SIG{__DIE__};
	eval "use $class; 1";
	if( $@ ne "" )
	{
		$repository->log( "Problem loading plugin $class [$fn]:\n$@" );
		return;
	}

	my $plugin = eval { $class->new(
		repository => $self->{repository},
		session => $self->{repository} ) };
	if( $@ ) {
		warn $@;
		return;
	}

	# disabled by class-global?
	no strict "refs";
	my $disvar = $class.'::DISABLE';
	my $disable = ${$disvar};
	$disable = ${$disvar}; # suppress "only once" warning
	#my %defaults = $class->defaults();
	use strict "refs";
	return if( $disable );

	return $self->register_plugin( $data, $plugin );
}

sub _load_xslt
{
	my( $self, $data, $repository, $fn, $class ) = @_;

	my $handler = $class;
	$handler =~ s/^(EPrints::Plugin::([^:]+)::XSLT).*/$1/;

	my $type = $2;

	{
	eval <<EOP;
package $class;

our \@ISA = qw( $handler );

1
EOP
	die $@ if $@;
	}

	my $xslt = {};

	{
		local $SIG{__DIE__};
		my $doc = eval { $repository->xml->parse_file( $fn ) };
		if( !defined $doc )
		{
			$repository->log( "Error parsing $fn: $@" );
			return;
		}
		foreach my $attr ($doc->documentElement->attributes)
		{
			next if $attr->isa( "XML::LibXML::Namespace" );
			next if !defined $attr->namespaceURI;
			next if $attr->namespaceURI ne EP_NS_XSLT;
			$xslt->{$attr->localName} = $attr->value();
		}
		if( $type eq "Export" )
		{
			$xslt->{accept} = [split / /, $xslt->{accept}||""];
		}
		elsif( $type eq "Import" )
		{
			$xslt->{accept} = [map {
					HTTP::Headers::Util::join_header_words(@$_)
				}
				HTTP::Headers::Util::split_header_words($xslt->{accept}||"")
			];
			$xslt->{produce} = [split / /, $xslt->{produce}||""];
		}

		$xslt->{doc} = $doc;
		$xslt->{_filename} = $fn;
		$xslt->{_mtime} = EPrints::Utils::mtime( $fn );
		$class->init_xslt( $repository, $xslt );
	}

	my $plugin = $class->new( repository => $repository );
		
	if( $plugin->isa( "EPrints::Plugin::Import" ) )
	{
		return if !@{$plugin->param( "produce" )};

		return $self->register_plugin( $data, $plugin );
	}
	elsif( $plugin->isa( "EPrints::Plugin::Export" ) )
	{
		return if !@{$plugin->param( "accept" )};

		return $self->register_plugin( $data, $plugin );
	}
	else
	{
		return; # unsupported
	}
}

=back

=head2 Methods

=over 4

=cut

=item $plugin = $plugins->get_plugin( $id, %params )

Returns a new plugin object identified by $id, initialised with %params.

=cut

sub get_plugin
{
	my( $self, $id, %params ) = @_;

	if( exists $self->{alias}->{$id} )
	{
		$params{id} = $id;
		$id = $self->{alias}->{$id};
	}
	return unless defined $id;

	if( $self->{disabled}->{$id} )
	{
		return;
	}

	my $class = $self->get_plugin_class( $id );
	if( !defined $class )
	{
		$self->{repository}->log( "Plugin '$id' not found." );
		return undef;
	}

	my $plugin = $class->new(
		repository => $self->{repository},
		session => $self->{repository},
		%params );

	if( ref($plugin) =~ /^EPrints::Plugin::(Import|Export)::XSLT::/ )
	{
		if( EPrints::Utils::mtime( $plugin->{_filename} ) > $plugin->{_mtime} )
		{
			my $ok = $self->_load_xslt(
				$self->{repository_data},
				$self->{repository},
				$plugin->{_filename},
				$class
			);
			if( $ok )
			{
				$plugin = $class->new(
					repository => $self->{repository},
					session => $self->{repository},
					%params );
			}
		}
	}

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

=item @plugins = $plugins->get_plugins( [ $params, ] %restrictions )

Returns a list of plugin objects that conform to %restrictions (may be empty).

If $params is given uses that hash reference to initialise the plugins.

=cut

sub get_plugins
{
	my( $self, @opts ) = @_;

	my $params = scalar(@opts) % 2 ?
		shift(@opts) :
		{};
	my %restrictions = @opts;

	my %plugins;

	$self->_list( \%plugins, $self->{repository_data}, $params, \%restrictions );
	$self->_list( \%plugins, $self->{data}, $params, \%restrictions );

	my @matches;
	# filter plugins for restrictions
	foreach my $plugin (values %plugins)
	{
		next unless defined $plugin;
		my $ok = 1;
		foreach my $k (keys %restrictions)
		{
			$ok = 0, last unless $plugin->matches( $k, $restrictions{$k} );
		}
		push @matches, $plugin if $ok;
	}

	return @matches;
}

sub _list
{
	my( $self, $found, $data, $params, $restrictions ) = @_;

	# this is an efficiency tweak - 99% of the time we'll want plugins
	# by type, so lets support doing that quickly
	my $type = $restrictions->{type};
	if( defined $type )
	{
		foreach my $id (@{$data->{$type}||[]})
		{
			next if exists $found->{$id};
			$found->{$id} = $self->get_plugin( $id, %$params );
		}
	}
	else
	{
		foreach $type (keys %$data)
		{
			next if $type eq "_class_";
			$self->_list( $found, $data, $params, {
				%$restrictions,
				type => $type
			} );
		}
	}
}

=item $plugin = $plugins->register_plugin( $data, $plugin )

Register a new plugin $plugin.

=cut

sub register_plugin
{
	my( $self, $data, $plugin ) = @_;

	my $id = $plugin->get_id;
	my $type = $plugin->get_type;
	my $class = ref($plugin);

	push @{$data->{$type}||=[]}, $id;
	$data->{"_class_"}->{$id} = $class;

	return $plugin;
}

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

