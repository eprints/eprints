=head1 NAME

EPrints::Plugin::Import::EndNote

=cut


=pod

=head1 FILE FORMAT

From L<Text::Refer>:

The bibliographic database is a text file consisting of records separated by one or more blank lines. Within each record fields start with a % at the beginning of a line. Each field has a one character name that immediately follows the %. The name of the field should be followed by exactly one space, and then by the contents of the field.

=head2 Supported Fields

EPrints mappings shown in B<bold>,

=over 8

=item 0 (the digit zero) Citation Type. Supported types:

=over 8

=item Book B<book>

=item Book Section B<book_section>

=item Conference Paper B<conference_item>

=item Conference Proceedings B<book>

=item Edited Book B<book>

=item Electronic Article B<article>

=item Electronic Book B<book>

=item Journal Article B<article>

=item Magazine Article B<article>

=item Newspaper Article B<article>

=item Patent B<patent>

=item Report B<monograph>

=item Thesis B<thesis>

=back

B<NOTE:> For the Conference Paper type, the C<pres_type> field is set to C<paper>.

=item D 

Year B<date>

=item J 

Journal (Journal Article only) B<publication>

=item K 

Keywords B<keywords>

=item T 

Title B<title>

=item U 

URL B<official_url>

=item X 

Abstract B<abstract>

=item Z 

Notes B<note>

B<NOTE:> Use of Z field for Image data not supported

=item 9

=over 8

=item Type of Article (Journal Article, Newspaper Article, Magazine Article)

=item Thesis Type (Thesis) B<thesis_type>

=item Report Type (Report) B<monograph_type>

=item Patent Type (Patent)

=item Type of Medium (Electronic Book)

=back

B<NOTE:> You may need to define your own regexps to munge this free text field into the values accepted by B<thesis_type> and B<monograph_type>.

=item A

=over 8

=item Inventor (Patent) B<creators_name>

=item Editor (Edited Book) B<editors_name>

=item Reporter (Newspaper Article) B<creators_name>

=item Author (Other Types) B<creators_name>

=back

B<FORMAT:> Lastname, Firstname, Lineage

=item B

=over 8

=item Series Title (Edited Book, Book, Report) B<series>

=item Academic Department (Thesis) B<department>

=item Newspaper (Newspaper Article) B<publication>

=item Magazine (Magazine Article) B<publication>

=item Book Title (Book Section) B<book_title>

=item Conference Name (Conference Paper, Conference Proceedings) B<event_title>

=item Periodical Title (Electronic Article) B<publication>

=item Secondary Title (Electronic Book)

=back

=item C

=over 8

=item Country (Patent)

=item Conference Location (Conference Paper, Conference Proceedings) B<event_location>

=item City (Other Types) B<place_of_pub>

=back

=item E

=over 8

=item Series Editor (Report, Book, Edited Book)

=item Issuing Organisation (Patent) B<institution>

=item Editor (Other Types) B<editors_name>

=back

B<FORMAT:> Lastname, Firstname, Lineage

=item I

=over 8

=item University (Thesis) B<institution>

=item Institution (Report) B<institution>

=item Assignee (Patent)

=item Publisher (Other Types) B<publisher>

=back

=item N

=over 8

=item Application Number (Patent)

=item Issue (Other Types) B<number>

=back

=item P

=over 8

=item Number of Pages (Book, Thesis, Edited Book) B<pages>

=item Pages (Other Types) B<pagerange>

=back

=item S 

=over 8

=item Series Title (Book Section, Conference Proceedings) B<series>

=item International Author (Patent)

=back

=item V

=over 8

=item Degree (Thesis)

=item Patent Version Number (Patent)

=item Volume (Other Types) B<volume>

=back

=item @

=over 8

=item ISSN (Journal Article, Newspaper Article, Magazine Article, Electronic Article) B<issn>

=item ISBN (Book, Book Section, Edited Book, Conference Proceedings, Electronic Book) B<isbn>

=item Report Number (Report) B<id_number>

=item Patent Number (Patent) B<id_number>

=back

=back

=head2 Unsupported Fields

=over 8

=item 2 

Issue Date (Patent)

=item 3 

Designated States (Patent)

=item 4 

Attorney/Agent (Patent)

=item 6 

Number of Volumes

=item 7 

International Patent Classification (Patent), Edition (Other Types)

=item 8

Date Accessed (Electronic Article, Electronic Book), Date (Other Types)

=item F

Label

=item G

Language

=item H

Translated Author

=item L

Call Number

=item M

Accession Number

=item O

Alternate Journal (Journal Article), Alternate Magazine (Magazine Article), Alternate Title (Other Types)

=item Q

Translated Title

=item R

Electronic Resource Number

=item W

Database Provider

=item Y

Advisor (Thesis), Series Editor (Book Section, Conference Proceedings), International Title (Patent)

=item [

Access Date

=item +

Inventor Address (Patent), Author Address

=item ^

Caption

=item =

Last Modified Date

=item $

Legal Status (Patent)

=item >

Link to PDF

=item ~

Name of Database

=item (

Priority Number (Patent), Original Publication (Other Types)

=item )

Reprint Edition

=item <

Research Notes

=item *

Reviewed Item

=item &

Section (Newspaper Article), International Patent Number (Patent)

=item !

Short Title

=item #

References (Patent)

=item ?

Sponsor (Conference Proceedings), Translator (Other Types)

=back

=head1 ENDNOTE 8 SUPPORT

Endnote 8 appears to add Byte Order Marks to the beginning of its
exported files. To import these files you need to install the
L<File::BOM> module from CPAN. If this module is detected EPrints
will automatically handle BOM (you will need to restart your web
server if importing via CGI).

=head1 CRLF (WINDOWS) SUPPORT

EPrints will correctly handle CRLF formatted text files, if you
are using Perl 5.8 or later. Otherwise use the dos2unix tool to
convert your files.

=head1 SEE ALSO

L<Text::Refer>, L<XML::Writer>, L<EPrints::Plugin::Export::EndNote>

=cut

package EPrints::Plugin::Import::EndNote;

use EPrints::Plugin::Import::TextFile;
use strict;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "EndNote";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	my $rc = EPrints::Utils::require_if_exists("Text::Refer");
	unless( $rc ) 
	{
		$self->{visible} = "";
		$self->{error} = "Failed to load required module Text::Refer";
	}

	return $self;
}

sub input_text_fh
{
	my( $plugin, %opts ) = @_;

	my $parser = Text::Refer::Parser->new( LeadWhite => 'KEEP', NewLine => "TOSPACE", ForgiveEOF => 1);

	my @ids;
	
	my $fh = $opts{fh};

	local $SIG{__WARN__} = sub { $plugin->warning( $_[0] ) };

	while (my $input_data = $parser->input( $fh ) ) 
	{
		my $epdata = $plugin->convert_input( $input_data );

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

sub convert_input 
{
	my ( $plugin, $input_data ) = @_;
	my $epdata = {};

	# 0 Citation type
	my $input_data_type = $input_data->get( "0" ) || "";
	$epdata->{type} = "article" if $input_data_type =~ /Article/;
	$epdata->{type} = "book" if $input_data_type =~ /Book/ || $input_data_type eq "Conference Proceedings";
	$epdata->{type} = "book_section" if $input_data_type eq "Book Section";
	if( $input_data_type eq "Conference Paper" )
	{
		$epdata->{type} = "conference_item";
		$epdata->{pres_type} = "paper";
	}
	$epdata->{type} = "monograph" if $input_data_type eq "Report";
	$epdata->{type} = "patent" if $input_data_type eq "Patent";
	$epdata->{type} = "thesis" if $input_data_type eq "Thesis";
	if( !defined $epdata->{type} ) 
	{
		$plugin->warning( $plugin->phrase( "unsupported_cite_type", type => $input_data_type ) );
		return undef;
	}

	# D Year
	$epdata->{date} = $input_data->date if defined $input_data->date;
	# J Journal
	$epdata->{publication} = $input_data->journal if defined $input_data->journal && $input_data_type eq "Journal Article";
	# K Keywords
	$epdata->{keywords} = $input_data->keywords if defined $input_data->keywords;
	# T Title
	$epdata->{title} = $input_data->title if defined $input_data->title;
	# U URL
	$epdata->{official_url} = $input_data->get( "U" ) if defined $input_data->get( "U" );
	# X Abstract
	$epdata->{abstract} = $input_data->abstract if defined $input_data->abstract;
	# Z Notes
	$epdata->{note} = $input_data->get( "Z" ) if defined $input_data->get( "Z" );

	# 9 Thesis Type, Report Type
	if( defined $input_data->get( "9" ) )
	{

		my $type = $input_data->get( "9" );
		if( $input_data_type eq "Thesis" )
		{
			$epdata->{thesis_type} = "phd" if $type =~ /ph\.?d/i;
			$epdata->{thesis_type} = "masters" if $type =~ /master/i;
		}
		elsif( $input_data_type eq "Report" )
		{
			$epdata->{monograph_type} = "technical_report" if $type =~ /tech/i;
			$epdata->{monograph_type} = "project_report" if $type =~ /proj/i;
			$epdata->{monograph_type} = "documentation" if $type =~ /doc/i;
			$epdata->{monograph_type} = "manual" if $type =~ /manual/i;
		}
	}


	for ( $input_data->author )
        {
                # catch: Lastname, Firstname format
                if( /^(.*?),(.*?)(,(.*?))?$/ )
                {
                        if( $input_data_type eq "Edited Book" )
                        {
                                push @{$epdata->{editors_name}}, { family => $1, given => $2, lineage => $4 };
                        }
                        else
                        {
                                push @{$epdata->{creators_name}}, { family => $1, given => $2, lineage => $4 };
                        }
                }
                # catch :  Anthony W. J. Bicknell  --  surname is the part after the last whitespace, and the first name is the front part
                elsif(/^(.*?) (\w{2,})$/)
                {
			if( $input_data_type eq "Edited Book" )
			{
	                        push @{$epdata->{editors_name}}, { family => $2, given => $1 };
			}
			else
			{
				push @{$epdata->{creators_name}}, { family => $2, given => $1 };
			}
                }
                # catch : Bicknell A W. J.  or Newton J  --   surname is the first part. 
                elsif(/^(\w{2,}) (.*)$/)
                {
			if( $input_data_type eq "Edited Book" )
			{
				push @{$epdata->{editors_name}}, { family => $1, given => $2 };
			}
			else
			{
				push @{$epdata->{creators_name}}, { family => $1, given => $2 };
			}
                }
                 else {
                        $plugin->warning( $plugin->phrase( "bad_author", author => $_ ) );
                }
        }




	# B Conference Name, Department (Thesis), Newspaper, Magazine, Series (Book, Edited Book, Report), Book Title (Book Section)
	if( defined $input_data->book )
	{
		if( $input_data_type eq "Conference Paper" || $input_data_type eq "Conference Proceedings" )
		{
			$epdata->{event_title} = $input_data->book;
		}
		elsif( $input_data_type eq "Thesis" )
		{
			$epdata->{department} = $input_data->book;
		}
		elsif( $input_data_type eq "Newspaper Article" || $input_data_type eq "Magazine Article" || $input_data_type eq "Electronic Article" )
		{
			$epdata->{publication} = $input_data->book;
		}
		elsif( $input_data_type eq "Book" || $input_data_type eq "Edited Book" || $input_data_type eq "Report" )
		{
			$epdata->{series} = $input_data->book;
		}
		elsif( $input_data_type eq "Book Section" ) 
		{
			$epdata->{book_title} = $input_data->book;
		}
	}

	# C Conference Location, Country (Patent), City (Other Types)
	if( defined $input_data->city )
	{
		if( $input_data_type eq "Conference Paper" || $input_data_type eq "Conference Proceedings" )
		{
			$epdata->{event_location} = $input_data->city;
		}
		elsif( $input_data_type eq "Patent" )
		{
			# Unsupported
		}
		else
		{
			$epdata->{place_of_pub} = $input_data->city;
		}
	}

	# E Issuing Organisation (Patent), Series Editor (Book, Edited Book, Report), Editor (Other Types)
	for ( $input_data->editor )
	{
		if( $input_data_type eq "Patent" ) {
			$epdata->{institution} = $_;
		}
		# Editor's names should be in Lastname, Firstname format
		elsif( /^(.*?),(.*?)(,(.*?))?$/ )
		{
			if( $input_data_type eq "Book" || $input_data_type eq "Edited Book" || $input_data_type eq "Report" )
			{
				# Unsupported
			}
			else
			{
				push @{$epdata->{editors_name}}, { family => $1, given => $2, lineage => $4 };
			}
		} 
		##catch: A. Lavin  ---   Lastname is the second part 
 		elsif(/^(.*?) (\w{2,})$/)
                {
			if( $input_data_type eq "Book" || $input_data_type eq "Edited Book" || $input_data_type eq "Report" )
                        {
                                 # Unsupported
                        }
                        else
                	{
                     		push @{$epdata->{editors_name}}, { family => $2, given => $1 };
                        }
                }


		else {
			$plugin->warning( $plugin->phrase( "bad_editor", editor => $_ ) );
		}
	}

	# I Institution (Report), University (Thesis), Assignee (Patent), Publisher (Other Types)
	if( defined $input_data->publisher )
	{
		if( $input_data_type eq "Report" || $input_data_type eq "Thesis" )
		{
			$epdata->{institution} = $input_data->publisher;
		}
		elsif( $input_data_type eq "Patent" )
		{
			# Unsupported
		}
		else
		{
			$epdata->{publisher} = $input_data->publisher;
		}
	}

	# N Application Number (Patent), Issue (Other Types)
	if( defined $input_data->number )
	{
		if( $input_data_type eq "Patent" )
		{
			# Unsupported
		}
		else
		{
			$epdata->{number} = $input_data->number;
		}
	}

	# P Number of Pages (Book, Edited Book, Thesis), Pages (Other Types)
	if( defined $input_data->page )
	{
		if( $input_data_type eq "Book" || $input_data_type eq "Edited Book" || $input_data_type eq "Thesis" )
		{
			$epdata->{pages} = $input_data->page;
		}
		else
		{
			$epdata->{pagerange} = $input_data->page;
		}
	}

	# S Series (Book Section, Conference Proceedings)
	if( defined $input_data->series )
	{
		if( $input_data_type eq "Book Section" || $input_data_type eq "Conference Proceedings" )
		{
			$epdata->{series} = $input_data->series;
		}
	}

	# V Patent Version Number, Degree (Thesis), Volume (Other Types) 
	if( defined $input_data->volume )
	{
		if( $input_data_type eq "Patent" ) 
		{
			# Unsupported
		}
		elsif( $input_data_type eq "Thesis" )
		{
			# Unsupported
		}
		else
		{
			$epdata->{volume} = $input_data->volume;
		}
	}

	# @ ISSN (Journal Article, Newspaper Article, Magazine Article), 
	#   Patent Number, Report Number, 
	#   ISBN (Book, Edited Book, Book Section, Conference Proceedings)
	if( defined $input_data->get( "@" ) )
	{
		if( $input_data_type =~ /Article/ )
		{
			$epdata->{issn} = $input_data->get( "@" );
		}
		elsif( $input_data_type eq "Patent" || $input_data_type eq "Report" )
		{
			$epdata->{id_number} = $input_data->get( "@" );
		}
		elsif( $input_data_type =~ /Book/ || $input_data_type eq "Conference Proceedings" )
		{
			$epdata->{isbn} = $input_data->get( "@" );
		}
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

