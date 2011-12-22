use Test::More tests => 3;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

$EPrints::Test::CONFIG_FILES = {};

{
package EPrints::Test::Repository;

our @ISA = qw( EPrints::Repository );

	sub load_config
	{
		# reset mem usage ready for the first call to a _load method below
		EPrints::Test::human_mem_increase();
		$EPrints::Test::MEM_SIZE = EPrints::Test::mem_size();

		return &EPrints::Repository::load_config;
	}
	sub _load_workflows
	{
		my $max = $ENV{SHOW} || 5;
		my $files = $EPrints::Test::CONFIG_FILES;
		my $total = 0;
		$total += $_ for values %$files;
		foreach my $filepath ((sort { $files->{$b} <=> $files->{$a} } keys %$files)[0..($max-1)])
		{
			$total -= $files->{$filepath};
			Test::More::diag( "\t.".substr($filepath,length($EPrints::SystemSettings::conf->{base_path}))."=".EPrints::Utils::human_filesize($files->{$filepath}));
		}
		Test::More::diag( "\t... ".(scalar(keys(%$files))-$max)." others=".EPrints::Utils::human_filesize( $total ) );

		Test::More::diag( "\t_load_config (total)=" . EPrints::Test::human_mem_increase( $EPrints::Test::MEM_SIZE ) );

		my $rc = &EPrints::Repository::_load_workflows;

		Test::More::diag( "\t_load_workflows=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
	sub _load_storage
	{
		my $rc = &EPrints::Repository::_load_storage;

		Test::More::diag( "\t_load_storage=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
	sub _load_namedsets
	{
		my $rc = &EPrints::Repository::_load_namedsets;

		Test::More::diag( "\t_load_namedsets=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
	sub _load_datasets
	{
		my $rc = &EPrints::Repository::_load_datasets;

		Test::More::diag( "\t_load_datasets=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
	sub _load_languages
	{
		my $rc = &EPrints::Repository::_load_languages;

		Test::More::diag( "\t_load_languages=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
	sub _load_templates
	{
		my $rc = &EPrints::Repository::_load_templates;

		Test::More::diag( "\t_load_templates=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
	sub _load_citation_specs
	{
		my $rc = &EPrints::Repository::_load_citation_specs;

		Test::More::diag( "\t_load_citation_specs=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
	sub _load_plugins
	{
		my $rc = &EPrints::Repository::_load_plugins;

		Test::More::diag( "\t_load_plugins=" . EPrints::Test::human_mem_increase() );

		return $rc;
	}
}

my $f = \&EPrints::Config::_bootstrap;
eval {
	no warnings;
	*EPrints::Config::_bootstrap = sub {
		my $perl = &$f;
		$perl =~ s/(eval .+)$/$1\n\$EPrints::Test::CONFIG_FILES->{\$filepath} = EPrints::Test::mem_increase();/m;
		return $perl;
	};
};

my $core_modules = EPrints::Test::human_mem_increase();
{
my $path = $EPrints::SystemSettings::conf->{base_path} . "/perl_lib/EPrints/MetaField";
opendir(my $dh, $path);
while(my $fn = readdir($dh))
{
	next if $fn =~ /^\./;
	if( $fn =~ s/\.pm$// )
	{
		EPrints::Utils::require_if_exists( "EPrints::MetaField::".$fn );
	}
}
closedir($dh);
}
diag( "LOAD=".$core_modules." + ".EPrints::Test::human_mem_increase()." fields" );
diag( "Repository-Specific Data" );
my $repository = EPrints::Test::Repository->new( EPrints::Test::get_test_id() );

ok(defined $repository, "test repository creation");
