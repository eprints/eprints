=head1 NAME

EPrints::Plugin::Export::DC

=cut

package EPrints::Plugin::Export::DC;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Dublin Core";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";

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
		my $v = $_->[1];
		$v=~s/[\r\n]/ /g;
		$r.=$_->[0].": $v\n";
	}
	$r.="\n";
	return $r;
}

sub dataobj_to_html_header
{
	my( $plugin, $dataobj ) = @_;

	my $links = $plugin->{session}->make_doc_fragment;

	$links->appendChild( $plugin->{session}->make_element(
		"link",
		rel => "schema.DC",
		href => "http://purl.org/DC/elements/1.0/" ) );
	$links->appendChild( $plugin->{session}->make_text( "\n" ));
	my $dc = $plugin->convert_dataobj( $dataobj );
	foreach( @{$dc} )
	{
		$links->appendChild( $plugin->{session}->make_element(
			"meta",
			name => "DC.".$_->[0],
			content => $_->[1],
			%{ $_->[2] || {} } ) );
		$links->appendChild( $plugin->{session}->make_text( "\n" ));
	}
	return $links;
}

	

sub convert_dataobj
{
	my( $plugin, $eprint ) = @_;

	my $dataset = $eprint->{dataset};

	my @dcdata = ();

	# The URL of the abstract page
	if( $eprint->is_set( "eprintid" ) )
	{
		push @dcdata, [ "relation", $eprint->get_url() ];
	}

	push @dcdata, $plugin->simple_value( $eprint, title => "title" );

	# grab the creators without the ID parts so if the site admin
	# sets or unsets creators to having and ID part it will make
	# no difference to this bit.

	if( $eprint->exists_and_set( "creators_name" ) )
	{
		my $creators = $eprint->get_value( "creators_name" );
		if( defined $creators )
		{
			foreach my $creator ( @{$creators} )
			{	
				next if !defined $creator;
				push @dcdata, [ "creator", EPrints::Utils::make_name_string( $creator ) ];
			}
		}
	}

	if( $eprint->exists_and_set( "subjects" ) )
	{
		my $subjectid;
		foreach $subjectid ( @{$eprint->get_value( "subjects" )} )
		{
			my $subject = EPrints::DataObj::Subject->new( $plugin->{session}, $subjectid );
			# avoid problems with bad subjects
				next unless( defined $subject ); 
			push @dcdata, [ "subject", EPrints::Utils::tree_to_utf8( $subject->render_description() ) ];
		}
	}

	push @dcdata, $plugin->simple_value( $eprint, abstract => "description" );
	push @dcdata, $plugin->simple_value( $eprint, publisher => "publisher" );

	if( $eprint->exists_and_set( "editors_name" ) )
	{
		my $editors = $eprint->get_value( "editors_name" );
		if( defined $editors )
		{
			foreach my $editor ( @{$editors} )
			{
				push @dcdata, [ "contributor", EPrints::Utils::make_name_string( $editor ) ];
			}
		}
	}

	## Date for discovery. For a month/day we don't have, assume 01.
	if( $eprint->exists_and_set( "date" ) )
	{
		my $date = $eprint->get_value( "date" );
		if( defined $date )
		{
			$date =~ s/(-0+)+$//;
			push @dcdata, [ "date", $date ];
		}
	}
	
	if( $eprint->exists_and_set( "type" ) )
	{
		push @dcdata, [ "type", EPrints::Utils::tree_to_utf8( $eprint->render_value( "type" ) ) ];
	}

	my $ref = "NonPeerReviewed";
	if( $eprint->exists_and_set( "refereed" ) && $eprint->get_value( "refereed" ) eq "TRUE" )
	{
		$ref = "PeerReviewed";
	}
	push @dcdata, [ "type", $ref ];

	my @documents = $eprint->get_all_documents();
	my $mimetypes = $plugin->{session}->get_repository->get_conf( "oai", "mime_types" );
	foreach( @documents )
	{
		my $format = $mimetypes->{$_->get_value("format")};
		$format = $_->get_value("format") unless defined $format;
		#$format = "application/octet-stream" unless defined $format;
		push @dcdata, [ "format", $format ];
		push @dcdata, [ "language", $_->value("language") ] if $_->exists_and_set("language");
		push @dcdata, [ "rights", $_->value("license") ] if $_->exists_and_set("license");
		push @dcdata, [ "identifier", $_->get_url() ];
	}

	# The citation for this eprint
	push @dcdata, [ "identifier",
		EPrints::Utils::tree_to_utf8( $eprint->render_citation() ) ];

	# Most commonly a DOI or journal link
	push @dcdata, $plugin->simple_value( $eprint, official_url => "relation" );
	
	# Probably a DOI
	push @dcdata, $plugin->simple_value( $eprint, id_number => "relation" );

	# If no documents, may still have an eprint-level language
	push @dcdata, $plugin->simple_value( $eprint, language => "language" );

	# dc.source not handled yet.
	# dc.coverage not handled yet.

	return \@dcdata;
}

# map eprint values directly into DC equivalents
sub simple_value
{
	my( $self, $eprint, $fieldid, $term ) = @_;

	my @dcdata;

	return () if !$eprint->exists_and_set( $fieldid );

	my $dataset = $eprint->dataset;
	my $field = $dataset->field( $fieldid );

	if( $field->isa( "EPrints::MetaField::Multilang" ) )
	{
		my( $values, $langs ) =
			map { $_->get_value( $eprint ) }
			@{$field->property( "fields_cache" )};
		$values = [$values] if ref($values) ne "ARRAY";
		$langs = [$langs] if ref($values) ne "ARRAY";
		foreach my $i (0..$#$values)
		{
			push @dcdata, [ $term, $values->[$i], { 'xml:lang' => $langs->[$i] } ];
		}
	}
	elsif( $field->property( "multiple" ) )
	{
		push @dcdata, map { 
			[ $term, $_ ]
		} @{ $field->get_value( $eprint ) };
	}
	else
	{
		push @dcdata, [ $term, $field->get_value( $eprint ) ];
	}

	return @dcdata;
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

