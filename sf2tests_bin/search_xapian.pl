#!/usr/bin/perl -w -I/opt/eprints3/perl_lib

use strict;
use EPrints;

my $repo = EPrints->new->repository( 'xapian' ) or die( 'no repo' );

my $xapian;
eval {
	my $path = $repo->config( "variables_path" ) . "/xapian";
	$xapian = Search::Xapian::Database->new( $path );
};

die( "$@" ) if $@;

my $plugin = $repo->plugin( 'Search::Xapian' ) or die( 'no plugin' );
my $stemmer = $plugin->stemmer;
my $stopper = $plugin->stopper;

my $qp = Search::Xapian::QueryParser->new( $xapian );
$qp->set_stemmer( $stemmer );
$qp->set_stopper( $stopper );
$qp->set_stemming_strategy( Search::Xapian::STEM_SOME() );
$qp->set_default_op( Search::Xapian::OP_AND() );


# if a facet is selected then the facet's field must be added to the list of prefix below:

my %search_fields = map { $_ => undef } @{
	$repo->config( 'search', 'simple', 'search_fields')->[0]->{meta_fields} || [] };

for( keys %search_fields )
{
	$qp->add_prefix( $_, "$_:" );
}

# facets as args?
my @facet_filters;
for(@ARGV)
{
	my( $qfacet_field, $qfacet_value ) = split( ":", $_ );
	next if( !defined $qfacet_field || !defined $qfacet_value );

	# TODO
	# technically qfacet_field should be checked as to whether it's a valid field to facet with!
	# otherwise we're allowing any field to be searched:
	#
	# also single fields are not allowed to be specified twice as facet (because an item couldn't be X and Y at the same time)
	# perhaps facets should only specified once anyways (so you can never facet X and Y for the same field)
	#

	if( !exists $search_fields{$qfacet_field} )
	{
		$search_fields{$qfacet_field} = undef;
		$qp->add_prefix( $qfacet_field, "$qfacet_field:" );
	}
	push @facet_filters, $_;
}

my $extra_cond = join( " AND ", @facet_filters );

my $query = Search::Xapian::Query->new( "_dataset:eprint" );

# the actual query
my $q = "yellow OR green OR habits";
$q = "($q) AND $extra_cond" if(length $extra_cond);

$query = Search::Xapian::Query->new(
	Search::Xapian::OP_AND(),
	$query,
	$qp->parse_query( $q,
		Search::Xapian::FLAG_PHRASE() |
		Search::Xapian::FLAG_BOOLEAN() |
		Search::Xapian::FLAG_LOVEHATE() |
		Search::Xapian::FLAG_WILDCARD()
	)
);

my $facet_conf = $repo->config('datasets', 'eprint', 'facets');

my $facets_idx = {};

foreach my $fconf (@{$facet_conf||[]} )
{
	# ooch
	my $max_slots = 5;

	foreach my $i ( 0..$max_slots )
	{
		my $key = "eprint._facet.".$fconf->{name}.".$i";
		my $idx = $xapian->get_metadata( $key );
		next if( !length $idx );
#		print "Found facet $key ($idx)\n";

		push @{$facets_idx->{$fconf->{name}}}, $idx;
	}
}

my $facets = {};
my $decider = sub {

	my( $doc ) = @_;

	foreach my $facet ( %{$facets_idx||{}} )
	{
		foreach my $slot ( @{ $facets_idx->{$facet} || [] } )
		{
			my $value = $doc->get_value( $slot );
			next if( !length $value );			
			$facets->{$facet}->{$value}++;
		}
	}

	return 1;
};

my $enq = $xapian->enquire( $query );

my $mset = $enq->get_mset( 0, $xapian->get_doccount, $decider );

foreach my $facet ( keys %{$facets||{}} )
{
	# TODO if only one distinct value -> not a facet (filtering wouldn't actually remove any items)
	next if( scalar( keys %{$facets->{$facet}||{}} ) < 2 );

	foreach my $value ( keys %{$facets->{$facet}||{}} )
	{
		my $occ = $facets->{$facet}->{$value};
		print "Facet $facet -> $value ($occ)\n";
	}
}

printf "\nRunning query '%s'\n\n", $enq->get_query()->get_description();

# return all results
my @matches = $enq->matches(0, $mset->get_matches_estimated);

print scalar(@matches) . " results found\n";

foreach my $match ( @matches ) 
{
	my $doc = $match->get_document();

	my $eprint = $repo->dataset( 'archive' )->dataobj( $doc->get_data );
	my $desc = defined $eprint ? $eprint->internal_uri. " (".$eprint->value( 'title' ).")" : 'unknown item';

	printf "ID %d %d%% [ %s ]\n", $match->get_docid(), $match->get_percent(), $desc;
}
print "\n\n\n";

exit;

