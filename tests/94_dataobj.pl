#!/usr/bin/perl

use Test::More tests => 7;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repoid = EPrints::Test::get_test_id();

my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
if( !defined $ep ) { BAIL_OUT( "Could not obtain the EPrints System object" ); }

my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );
if( !defined $repo ) { BAIL_OUT( "Could not obtain the Repository object" ); }

my $TITLE = "My First Title";

my $epdata = {
	eprint_status => "inbox",
	title => $TITLE,
	userid => 1,
};

my $eprint = $repo->dataset( "eprint" )->create_dataobj( $epdata );
BAIL_OUT( "Failed to create eprint object" ) if !defined $eprint;

ok($eprint->value( "title" ) eq $TITLE, "eprint created with title" );

# subobject

my $FORMAT = "application/pdf";

$epdata = {
	format => $FORMAT,
};

my $doc = $eprint->create_subobject( "documents", $epdata );
BAIL_OUT( "Failed to create doc object" ) if !defined $doc;

ok($doc->value( "format" ) eq $FORMAT, "doc created with format" );
ok($doc->parent->id eq $eprint->id, "doc created as subobject of eprint");

$eprint->delete(); # deletes document sub-object too
