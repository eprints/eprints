use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

our %_PLUGIN_MEM_USAGE;

{
package EPrints::Test::PluginFactory;

our @ISA = qw( EPrints::PluginFactory );

	sub _load_plugin
	{
		my( $self, $data, $repository, $fn, $class ) = @_;

		EPrints::Test::mem_increase(0); # Reset
		eval "use $class; 1";
		if( $@ ne "" )
		{
			$repository->log( "Problem loading plugin $class [$fn]:\n$@" );
			return;
		}

		my $plugin = $class->new();
		$_PLUGIN_MEM_USAGE{$class} = EPrints::Test::mem_increase();

		# disabled by class-global?
		no strict "refs";
		my $disvar = $class.'::DISABLE';
		my $disable = ${$disvar};
		$disable = ${$disvar}; # supress "only once" warning
		#my %defaults = $class->defaults();
		use strict "refs";
		return if( $disable );

		$self->register_plugin( $plugin );

#		Test::More::diag( "\t_load_plugin[$class]=" . EPrints::Test::human_mem_increase() );
	}
}
{
package EPrints::Test::Repository;

our @ISA = qw( EPrints::Repository );

	sub _load_plugins
	{
		my( $self ) = @_;

		$self->{plugins} = EPrints::Test::PluginFactory->new( $self );

		return defined $self->{plugins};
	}
}

my $repository = EPrints::Test::Repository->new( EPrints::Test::get_test_id() );

my $session = EPrints::Test::get_test_session();

ok(defined $repository, "test repository creation");
ok(defined $session, "test session creation");

$session->terminate;

my %usage = %_PLUGIN_MEM_USAGE;

my $show = 5;

diag( "\nPlugin Memory Usage" );
foreach my $class (sort { $usage{$b} <=> $usage{$a} } keys %usage)
{
	diag( "$class=".EPrints::Utils::human_filesize( $usage{$class} ) );
	last unless --$show;
}
