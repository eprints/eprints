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

use Encode;
use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

our %BIBTEX_MAPPING = qw(
	author creators_name
	editor editors_name
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

	my $rc = EPrints::Utils::require_if_exists("Text::BibTeX::Yapp") &&
		EPrints::Utils::require_if_exists("Text::BibTeX::YappName");
	unless( $rc ) 
	{
		$self->{visible} = "";
		$self->{error} = "Failed to load required module Text::BibTeX::Yapp";
	}

	$self->{decode_tex} = 1;
	$rc = EPrints::Utils::require_if_exists("TeX::Encode");
	unless( $rc ) 
	{
		$self->{decode_tex} = 0;
	}

	return $self;
}

sub input_fh
{
	my( $plugin, %opts ) = @_;
	
	my @ids;

	my $parser = Text::BibTeX::Yapp->new;

	my $bibs = $parser->parse_fh( $opts{fh} );
	$bibs = Text::BibTeX::Yapp::expand_names( $bibs, %BIBTEX_NAMES );

	foreach my $entry (@$bibs)
	{
		my( $type, $struct ) = @$entry;
		next if( $type eq "STRING" );
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

sub decode_tex
{
	my( $plugin, $data ) = @_;

	$data = decode( "latex", $data );
	utf8::encode( $data );
	return $data;
}

sub convert_input 
{
	my ( $plugin, $input_data ) = @_;
	my $epdata = ();

	my $name_parser = Text::BibTeX::YappName->new;

	my( $input_data_type, $content ) = @$input_data;
	$input_data_type = lc($input_data_type);

	# Entry Type
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
		$plugin->warning( $plugin->phrase( "unsupported_cite_type", type => $input_data_type ) );
		return undef;
	}

	my( $identifier, $fields ) = @$content;

	# Decode latex
	while(my( $field, $value ) = each %$fields)
	{
		next if $field eq 'author' or $field eq 'editor';
		if( $plugin->{decode_tex} and $field ne 'url' and $field ne 'uri' )
		{
			for(@$value)
			{
				$_ = $plugin->decode_tex( $_ );
			}
		}
		$fields->{$field} = join ' ', map { "$_" } @$value;
	}

	# address
	$epdata->{place_of_pub} = $fields->{"address"} if exists $fields->{"address"};

	# author/editor
	foreach my $field (qw( author editor ))
	{
		next unless exists $fields->{$field} and length $fields->{$field}->[0];
		my $names;
		eval { $names = $name_parser->parse_string( $fields->{$field}->[0] ) };
		if( $@ )
		{
			$plugin->warning("Error parsing $field names: ".$fields->{$field}->[0]);
			next;
		}
		foreach my $name (@$names)
		{
			my $a_name;
			$a_name->{given} = $name->first if $name->first;
			$a_name->{family} = $name->von . " " if $name->von;
			$a_name->{family} .= $name->last if $name->last;
			$a_name->{lineage} = $name->jr if $name->jr;
			if( $plugin->{decode_tex} )
			{
				for(values(%$a_name))
				{
					$_ = $plugin->decode_tex( $_ );
				}
			}
			push @{$epdata->{$BIBTEX_MAPPING{$field}}}, $a_name;
		}
	}
	
	# booktitle
	if( $input_data_type eq "incollection" )
	{
		$epdata->{book_title} = $fields->{"booktitle"} if exists $fields->{"booktitle"};
	}
	elsif( $input_data_type eq "inproceedings" )
	{
		$epdata->{event_title} = $fields->{"booktitle"} if exists $fields->{"booktitle"};
	}

	# institution
	if( $input_data_type eq "techreport" )
	{
		$epdata->{institution} = $fields->{"institution"} if exists $fields->{"institution"};
	}

	# journal
	$epdata->{publication} = $fields->{"journal"} if exists $fields->{"journal"};

	# note	
	$epdata->{note} = $fields->{"note"} if exists $fields->{"note"};

	# number
	if( $input_data_type eq "techreport" || $input_data_type eq "manual" )
	{
		$epdata->{id_number} = $fields->{"number"} if exists $fields->{"number"};
	}
	else
	{
		$epdata->{number} = $fields->{"number"} if exists $fields->{"number"};
	}

	# organization
	if( $input_data_type eq "manual" )
	{
		$epdata->{institution} = $fields->{"organization"} if exists $fields->{"organization"};
	}

	# pages
	if( exists $fields->{"pages"} )
	{
		$epdata->{pagerange} = $fields->{"pages"};
		$epdata->{pagerange} =~ s/--/-/;
	}

	# publisher
	$epdata->{publisher} = $fields->{"publisher"} if exists $fields->{"publisher"};

	# school
	if( $input_data_type eq "phdthesis" || $input_data_type eq "mastersthesis" )
	{
		$epdata->{institution} = $fields->{"school"} if exists $fields->{"school"};
	}

	# series
	$epdata->{series} = $fields->{"series"} if exists $fields->{"series"};

	# title
	$epdata->{title} = $fields->{"title"} if exists $fields->{"title"};

	# type
	if( $input_data_type eq "techreport")
	{
		# TODO: regexps
		#$epdata->{monograph_type} = $fields->{""} if exists $fields->{""};
	}

	# volume
	$epdata->{volume} = $fields->{"volume"} if exists $fields->{"volume"};

	# year
	if( exists $fields->{"year"} )
	{
		my $year = $fields->{"year"};
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
	if( exists $fields->{"month"} )
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
		my $month = substr( lc( $fields->{"month"} ), 0, 3 );
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
	$epdata->{abstract} = $fields->{"abstract"} if exists $fields->{"abstract"};
	# keywords
	$epdata->{keywords} = $fields->{"keywords"} if exists $fields->{"keywords"};
	# url
	$epdata->{official_url} = $fields->{"url"} if exists $fields->{"url"};

	return $epdata;
}

1;

