=head1 NAME

EPrints::Plugin::Export::MODS

=cut

package EPrints::Plugin::Export::MODS;

use strict;
use warnings;

use EPrints::Plugin::Export::XMLFile;

our @ISA = qw( EPrints::Plugin::Export::XMLFile );

our $PREFIX = "mods:";

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "MODS";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	
	$self->{xmlns} = "http://www.loc.gov/mods/v3";
	$self->{schemaLocation} = "http://www.loc.gov/standards/mods/v3/mods-3-3.xsd";

	return $self;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}


sub xml_dataobj
{
	my( $plugin, $dataobj, $prefix ) = @_;

	my $session = $plugin->{ session };

	my $dataset = $dataobj->get_dataset;

	$PREFIX = $prefix
		if defined( $prefix );	

	my $nsp = "xmlns:${PREFIX}";
	chop($nsp); # Remove the ':'
	my $mods = $session->make_element(
		"${PREFIX}mods",
		"version" => "3.3",
		$nsp => $plugin->{ xmlns },
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => ($plugin->{ xmlns } . ' ' . $plugin->{ schemaLocation }),
	);

	# title
	$mods->appendChild( _make_title( $session, $dataset, $dataobj ));

	# creators
	$mods->appendChild( _make_creators( $session, $dataset, $dataobj ));

	# abstract
	$mods->appendChild( _make_abstract( $session, $dataset, $dataobj ));

	# subjects
	$mods->appendChild( _make_subjects( $session, $dataset, $dataobj ));
	
	# date_issue
	$mods->appendChild( _make_issue_date( $session, $dataset, $dataobj ));

	# publisher
	$mods->appendChild( _make_publisher( $session, $dataset, $dataobj ));
	
	# genre
	$mods->appendChild( _make_genre( $session, $dataset, $dataobj ));
	
	$PREFIX = "mods:";
	
	return $mods;
}

sub _make_title
{
	my( $session, $dataset, $dataobj ) = @_;

	return $session->make_doc_fragment unless $dataset->has_field( "title" );
	my $val = $dataobj->get_value( "title" );
	return $session->make_doc_fragment unless defined $val;
	
	my $titleInfo = $session->make_element( "${PREFIX}titleInfo" );
	$titleInfo->appendChild( my $title = $session->make_element( "${PREFIX}title" ));
	$title->appendChild( $session->make_text( $val ));
	
	return $titleInfo;
}

sub _make_creators
{
	my( $session, $dataset, $dataobj ) = @_;
	
	my $frag = $session->make_doc_fragment;
	return $frag unless $dataset->has_field( "creators_name" );
	
	my $creators = $dataobj->get_value( "creators_name" );
	return $frag unless defined $creators;

	foreach my $creator ( @{$creators} )
	{	
		next if !defined $creator;
		$frag->appendChild(my $name = $session->make_element(
			"${PREFIX}name",
			"type" => "personal"
		));
		$name->appendChild(my $given = $session->make_element(
			"${PREFIX}namePart",
			"type" => "given"
		));
		$given->appendChild( $session->make_text( $creator->{ given } ));
		$name->appendChild(my $family = $session->make_element(
			"${PREFIX}namePart",
			"type" => "family"
		));
		$family->appendChild( $session->make_text( $creator->{ family } ));
		$name->appendChild(my $role = $session->make_element(
			"${PREFIX}role",
		));
		$role->appendChild( my $roleTerm = $session->make_element(
			"${PREFIX}roleTerm",
			"type" => "text"
		));
		$roleTerm->appendChild( $session->make_text( "author" ));
	}

	return $frag;
}

sub _make_abstract
{
	my( $session, $dataset, $dataobj ) = @_;
	
	return $session->make_doc_fragment unless $dataset->has_field( "abstract" );
	my $val = $dataobj->get_value( "abstract" );
	return $session->make_doc_fragment unless defined $val;
	
	my $abstract = $session->make_element( "${PREFIX}abstract" );
	$abstract->appendChild( $session->make_text( $val ));
	
	return $abstract;
}

sub _make_subjects
{
	my( $session, $dataset, $dataobj ) = @_;
	
	my $frag = $session->make_doc_fragment;
	
	my $subjects = $dataset->has_field("subjects") ?
		$dataobj->get_value("subjects") :
		undef;
	return $frag unless EPrints::Utils::is_set( $subjects );
	
	foreach my $val (@$subjects)
	{
		my $subject = EPrints::DataObj::Subject->new( $session, $val );
		next unless defined $subject;
		$frag->appendChild( my $classification = $session->make_element(
			"${PREFIX}classification",
			"authority" => "lcc"
		));
		$classification->appendChild( $session->make_text(
			EPrints::XML::to_string($subject->render_description)
		));
	}
	
	return $frag;
}

sub _make_issue_date
{
	my( $session, $dataset, $dataobj ) = @_;
	
	return $session->make_doc_fragment unless $dataset->has_field( "date" );
	my $val = $dataobj->get_value( "date" );
	return $session->make_doc_fragment unless defined $val;
	
	$val =~ s/(-0+)+$//;
	
	my $originInfo = $session->make_element( "${PREFIX}originInfo" );
	$originInfo->appendChild( my $dateIssued = $session->make_element(
		"${PREFIX}dateIssued",
		"encoding" => "iso8601"
	));
	$dateIssued->appendChild( $session->make_text( $val ));
	
	return $originInfo;
}

sub _make_publisher
{
	my( $session, $dataset, $dataobj ) = @_;
	
	my $val;
	
	my $type = lc($dataobj->get_value( "type" ));
	if( $type eq "thesis" and $dataobj->is_set( "institution" ) )
	{
		$val = $dataobj->get_value( "institution" );
		if( $dataobj->is_set( "department" ))
		{
			$val .= ";" . $dataobj->get_value( "department" );
		}
	}
	elsif( $dataset->has_field( "publisher" ) )
	{
		$val = $dataobj->get_value( "publisher" );		
	}
	
	return $session->make_doc_fragment unless defined $val;	
	
	my $originInfo = $session->make_element( "${PREFIX}originInfo" );
	$originInfo->appendChild( my $pub = $session->make_element( "${PREFIX}publisher" ));
	$pub->appendChild( $session->make_text( $val ));
	
	return $originInfo;
}

sub _make_genre
{
	my( $session, $dataset, $dataobj ) = @_;
	
	my $val = $session->phrase( $dataset->confid()."_typename_".$dataobj->get_type() );
	
	my $genre = $session->make_element( "${PREFIX}genre" );
	$genre->appendChild( $session->make_text( $val ));
	
	return $genre; 
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

