#!/usr/bin/perl

use Test::More tests => 29;
use Test::MockObject;
use Test::MockObject::Extends;
use Data::Compare;
use Data::Dumper;
use EPrints; 

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::Test::RepositoryLog" ); }

my $repo = Test::MockObject->new();
$repo->mock("log", sub {print $_[1];});
$repo->mock("html_phrase", sub {return $_[1];});
$repo->set_always("get_field_defaults",undef);
$repo->set_always("set_field_defaults",undef);
$repo->set_always("config",{});
$repo->set_always("get_langid", "en");


my $field_type = "test";
my $confid = "anystring";
my $ds = Test::MockObject->new();
$ds->{repository} = $repo;
$ds->{confid} = $confid;

my $name = "thetestfield";
my $field = EPrints::MetaField->new( name=>$name, type=>$field_type, dataset=>$ds);

ok( ref $field eq "EPrints::MetaField::Test", "instantiated a metafield of type test" );

ok( $field->name eq $name, "name method renders correct" );

ok( $field->basename eq $name, "with no prefix basename is just name" );

my $prefix = "foo";
ok( $field->basename($prefix) eq $prefix."_".$name, "prefix is joined to basename" );

my $phrase_field_name = $confid."_fieldname_".$name;
ok( $field->render_name eq $phrase_field_name, "render_name attempts to render an appropriately named phrase" );

my $phrase_field_help = $confid."_fieldhelp_".$name;
ok( $field->render_help eq $phrase_field_help, "render_help attempts to render an appropriately named phrase" );

ok( $field_type eq $field->type, "field type is correct" );

ok( $field->has_property("type"), "has_property returns true when property is set" );

ok( !$field->has_property("foobarbaz"), "has_property returns false when property is not set" );

ok( $field->property("confid") eq $confid, "property returns a set property" );

ok( $field->is_type("foo", "test", "bar"), "is_type returns true when a correct type name is supplied" );

ok( !$field->is_type("foo", "bar", "baz"), "is_type returns false when no correct types are supplied" );

my $db = Test::MockObject->new();
$repo->set_always("get_database", $db);

my $values = ["foo", "bar", "baz"];
my $values_sorted_string = "bar:baz:foo";
$db->set_always("get_values", $values);

my $unsorted_values = $field->get_unsorted_values($repo, $ds);

ok( $unsorted_values == $values, "unsorted values returns db get values") ;

my $sorted_values = $field->get_values($repo);

ok( join(":", @{$sorted_values}) eq $values_sorted_string, "get_values sorts the values returned by get_unsorted_values" );

my $result = $field->all_values;

ok( join(":", @{$result}) eq $values_sorted_string, "all_values returns what get_values says" );

my $value = "Foo";
my $id = $field->get_id_from_value($repo, $value);

ok( $id eq $value, "id is correctly derived from suppied value");

$id = $field->get_id_from_value($repo, undef);

ok($id eq "NULL", "when value is undef id is NULL");

$id = "Foo";
$value = undef;

$value = $field->get_value_from_id($repo, $id);

ok( $value eq $id, "Value is correctly derived from id");

$value = $field->get_value_from_id( $repo, "NULL" );

ok( !defined($value), "NULL value is correctly translated back to undef" );

ok( $field->repository == $repo, "repository method returns the repository obj" );

ok( $field->dataset == $ds, "dataset method returns the dataset" );

ok( $field->empty_value eq "", "empty value returns empty string" );

ok( $field->is_browsable, "this field is browsable" );

ok( !$field->is_virtual, "this field is not virtual" );

my @list_value = $field->list_values(undef);

ok( scalar(@list_value) == 0, "empty value returns the empty array, not sure why this is..." );

$value = "Foo";

ok( $field->list_values($value) eq $value, "list values when called with a single value returns the value because field is not multiple" );




#there are a few places where _actual functions do a something for multiple or call the _single method. Should be _single and _multiple and probably should be roled in the key function.
#render_value
#call over loaded function
#call single value
#call multiple value

# {get,set}_field_defaults should maybe be private values on MetaField
# unsorted_values on metafield just calls get_values on Database but that doesnt actually do anything database relevent so should probably move to internal to metafield. also unsorted values seems like something which maybe should be private to metafield.


#TESTED
#sub new
#sub name
#sub basename 
#sub render_name
#sub render_help
#sub type
#sub has_property
#sub property
#sub is_type
#sub all_values
#sub get_values # deprecate in favour of all values?
#sub get_unsorted_values # all_values_unsorted for consistency?
#sub get_id_from_value
#sub get_value_from_id
#sub repository
#sub dataset
#sub empty_value
#sub is_browsable
#sub is_virtual
#sub list_values


#TO TEST
#sub call_property
#sub characters
#sub clone
#sub create_ordervalues_field
#sub end_element
#sub field_defaults
#sub final
#sub form_value #this really needs a form_name function. basename code is repeated in a few places
#sub form_value_actual 
#sub form_value_basic
#sub form_value_single
#sub from_search_form
#sub get_basic_input_elements 
#sub get_basic_input_ids 
#sub get_default_value
#sub get_ids_by_value
#sub get_index_codes
#sub get_index_codes_basic
#sub get_input_col_titles
#sub get_input_elements
#sub get_input_elements_single
#sub get_max_input_size
#sub get_property_defaults
#sub get_search_conditions
#sub get_search_conditions_not_ex
#sub get_search_group { return 'basic'; } 
#sub get_sql_index
#sub get_sql_name
#sub get_sql_names
#sub get_sql_properties
#sub get_sql_type
#sub get_state_params
#sub get_value
#sub get_xml_schema_field_type
#sub get_xml_schema_type { 'xs:string' }
#sub has_internal_action
#sub ordervalue # this is a mess, it shouldnt quote the value
#sub ordervalue_basic #should be private
#sub ordervalue_single # this has to be public because it can be overwritten seperately
#sub render_input_field
#sub render_input_field_actual
#sub render_search_description #this looks like it isnt used much. it should probably be in the screen plugin...
#sub render_search_input
#sub render_search_value
#sub render_single_value
#sub render_value # arguments for this are a real mess
#sub render_value_actual # should be private
#sub render_value_no_multiple # this should be private
#sub render_value_withopts # make private
#sub render_xml_schema
#sub render_xml_schema_type
#sub set_property
#sub set_value
#sub should_reverse_order { return 0; }
#sub sort_values
#sub split_search_value
#sub sql_row_from_value
#sub start_element
#sub to_sax
#sub to_sax_basic
#sub to_xml
#sub validate
#sub value_from_sql_row


#DEPRECATE THESE
#sub get_dataset { shift->dataset( @_ ) }
#sub get_name { shift->name( @_ ) }
#sub get_type { shift->type( @_ ) }
#sub get_property { shift->property( @_ ) }
#sub display_name
#sub get_value_label #deprecate in favour of render_value_label
#sub render_value_label #deprecate this and remove from API in favour of render_value?
