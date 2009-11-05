#!/usr/bin/perl

use Test::More tests => 16;

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

my $xhtml = $repo->xhtml;

$node = $xhtml->hidden_field( "foo", "bar" );
ok(defined($node) && $node->getAttribute( "name" ) eq "foo" && $node->getAttribute( "value" ) eq "bar" && $node->getAttribute( "type" ) eq "hidden", "xhtml hidden field");
$node = $xml->create_element( "html" );
$node->appendChild( $xml->create_element( "script", type => 'text/javascript' ) );
$node->appendChild( $xml->create_element( "div" ) );
$node->appendChild( $xml->create_element( "br" ) );
my $str = $xml->to_string( $node );
is($str,'<html><script type="text/javascript"/><div/><br/></html>',"to_string");
$str = $xhtml->to_xhtml( $node );
is($str,'<html xmlns="http://www.w3.org/1999/xhtml"><script type="text/javascript">// <!-- No script --></script><div></div><br /></html>',"to_xhtml");

$xml->dispose( $doc );

$node = $xml->create_element( "foo" );
my $clone = $xml->clone( $node );
$node->setAttribute( foo => "bar" );
ok( !$clone->hasAttribute( "foo" ), "same-doc clones are cloned" );

$node->appendChild( $xml->create_element( "bar" ) );
$clone = $xml->clone( $node );
ok( $clone->hasChildNodes, "deep clone clones child nodes" );

$clone = $xml->clone_node( $node );
ok( !$clone->hasChildNodes, "shallow clone doesn't clone children" );
