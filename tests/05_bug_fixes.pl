#!/usr/bin/perl

use Test::More tests => 11;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repoid = EPrints::Test::get_test_id();
my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );

my $dataset = $repo->dataset( "eprint" );
my $dataobj = EPrints::Test::get_test_dataobj( $dataset );
my $list;

#3648 - 100 in review messages
$list = $dataset->search( limit => 3 );
is($list->count, 3, "list is 3 long");
$list->map(sub {});
is($list->count, 3, "list is 3 long after map");
is(scalar($list->slice(0)), 3, "all slice is 3 long");
is(scalar($list->slice(0,3)), 3, "slice is 3 long");
is(scalar($list->slice(0,5)), 3, "slice is 3 long, asked for 5");
is(scalar($list->slice(0,2)), 2, "slice is 2 long, asked for 2");
is($list->count, 3, "list is 3 long after slice");
