#!/usr/bin/perl

use Test::More tests => 3;

use EPrints;

my $repository = [EPrints::Config::get_repository_ids()]->[0];
my $session = EPrints::Session->new( 1, $repository, 2, 1 );
my $dataset = $session->get_repository->get_dataset( "archive" );

my $eprint = EPrints::DataObj::EPrint->new_from_data( $session, {
	eprint_status => "archive",
}, $dataset );

$eprint->set_value( "creators", [
{ name => { family => 'family_value1', given => 'given_value1' } },
{ name => { family => 'family_value2', given => 'given_value2' } },
]);

my $creators = $eprint->get_value( "creators_name" );

is( $creators->[0]->{family}, "family_value1" );
is( $creators->[1]->{family}, "family_value2" );

$eprint->set_value( "corp_creators", [
 "first",
 "second",
]);

my $corp_creators = $eprint->get_value( "corp_creators" );

is( $corp_creators->[1], "second" );
