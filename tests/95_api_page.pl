#!/usr/bin/perl

use Test::More tests => 14;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $TEMP_FILE = "/tmp/page_api_test.$$";
if( -e $TEMP_FILE ) { unlink( $TEMP_FILE ); }

my $repoid = EPrints::Test::get_test_id();

my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
if( !defined $ep ) { BAIL_OUT( "Could not obtain the EPrints System object" ); }

my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );
if( !defined $repo ) { BAIL_OUT( "Could not obtain the Repository object" ); }

# Test EPrints::Page::Text
{
	my $test_dom = $repo->xml->create_element( "element" );
	$test_dom->appendChild( $repo->xml->create_text_node( "some text" ) );
	my $title = $repo->xml->create_text_node( "test title" );
	
	my $page = $repo->xhtml->page( { page=>$test_dom, title=>$title } );
	isa_ok( $page, "EPrints::Page::Text", "\$repo->xhtml->page(..)" );

	$page->write_to_file( $TEMP_FILE );
	ok( -e $TEMP_FILE, "EPrints::Page::Text: \$page->write_to_file creates file" );

	open( T, $TEMP_FILE ) || BAIL_OUT( "Failed to read $TEMP_FILE: $!" );
	my $data = join( "", <T> );
	close T;

	ok( $data =~ m/test title/, "EPrints::Page::Text: Output file contains title string" );
	ok( $data =~ m/<element>some text<\/element>/, "EPrints::Page::Text: Output file contains body string" );
	#print STDERR $data;

	unlink( $TEMP_FILE );
}


# Test EPrints::Page::DOM
{
	my $test_dom = $repo->xml->create_element( "element" );
	$test_dom->appendChild( $repo->xml->create_text_node( "some text" ) );
	
	my $page = EPrints::Page::DOM->new( $repo, $test_dom, add_doctype=>0 );
	isa_ok( $page, "EPrints::Page::DOM", "\$repo->xhtml->page(..)" );
	$page->write_to_file( $TEMP_FILE );
	ok( -e $TEMP_FILE, "EPrints::Page::DOM: \$page->write_to_file creates file" );

	open( T, $TEMP_FILE ) || BAIL_OUT( "Failed to read $TEMP_FILE: $!" );
	my $data = join( "", <T> );
	close T;

	ok( $data eq "<element>some text</element>", "EPrints::Page::DOM: Output file contains body string" );

	unlink( $TEMP_FILE );
}

# DOCTYPE
{
	my $test_dom = $repo->xml->create_element( "element" );
	$test_dom->appendChild( $repo->xml->create_text_node( "some text" ) );
	
	my $page = EPrints::Page::DOM->new( $repo, $test_dom );
	isa_ok( $page, "EPrints::Page::DOM", "\$repo->xhtml->page(..)" );
	$page->write_to_file( $TEMP_FILE );
	ok( -e $TEMP_FILE, "EPrints::Page::DOM: \$page->write_to_file creates file" );

	open( T, $TEMP_FILE ) || BAIL_OUT( "Failed to read $TEMP_FILE: $!" );
	my $data = join( "", <T> );
	close T;

	ok( $data =~ m/<!DOCTYPE /, "EPrints::Page::DOM: Starts with <!DOCTYPE" );

	unlink( $TEMP_FILE );
}

