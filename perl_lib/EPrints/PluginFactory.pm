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

use EPrints;
use EPrints::Const;

use strict;

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

	$self->{xslt} = {};

	my $dir;

	my $use_xslt =
		$EPrints::XML::CLASS eq "EPrints::XML::LibXML" &&
		EPrints::Utils::require_if_exists( "XML::LibXSLT" );

	# system plugins (only load once)
	$dir = $repository->get_conf( "base_path" )."/perl_lib";
	if( !scalar keys %SYSTEM_PLUGINS )
	{
		$self->_load_dir( $self->{data}, $repository, $dir );
		if( $use_xslt )
		{
			$self->_load_xslt_dir( $self->{data}, $repository, $dir );
		}
	}

	# repository-specific plugins
	$dir = $repository->get_conf( "config_path" )."/plugins";
	$self->_load_dir( $self->{repository_data}, $repository, $dir );
	if( $use_xslt )
	{
		$self->_load_xslt_dir( $self->{repository_data}, $repository, $dir );
	}

	$self->{disabled} = {};

	# build a cheat-sheet of config-disabled plugins
	foreach my $plugin ($self->get_plugins)
	{
		my $pluginid = $plugin->get_id();
		$self->{disabled}->{$pluginid} = $plugin->param( "disable" );
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

sub _load_xslt_dir
{
	my( $self, $data, $repository, $base_dir ) = @_;

	$base_dir .= "/EPrints/Plugin";

	return unless -d $base_dir;

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
			$self->_load_xslt( $data, $repository, $File::Find::name, $class );
		},
		no_chdir => 1,
		},
		$base_dir
	);
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

	my $plugin = $class->new(
		repository => $self->{repository},
		session => $self->{repository} );

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

sub _load_xslt
{
	my( $self, $data, $repository, $fn, $class ) = @_;

	if( !exists $self->{xslt}->{$fn} )
	{
		local $SIG{__DIE__};
		my $doc = eval { $repository->xml->parse_file( $fn ) };
		if( !defined $doc )
		{
			$repository->log( "Error parsing $fn: $@" );
			return;
		}
		my $xslt = $self->{xslt}->{$fn} = {};
		foreach my $attr ($doc->documentElement->attributes)
		{
			next if $attr->isa( "XML::LibXML::Namespace" );
			next if !defined $attr->namespaceURI;
			next if $attr->namespaceURI ne EP_NS_XSLT;
			$xslt->{$attr->localName} = $attr->value();
		}
		for(qw( produce accept ))
		{
			$xslt->{$_} = [split / /, $xslt->{$_}||""];
		}
		my $stylesheet = XML::LibXSLT->new->parse_stylesheet( $doc );
		$xslt->{stylesheet} = $stylesheet;
	}
	my $xslt = $self->{xslt}->{$fn};

	my $handler = $class;
	$handler =~ s/^(EPrints::Plugin::[^:]+::XSLT).*/$1/;

	my $settingsvar = $class."::SETTINGS";

	{
	no warnings; # avoid redef-warnings for new()
	eval <<EOP;
package $class;

our \@ISA = qw( $handler );

sub new
{
	return shift->SUPER::new( \%\$$settingsvar, \@_ );
}

1
EOP
	die $@ if $@;
	}

	{
		no strict "refs";
		${$settingsvar} = $xslt;
	}

	my $plugin = $class->new( repository => $repository );
		
	if( $plugin->isa( "EPrints::Plugin::Import" ) )
	{
		return if !@{$plugin->param( "produce" )};

		$self->register_plugin( $plugin );
	}
	elsif( $plugin->isa( "EPrints::Plugin::Export" ) )
	{
		return if !@{$plugin->param( "accept" )};

		$self->register_plugin( $plugin );
	}
	else
	{
		return; # unsupported
	}
}

=item $ok = EPrints::PluginFactory->register_plugin( $plugin )

Register a new plugin with all repositories.

=cut

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

	if( $self->{disabled}->{$id} )
	{
		return;
	}

	if( exists $self->{alias}->{$id} )
	{
		$params{id} = $id;
		$id = $self->{alias}->{$id};
	}
	return unless defined $id;

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
