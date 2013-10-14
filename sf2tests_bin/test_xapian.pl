#!/usr/bin/perl -w -I/opt/eprints3/perl_lib

use strict;
use EPrints;

my $repo = EPrints->new->repository( 'xapian' ) or die( 'no repo' );

my $done_any = 0;
my $xapian;
eval {
	my $path = $repo->config( "variables_path" ) . "/xapian";
	$xapian = Search::Xapian::Database->new( $path );
};

my $eprint = $repo->dataset( 'eprint' )->dataobj( $ARGV[0] || 1 ) or die( 'no eprint' );


if( defined $xapian )
{
	my $key = "_id:/id/eprint/" . $eprint->get_id;

	my $enq = $xapian->enquire( Search::Xapian::Query->new(
		Search::Xapian::OP_AND(),
		"_dataset:eprint",
		$key,
	) );

	my $rset = Search::Xapian::RSet->new();
	my( $match ) = $enq->matches(0, 1);

# match == xapian::document
=pod
if( defined $match )
{
	my $terms = $match->termlist_begin;
	for(my $i=0;$i<$match->termlist_count;$i++)
	{
		print $terms->get_termname."\n";
		$terms++;
	}
}

print "\n\n\n\n#######################################\n\n\n\n";
=cut
	if( defined $match )
	{
		$rset->add_document( $match->get_docid );

		$enq = Search::Xapian::Enquire->new( $xapian );

		my $eset = $enq->get_eset( 1_000_000, $rset );
		my @terms = map { $_->get_termname() } $eset->items;

		#print join( "\n", sort @terms );

		my $fieldsmap = {};

		foreach my $term (@terms)
		{
			if( $term =~ /^([^:]*):(.*)$/ )
			{
				my ($field, $term) = ($1,$2);
				if( $field =~ s/^Z// )
				{
					$term .= " (stemmed)";
				}

				push @{$fieldsmap->{$field}}, $term;
			}
			else
			{
				push @{$fieldsmap->{'FULLTEXT'}}, $term;
			}		
		}

		foreach my $field (sort keys %$fieldsmap)
		{
			print "$field: ".join( " ", @{$fieldsmap->{$field}})."\n";
		}

	}
}


=pod



		$enq = Search::Xapian::Enquire->new( $xapian );
		$enq->set_query(
			Search::Xapian::Query->new(
				Search::Xapian::OP_AND(),
				"eprint_status:archive",
				Search::Xapian::Query->new(
					Search::Xapian::OP_AND_NOT(),
					"_dataset:eprint",
					$key,
				),
				Search::Xapian::Query->new(
					Search::Xapian::OP_OR(),
					@terms
				),
		) );

		my $threshold = 40;
		foreach my $rel ( $enq->matches( 0, 5 ) )
		{
			last if( !defined $rel );
			my $score = $rel->get_percent;
			next if( $score < $threshold );

	#		my $eprint = $repo->dataset( 'archive')->dataobj( $rel->get_document->get_data ) or next;
	#		my $li = $repo->make_element( "li" );
	##		$ul->appendChild( $li );
	#		$li->appendChild( $eprint->render_citation_link( "brief" ) );
	#		$done_any++;
		}
=cut
