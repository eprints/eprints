=head1 NAME

EPrints::Plugin::Import::BibTeX

=cut

=pod

=head1 FILE FORMAT

=head2 Supported fields

=over 8

=item Entry Key

B<eprintid>

=item Entry Type. Supported types:

=over 8

=item article B<article>

=item book B<book>

=item conference B<conference_item>

=item inbook B<book_section>

=item incollection B<book_section>

=item inproceedings B<conference_item>

=item manual B<monograph>, B<monograph_type>=manual|documentation

=item mastersthesis B<thesis>, B<thesis_type>=masters

=item misc B<other>

=item phdthesis B<thesis>, B<thesis_type>=phd

=item proceedings B<book>

=item techreport B<monograph>, B<monograph_type>!=manual|documentation

=item unpublished B<status>=unpub

=back

=item address

Address of publisher or institution B<place_of_pub>

=item author 

Name(s) of authors B<creators_name>

B<FORMAT:> Multiple authors separated by 'and'

=item booktitle

Title of Book (incollection, inproceedings) B<book_title>

=item editor

Name(s) of editors B<editors_name>

B<FORMAT:> Multiple authors separated by 'and'

=item institution

Sponsoring institution (techreport) B<institution>

=item journal

Journal name B<publication>

=item month

=over 8

=item Month written (unpublished) B<date>

=item Month published (Other Types) B<date>

=back

B<FORMAT:> three letter abbreviations

=item note

Additional information B<note>

=item number

=over 8

=item ID Number (techreport) B<id_number>

=item Number (Other Types)

=back

=item organization

=over 8

=item Organization (manual) B<institution>

=item Sponsor (inproceedings)

=back

=item pages

Page numbers B<pagerange>

B<FORMAT:> A--B

=item publisher

Publisher B<publisher>

=item school

School (mastersthesis, phdthesis) B<institution>

=item series

Series B<series>

=item title

Title B<title>

=item type

=over 8

=item Type of report (techreport) B<monograph_type>

=item Sectional unit (incollection)

=item Different type of thesis (mastersthesis, phdthesis)

=back

=item volume

Volume B<volume>

=item year

=over 8

=item Year written (unpublished) B<date>

=item Year published (Other Types) B<date>

=back

=back

=head2 Not strictly BibTeX but often used

=over 8

=item abstract B<abstract>

Abstract

=item keywords B<keywords>

Keywords

=item url B<official_url>

URL

=back

Abstract

=head2 Unsupported fields

=over 8

=item annote

Annotation

=item chapter

Chapter number

=item crossref

Database key of entry being cross-referenced

=item edition

Edition of a book

=item howpublished

How something strange was published

=item key

Label

=back

=head1 SEE ALSO

L<Text::BibTeX>, <EPrints::Plugin::Export::BibTeX>

=cut

package EPrints::Plugin::Import::BibTeX;

use BibTeX::Parser;
use Encode;
use strict;

use EPrints::Plugin::Import::TextFile;
our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

our %BIBTEX_MAPPING = qw(
	author creators
	editor editors
);
our %BIBTEX_NAMES = (
#	jan => Text::BibTeX::Yapp::String->new( "January" ),
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "BibTeX";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];
	unshift @{$self->{accept}}, qw( application/x-bibtex );

	return $self;
}

sub input_text_fh
{
	my( $plugin, %opts ) = @_;
	
	my @ids;

	my $fh = $opts{fh};
	binmode( $fh, ":utf8" );
	my $parser = BibTeX::Parser->new( $fh );

	while(my $entry = $parser->next)
	{
		if( !$entry->parse_ok )
		{
			$plugin->warning( "Error parsing: " . $entry->error );
			next;
		}

		my $epdata = $plugin->convert_input( $entry );
		next unless defined $epdata;

		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
		next unless defined $dataobj;

		push @ids, $dataobj->get_id;
	}
	
	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
}

sub input_dataobj
{
	my( $plugin, $data ) = @_;

	my $fh = IO::String->new( $data );

	my $parser = BibTeX::Parser->new( $fh );

	if( my $entry = $parser->next )
	{
		if( !$entry->parse_ok )
		{
			$plugin->warning( "Error parsing: " . $entry->error );
			next;
		}

		my $epdata = $plugin->convert_input( $entry );
		return $plugin->epdata_to_dataobj( $plugin->{dataset}, $epdata );
	}

	return undef;
}

sub decode_tex
{
	my( $plugin, $data ) = @_;

	$data = decode( "latex", $data );
	utf8::encode( $data );
	return $data;
}

sub convert_input 
{
	my ( $plugin, $entry ) = @_;
	my $epdata = ();

	my $type = uc($entry->type);

	return undef if $type eq "STRING";

	# Entry Type
	$epdata->{type} = "article" if $type eq "ARTICLE";
	$epdata->{type} = "book" if $type eq "BOOK";
	$epdata->{type} = "book" if $type eq "PROCEEDINGS";
	$epdata->{type} = "book_section" if $type eq "INBOOK";
	$epdata->{type} = "book_section" if $type eq "INCOLLECTION";
	$epdata->{type} = "conference_item" if $type eq "INPROCEEDINGS";
	$epdata->{type} = "conference_item" if $type eq "CONFERENCE";
	$epdata->{type} = "other" if $type eq "MISC";
	if( $type eq "MANUAL" )
	{
		$epdata->{type} = "monograph";
		$epdata->{monograph_type} = "manual";
	}
	if( $type eq "TECHREPORT" )
	{
		$epdata->{type} = "monograph";
		$epdata->{monograph_type} = "technical_report";
	}
	if( $type eq "MASTERSTHESIS" )
	{
		$epdata->{type} = "thesis";
		$epdata->{thesis_type} = "masters";
	}
	if( $type eq "PHDTHESIS" )
	{
		$epdata->{type} = "thesis";
		$epdata->{thesis_type} = "phd";
	}
	if( $type eq "UNPUBLISHED" )
	{
		$epdata->{type} = "other";
		$epdata->{ispublished} = "unpub";
	}
	if( !defined $epdata->{type} )
	{
		$plugin->warning( $plugin->phrase( "unsupported_cite_type", type => $plugin->{session}->make_text( $type ) ) );
		return undef;
	}

	# address
	$epdata->{place_of_pub} = $entry->field( "address" );

	$epdata->{creators} = [];
	# author
	foreach my $author ($entry->author)
	{
		push @{$epdata->{creators}}, { name => {
			family => join(" ", (defined $author->von ? $author->von : ()), $author->last),
			given => $author->first,
			lineage => $author->jr,
		}};
	}

	$epdata->{editors} = [];
	# editor
	foreach my $editor ($entry->editor)
	{
#		push @{$epdata->{editors}}, { name => {
#			family => join(" ", (defined $editor->von ? $editor->von : ()), $editor->last),
#			given => $editor->first,
#			lineage => $editor->jr,
#		}};
	}

	# booktitle
	if( $type eq "INCOLLECTION" )
	{
		$epdata->{book_title} = $entry->field( "booktitle" );
	}
	elsif( $type eq "INPROCEEDINGS" )
	{
		$epdata->{event_title} = $entry->field( "booktitle" );
	}

	# institution
	if( $type eq "TECHREPORT" )
	{
		$epdata->{institution} = $entry->field( "institution" );
	}

	# journal
	$epdata->{publication} = $entry->field( "journal" );

	# note	
	$epdata->{note} = $entry->field( "note" );

	# number
	if( $type eq "TECHREPORT" || $type eq "MANUAL" )
	{
		$epdata->{id_number} = $entry->field( "number" );
	}
	else
	{
		$epdata->{number} = $entry->field( "number" );
	}

	# organization
	if( $type eq "MANUAL" )
	{
		$epdata->{institution} = $entry->field( "organization" );
	}

	# pages
	if( defined $entry->field( "pages" ) )
	{
		$epdata->{pagerange} = $entry->field( "pages" );
		$epdata->{pagerange} =~ s/--/-/;
	}

	# publisher
	$epdata->{publisher} = $entry->field( "publisher" );

	# school
	if( $type eq "PHDTHESIS" || $type eq "MASTERSTHESIS" )
	{
		$epdata->{institution} = $entry->field( "school" );
	}

	# series
	$epdata->{series} = $entry->field( "series" );

	# title
	$epdata->{title} = $entry->field( "title" );

	# type
	if( $type eq "TECHREPORT")
	{
		# !See note for monograph_type in _decode_bibtex sub below
		# TODO: regexps
		#$epdata->{monograph_type} = $fields->{""} if exists $fields->{""};
	}

	# volume
	$epdata->{volume} = $entry->field( "volume" );

	# year
	if( defined $entry->field( "year" ) )
	{
		my $year = $entry->field( "year" );
		if( $year =~ /^[0-9]{4}$/ )
		{
			$epdata->{date} = $year;
		}
		else
		{
			$plugin->warning( $plugin->phrase( "skip_year", year => $year ) );
		}
	}
	
	# month
	if( defined $entry->field( "month" ) )
	{
		my %months = (
			jan => "01",
			feb => "02",
			mar => "03",
			apr => "04",
			may => "05",
			jun => "06",
			jul => "07",
			aug => "08",
			sep => "09",
			oct => "10",
			nov => "11",
			dec => "12",
		);
		my $month = substr( lc( $entry->field( "month" ) ), 0, 3 );
		if( defined $months{$month} )
		{
			$epdata->{date} .= "-" . $months{$month}; 
		}
		else
		{
			$plugin->warning( $plugin->phrase( "skip_month", month => $month ) );
		}
	}

	# abstract
	$epdata->{abstract} = $entry->field( "abstract" );
	# keywords
	$epdata->{keywords} = $entry->field( "keywords" );

	$epdata = _decode_bibtex( $epdata );

	# url (don't decode TeX)
	$epdata->{official_url} = $entry->field( "url" );
	$epdata->{official_url} =~ s/\\\%/%/g
		if defined $epdata->{official_url};

	return $epdata;
}

sub _decode_bibtex
{
	my( $epdata ) = @_;

	return undef if !defined $epdata;

	if( ref($epdata) eq "HASH" )
	{
		while( my($k,$v) = each(%$epdata) )
		{
			next if( $k eq 'type' ); # always defined in convert_input. Never passed as raw BibTeX
			next if( $k eq 'monograph_type' ); # as above
			$epdata->{$k} = _decode_bibtex( $v );
		}
	}
	elsif( ref($epdata) eq "ARRAY" )
	{
		for(@$epdata)
		{
			$_ = _decode_bibtex($_);
		}
	}
	else
	{
		$epdata = decode('bibtex', $epdata);
	}

	return $epdata;
}

1;


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

