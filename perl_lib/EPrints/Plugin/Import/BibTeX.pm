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

Name(s) of authors B<creators>

B<FORMAT:> Multiple authors separated by 'and'

=item booktitle

Title of Book (incollection, inproceedings) B<book_title>

=item editor

Name(s) of editors B<editors>

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

=item Year written (unpublished) B<date_issue>

=item Year published (Other Types) B<date_issue>

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

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "BibTeX";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	my $rc = EPrints::Utils::require_if_exists("Text::BibTex");
	unless( $rc ) 
	{
		$self->{visible} = "";
		$self->{error} = "Failed to load required module Text::BibTeX";
	}

	return $self;
}

		

sub input_list
{
	my( $plugin, %opts ) = @_;

	my $bibfile = Text::BibTeX::File->new( $opts{filename} );

	my @ids;

	while ( my $entry = Text::BibTeX::Entry->new( $bibfile ) )
	{
		next unless $entry->parse_ok;

		my $epdata = $plugin->convert_input( $entry );
		next unless( defined $epdata );

		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
		if( defined $dataobj )
		{
			push @ids, $dataobj->get_id;
		}
	}
	
	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
}

sub input_dataobj
{
	my( $plugin, $data ) = @_;

	my $entry = Text::BibTeX::Entry->new;
	$entry->parse_s( $data );
	if( $entry->parse_ok )
	{
		my $epdata = $plugin->convert_input( $entry );
		return $plugin->epdata_to_dataobj( $plugin->{dataset}, $epdata );
	}
	return undef;
}

sub convert_input 
{
	my ( $plugin, $input_data ) = @_;
	my $epdata = ();


	# Entry Type
	my $input_data_type = $input_data->type;
	$epdata->{type} = "article" if $input_data_type eq "article";
	$epdata->{type} = "book" if $input_data_type eq "book";
	$epdata->{type} = "book" if $input_data_type eq "proceedings";
	$epdata->{type} = "book_section" if $input_data_type eq "inbook";
	$epdata->{type} = "book_section" if $input_data_type eq "incollection";
	$epdata->{type} = "conference_item" if $input_data_type eq "inproceedings";
	$epdata->{type} = "conference_item" if $input_data_type eq "conference";
	$epdata->{type} = "other" if $input_data_type eq "misc";
	if( $input_data_type eq "manual" )
	{
		$epdata->{type} = "monograph";
		$epdata->{monograph_type} = "manual";
	}
	if( $input_data_type eq "techreport" )
	{
		$epdata->{type} = "monograph";
		$epdata->{monograph_type} = "technical_report";
	}
	if( $input_data_type eq "mastersthesis" )
	{
		$epdata->{type} = "thesis";
		$epdata->{thesis_type} = "masters";
	}
	if( $input_data_type eq "phdthesis" )
	{
		$epdata->{type} = "thesis";
		$epdata->{thesis_type} = "phd";
	}
	if( $input_data_type eq "unpublished" )
	{
		$epdata->{type} = "other";
		$epdata->{ispublished} = "unpub";
	}
	if( !defined $epdata->{type} )
	{
		$plugin->warning( "Skipping unsupported citation type $input_data_type" );
		return undef;
	}

	# address
	$epdata->{place_of_pub} = $input_data->get( "address" ) if $input_data->exists( "address" );

	# author
	for( $input_data->names( "author" ) )
	{
		my $name;
		$name->{given} = join( " ", $_->part( "first" ) ) if scalar $_->part( "first" );
		$name->{family} = join( " ", $_->part( "von" ) ) if scalar $_->part( "von" );
		$name->{family} .= join( " ", $_->part( "last" ) ) if scalar $_->part( "last" );
		$name->{lineage} = join( " ", $_->part( "jr" ) ) if scalar $_->part( "jr" );
		push @{ $epdata->{creators} }, $name;
	}
	
	# booktitle
	if( $input_data_type eq "incollection" )
	{
		$epdata->{book_title} = $input_data->get( "booktitle" ) if $input_data->exists( "booktitle" );
	}
	elsif( $input_data_type eq "inproceedings" )
	{
		$epdata->{event_title} = $input_data->get( "booktitle" ) if $input_data->exists( "booktitle" );
	}

	# editor
	for( $input_data->names( "editor" ) )
	{
		my $name;
		$name->{given} = join( " ", $_->part( "first" ) ) if scalar $_->part( "first" );
		$name->{family} = join( " ", $_->part( "von" ) ) if scalar $_->part( "von" );
		$name->{family} .= join( " ", $_->part( "last" ) ) if scalar $_->part( "last" );
		$name->{lineage} = join( " ", $_->part( "jr" ) ) if scalar $_->part( "jr" );
		push @{ $epdata->{editors} }, $name;
	}

	# institution
	if( $input_data_type eq "techreport" )
	{
		$epdata->{institution} = $input_data->get( "institution" ) if $input_data->exists( "institution" );
	}

	# journal
	$epdata->{publication} = $input_data->get( "journal" ) if $input_data->exists( "journal" );

	# note	
	$epdata->{note} = $input_data->get( "note" ) if $input_data->exists( "note" );

	# number
	if( $input_data_type eq "techreport" || $input_data_type eq "manual" )
	{
		$epdata->{id_number} = $input_data->get( "number" ) if $input_data->exists( "number" );
	}
	else
	{
		$epdata->{number} = $input_data->get( "number" ) if $input_data->exists( "number" );
	}

	# organization
	if( $input_data_type eq "manual" )
	{
		$epdata->{institution} = $input_data->get( "organization" ) if $input_data->exists( "organization" );
	}

	# pages
	if( $input_data->exists( "pages" ) )
	{
		$epdata->{pagerange} = $input_data->get( "pages" );
		$epdata->{pagerange} =~ s/--/-/;
	}

	# publisher
	$epdata->{publisher} = $input_data->get( "publisher" ) if $input_data->exists( "publisher" );

	# school
	if( $input_data_type eq "phdthesis" || $input_data_type eq "mastersthesis" )
	{
		$epdata->{institution} = $input_data->get( "school" ) if $input_data->exists( "school" );
	}

	# series
	$epdata->{series} = $input_data->get( "series" ) if $input_data->exists( "series" );

	# title
	$epdata->{title} = $input_data->get( "title" ) if $input_data->exists( "title" );

	# type
	if( $input_data_type eq "techreport")
	{
		# TODO: regexps
		#$epdata->{monograph_type} = $input_data->get( "" ) if $input_data->exists( "" );
	}

	# volume
	$epdata->{volume} = $input_data->get( "volume" ) if $input_data->exists( "volume" );

	# year
	if( $input_data->exists( "year" ) )
	{
		my $year = $input_data->get( "year" );
		if( $year =~ /^[0-9]{4}$/ )
		{
			$epdata->{date} = $year;
		}
		else
		{
			$plugin->warning( "Skipping year '$year'" );
		}
	}
	
	# month
	if( $input_data->exists( "month" ) )
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
		my $month = substr( lc( $input_data->get( "month" ) ), 0, 3 );
		if( defined $months{$month} )
		{
			$epdata->{date} .= "-" . $months{$month}; 
		}
		else
		{
			$plugin->warning( "Skipping month '$month'" );
		}
	}

	# abstract
	$epdata->{abstract} = $input_data->get( "abstract" ) if $input_data->exists( "abstract" );
	# keywords
	$epdata->{keywords} = $input_data->get( "keywords" ) if $input_data->exists( "keywords" );
	# url
	$epdata->{official_url} = $input_data->get( "url" ) if $input_data->exists( "url" );

	return $epdata;
}

1;

