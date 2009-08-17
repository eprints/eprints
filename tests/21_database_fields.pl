use strict;
use Test::More tests => 17;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $handle = EPrints::Test::get_test_session( 0 );
ok(defined $handle, 'opened an EPrints::Handle object (noisy, no_check_db)');

# a dataset that won't mind being broken
my $dataset = $handle->get_repository->get_dataset( "upload_progress" );

my $db = $handle->get_db;

my $field;

# singular add/remove
$field = EPrints::MetaField->new(
	dataset => $dataset,
	type => "text",
	name => "unit_tests",
	sql_index => 1,
);
ok( $db->add_field( $dataset, $field ), "add field" );
ok( $db->has_column( $dataset->get_sql_table_name, $field->get_sql_name ), "expected column name" );
ok( $db->remove_field( $dataset, $field ), "remove field" );

# single rename
$field = EPrints::MetaField->new(
	dataset => $dataset,
	type => "text",
	name => "unit_tests",
);
ok( $db->add_field( $dataset, $field ), "add field" );
$field->set_property( name => "unit_tests2" );
ok( $db->rename_field( $dataset, $field, "unit_tests" ), "rename field" );
ok( $db->has_column( $dataset->get_sql_table_name, $field->get_sql_name ), "expected column name" );
ok( $db->remove_field( $dataset, $field ), "remove field" );

# multiple add/remove
$field = EPrints::MetaField->new(
	dataset => $dataset,
	type => "text",
	name => "unit_tests",
	multiple => 1,
);
ok( $db->add_field( $dataset, $field ), "add multiple field" );
ok( $db->has_table( $dataset->get_sql_sub_table_name( $field ) ), "expected table name" );
ok( $db->remove_field( $dataset, $field ), "remove multiple field" );

# multiple rename
$field = EPrints::MetaField->new(
	dataset => $dataset,
	type => "text",
	name => "unit_tests",
	multiple => 1,
);
ok( $db->add_field( $dataset, $field ), "add multiple field" );
$field->set_property( name => "unit_tests2" );
ok( $db->rename_field( $dataset, $field, "unit_tests" ), "rename multiple field" );
ok( $db->has_table( $dataset->get_sql_sub_table_name( $field ) ), "expected table name" );
ok( $db->remove_field( $dataset, $field ), "remove multiple field" );

$handle->terminate;
