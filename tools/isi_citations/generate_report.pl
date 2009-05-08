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

B<generate_report.pl> - ISI Web of Science citations tool

=head1 SYNOPSIS

B<generate_report.pl> I<repoid> [B<options>] [B<eprint ids>]

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

my $dataset = $session->get_repository->get_dataset( "archive" );
for(qw( wos creators_name title ))
{
	if( !$dataset->has_field( $_ ) )
	{
		die "Requires $_ field to be configured\n";
	}
}

my $searchconf = $session->get_repository->get_conf( "wos", "filters" );

my $plugin = $session->plugin( "Export::CitationReport" );

# lets get updating
if( scalar(@idlist) )
{
	my $list = EPrints::List->new(
		session => $session,
		dataset => $dataset,
		ids => \@idlist
		);
	$list->export( "CitationReport", fh => \*STDOUT );
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
		$list->export( "CitationReport", fh => \*STDOUT );
	}
	$list->dispose;
}
else
{
	my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $dataset,
			session => $session );
	my $list = $searchexp->perform_search();
	$list->export( "CitationReport", fh => \*STDOUT );
	$searchexp->dispose();
}

$session->terminate;

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
