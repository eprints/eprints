package EPrints::Plugin::Import::DSpace;

=head1 NAME

EPrints::Plugin::Import::DSpace - generic DSpace importer

=cut

use strict;

use LWP::UserAgent;
use URI;

use EPrints::Plugin::Import::TextFile;

our @ISA = qw( EPrints::Plugin::Import::TextFile );

our %GRAMMAR = (
		'dc.contributor.author' => [ 'creators_name', \&ep_dc_contributor_author ],
		'dc.contributor.department' => [ 'department' ],
		'dc.date.accessioned' => [ 'datestamp' ],
		'dc.date.issued' => [ 'date' ],
		'dc.identifier.uri' => [ 'documents', \&ep_dc_identifier_uri ],
		'dc.publisher' => [ 'publisher' ],
		'dc.title' => [ 'title' ],
		'dc.type' => [ 'type', \&ep_dc_type ],
		'dc.description' => [ 'abstract', \&ep_dc_description ],
		'dc.description.degree' => [ 'thesis_type', \&ep_dc_description_degree ],
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

sub get_grammar
{
	return \%GRAMMAR;
}

sub retrieve_epdata
{
	my( $self, $url ) = @_;

	$url = URI->new( $url );
	$url->query_form(
		mode => "full",
		show => "full",
		);

	$self->{errurl} = $url;

	my $dc = $self->retrieve_dcq( $url );

	return undef unless defined $dc;

	my $grammar = $self->get_grammar;

	my $epdata = {
			source => $url,
		};

	while(my( $dcq, $actions ) = each %$grammar)
	{
		my( $fieldname, $f ) = @$actions;

		# skip this field if it is supported by the current repository
		next unless $self->{dataset}->has_field( $fieldname );

		# see whether there are any DC values defined
		my $values = $dc->{$dcq};
		next unless defined $values;

		# get an epdata version of $values
		my $ep_value = {};

		my $field = $self->{dataset}->get_field( $fieldname );
		if( defined $f )
		{
			$ep_value = &$f( $self, $values );
		}
		elsif( $field->get_property( "multiple" ) )
		{
			$ep_value->{$fieldname} = $values;
		}
		else
		{
			$ep_value->{$fieldname} = $values->[0];
		}

		# merge ep_value into epdata
		foreach my $fieldname (keys %$ep_value)
		{
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

sub retrieve_dcq
{
	my( $self, $url ) = @_;

	my $r = $self->{ua}->get( $url );

	if( $r->is_error )
	{
		$self->{errmsg} = $r->content;
		return undef;
	}

	my $doc = EPrints::XML::parse_xml_string( $r->content );

	my $table = $self->find_dc_table( $doc );

	if( !defined $table )
	{
		$self->{errmsg} = "Could not find DCQ table";
		return undef;
	}

	my %DC = $self->extract_dc( $table );

	$self->{errurl} = $self->{errmsg} = undef;

	return \%DC;
}

sub find_dc_table
{
	my( $self, $doc ) = @_;

	my @tables = $doc->getElementsByTagName( "table" );

	foreach my $table ( @tables )
	{
		my( $td ) = $table->getElementsByTagName( "td" );
		if( $td->firstChild->toString =~ /^dc\./ )
		{
			return $table;
		}
	}

	return undef;
}

sub extract_dc
{
	my( $self, $table ) = @_;

	my @rows = $table->getElementsByTagName( "tr" );
	
	my %DC;

	foreach my $row (@rows)
	{
		my( $td_key, $td_data, $td_lang ) = $row->getElementsByTagName( "td" );
		next unless defined $td_lang;

		$td_key = $td_key->hasChildNodes ? $td_key->firstChild->toString : undef;
		$td_data = $td_data->hasChildNodes ? $td_data->firstChild->toString : undef;
		$td_lang = $td_lang->hasChildNodes ? $td_lang->firstChild->toString : undef;
		next unless defined $td_key && defined $td_data;

		push @{$DC{$td_key}||=[]}, $td_data;
	}

	return %DC;
}

sub ep_dc_contributor_author
{
	my( $self, $names ) = @_;

	my $epdata = { creators_name => [] };

	foreach my $name (@$names)
	{
		my( $family, $given ) = split /,\s*/, $name;

		push @{$epdata->{creators_name}}, {
			family => $family,
			given => $given,
		};
	}

	return $epdata;
}

sub ep_dc_type
{
	my( $self, $types ) = @_;

	return { type => ({
			'Electronic thesis or dissertation' => 'thesis',
			'Thesis' => 'thesis',
		}->{$types->[0]} || 'other'
	)};
}

sub ep_dc_description
{
	my( $self, $descs ) = @_;

	return {
		abstract => join "\n", @$descs
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
