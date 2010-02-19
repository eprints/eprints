#!/usr/bin/perl

use Test::More tests => 10;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::Test::RepositoryLog" ); }

my $repoid = EPrints::Test::get_test_id();

my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
if( !defined $ep ) { BAIL_OUT( "Could not obtain the EPrints System object" ); }

my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );
if( !defined $repo ) { BAIL_OUT( "Could not obtain the Repository object" ); }

my @fields = @{ $repo->config( "fields","eprint" ) };


my $dataset = $repo->dataset( "archive" );
if( !defined $dataset ) { BAIL_OUT( "Could not obtain the archive dataset" ); }


my $export_ok = 1;
my $create_ok = 1;
my $move_to_buffer_ok = 1;
my $move_to_archive_ok = 1;
my $move_to_deletion_ok = 1;

local $EPrints::die_on_abort = 1;

foreach my $field_data ( @fields )
{
	my $field_name = $field_data->{name};

	local $dataset->{field_index} = {%{$dataset->{field_index}}};
	$dataset->unregister_field( $dataset->field( $field_name ) );

	my $eprint = eval { $dataset->create_dataobj( { 
		eprint_status => "inbox", 
		userid => 1,
		type => "article",
		creators => [
			 { id=>"23",name=>{given=>"John",family=>"Connor"}},
			 { name=>{given=>"Sally",family=>"Foobar"}},
		],
		editors => [
			 { id=>"23",name=>{given=>"John",family=>"Connor"}},
			 { name=>{given=>"Sally",family=>"Foobar"}},
		],
		contributors => [
			 { id=>"23",name=>{given=>"John",family=>"Connor"}, 
				type=>"http://www.loc.gov/loc.terms/relators/CRP"},
		],
		title => "Test title",
		abstract => "blah blah",
		date => "2009",
		isbn => "1234567890",
		issn => "12345690",
	} ); };
	if( $@ )
	{
		$create_ok = 0;
		print STDERR "*************************************************************\n";
		print STDERR "* Create eprint assumed field '$field_name' existed\n";
		print STDERR "*************************************************************\n";
		next;
	}

	if( !defined $eprint ) { BAIL_OUT( "Could not create a new eprint object (in sans $field_name mode)" ); }

	eval { $eprint->move_to_buffer(); };
	if( $@ )
	{
		$move_to_buffer_ok = 0;
		print STDERR "*************************************************************\n";
		print STDERR "* Move to buffer assumed field '$field_name' existed\n";
		print STDERR "*************************************************************\n";
	}

	eval { $eprint->move_to_archive(); };
	if( $@ )
	{
		$move_to_archive_ok = 0;
		print STDERR "*************************************************************\n";
		print STDERR "* Move to archive assumed field '$field_name' existed\n";
		print STDERR "*************************************************************\n";
	}

	my @plugins = $repo->plugin_list( 
				type=>"Export",
				can_accept=>"dataobj/eprint" );
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $repo->plugin( $plugin_id );
		eval { $plugin->output_dataobj( $eprint ); };
		if( $@ )
		{
			$export_ok = 0;
			print STDERR "*************************************************************\n";
			print STDERR "* Plugin '$plugin_id' assumed field '$field_name' existed\n";
			print STDERR "*************************************************************\n";
		}
	}

	eval { $eprint->move_to_deletion(); };
	if( $@ )
	{
		$move_to_deletion_ok = 0;
		print STDERR "*************************************************************\n";
		print STDERR "* Move to deletion assumed field '$field_name' existed\n";
		print STDERR "*************************************************************\n";
	}

	$eprint->delete; # clean up
}

ok( $export_ok, "Plugins with missing default field" );
ok( $create_ok, "Creating eprint with missing default field" );
ok( $move_to_buffer_ok, "move_to_buffer with missing default field" );
ok( $move_to_archive_ok, "move_to_archive with missing default field" );
ok( $move_to_deletion_ok, "move_to_deletion with missing default field" );


# done
