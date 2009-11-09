#!/usr/bin/perl

use Test::More tests => 3;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repoid = EPrints::Test::get_test_id();
my $ep = EPrints->new();
my $repo = $ep->repository( $repoid );

my $searchexp = EPrints::Search->new(
	session => $repo,
	dataset => $repo->dataset( "subject" ),
	allow_blank => 1
);

my @subjects = $searchexp->perform_search->get_records();

BAIL_OUT("No subjects loaded") if !@subjects;

my $childless;
for(@subjects)
{
	$childless = $_, last if !($_->get_children);
}

$repo->cache_subjects;

my $cached = EPrints::DataObj::Subject->new( $repo, $childless->get_id );

#3451
ok(!$cached->get_children, "can call get_children on childless subject")
