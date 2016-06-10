#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use SOAP::Lite
	+trace => "all"
;
use XML::LibXML;
use Data::Dumper;

our $ISI_ENDPOINT = "http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve";
our $ISI_NS = "http://esti.isinet.com/soap/search";

my $soap = SOAP::Lite->new();
$soap->proxy( $ISI_ENDPOINT );

# don't include namespace in actions
$soap->on_action(sub { qq("$_[1]") });
#$soap->on_fault(sub { print STDERR "Error: $_[1]" });

# don't guess auto types
$soap->autotype(0);
# send pretty-printed XML
$soap->readable(1);
# put everything in the ISI namespace
$soap->default_ns($ISI_NS);

my( $query ) = @ARGV;

die <<EOH unless $query;
Usage: perl $0 <query>
Where:
	query - an ISI query string
	
AU = (Brody) and TI = (Earlier web usage statistics as predictors of later citation impact) and PY = (2006)

EOH

#	my $query = "AU = (Brody) and TI = (Earlier web usage statistics as predictors of later citation impact) and PY = (2006)";
	my $databaseID = "WOS";
#	$databaseID = "ISIP";
#	$query = "AU = () and PY = (2006)";

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
	die $som->fault->{ faultstring } if $som->fault;

	my $result = $som->result;
#print Data::Dumper::Dumper($result), "\n";

	my $total = $result->{"recordsFound"};
	my @records;

	print "Found $total matches\n";

	# the actual records are stored as a serialised XML string
	my $parser = XML::LibXML->new;
	my $doc = $parser->parse_string( $result->{records} );
	foreach my $node ($doc->documentElement->childNodes)
	{
		next unless $node->isa( "XML::LibXML::Element" );
		my $record = {
			timescited => $node->getAttribute( "timescited" ),
		};
		my( $item ) = $node->getElementsByTagName( "item" );
		$record->{"year"} = $item->getAttribute( "coverdate" );
		$record->{"year"} =~ s/^(\d{4}).+/$1/; # yyyymm
		my( $ut ) = $item->getElementsByTagName( "ut" );
		$record->{"primarykey"} = $ut->textContent;
		my( $item_title ) = $item->getElementsByTagName( "item_title" );
		$record->{"title"} = $item_title->textContent;
		push @records, $record;
	}

	# do some work
	print "Got records: ".Data::Dumper::Dumper( @records );

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
