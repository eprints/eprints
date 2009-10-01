#!/usr/bin/perl

use Test::More tests => 14;

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

my $dataset = $repo->dataset( "archive" );
if( !defined $dataset ) { BAIL_OUT( "Could not obtain the archive dataset" ); }


is($dataset->id,"archive","id");
is($dataset->base_id,"eprint","id");

### Fields ###
my $field = $dataset->field( "eprint_status" );
if( !defined $dataset ) { BAIL_OUT( "Could not obtain the eprint_status field" ); }
isa_ok( $field, "EPrints::MetaField::Set", "eprint_status field type" );

ok(!defined($dataset->field( "INVALID_FIELDNAME" )), "invalid field name is undef" );

my $key_field = $dataset->key_field;
ok(defined($key_field), "key field exists");

my @fields = $dataset->fields;
is($key_field->name,$fields[0]->name,"key field is first element");

### Search ###
my $searchexp = $dataset->prepare_search(filters => [
	{ meta_fields => [qw( eprint_status )], value => "archive" }
]);
isa_ok( $searchexp, "EPrints::Search", "prepare_search()" );

### Objects ###
my $TITLE = "TEST EPRINT";

my $dataobj = $dataset->create_dataobj( { eprint_status => "inbox", title => $title, userid => 1 } );
if( !defined $dataobj ) { BAIL_OUT( "Could not create a new data object" ); }
my $dataobj_id = $dataobj->get_id;
my $dataobj_copy = $dataset->dataobj( $dataobj_id );
if( !defined $dataobj_copy ) { BAIL_OUT( "Could not retrieve new data object copy" ); }
ok( $dataobj_copy->get_id, $dataobj_id, "ids match of retrieved objects" );
ok(!defined($dataset->dataobj( "INVALID_ID" )), "invalid dataobj identifier is undef" )
is( $dataobj_copy->value( "title" ), $TITLE, "title value" );

$dataobj->delete; # clean up
