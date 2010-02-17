#!/usr/bin/perl

use Test::More tests => 13;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repoid = EPrints::Test::get_test_id();
my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );

my $dataset = $repo->dataset( "eprint" );
my $dataobj = EPrints::Test::get_test_dataobj( $dataset );
my $list;

#3648 - 100 in review messages
$list = $dataset->search( limit => 3 );
is($list->count, 3, "list is 3 long");
$list->map(sub {});
is($list->count, 3, "list is 3 long after map");
is(scalar($list->slice(0)), 3, "all slice is 3 long");
is(scalar($list->slice(0,3)), 3, "slice is 3 long");
is(scalar($list->slice(0,5)), 3, "slice is 3 long, asked for 5");
is(scalar($list->slice(0,2)), 2, "slice is 2 long, asked for 2");
is($list->count, 3, "list is 3 long after slice");

#3679 - 4096 [size] files issues on ECS Eprints
{
	my $str = 'x' x 5000;
	my $doc = $dataobj->create_subdataobj( 'documents', {
		format => $dataobj->{session}->{types}->{'document'}->[0]
	});
	my $file = $doc->create_subdataobj( 'files', {
		_content => \$str,
		filename => "TEST_DATA",
		filesize => length($str),
	});
	my $cnt = "";
	$file->get_file( sub { $cnt .= $_[0] } );
	is( length($cnt), length($str), "file stored ok" );
	my $doc_clone = $doc->clone( $dataobj );
	my $file_clone = $doc_clone->get_stored_file( "TEST_DATA" );
	my $clone_str = "";
	$file_clone->get_file( sub { $clone_str .= $_[0] } );
	is( length($clone_str), length($str), "file clones ok" );
	$doc_clone->remove;
	$file->remove;
}
