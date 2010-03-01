#!/usr/bin/perl

use Test::More;

use strict;
use warnings;

use EPrints;
use EPrints::Test;
use EPrints::Test::RepositoryLog;

my $repoid = EPrints::Test::get_test_id();

my $ep = EPrints->new();
if( !defined $ep ) { BAIL_OUT( "Could not obtain the EPrints System object" ); }

my $repo = $ep->repository( $repoid );
if( !defined $repo ) { BAIL_OUT( "Could not obtain the Repository object" ); }

my @fields = @{ $repo->config( "fields","eprint" ) };

my $dataset = $repo->dataset( "archive" );
if( !defined $dataset ) { BAIL_OUT( "Could not obtain the archive dataset" ); }

my @plugins = $repo->get_plugins( 
	type => "Export",
	can_accept => "dataobj/eprint",
	is_advertised => 1 ); # only check public plugins - others might to bad things!

plan tests => @fields * 4 + @fields * @plugins;

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
		publication => "Foo Journal",
		event_title => "BLAH2005",
		date => "2009",
		isbn => "1234567890",
		issn => "12345690",
	} ); };
	ok( !$@, "create eprint without '$field_name' field" );

	if( !defined $eprint ) { BAIL_OUT( "Could not create a new eprint object (in sans $field_name mode)" ); }

	eval { $eprint->move_to_buffer(); };
	ok( !$@, "move_to_buffer without '$field_name' field" );

	eval { $eprint->move_to_archive(); };
	ok( !$@, "move_to_archive without '$field_name' field" );

	foreach my $plugin ( @plugins ) 
	{
		my $plugin_id = $plugin->get_id;
		eval { $plugin->output_dataobj( $eprint ); };
		ok( !$@, "plugin '$plugin_id' without '$field_name' field" );
	}

	eval { $eprint->move_to_deletion(); };
	ok( !$@, "move_to_deletion without '$field_name' field" );

	$eprint->delete; # clean up
}

# done
