package EPrints::Plugin::Import::DSpace;

=head1 NAME

EPrints::Plugin::Import::DSpace - generic DSpace importer

=head1 DESCRIPTION

This module uses a simple grammar to translate "qualified Dublin Core" (DC) from DSpace instances into local EPrints objects. This module accepts a list of abstract page URLs which are then queried using "mode=full" and "show=full" to retrieve a table of DC terms and values. These are processed using the grammar to get an EPData structure.

Mileage will vary between DSpace instances.

=cut

use strict;

our $DISABLE = 0;

use LWP::UserAgent;
use URI;

use EPrints::Plugin::Import::TextFile;

our @ISA = qw( EPrints::Plugin::Import::TextFile );

=head2 Grammar

You can subclass this plugin to refine the grammar used. Return your customised grammar using the get_grammar method.

Example grammar:

  @grammar = (
	'dc.description' => [ 'abstract' ],
	'dc.description.abstract' => [ 'abstract' ],
  	'dc.contributor.author' => [ \&translate_name, 'creators_name' ],
  );

This will map the first value in B<dc.description> to B<abstract>. If the DC also contains B<dc.description.abstract> this will override any value in B<dc.description>.

You can also apply a method to the DC value before assignment by using a code reference e.g. B<translate_name>:

	sub translate_name
	{
		my( $plugin, $values, $fieldname ) = @_;

		my @names;

		foreach my $value (@$values)
		{
			my( $family, $given ) = split /,\s*/, $value;
	
			push @names,
				family => $family,
				given => $given,
			};
		}

		return { $fieldname => \@names };
	}

=cut

our @GRAMMAR = (
		'dc.contributor.author' => [ \&ep_dc_name, 'creators_name' ],
		'dc.contributor.department' => [ 'department' ],
		'dc.date.accessioned' => [ 'datestamp' ],
		'dc.date.issued' => [ 'date' ],
		'dc.identifier.uri' => [ \&ep_dc_identifier_uri ],
		'dc.publisher' => [ 'publisher' ],
		'dc.title' => [ 'title' ],
		'dc.type' => [ \&ep_dc_type, 'type' ],
		'dc.description' => [ \&ep_dc_join, 'abstract' ],
		'dc.description.abstract' => [ \&ep_dc_join, 'abstract' ],
		'dc.description.degree' => [ \&ep_dc_description_degree, 'thesis_type' ],
		'dc.rights' => [ 'notes' ],
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "DSpace Metadata";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];

	$self->{ua} ||= LWP::UserAgent->new();

	return $self;
}

sub input_text_fh
{
	my( $self, %opts ) = @_;

	my @ids;

	my $fh = $opts{fh};
	while(my $url = <$fh>)
	{
		$self->{dataset} = $opts{dataset};
		my $epdata = $self->retrieve_epdata( $url );
		if( !defined $epdata )
		{
			$self->handler->message( "warning", $self->html_phrase( "retrieve_failed",
				url => $self->{session}->make_text( $url ),
				error => $self->{session}->make_text( $self->{errmsg} )
				) );
			next;
		}

		my $dataobj = $self->epdata_to_dataobj( $opts{dataset}, $epdata );
		if( defined $dataobj )
		{
			push @ids, $dataobj->get_id;
		}

		delete $self->{dataset};
	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $self->{session},
		ids => \@ids );
}

=item $grammar = $plugin->get_grammar

Returns an array reference to a grammar.

=cut

sub get_grammar
{
	return \@GRAMMAR;
}

# retrieve epdata from a DSpace abstract page
sub retrieve_epdata
{
	my( $self, $url ) = @_;

	my $epdata = {
			source => $url,
		};

	$url = URI->new( $url );
	$url->query_form(
		mode => "full",
		show => "full",
		);

	$self->{errurl} = $url;

	my $dc = $self->retrieve_dcq( $url );

	return undef unless defined $dc;

	my $suggestions = "";
	while(my( $dcq, $values ) = each %$dc)
	{
		foreach my $value (@$values)
		{
			$suggestions .= "$dcq=$value\n";
		}
	}
	$epdata->{suggestions} = $suggestions;

	my $grammar = $self->get_grammar;

	for(my $i = 0; $i < @$grammar; $i += 2)
	{
		my $dcq = $grammar->[$i];
		my( $f, @opts ) = @{$grammar->[$i+1]};

		# see whether there are any DC values defined
		my $values = $dc->{$dcq};
		next unless defined $values;

		# get an epdata version of $values
		my $ep_value = {};

		if( ref($f) eq "CODE" )
		{
			$ep_value = &$f( $self, $values, @opts );
		}
		else
		{
			my $fieldname = $f;
			# skip this field if it isn't supported by the current repository
			next unless $self->{dataset}->has_field( $fieldname );

			my $field = $self->{dataset}->get_field( $fieldname );
			if( $field->get_property( "multiple" ) )
			{
				$ep_value->{$fieldname} = $values;
			}
			else
			{
				$ep_value->{$fieldname} = $values->[0];
			}
		}

		# merge ep_value into epdata
		foreach my $fieldname (keys %$ep_value)
		{
			next unless $self->{dataset}->has_field( $fieldname );

			my $field = $self->{dataset}->get_field( $fieldname );
			if( $field->get_property( "multiple" ) )
			{
				push @{$epdata->{$fieldname}||=[]}, @{$ep_value->{$fieldname}};
			}
			else
			{
				$epdata->{$fieldname} = $ep_value->{$fieldname};
			}
		}
	}

	return $epdata;
}

# retrieve DC from a URL
sub retrieve_dcq
{
	my( $self, $url ) = @_;

	my $r = $self->{ua}->get( $url );

	if( $r->is_error )
	{
		$self->{errmsg} = $r->content;
		return undef;
	}

	my $dc = $self->find_dc_pairs( $r->decoded_content );
	return undef unless defined $dc;

	$self->{errurl} = $self->{errmsg} = undef;

	return $dc;
}

# find DC pairs from a DSpace DC table HTML page
sub find_dc_pairs
{
	my( $self, $content ) = @_;

	my %DC;
	while( $content =~ m{<td[^>]*>(dc\.[^<]+)</td><td[^>]*>(.*?)<\s*/\s*td\s*>}sig )
	{
		push @{$DC{$1}||=[]}, $2 if length($2);
	}

	return undef unless scalar keys %DC;

	return \%DC;
}

=item $epdata = $plugin->ep_dc_contributor_author( NAMES, FIELDNAME )

Converts a list of DSpace name strings into epdata.

=cut

sub ep_dc_name
{
	my( $self, $values, $fieldname ) = @_;

	my @names;

	foreach my $value (@$values)
	{
		my( $family, $given ) = split /\s*,\s*/, $value;

		push @names, {
			family => $family,
			given => $given,
		};
	}

	return { $fieldname => \@names };
}

=item $epdata = $plugin->ep_dc_type( TYPES )

Maps a DSpace dc.type to eprint type.

=cut

sub ep_dc_type
{
	my( $self, $types ) = @_;

	return { type => ({
			'journal' => 'article',
			'Electronic thesis or dissertation' => 'thesis',
			'Thesis' => 'thesis',
		}->{$types->[0]} || 'other'
	)};
}

sub ep_dc_join
{
	my( $self, $values, $fieldname ) = @_;

	return {
		$fieldname => join "\n", @$values
	};
}

sub ep_dc_description_degree
{
	my( $self, $types ) = @_;

	return { thesis_type => ({
			'Ph.D.' => 'phd',
		}->{$types->[0]} || 'other'
	)};
}

sub ep_dc_identifier_uri
{
	my( $self, $uris ) = @_;

	my $epdata = {};

	foreach my $uri (@$uris)
	{
		if( $uri =~ m{^http://hdl.handle.net/}i )
		{
			$epdata->{official_url} = $uri;
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

