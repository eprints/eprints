#!/usr/bin/perl

use Test::More tests => 15;
use Test::MockObject;
use Data::Dumper;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::Test::RepositoryLog" ); }

my $default_order = "title";
my $repo = Test::MockObject->new();

$repo->mock( "get_conf", sub {
	my ( $self, $conf_item ) = @_;

	if($conf_item eq "default_order")
	{
		return $default_order;
	}

	if($conf_item eq "fields")
	{
		return [ { name=>"subtitle", type=>"text", required=>1 } ];
	}
});

$repo->mock("config", sub
{
	my ( $self, $conf_item, $dataset_id ,$search, $search_id) = @_;
	if($conf_item eq "field_defaults")
	{
		return {};
	}
	if($conf_item eq "datasets" && $search_id eq "bigsearch")
	{
		return {property1=>"param", other=>"param"};
	}
	return undef;
});

$repo->mock("log", sub {
	my ( $self, $message ) = @_;
	print $message,"\n";
});

$repo->set_always("get_field_defaults", undef);
$repo->set_true("set_field_defaults");

{
package EPrints::DataObj::FakeObj;

our @ISA = ("EPrints::DataObj");

sub get_system_field_info
{
	return  ( { name=>"id", type=>"counter", required=>1, import=>0, show_in_html=>0, can_clone=>0,
		sql_counter=>"documentid" },

	{ name=>"title", type=>"text", required=>1, can_clone=>0, default_value=>"some text" });

}

sub create_from_data
{
	my ($class, $repo, $data, $dataset) = @_;
	return bless $data, $class;
}

sub new
{
	my ($class, $repository, $id, $dataset) = @_;
	return bless {id=>$id}, $class;
}

};

my $set_name = "fakeset";
my $set_object = "FakeObj";
my $dataobj_class = "EPrints::DataObj::".$set_object;
my $ds = EPrints::DataSet->new( repository=>$repo, name=>$set_name, type=>$set_object );

ok( defined($ds), "Dataset created successfully" );

ok( $ds->id eq $set_name, "dataset id is the name that was passed");
ok( $ds->base_id eq $set_name, "because no confid was passed the id is the same as baseid");
my $test_title = "test demo title";
my $obj = $ds->create_dataobj( { title=>$test_title } );
ok( ref $obj eq $dataobj_class, "create_dataobj instantiates an object of the correct type" );
ok( $obj->{title} eq $test_title, "dataset passes through the hash of data correctly when creating and object");

my $test_id = 21;
$obj = $ds->dataobj( $test_id );
ok( ref $obj eq $dataobj_class, "dataobj instatiates an object of the correct type" );
ok( $obj->{id} == $test_id, "dataobj passes through id to the instantiated object correctly" );

my $search = $ds->prepare_search;
ok( ref $search eq "EPrints::Search", "prepare_search returns a search" );

#my $list = $ds->search;
#ok( ref $list eq "EPrints::List", "search returns a list");

my $field_name = "title";

ok( $ds->has_field($field_name), "has_field returns true when the field exists");
ok( !$ds->has_field("NONEXISTENTFIELD"), "has_field returns false when the field exists");

my $field = $ds->field($field_name);
ok( $field->name eq $field_name, "field returns a field with the correct name" );
ok( $field->type eq "text", "field returns a field with the correct type" );

my $key_field = $ds->key_field;
ok( $key_field->name eq "id", "key_field returns the field with the correct name");

my @metafields = $ds->fields;
ok( scalar @metafields == 3, "fields returns the correct number of fields" );

ok( $ds->default_order eq $default_order, "default_order is returns the value it was set to in the repository conf" );

ok( dataset_info_ok( $ds->get_system_dataset_info ), "all datasets in the system info have an sqlname" );

ok( !$ds->is_virtual, "is_virtual returns false when the dataset is not virtual");

ok( !defined($ds->ordered), "ordered returns undef when the dataset is not ordered" );

my $list = $ds->list([ 1,2,3,5 ]);

ok( $list->count == 4, "list creates a list of appropriate length");

ok($ds->dataobj_class eq $dataobj_class, "dataobj_class returns the correct class name");

ok( !defined($ds->indexable), "indexable returns undef when the index property is not set" );

ok( scalar( keys %{ $ds->search_config("unknown_search_id") } ) == 0, "search_config returns empty hash when the search_id is unknown");
ok( defined($ds->search_config("bigsearch")->{property1} ) , "search_config returns repository config for search when search_id is known" );

my $search_fields_config = join(":", @{$ds->search_config( "simple" )->{search_fields}->[0]->{meta_fields}});
my $search_fields_from_sub = join(":", @{$ds->_simple_search_config->{search_fields}->[0]->{meta_fields}});

ok( $search_fields_config eq $search_fields_from_sub, "search_config returns _simple_search_config when not defined in repository config" );



#TODO add a mock to test what this does when a search conf is found and etc etc for all the other slightly odd behaviour

sub dataset_info_ok
{
	my ( $info ) = @_;
	
	my $problem = 1;
	foreach my $key (keys %{$info})
	{
		$problem = 0 if !defined($info->{$key}->{sqlname});
	}
	return $problem;
}

#TESTED
#sub new
#sub base_id
#sub id
#sub create_dataobj
#sub key_field
#sub field
#sub has_field
#sub prepare_search
#sub fields
#sub default_order
#sub get_system_dataset_info
#sub dataobj
#sub is_virtual
#sub ordered
#sub list
#sub dataobj_class
#sub indexable
#sub search_config
#sub register_field

#TO TEST
#sub unregister_field
#sub count
#sub get_sql_table_name
#sub get_sql_index_table_name
#sub get_sql_grep_table_name
#sub get_sql_rindex_table_name
#sub get_ordervalues_table_name
#sub get_sql_sub_table_name
#sub get_object_from_uri
#sub render_name
#sub map
#sub repository
#sub reindex
#sub get_dataset_ids
#sub get_sql_dataset_ids
#sub get_item_ids
#sub get_dataset_id_field
#sub get_filters
#sub get_datestamp_field
#sub search
#sub columns
#sub run_trigger
#sub citation


#DEPRECATE these....
#sub get_object_class { &dataobj_class }
#sub get_archive { &repository }
#sub get_repository { &repository }
#sub get_key_field { &key_field }
#sub get_fields { &fields }
#sub confid { &base_id }
#sub create_object
#sub make_dataobj
#sub get_object
#sub get_field { &field }
#sub make_object { $_[0]->make_dataobj( $_[2] ) }
