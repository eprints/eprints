#!/usr/bin/perl

use Test::More tests => 10;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repository = EPrints::Test::get_test_repository();
my $session = EPrints::Test::get_test_session();
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

my $field;
for($dataset->fields)
{
	$field = $_, last if $_->get_property( "multiple" ) && $_->isa( "EPrints::MetaField::Set" );
}

SKIP: {
	skip "Missing multiple MetaField::Set", 1 unless defined $field;

	$field->set_value( $eprint, [qw( one two three two five)] );

	is_deeply( $field->get_value( $eprint ), [qw( one two three five )], "set field removes duplicates");
};

my $tf = EPrints::MetaField->new(
	type => "time",
	name => "xxx_time",
	repository => $repository );
$dataset->register_field( $tf );

$tf->set_value( $eprint, "1234-12-31 23:59:59" );
is( $tf->get_value( $eprint ), "1234-12-31 23:59:59", "set time value default" );
$tf->set_value( $eprint, "1234-12-31T23:59:59Z" );
is( $tf->get_value( $eprint ), "1234-12-31 23:59:59", "set time value ISO" );
$tf->set_value( $eprint, "1234-12-31 23" );
is( $tf->get_value( $eprint ), "1234-12-31 23", "set partial time value" );
$tf->set_value( $eprint, undef );
is( $tf->get_value( $eprint ), undef, "set undef time value" );
