=head1 NAME

EPrints::Plugin::Export::BibTeX

=cut

=pod

=head1 FILE FORMAT

See L<EPrints::Plugin::Import::BibTeX>

=cut

package EPrints::Plugin::Export::BibTeX;

use Encode;
use TeX::Encode;
use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "BibTeX";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".bib";
	$self->{mimetype} = "text/plain";

	return $self;
}

sub convert_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = ();

	# Key
	$data->{key} = $plugin->{session}->get_repository->get_id . $dataobj->get_id;

	# Entry Type
	my $type = $dataobj->get_type;
	$data->{type} = "misc";
	$data->{type} = "article" if $type eq "article";
	$data->{type} = "book" if $type eq "book";
	$data->{type} = "incollection" if $type eq "book_section";
	$data->{type} = "inproceedings" if $type eq "conference_item";
	if( $type eq "monograph" )
	{
		if( $dataobj->exists_and_set( "monograph_type" ) &&
			( $dataobj->get_value( "monograph_type" ) eq "manual" ||
			$dataobj->get_value( "monograph_type" ) eq "documentation" ) )
		{
			$data->{type} = "manual";
		}
		else
		{
			$data->{type} = "techreport";
		}
	}
	if( $type eq "thesis")
	{
		if( $dataobj->exists_and_set( "thesis_type" ) && $dataobj->get_value( "thesis_type" ) eq "masters" )
		{
			$data->{type} = "mastersthesis";
		}
		else
		{
			$data->{type} = "phdthesis";	
		}
	}
	if( $dataobj->exists_and_set( "ispublished" ) )
	{
		$data->{type} = "unpublished" if $dataobj->get_value( "ispublished" ) eq "unpub";
	}

	# address
	$data->{bibtex}->{address} = $dataobj->get_value( "place_of_pub" ) if $dataobj->exists_and_set( "place_of_pub" );

	# author
	if( $dataobj->exists_and_set( "creators" ) )
	{
		my $names = $dataobj->get_value( "creators" );	
		$data->{bibtex}->{author} = join( " and ", map { EPrints::Utils::make_name_string( $_->{name}, 1 ) } @$names );
	}
	
	# booktitle
	$data->{bibtex}->{booktitle} = $dataobj->get_value( "event_title" ) if $dataobj->exists_and_set( "event_title" );
	$data->{bibtex}->{booktitle} = $dataobj->get_value( "book_title" ) if $dataobj->exists_and_set( "book_title" );

	# editor
	if( $dataobj->exists_and_set( "editors" ) )
	{
		my $names = $dataobj->get_value( "editors" );	
		$data->{bibtex}->{editor} = join( " and ", map { EPrints::Utils::make_name_string( $_->{name}, 1 ) } @$names );
	}

	# institution
	if( $type eq "monograph" && $data->{type} ne "manual" )
	{
		$data->{bibtex}->{institution} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}

	# journal
	$data->{bibtex}->{journal} = $dataobj->get_value( "publication" ) if $dataobj->exists_and_set( "publication" );

	# month
	if ($dataobj->exists_and_set( "date" )) {
		if( $dataobj->get_value( "date" ) =~ /^[0-9]{4}-([0-9]{2})/ ) {
			$data->{bibtex}->{month} = EPrints::Time::get_month_label( $plugin->{session}, $1 );
		}
	}

	# note	
	$data->{bibtex}->{note}	= $dataobj->get_value( "note" ) if $dataobj->exists_and_set( "note" );

	# number
	if( $type eq "monograph" )
	{
		$data->{bibtex}->{number} = $dataobj->get_value( "id_number" ) if $dataobj->exists_and_set( "id_number" );
	}
	else
	{
		$data->{bibtex}->{number} = $dataobj->get_value( "number" ) if $dataobj->exists_and_set( "number" );
	}

	# organization
	if( $data->{type} eq "manual" )
	{
		$data->{bibtex}->{organization} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}

	# pages
	if( $dataobj->exists_and_set( "pagerange" ) )
	{	
		$data->{bibtex}->{pages} = $dataobj->get_value( "pagerange" );
		$data->{bibtex}->{pages} =~ s/-/--/;
	}

	# publisher
	$data->{bibtex}->{publisher} = $dataobj->get_value( "publisher" ) if $dataobj->exists_and_set( "publisher" );

	# school
	if( $type eq "thesis" )
	{
		$data->{bibtex}->{school} = $dataobj->get_value( "institution" ) if $dataobj->exists_and_set( "institution" );
	}

	# series
	$data->{bibtex}->{series} = $dataobj->get_value( "series" ) if $dataobj->exists_and_set( "series" );

	# title
	$data->{bibtex}->{title} = $dataobj->get_value( "title" ) if $dataobj->exists_and_set( "title" );

	# type
	if( $type eq "monograph" && $dataobj->exists_and_set( "monograph_type" ) )
	{
		$data->{bibtex}->{type} = EPrints::Utils::tree_to_utf8( $dataobj->render_value( "monograph_type" ) );
	}

	# volume
	$data->{bibtex}->{volume} = $dataobj->get_value( "volume" ) if $dataobj->exists_and_set( "volume" );

	# year
	if ($dataobj->exists_and_set( "date" )) {
		$dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
		$data->{bibtex}->{year} = $1 if $1;
	}

	# Not part of BibTeX
	$data->{additional}->{abstract} = $dataobj->get_value( "abstract" ) if $dataobj->exists_and_set( "abstract" );
	$data->{additional}->{url} = $dataobj->get_url(); 
	$data->{additional}->{keywords} = $dataobj->get_value( "keywords" ) if $dataobj->exists_and_set( "keywords" );

	return $data;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my @list = ();
	foreach my $k ( keys %{$data->{bibtex}} )
	{
		push @list, sprintf( "%16s = {%s}", $k, encode('bibtex', $data->{bibtex}->{$k} ));
	}
	foreach my $k ( keys %{$data->{additional}} )
	{
		my $value = $data->{additional}->{$k};
		if( $k eq "url" )
		{
			$value = TeX::Encode::BibTeX->encode_url( $value );
		}
		else
		{
			$value = encode('bibtex', $value );
		}
		push @list, sprintf( "%16s = {%s}", $k, $value );
	}

	my $out = '@' . $data->{type} . "{" . $data->{key} . ",\n";
	$out .= join( ",\n", @list ) . "\n";
	$out .= "}\n\n";

	return $out;
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

