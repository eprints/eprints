=pod

=head1 FILE FORMAT

See L<EPrints::Plugin::Import::EndNote>

=cut

package EPrints::Plugin::Export::EndNote;

use EPrints::Plugin::Export::TextFile;
use EPrints;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;
	
	my $self = $class->SUPER::new( %opts );

	$self->{name} = "EndNote";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".enw";
	$self->{mimetype} = "text/plain";

	return $self;
}

sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = ();

	# 0 Citation type
	my $type = $dataobj->get_type;
	$data->{0} = "Generic";
	$data->{0} = "Book" if $type eq "book";
	$data->{0} = "Book Section" if $type eq "book_section";
	$data->{0} = "Conference Paper" if $type eq "conference_item";
	$data->{0} = "Edited Book" if $type eq "book" && !$dataobj->is_set( "creators" ) && $dataobj->is_set( "editors" );
	$data->{0} = "Journal Article" if $type eq "article";
	$data->{0} = "Patent" if $type eq "patent";
	$data->{0} = "Report" if $type eq "monograph";
	$data->{0} = "Thesis" if $type eq "thesis";

	# D Year
	if( $dataobj->exists_and_set( "date" ) )
	{
		$dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
		$data->{D} = $1;
	}
	# J Journal
	if( $type eq "article" )
	{
		$data->{J} = $dataobj->get_value( "publication" ) if $dataobj->exists_and_set( "publication" );
	}
	# K Keywords
	$data->{K} = $dataobj->get_value( "keywords" ) if $dataobj->exists_and_set( "keywords" );
	# T Title
	$data->{T} = $dataobj->get_value( "title" ) if $dataobj->exists_and_set( "title" );
	# U URL
	$data->{U} = $dataobj->get_url;
	# X Abstract
	$data->{X} = $dataobj->get_value( "abstract" ) if $dataobj->exists_and_set( "abstract" );
	# Z Notes
	$data->{Z} = $dataobj->get_value( "note" ) if $dataobj->exists_and_set( "note" );
	# 9 Thesis Type, Report Type
	$data->{9} = EPrints::Utils::tree_to_utf8( $dataobj->render_value( "monograph_type" ) ) if $dataobj->exists_and_set( "monograph_type" );
	$data->{9} = EPrints::Utils::tree_to_utf8( $dataobj->render_value( "thesis_type" ) ) if $dataobj->exists_and_set( "thesis_type" );

	# A Author	
	if( $dataobj->exists_and_set( "creators" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "creators" ) } )
		{
			# Family name first
			push @{ $data->{A} }, EPrints::Utils::make_name_string( $name->{name}, 0 );
		}
	}

	# B Conference Name, Department (Thesis), Series (Book, Report), Book Title (Book Section)
	if( $type eq "conference_item")
	{
		$data->{B} = $dataobj->get_value( "event_title" ) if $dataobj->exists_and_set( "event_title" );
	}
	elsif( $type eq "thesis" )
	{
		$data->{B} = $dataobj->get_value( "department" ) if $dataobj->exists_and_set( "department" );
	}
	elsif( $type eq "book" || $type eq "monograph" )
	{
		$data->{B} = $dataobj->get_value( "series" ) if $dataobj->exists_and_set( "series" );
	}
	elsif( $type eq "book_section" )
	{
		$data->{B} = $dataobj->get_value( "book_title" ) if $dataobj->exists_and_set( "book_title" );
	}

	# C Conference Location, Country (Patent), City (Other Types)
	if( $type eq "conference_item")
	{
		$data->{C} = $dataobj->get_value( "event_location" ) if $dataobj->exists_and_set( "event_location" );
	}
	elsif( $type eq "patent" )
	{
		# Unsupported
	}
	else
	{
		$data->{C} = $dataobj->get_value( "place_of_pub" ) if $dataobj->exists_and_set( "place_of_pub" );
	}

	# E Issuing Organisation (Patent), Editor (Other Types)
	if( $type eq "patent")
	{
		$data->{E} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}
	elsif( $dataobj->exists_and_set( "editors" ) )
	{
		foreach my $name ( @{ $dataobj->get_value( "editors" ) } )
		{
			# Family name first
			push @{ $data->{E} }, EPrints::Utils::make_name_string( $name->{name}, 0 );
		}
	}

	# I Institution (Report), University (Thesis), Assignee (Patent), Publisher (Other Types)
	if( $type eq "monograph" || $type eq "thesis" )
	{
		$data->{I} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}
	elsif( $type eq "patent" )
	{
		# Unsupported
	}
	else
	{
		$data->{I} = $dataobj->get_value( "publisher" ) if $dataobj->exists_and_set( "publisher" );
	}

	# N Application Number (Patent), Issue (Other Types)
	if( $type eq "patent" )
	{
		# Unsupported
	}
	else
	{
		$data->{N} = $dataobj->get_value( "number" ) if $dataobj->exists_and_set( "number" );
	}	

	# P Number of Pages (Book, Thesis), Pages (Other Types)
	if( $type eq "book" || $type eq "thesis" )
	{
		$data->{P} = $dataobj->get_value( "pages" ) if $dataobj->exists_and_set( "pages" );
	}
	else
	{
		$data->{P} = $dataobj->get_value( "pagerange" ) if $dataobj->exists_and_set( "pagerange" );
	}

	# S Series (Book Section)
	if( $type eq "book_section" )
	{
		$data->{S} = $dataobj->get_value( "series" ) if $dataobj->exists_and_set( "series" );
	}

	# V Patent Version Number, Degree (Thesis), Volume (Other Types)
	if( $type eq "patent" )
	{
		# Unsupported
	}
	elsif( $type eq "thesis" )
	{
		# Unsupported
	}
	else
	{
		$data->{V} = $dataobj->get_value( "volume" ) if $dataobj->exists_and_set( "volume" );
	}

	# @ ISSN (Article), Patent Number, Report Number, ISBN (Book, Book Section)
	if( $type eq "article" )
	{
		$data->{"@"} = $dataobj->get_value( "issn" ) if $dataobj->exists_and_set( "issn" );
	}
	elsif( $type eq "patent" || $type eq "monograph" )
	{
		$data->{"@"} = $dataobj->get_value( "id_number" ) if $dataobj->exists_and_set( "issn" );
	}
	elsif( $type eq "book" || $type eq "book_section" )
	{
		$data->{"@"} = $dataobj->get_value( "isbn" ) if $dataobj->exists_and_set( "issn" );
	}

	# F Label
	$data->{F} = $plugin->{session}->get_repository->get_id . ":" . $dataobj->get_id;

	return $data;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $out = "";
	foreach my $k ( sort keys %{ $data } )
	{
		if( ref( $data->{$k} ) eq "ARRAY" )
		{
			foreach my $v ( @{ $data->{$k} } )
			{
				$v=~s/[\r\n]/ /g;
				$out .= "\%$k $v\n";
			}
		} else {
			my $v = $data->{$k};
			$v=~s/[\r\n]/ /g;
			$out .= "\%$k $v\n";
		}
	}
	$out .= "\n";

	return $out;
}

1;
