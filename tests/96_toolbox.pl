#!/usr/bin/perl

use Test::More tests => 9;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::Toolbox" ); }

my $repoid = EPrints::Test::get_test_id();

my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
if( !defined $ep ) { BAIL_OUT( "Could not obtain the EPrints System object" ); }

my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );
if( !defined $repo ) { BAIL_OUT( "Could not obtain the Repository object" ); }

my $document = EPrints::Test::get_test_dataobj( $repo->dataset( "document" ) );

my $filename = "test_$$.txt";
my $data = "Hello, World!\n";

my @results;

@results = EPrints::Toolbox::tool_addFile(
	session => $repo,
	document => $document,
	filename => $filename,
	data_fn => sub { $data }, );
ok( $results[0] eq "0", "tool_addFile" );

@results = EPrints::Toolbox::tool_getFile(
	session => $repo,
	document => $document,
	filename => $filename, );
is( $results[1], $data, "tool_getFile" );

@results = EPrints::Toolbox::tool_removeFile(
	session => $repo,
	document => $document,
	filename => $filename, );
ok( $results[0] eq "0", "tool_delFile" );

ok(1);
