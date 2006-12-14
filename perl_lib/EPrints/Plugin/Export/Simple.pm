package EPrints::Plugin::Export::Simple;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Simple Metadata";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = "text";
	$self->{mimetype} = "text/plain";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $r = "";
	foreach( @{$data} )
	{
		next unless defined( $_->[1] );
		$r.=$_->[0].": ".$_->[1]."\n";
	}
	$r.="\n";
	return $r;
}

sub dataobj_to_html_header
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $links = $plugin->{session}->make_doc_fragment;

	my $epdata = $plugin->convert_dataobj( $dataobj );
	foreach( @{$epdata} )
	{
		$links->appendChild( $plugin->{session}->make_element(
			"meta",
			name => "eprints.".$_->[0],
			content => $_->[1] ) );
		$links->appendChild( $plugin->{session}->make_text( "\n" ));
	}
	return $links;
}

sub convert_dataobj
{
	my( $plugin, $eprint ) = @_;

	my @epdata = ();
	my $dataset = $eprint->get_dataset;

	foreach my $fieldname ( qw/
creators_name
creators_id
editors_name
editors_id
type
datestamp
lastmod
metadata_visibility
latitude
longitude
corp_creators
title
ispublished
subjects
full_text_status
monograph_type
pres_type
keywords
note
abstract
date
date_type
series
publication
volume
number
publisher
place_of_pub
pagerange
pages
event_title
event_location
event_dates
event_type
id_number
patent_applicant
institution
department
thesis_type
refereed
isbn
issn
book_title
official_url
related_url_url
related_url_type
referencetext / )
	{
		next unless $dataset->has_field( $fieldname );
		next unless $eprint->is_set( $fieldname );
		my $field = $dataset->get_field( $fieldname );
		my $value = $eprint->get_value( $fieldname );
		if( $field->get_property( "multiple" ) )
		{
			foreach my $item ( @{$value} )
			{
				if( $field->is_type( "name" ) )
				{
					push @epdata, [ $fieldname, ($item->{family}||"").", ".($item->{given}||"") ];
				}
				else
				{
					push @epdata, [ $fieldname, $item ];
				}
			}
		}
		else
		{
			push @epdata, [ $fieldname, $value ];
		}
	}

	# The citation for this eprint
	push @epdata, [ "citation",
		EPrints::Utils::tree_to_utf8( $eprint->render_citation() ) ];

	foreach my $doc ( $eprint->get_all_documents )
	{
		push @epdata, [ "document_url", $doc->get_url() ];
	}

	return \@epdata;
}


1;
