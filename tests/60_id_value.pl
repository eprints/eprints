use strict;
use Test::More tests => 6;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session();
my $repository = $session->get_repository;

my $field = EPrints::MetaField->new(
	repository => $repository,
	name => "test",
	type => "text",
	);

my $value = chr(0x169) . " X '\"&++";

is( $field->get_id_from_value( $session, undef ), "NULL", "undef->NULL" );
is( $field->get_value_from_id( $session, "NULL" ), undef, "NULL->''" );

my $id = $field->get_id_from_value( $session, $value );
is( $field->get_value_from_id( $session, $id ), $value, "value->id->value" );

$field = EPrints::MetaField->new(
	repository => $repository,
	name => "test",
	type => "name",
	);

my $name = {
	family => "XxXx '+:^%".chr(0x169),
	given => "XxXx '+:^%".chr(0x169),
	honourific => "DR.",
};

$id = $field->get_id_from_value( $session, $name );
is_deeply( $field->get_value_from_id( $session, $id ), $name, "name->id->name" );

