#!/usr/bin/perl -I/opt/eprints3/perl_lib

# Copyright 2009 University of Southampton.
# 
# This file is part of EPrints.
#
# EPrints is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
# 
# EPrints is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with EPrints.  If not, see <http://www.gnu.org/licenses/>.

=pod

=head1 NAME

B<isi_citations.pl> - ISI Web of Science citations tool

=head1 SYNOPSIS

B<isi_citations.pl> I<repoid> [B<options>] [B<eprint ids>]

=head1 OPTIONS

=over 8

=item B<--verbose>

Be more verbose.

=back

=cut

use strict;
use warnings;

use EPrints;
use Getopt::Long;
use Pod::Usage;

use SOAP::Lite
#	+trace => 'all'
;
use Data::Dumper;

our $ISI_ENDPOINT = "http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve";
our $ISI_NS = "http://esti.isinet.com/soap/search";

my $opt_help = 0;
my $opt_verbose = 0;
my $opt_quiet = 0;

GetOptions(
	"help|?" => \$opt_help,
	"verbose+" => \$opt_verbose,
	"quiet" => \$opt_quiet,
) or pod2usage( 2 );

pod2usage( 1 ) if $opt_help;

my $noise = $opt_quiet ? 0 : $opt_verbose+1;

my( $repoid, @idlist ) = @ARGV;
pod2usage( 2 ) unless defined $repoid;

my $session = EPrints::Session->new( 1, $repoid, $noise );
exit( 1 ) unless defined $session;

my $dataset = $session->dataset( "archive" );
for(qw( wos creators_name title ))
{
	if( !$dataset->has_field( $_ ) )
	{
		die "Requires $_ field to be configured\n";
	}
}

my $soap = SOAP::Lite->new();
$soap->proxy( $ISI_ENDPOINT,
	agent => "eprints.org/".$session->config("version_id"),
	from => $session->config("adminemail"),
	);

# don't include namespace in actions
$soap->on_action(sub { qq("$_[1]") });
#$soap->on_fault(sub { print STDERR "Error: $_[1]" });

# don't guess auto types
$soap->autotype(0);
# send pretty-printed XML
$soap->readable(1);
# put everything in the ISI namespace
$soap->default_ns($ISI_NS);

my $searchconf = $session->config( "wos", "filters" );

my $query_builder = $session->config( "wos", "build_query" );

# lets get updating
if( scalar(@idlist) )
{
	my $list = EPrints::List->new(
		session => $session,
		dataset => $dataset,
		ids => \@idlist
		);
	$list->map(\&update_eprint);
	$list->dispose;
}
elsif( defined $searchconf )
{
	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $dataset,
		allow_blank => 1,
		filters => $searchconf
		);
	my $list = $searchexp->perform_search;
	if( $list->count == 0 )
	{
		print STDERR "The configured filters didn't match anything.\n"
			if $noise;
	}
	else
	{
		$list->map(\&update_eprint);
	}
	$list->dispose;
}
else
{
	$dataset->map($session, \&update_eprint);
}

FINISH:

$session->terminate;

sub update_eprint
{
	my( $session, $dataset, $eprint ) = @_;

	return unless defined $eprint;

	# e.g. "AU = (Brody) and TI = (Earlier web usage statistics as predictors of later citation impact) and PY = (2006)";
	my $query = &$query_builder( $eprint );

	print STDERR $eprint->get_id.": searching for '$query'\n"
		if $noise > 1;

	my $databaseID = "WOS";
#	$databaseID = "ISIP";

	# sleep a bit
	sleep(int(rand(3)));

	# make a SOAP query to ISI
	# ISI requires every argument be included, even if it's blank
	my $som = $soap->call("searchRetrieve",
			SOAP::Data->name("databaseID")->value($databaseID),
			SOAP::Data->name("query")->value($query),
			# depth is the time period
			SOAP::Data->name("depth")->value(""),
			# editions is SCI, SSCI etc.
			SOAP::Data->name("editions")->value(""),
			# sort by descending relevance
			SOAP::Data->name("sort")->value("Relevance"),
			# start returning records at 1
			SOAP::Data->name("firstRec")->value("1"),
			# return up to 10 records
			SOAP::Data->name("numRecs")->value("10"),
			# NOTE: if no fields are specified all are returned, times_cited is
			# an option
			SOAP::Data->name("fields")->value("times_cited"),
		);
	# something went wrong
	if( $som->fault )
	{
		print STDERR "\tError from SOAP endpoint: ".$som->fault->{ faultstring }."\n";
		return;
	}

	my $result = $som->result;
#print Data::Dumper::Dumper($result), "\n";

	my $total = $result->{"recordsFound"};
	my @records;

	if( $total == 0 )
	{
		print STDERR "\tNo matches found, ignoring.\n"
			if $noise > 1;
		return;
	}
	if( $total > 1 )
	{
		print STDERR "\tMatched more than once, ignoring.\n"
			if $noise > 1;
		return;
	}

	# the actual records are stored as a serialised XML string
	my $doc = EPrints::XML::parse_xml_string( $result->{records} );
	foreach my $node ($doc->documentElement->childNodes)
	{
		next unless EPrints::XML::is_dom( $node, "Element" );
		my $record = {
			eprintid => $eprint->get_id,
			timescited => $node->getAttribute( "timescited" ),
		};
		my( $item ) = $node->getElementsByTagName( "item" );
		$record->{"year"} = $item->getAttribute( "coverdate" );
		$record->{"year"} =~ s/^(\d{4}).+/$1/; # yyyymm
		my( $ut ) = $item->getElementsByTagName( "ut" );
		$record->{"primarykey"} = $ut->firstChild;
		my( $item_title ) = $item->getElementsByTagName( "item_title" );
		$record->{"title"} = $item_title->firstChild;
		push @records, $record;
	}

	# do some work
#	print "Got records: ".Data::Dumper::Dumper( @records );

	my $record = $records[0];

	my $wos = {
		cluster => $record->{"primarykey"},
		impact => $record->{"timescited"},
		datestamp => EPrints::Time::get_iso_timestamp()
	};
	$eprint->set_value( "wos", $wos );
	$eprint->commit;

	print STDERR "\t$record->{timescited} citations\n"
		if $noise > 1;

#	goto FINISH;
}

__DATA__
abbrev_iso
abbrev_11
abbrev_22
abbrev_29
abstract
article_no
article_nos
author
authors
bib_date
bib_id
bib_issue
bib_misc
bib_pagecount
bib_pages
bib_vol
bk_binding
bk_ordering
bk_prepay
bk_price
bk_publisher
book_authors
book_corpauthor
book_chapters
book_desc
book_editor
book_editors
book_note
book_notes
book_series
book_subtitle
bs_subtitle
bs_title
categories
category
conference
conferences
conf_city
conf_date
conf_end
conf_host
conf_id
conf_location
conf_start
conf_title
conf_sponsor
conf_sponsors
conf_state
copyright
corp_authors
doctype
editions
editor
email
emails
email_addr
heading
headings
ids
io
isbn
issn
issue_ed
issue_title
item_enhancedtitle
item_title
i_cid
i_ckey
keyword
keywords
keywords_plus
lang
languages
load
meeting_abstract
name
p
primaryauthor
primarylang
publisher
pubtype
pub_address
pub_city
pub_url
ref
refs
reprint
research_addrs
research
reviewed_work
rp_address
rp_author
rp_city
rp_country
rp_organization
rp_state
rp_street
rp_suborganization
rp_suborganizations
rp_zip
rp_zips
rs_address
rs_city
rs_country
rs_organization
rs_state
rs_street
rs_suborganization
rs_suborganizations
rs_zip
rs_zips
rw_author
rw_authors
rw_lang
rw_langs
rw_year
source_abbrev
source_editors
source_series
source_title
sq
subject
subjects
ui
unit
units
ut
