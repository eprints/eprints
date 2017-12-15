use strict;
use utf8;
use Test::More tests => 17;
use Test::MockObject;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $dummy_cache_id = 1234;

my $db = Test::MockObject->new();

$db->set_always("cache", $dummy_cache_id);
$db->set_true("drop_cache");
$db->mock("get_dataobjs", sub {
	my ( $self, $dataset, @ids ) = @_;

	my @objs = ();

	foreach my $id (@ids)
	{
		my $obj = Test::MockObject->new();
		$obj->set_always("id", $id);
		push @objs, $obj;
	}

	return @objs;
});

my $repo = Test::MockObject->new();

my $dataset = Test::MockObject->new();

$repo->set_always("get_database", $db);

my $ids = [3,4,6,9];

my %params = ( session=>$repo, dataset=>$dataset, ids=>$ids);

my $list = EPrints::List->new(%params);

ok(defined($list), "list instantiated with basic parameters");

ok( $list->count == scalar @{$ids}, "count returns the correct number of elements" );

ok( array_refs_match($list->ids, $ids), "ids sub returns the same ids we instatiated with");

ok( $list->get_dataset() == $dataset, "get dataset returns the dataset we gave it");

my $dataobj = $list->item(3);
ok( $dataobj->id == $ids->[3], "item gets the correct item from the list" );

my @objects = $list->slice;

ok( objects_have_ids(\@objects, $ids), "slice with no arguements returns all ids" );

@objects = $list->slice( 1,2 );
my $slice_ids = [$ids->[1], $ids->[2]];

ok( objects_have_ids(\@objects, $slice_ids), "slice cuts the objects correctly" );

my $ctx = {count=>0};

$list->map( sub { 
	my ( $repo, $dataset, $dataobj, $ctx ) = @_;
	
	if($dataobj->id)
	{
		$ctx->{count}++;
	}
}, $ctx);

ok($ctx->{count} == scalar @{$ids}, "map is called once for each item in the list and the context is passed through");

ok( !defined($list->get_cache_id), "an uncached list should have undef cache_id");

$list->cache;

ok( $db->called("cache"), "list->cache calls db->cache");

ok( $list->get_cache_id == $dummy_cache_id, "cache_id is stored correctly after cache is called");

$list->dispose;

ok( !defined($list->get_cache_id), "dispose removes the cache id");

$list = EPrints::List->new(%params);

my $ids2 = [$ids->[2],13,14,15];
my %params2 = ( session=>$repo, dataset=>$dataset, ids=>$ids2);
my $list2 = EPrints::List->new(%params2);
my $union = $list->union($list2);

my @union_ids = (@{$ids2});
shift @union_ids;
@union_ids = (@{$ids}, @union_ids);

ok( array_refs_match( [$union->ids], \@union_ids ), "union joins the ids and does not duplicate overlapping ids" );

my $intersect = $list->intersect($list2);

ok( array_refs_match( [$intersect->ids], [$ids->[2]] ), "intersect returns only the overlapping ids" );

my $remainder = $list->remainder($list2);

my @remainder_ids = @{$ids};
delete $remainder_ids[2];

ok( array_refs_match( [$remainder->ids], \@remainder_ids ), "remainder subtracts items in the parameter list from the calling list");





sub objects_have_ids 
{
	my ($objects, $ids) = @_;

	for( my $i=0; $i < scalar @{$objects}; $i++)
	{
		if($ids->[$i] != $objects->[$i]->id)
		{
			return 0;
		}
	}
	
	return 1;
}

sub array_refs_match
{
	my ($arr1, $arr2) = @_;
	
	my $str1 = join(@{$arr1},",");
	my $str2 = join(@{$arr2},",");

	return $str1 eq $str2;
	
}

#sub reorder
#sub export
#sub render_description

#sub union
#sub remainder
#sub intersect
#sub map
#sub get_dataset
#sub cache
#sub get_cache_id
#sub dispose
#sub count 
#sub item
#sub slice
#sub ids
