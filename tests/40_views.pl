use strict;
use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

our $VIEW_DIR = undef;

END
{
	if( defined $VIEW_DIR )
	{
		EPrints::Utils::rmtree( $VIEW_DIR );
	}
}

$SIG{INT} = sub { die "CAUGHT SIGINT\n" };

EPrints::Test::mem_increase();

my $handle = EPrints::Test::get_test_session( 0 );
ok(defined $handle, 'opened an EPrints::Handle object (noisy, no_check_db)');

$handle->cache_subjects;

my $repository = $handle->get_repository;

my $views = $repository->get_conf( "browse_views" );

my $ds = $repository->get_dataset( "archive" );

my $test_id = "_40_views_pl";

my $lang = $handle->get_lang;
my $langid = $lang->{id};

# Work-around to suppress the phrase warnings
{
my $data = $lang->_get_repositorydata;
$data->{xml}->{"viewname_eprint_$test_id"} = $handle->make_text( $test_id );
keys %{$data->{file}};
(undef, $data->{file}->{"viewname_eprint_$test_id"}) = each %{$data->{file}};
keys %{$data->{file}};
}

my $test_view = 
{
	id => $test_id,
	allow_null => 1,
	fields => "-date;res=year",
	order => "creators_name/title",
	variations => [
		"creators_name;first_letter",
		"type",
		"DEFAULT" ],
};

$VIEW_DIR = $repository->get_conf( "htdocs_path" )."/".$langid."/view/$test_id";

my @files;

EPrints::Test::mem_increase();
Test::More::diag( "memory footprint\n" );

push @files, update_view_by_path(
		handle => $handle,
		view => $test_view, 
		langid => $langid, 
		path => [],
		do_menus => 1,
		do_lists => 1 );

Test::More::diag( "\t update_view_by_path=" . EPrints::Test::human_mem_increase() );

push @files, EPrints::Update::Views::update_browse_view_list(
		$handle,
		$langid );

Test::More::diag( "\t update_browse_view_list=" . EPrints::Test::human_mem_increase() );

$handle->terminate;

ok(1);

sub update_view_by_path
{
	my( %opts ) = @_;

	my @files = ();

	my $sizes = EPrints::Update::Views::get_sizes( $opts{handle}, $opts{view}, $opts{path} );

	if( defined $sizes )
	{
		# has sub levels
		if( $opts{do_menus} )
		{
			my @menu_files = EPrints::Update::Views::update_view_menu( $opts{handle}, $opts{view}, $opts{langid}, $opts{path} );
			push @files, @menu_files;
		}

		foreach my $menu_value ( keys %{$sizes} )
		{
			my %newopts = %opts;
			$menu_value = EPrints::Utils::escape_filename( $menu_value );
			$newopts{path} = [@{$newopts{path}}, $menu_value];
			push @files, update_view_by_path( %newopts );
			last; # only do one branch
		}
	}

	if( !defined $sizes && $opts{do_lists} )
	{
		# is a leaf node
		my @leaf_files = EPrints::Update::Views::update_view_list( $opts{handle}, $opts{view}, $opts{langid}, $opts{path} );
		push @files, @leaf_files;
	}

	return @files;
}

