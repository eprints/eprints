=head1 NAME

EPrints::Plugin::Import::ISIWoK

=cut

package EPrints::Plugin::Import::ISIWoK;

use EPrints::Plugin::Import::TextFile;
@ISA = qw( EPrints::Plugin::Import::TextFile );

our @WOS_INDEXES = (
		AD => 'Address',
		AU => 'Author',
		CA => 'Cited Author',
		CI => 'City',
		CT => 'Conference',
		CU => 'Country',
		CW => 'Cited Work',
		CY => 'Cited Year',
		DT => 'Document Type',
		GP => 'Group Author',
		LA => 'Language',
		OG => 'Organization',
		PS => 'Province/State',
		PY => 'Pub Year',
		SA => 'Street Address',
		SG => 'Sub-organization',
		SO => 'Source',
		TI => 'Title',
		TS => 'Topic',
		UT => 'ISI UT identifier',
		ZP => 'Zip/Postal Code',
	);

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "ISI Web of Knowledge";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];
	$self->{screen} = "Import::ISIWoK";
	$self->{input_textarea} = 0;
	$self->{input_file} = 0;
	$self->{input_form} = 1;

	if( !EPrints::Utils::require_if_exists( "SOAP::ISIWoK::Lite", "1.05" ) )
	{
		$self->{visible} = 0;
		$self->{error} = "Requires SOAP::ISIWoK::Lite 1.05";
	}

	return $self;
}

sub render_input_form
{
	my( $self, $screen, $basename, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->html_phrase( "help" ) );

	my $table = $frag->appendChild( $xml->create_element( "table" ) );

	for(my $i = 0; $i < @WOS_INDEXES; $i+=2)
	{
		my( $key, undef ) = @WOS_INDEXES[$i,$i+1];
		my $param_key = join '_', $basename, $key;
		$table->appendChild( $repo->render_row_with_help(
				label => $self->html_phrase( "field:$key" ),
				field => $repo->render_input_field(
					class => "ep_form_text",
					type => "text",
					name => join('_', $basename, $key),
					value => $opts{query}{$key},
					maxlength => 256 ),
			) );
	}

	$frag->appendChild( $xhtml->input_field(
		_action_search => $repo->phrase( "lib/searchexpression:action_search" ),
		type => "submit",
		class => "ep_form_action_button",
	) );

	return $frag;
}

sub input_form
{
	my( $self, %opts ) = @_;

	my $repo = $self->{repository};

	my %query;
	for(@WOS_INDEXES)
	{
		my $value = $opts{query}{$_};
		next if !EPrints::Utils::is_set( $value );
		$query{$_} = $value;
	}

	my $query = join ' AND ', map { 
			"$_ = ($query{$_})"
		} keys %query;

	$self->_input_query( $query, %opts );

	return $self->{count};
}

sub input_text_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	my $query = join '', <$fh>;

	return $self->_input_query( $query, %opts );
}

sub _input_query
{
	my( $self, $query, %opts ) = @_;

	my $repo = $self->{repository};
	my $dataset = $opts{dataset};

	my @ids;

	my $wok = SOAP::ISIWoK::Lite->new;

	my $xml = $wok->search( $query,
		(defined $opts{offset} ? (offset => $opts{offset}) : ()),
	);

	$self->{count} = $xml->documentElement->getAttribute( "recordsFound" );

	foreach my $rec ($xml->getElementsByTagName( "REC" ))
	{
		my $epdata = $self->xml_to_epdata( $dataset, $rec );
		next if !scalar keys %$epdata;
		my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );
		push @ids, $dataobj->id if defined $dataobj;
	}

	return EPrints::List->new(
		session => $repo,
		dataset => $dataset,
		ids => \@ids );
}

sub xml_to_epdata
{
	my( $self, $dataset, $rec ) = @_;

	my $epdata = {};

	my $node;

	( $node ) = $rec->findnodes( "item/ut" );
	$epdata->{source} = $node->textContent if $node;

	( $node ) = $rec->findnodes( "item/item_title" );
	$epdata->{title} = $node->textContent if $node;

	if( !$node )
	{
		die "Expected to find item_title in: ".$rec->toString( 1 );
	}

	( $node ) = $rec->findnodes( "item/source_title" );
	if( $node )
	{
		$epdata->{publication} = $node->textContent;
		$epdata->{ispublished} = "pub";
	}

	foreach my $node ($rec->findnodes( "item/article_nos/article_no" ))
	{
		my $id = $node->textContent;
		if( $id =~ s/^DOI\s+// )
		{
			$epdata->{id_number} = $id;
		}
	}

	( $node ) = $rec->findnodes( "item/bib_pages" );
	$epdata->{pagerange} = $node->textContent if $node;

	( $node ) = $rec->findnodes( "item/bib_issue" );
	if( $node )
	{
		$epdata->{date} = $node->getAttribute( "year" ) if $node->hasAttribute( "year" );
		$epdata->{volume} = $node->getAttribute( "vol" ) if $node->hasAttribute( "vol" );
	}

	# 
	$epdata->{type} = "article";
	( $node ) = $rec->findnodes( "item/doctype" );
	if( $node )
	{
	}

	foreach my $node ($rec->findnodes( "item/authors/*" ))
	{
		if( $node->nodeName eq "fullauthorname" )
		{
			next if !$epdata->{creators};
			my( $family ) = $node->getElementsByTagName( "AuLastName" );
			my( $given ) = $node->getElementsByTagName( "AuFirstName" );
			$family = $family->textContent if $family;
			$given = $given->textContent if $given;
			$epdata->{creators}->[$#{$epdata->{creators}}]->{name} = {
				family => $family,
				given => $given,
			};
		}
		else
		{
			my $name = $node->textContent;
			my( $family, $given ) = split /,/, $name;
			push @{$epdata->{creators}}, {
				name => { family => $family, given => $given },
			};
		}
	}

	foreach my $node ($rec->findnodes( "item/keywords/*" ))
	{
		push @{$epdata->{keywords}}, $node->textContent;
	}
	$epdata->{keywords} = join ", ", @{$epdata->{keywords}} if $epdata->{keywords};

	( $node ) = $rec->findnodes( "item/abstract" );
	$epdata->{abstract} = $node->textContent if $node;

	# include the complete data for debug (disabled for being too big)
#	$epdata->{suggestions} = $rec->toString( 1 );

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

