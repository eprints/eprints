#!/usr/bin/perl

use Test::More tests => 18;

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

my $TITLE = "My First Title";

my $epdata = {
	eprint_status => "inbox",
	title => $TITLE,
	userid => 1,
};

my $eprint = $repo->dataset( "eprint" )->create_dataobj( $epdata );
BAIL_OUT( "Failed to create eprint object" ) if !defined $eprint;

ok($eprint->value( "title" ) eq $TITLE, "eprint created with title" );

# subobject

my $FORMAT = "application/pdf";

$epdata = {
	format => $FORMAT,
};

my $doc = $eprint->create_subdataobj( "documents", $epdata );
BAIL_OUT( "Failed to create doc object" ) if !defined $doc;

ok($doc->value( "format" ) eq $FORMAT, "doc created with format" );
ok($doc->parent->id eq $eprint->id, "doc created as subobject of eprint");

my $doc2 = $eprint->create_subdataobj( "documents", $epdata );
BAIL_OUT( "Failed to create doc object" ) if !defined $doc2;

my @REL = (has => 'is', hasVersion => 'isVersionOf' );
$doc2->add_dataobj_relations( $doc, @REL );

$doc->commit;
$doc2->commit;

ok($doc2->has_related_dataobjs( $REL[0] ), "doc2 has relation" );
ok($doc->has_related_dataobjs( $REL[1] ), "doc has relation" );
ok(!$doc2->has_related_dataobjs( 'xxx' ), "doc2 does not have 'xxx' relation" );
ok($doc2->has_dataobj_relations( $doc, $REL[0] ), "doc2 is related to doc");
ok($doc->has_dataobj_relations( $doc2, $REL[1] ), "doc is related to doc2");
my( $doc_copy ) = @{($doc2->related_dataobjs( $REL[0] ))};
ok( defined $doc_copy && $doc_copy->id eq $doc->id, "related_dataobjs found doc" );
( $doc_copy ) = @{($doc2->related_dataobjs( @REL[0,2] ))};
ok( defined $doc_copy && $doc_copy->id eq $doc->id, "related_dataobjs found doc by 2 relations" );
( $doc_copy ) = @{($doc2->related_dataobjs( @REL[0,2], 'xxx' ))};
ok( !defined $doc_copy, "related_dataobjs didn't match 'xxx'" );
my $docs = $doc2->related_dataobjs( @REL[0,2] );
ok( scalar(@$docs) == 1, "related_dataobjs returns one match" );

$eprint->set_value( "creators", [
	{ name => { family => "Smith", given => "John" }, id => "xxx" },
	{ name => { family => "Bloggs", given => "Joe" } },
]);

#my $xml;
#my $wr = EPrints::XML::SAX::Writer->new( Output => \$xml );
#$wr->start_document;
#$eprint->to_sax( Handler => $wr );
#$wr->end_document;

#diag($xml);

my $dom = $eprint->to_xml;

#print STDERR "\n\n\n", $dom->toString( 1 ), "\n\n\n";

$epdata = EPrints::DataObj::EPrint->xml_to_epdata( $repo, $dom );

is( $epdata->{title}, $eprint->value( "title" ), "xml_to_epdata" );

is( eval { $epdata->{creators}->[0]->{name}->{family} }, eval { $eprint->value( "creators" )->[0]->{name}->{family} }, "xml_to_epdata - compound/multiple" );

#print STDERR "\n\n", Data::Dumper::Dumper( $epdata ), "\n\n";

$eprint->delete(); # deletes document sub-object too
