#!/usr/bin/perl

use Test::More tests => 10;

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

my $xml = $repo->xml;

my $XML = <<EOX;
<?xml version='1.0'?>
<root>
<ele attr='foo'>
<child>content</child>
</ele>
</root>
EOX

my $doc = $xml->parse_string( $XML );
ok(defined($doc) && $doc->documentElement->nodeName eq "root", "parse_string");
ok($xml->is($doc->documentElement, "Element"), "is type matches Element");

my $node;

$node = $xml->create_element( "ele", attr => "foo" );
ok(defined($node) && $xml->is( $node, "Element" ) && $node->getAttribute( 'attr' ) eq "foo", "create_element");

$node = $xml->create_text_node( "content" );
ok(defined($node) && $xml->is( $node, "Text" ) && $node->nodeValue eq "content", "create_text_node" );
$node = $xml->create_comment( "content" );
ok(defined($node) && $xml->is( $node, "Comment" ) && $node->nodeValue eq "content", "create_comment" );
$node = $xml->create_document_fragment;
ok(defined($node) && $xml->is( $node, "DocumentFragment" ), "create_document_fragment" );

$xml->dispose( $doc );
