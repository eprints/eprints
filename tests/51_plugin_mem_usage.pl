use Test::More tests => 3;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

our %PLUGIN_MEM_USAGE;

{
package EPrints::Test::PluginFactory;

our @ISA = qw( EPrints::PluginFactory );

	sub _load_plugin
	{
		my( $self, $data, $repository, $fn, $class ) = @_;

		EPrints::Test::mem_increase(0); # Reset

		my $rc = $self->SUPER::_load_plugin( @_[1..$#_] );

		$PLUGIN_MEM_USAGE{$class} = EPrints::Test::mem_increase();

		return $rc;
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

ok(defined $repository, "test repository creation");

my %usage = %PLUGIN_MEM_USAGE;

my $show = $ENV{PLUGIN_MEM_USAGE} || 5;

diag( "\nPlugin Memory Usage" );
foreach my $class (sort { $usage{$b} <=> $usage{$a} } keys %usage)
{
	diag( "$class=".EPrints::Utils::human_filesize( $usage{$class} ) );
	last unless --$show;
}
