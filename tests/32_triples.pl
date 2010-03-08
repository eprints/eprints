#!/usr/bin/perl

use Test::More;

use strict;
use warnings;

use EPrints;
use EPrints::Test;
use EPrints::Test::RepositoryLog;

my $repoid = EPrints::Test::get_test_id();

my $ep = EPrints->new();
if( !defined $ep ) { BAIL_OUT( "Could not obtain the EPrints System object" ); }

my $repo = $ep->repository( $repoid );
if( !defined $repo ) { BAIL_OUT( "Could not obtain the Repository object" ); }

my $dataset = $repo->dataset( "triple" );
if( !defined $dataset ) { BAIL_OUT( "Could not obtain the triple dataset" ); }

plan tests => 4;

{
	my $graph = EPrints::RDFGraph->new( repository=>$repo );
	ok( defined $graph, "Created a graph" );

	ok( $graph->count == 0, "Empty graph has zero size" );

	$graph->add( 
		subject => '<aaa>', 
		predicate => '<bbb>',
		object => "<ccc>" );

	ok( $graph->count == 1, "Graph has size of 1 after adding an item." );

	my $plugin = $repo->plugin( "Export::RDFNT" );
	my $nt = $plugin->output_graph( $graph );

	ok( $nt eq "<aaa> <bbb> <ccc> .\n", "Output graph" );
}

# done
