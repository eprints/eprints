
=pod

=head1 FILE FORMAT

=head2 Supported Fields

EPrints mappings shown in B<bold>.

=over 8

=item ID

Ref ID B<eprintid>

=item TY Ref Type. Supported types:

=over 8

=item CHAP B<book_section>

=item BOOK B<book>

=item CONF B<conference_item>
	
=item JOUR B<article>

=item PAT B<patent>

=item RPRT B<monograph>

=item THES B<thesis>

=item GEN B<other>

=item INPR B<status="inpress">

=item UNPB B<status="unpub">

=back

=item T1

=over 8
	
=item Chapter Title (CHAP) B<title>

=item Book Title (BOOK) B<title>

=item Title, primary (GEN) B<title>

=item Title (Other Types) B<title>

=back

=item A1

Authors, primary (GEN) B<creators>

Authors (Other Types) B<creators>

B<NOTE:> Each author on separate line

B<FORMAT:> Lastname, Firstname, Suffix
	
=item Y1

Date primary (GEN) B<date>

Pub Date (Other Types) B<date>

B<FORMAT:> YYYY/MM/DD/other info 

B<NOTE:> MM, DD and other info optional but slashes required
	
=item N1

Notes B<note>
	
=item KW

Keywords B<keywords>

B<NOTE:> Each keyword/phrase on separate line	

=item SP

Start page B<pagerange>

=item EP

End page B<pagerange>
	
=item JF

=over 8

=item Proceedings Title (CONF)

=item Journal (JOUR) B<publication>

=item Periodical (GEN, THES)

=back
	
=item VL

=over 8

=item Edition (CHAP, BOOK)

=item Volume (CONF, JOUR, THES) B<volume>

=item Application Num (PAT)

=item Report Num (RPRT) B<id_number>

=back
	
=item T2

=over 8

=item Book Title (CHAP) B<book_title>

=item Title, Secondary (GEN)

=item Conference Title (CONF) B<event_title>

=back
	
=item A2

=over 8

=item Editors (CHAP, BOOK, CONF, RPRT, UNPB) B<editors>

=item Authors, secondary (GEN)

=item Assignees (PAT)

B<NOTE:> Each author on separate line

B<FORMAT:> Lastname, Firstname, Suffix
	
=back
	
=item IS

=over 8

=item Chapter Num (CHAP)

=item Volume (BOOK) B<volume>

=item Edition (CONF)

=item Issue (GEN, JOUR, THES) B<number>

=item Patent Num (PAT) B<id_number>

=back
	
=item CY

=over 8

=item City (CHAP, BOOK) B<place_of_pub>

=item Pub Place (GEN, CONF, JOUR, RPRT, THES) B<place_of_pub>

=item State/Country (PAT)

=back
	
=item PB

=over 8

=item Publisher (GEN, CHAP, BOOK, CONF, JOUR, RPRT) b<publisher>

=item References (PAT)

=item Institution (THES) b<institution>

=back
	
=item T3

=over 8

=item Unique ID (DOI) (PAT)

=item Title, series (Other Types) B<series>

=back
	
=item N2

Abstract B<abstract>
	
=item SN

=over 8

=item ISBN (BOOK) B<isbn>

=item ISSN/ISBN (Other Types) B<issn>, B<isbn>

=back
	
=item AV

Availability B<full_text_status>

=item M1

=over 8

=item Misc 1 (GEN)

=item Num Volumes (CHAP, BOOK, CONF)

=item Medium (JOUR)

=item Class Code - Int'l (PAT)

=item Type (RPRT) B<monograph_type>

=item Degree (THES) B<thesis_type>

=back

=item M2

=over 8

=item Misc 2 (GEN)

=item Volume (CHAP) B<volume>

=item Conference Location (CONF) B<event_location>

=item Class Code - US (PAT)

=item Type (THES)

=back

=item UR

Web URL B<official_url>

=back
	
=head2 Unsupported Fields

=over 8

=item RP

Reprint

=item U1-5

User Def 1-5

=item A3

Series Editors (CHAP, BOOK, CONF), Authors, series (GEN)

=item M3

Document Type (PAT), Unique ID (DOI) (Other Types)

=item AD

Address

=item L1

Link to PDF

=item L2

Link to Full-text

=item L3

Related Links

=item L4

Images

=item Y2

Date secondary (GEN), Date of Conference (CONF), Date Accessed (CHAP, BOOK, JOUR, THES, UNPB), Date (RPRT), Date Filed (PAT)

=cut

package EPrints::Plugin::Export::RIS;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use Encode;

use strict;


sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Reference Manager";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".ris";
	$self->{mimetype} = "text/plain";

	return $self;
}


sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = {};

	# ID Ref ID
	$data->{ID} = $plugin->{session}->get_repository->get_id . $dataobj->get_id;

	# TY Pub Type
	my $type = $dataobj->get_type;
	$data->{TY} = "GEN";
	$data->{TY} = "JOUR" if $type eq "article";
	$data->{TY} = "BOOK" if $type eq "book";
	$data->{TY} = "CHAP" if $type eq "book_section";
	$data->{TY} = "CONF" if $type eq "conference_item";
	$data->{TY} = "RPRT" if $type eq "monograph";
	$data->{TY} = "PAT" if $type eq "patent";
	$data->{TY} = "THES" if $type eq "thesis";
	if( $dataobj->exists_and_set( "ispublished" ) )
	{
		my $status = $dataobj->get_value( "ispublished" );
		$data->{TY} = "INPR" if $status eq "inpress"; 
		$data->{TY} = "UNPB" if $status eq "unpub";
	}

	# T1 Title
	$data->{TI} = $dataobj->get_value( "title" ) if $dataobj->exists_and_set( "title" );

	# A1 Authors
	if( $dataobj->exists_and_set( "creators" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "creators" ) } )
		{
			# family name first
			push @{ $data->{A1} }, EPrints::Utils::make_name_string( $name->{name}, 0 );
		}
	}

	# Y1 Pub Date
	# TODO: month and day
	if( $dataobj->exists_and_set( "date" ) ) {
		$dataobj->get_value( "date" ) =~ /^([0-9]{4})(-([0-9]{2}))?(-([0-9]{2}))?$/;
		# YYYY/MM/DD/other info - slashes required
		$data->{Y1} = sprintf(
			"%s/%s/%s/", 
			$1, 
			$3 ? $3 : "",
			$5 ? $5 : "" );
	}
	
	# N1 Notes
	$data->{N1} = $dataobj->get_value( "note" ) if $dataobj->exists_and_set( "note" );

	# KW Keywords
	push @{ $data->{KW} }, split( ",", $dataobj->get_value( "keywords" ) ) if $dataobj->exists_and_set( "keywords" );

	# SP Start Page
	# EP End Page
	if( $dataobj->exists_and_set( "pagerange" ) )
	{
		$dataobj->get_value( "pagerange" ) =~ /^(.*?)\-(.*?)$/;
		$data->{SP} = $1 if $1;
		$data->{EP} = $2 if $2;
	}
	elsif( $dataobj->exists_and_set( "pages" ) )
	{
		$data->{EP} = $dataobj->get_value( "pages" );
	}
	
	# JF Periodical
	if( $type eq "article" )
	{	
		$data->{JF} = $dataobj->get_value( "publication" ) if $dataobj->exists_and_set( "publication" );
	}

	# VL Volume
	if( $type eq "conference_item" || $type eq "article" || $type eq "thesis" )
	{
		$data->{VL} = $dataobj->get_value( "volume" ) if $dataobj->exists_and_set( "volume" );
	}
	elsif( $type eq "monograph" )
	{
		$data->{VL} = $dataobj->get_value( "id_number" ) if $dataobj->exists_and_set( "id_number" );
	}

	# T2 Book Title
	if( $type eq "book_section" )
	{
		$data->{T2} = $dataobj->get_value( "book_title" ) if $dataobj->exists_and_set( "book_title" );
	}
	elsif( $type eq "conference_item" )
	{
		$data->{T2} = $dataobj->get_value( "event_title" ) if $dataobj->exists_and_set( "event_title" );
	}

	# A2 Editors
	if( $type eq "book_section" || $type eq "book" || $type eq "conference_item" || $type eq "monograph" )
	{
		if( $dataobj->exists_and_set( "editors" ) )
		{
			foreach my $name ( @{ $dataobj->get_value( "editors" ) } )
			{
				# family name first
				push @{ $data->{ED} }, EPrints::Utils::make_name_string( $name->{name}, 0 );
			}
		}
	}

	# IS Issue
	if( $type eq "book" )
	{
		$data->{IS} = $dataobj->get_value( "volume" ) if $dataobj->exists_and_set( "volume" );
	}
	elsif( $type eq "article" || $type eq "other" || $type eq "thesis" )
	{
		$data->{IS} = $dataobj->get_value( "number" ) if $dataobj->exists_and_set( "number" );
	}
	elsif( $type eq "patent" )
	{
		$data->{IS} = $dataobj->get_value( "id_number" ) if $dataobj->exists_and_set( "id_number" );
	}

	# CY City
	if( $type ne "patent" )
	{
		$data->{CY} = $dataobj->get_value( "place_of_pub" ) if $dataobj->exists_and_set( "place_of_pub" );
	}

	# PB Publisher
	if( $type eq "thesis" )
	{
		$data->{PB} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}
	elsif( $type ne "patent" )
	{
		$data->{PB} = $dataobj->get_value( "publisher" ) if $dataobj->exists_and_set( "publisher" );
	}

	# T3 Series Title
	if( $type ne "patent" )
	{
		$data->{T3} = $dataobj->get_value( "series" ) if $dataobj->exists_and_set( "series" );
	}
	
	# N2 Abstract
	$data->{N2} = $dataobj->get_value( "abstract" ) if $dataobj->exists_and_set( "abstract" );
	
	# SN ISSN/ISBN
	if( $type eq "book" )
	{
		$data->{SN} = $dataobj->get_value( "isbn" ) if $dataobj->exists_and_set( "isbn" );
	}
	else
	{
		if( $dataobj->exists_and_set( "issn" ) )
		{
			$data->{SN} = $dataobj->get_value( "issn" );
		}
		elsif( $dataobj->exists_and_set( "isbn" ) )
		{
			$data->{SN} = $dataobj->get_value( "isbn" );
		}
	}

	# AV Availability
	$data->{AV} = $dataobj->get_value( "full_text_status" ) if $dataobj->exists_and_set( "full_text_status" );

	# M1 Misc 1
	if( $type eq "monograph" )
	{
		$data->{M1} = $dataobj->get_value( "monograph_type" ) if $dataobj->exists_and_set( "monograph_type" );
	}
	elsif( $type eq "thesis" )
	{
		$data->{M1} = $dataobj->get_value( "thesis_type" ) if $dataobj->exists_and_set( "thesis_type" );
	}

	# M2 Misc 2
	if( $type eq "book_section" )
	{
		$data->{M1} = $dataobj->get_value( "volume" ) if $dataobj->exists_and_set( "volume" );
	}
	elsif( $type eq "conference_item" )
	{
		$data->{M2} = $dataobj->get_value( "event_location" ) if $dataobj->exists_and_set( "event_location" );
	}

	# UR Web URL
	if( $dataobj->exists_and_set( "official_url" ) )
	{
		$data->{UR} = $dataobj->get_value( "official_url" );
	}
	else
	{
		$data->{UR} = $dataobj->get_url;
	}

	return $data;
}

# The characters allowed in the reference ID fields can be in the set "0" through "9," or "A" through "Z." 
# The characters allowed in all other fields can be in the set from "space" (character 32) to character 255 in the IBM Extended Character Set.
# Note, however, that the asterisk (character 42) is not allowed in the author, keywords or periodical name fields.	

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $out = "TY  - " . $data->{TY} . "\n";
	foreach my $k ( keys %{ $data } )
	{
		next if $k eq "TY";
		if( ref( $data->{$k} ) eq "ARRAY" )
		{
			foreach( @{ $data->{$k} } )
			{
				$out .= "$k  - " . remove_utf8( $_ ) . "\n";
			}
		} else {
			$out .= "$k  - " . remove_utf8( $data->{$k} ) . "\n";
		}
	}
	$out .= "ER  -\n\n";

	return $out;
}

sub remove_utf8
{
	my( $text, $char ) = @_;

	return "" unless defined $text;

	$text = Encode::decode_utf8($text); # stringify $text
	$text = Encode::encode("iso-8859-1", $text, Encode::FB_DEFAULT);

	return $text;
}

1;
