#!/usr/bin/perl

use Test::More tests => 39;

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

my $ele = $doc->documentElement->firstChild->nextSibling;
ok($ele->nodeName eq "ele", "child node named correctly");
ok($ele->hasAttribute("attr"), "child node has attribute attr");
ok($ele->getAttribute("attr") eq "foo", "attribute has value foo");

my $content = $ele->firstChild->nextSibling->firstChild->nodeValue;

ok($content eq "content", "text node at the bottom of the tree is created correctly");

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

my $url = "http://foo.bar/save/";
my $method = "POST";
my $form = $xhtml->form($method, $url);

ok( defined($form) && $form->nodeName eq "form",  "\$xhtml->form produces a form element" );

ok( $form->getAttribute("method") eq "post", "form has its method attribute set correctly" );

ok( $form->getAttribute("action") eq $url, "form has its action attribute set correctly" );

$node = $xhtml->hidden_field( "foo", "bar" );
ok(defined($node) && $node->getAttribute( "name" ) eq "foo" && $node->getAttribute( "value" ) eq "bar" && $node->getAttribute( "type" ) eq "hidden", "xhtml hidden field");

my $name="foo";
my $value="bar";
my $input = $xhtml->input_field($name, $value);

ok( defined($input) && $input->nodeName eq "input", "\$xhtml input_field returns an input element" );

ok( $input->getAttribute("name") eq $name, "input element has its name attribute set correctly" );

ok( $input->getAttribute("value") eq $value, "input element has its value attribute set correctly" );

my $type = "radio";
my %opts = ( "type"=>"radio", "noenter"=>1 );
my $input_with_opts = $xhtml->input_field( $name, $value, %opts );


ok( defined($input_with_opts) && $input_with_opts->nodeName eq "input", "\$xhtml input_field returns an input element" );

ok( $input_with_opts->getAttribute("name") eq $name, "input element has its name attribute set correctly" );

ok( $input_with_opts->getAttribute("value") eq $value, "input element has its value attribute set correctly" );

ok( $input_with_opts->getAttribute("type") eq $type, "input has its type set correctly" );

ok( $input_with_opts->hasAttribute("onkeypress"), "input has an onkeypress attibute which hopefully stops people using the enter key in the input" );

$value = "Running a big test with lots of words in the \n box and checking that everything still renders out correctly";

my $textarea = $xhtml->text_area_field($name, $value);

ok( defined($textarea) && $textarea->nodeName eq "textarea", "XHTML text_area_field returns a textarea" );

ok( $textarea->getAttribute("name") eq $name, "text has the name attribute set correctly" );

my $text_area_contents = $textarea->firstChild->toString;

ok( $text_area_contents eq $value, "textarea contains a text node with the correct value" );

my $data_element = $xhtml->data_element($name, $value, "foo" => "bar");

ok($data_element->nodeName eq $name, "data_element has correct name");
ok($data_element->firstChild->toString eq $value, "data_element has correct value");
ok($data_element->hasAttribute("foo"), "data_element has attribute foo");
ok($data_element->getAttribute("foo") eq "bar", "data_element attribute value bar");

$node = eval { $xhtml->tree([ # dl
		[ "fruit", # dt
			[ "apple", "orange", ], # ul {li, li}
		],
		[ "vegetable", # dt
			[ "potato", "carrot", ], # ul {li, li}
			],
		[ "animal", # dt
			[ # dl
				[ "cat", # dt
					[ "lion", "leopard", ], # ul {li, li}
				],
			],
		],
		"soup", # ul {li}
		$xml->create_element( "p" ), # <p> is appended
	],
	prefix => "mytree",
) };

ok( defined $node && $node->toString =~ /leopard/, "XHTML::tree" );

#sub action_button
#sub action_icon
#sub data_element
#sub to_text_dump
#sub page
#sub tabs
#sub tree2
#sub action_list
#sub action_definition_list
#sub doc_type

