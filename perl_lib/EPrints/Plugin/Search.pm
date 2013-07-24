package EPrints::Plugin::Search;

@ISA = qw( EPrints::Plugin );

use strict;

=for Pod2Wiki

=head1 NAME

EPrints::Plugin::Search - pluggable search engines

=head1 SYNOPSIS

	# use a specific engine
	$searchexp = $repo->plugin( "Search::XXX",
		dataset => $repo->dataset( "archive" ),
		filters => [{
			meta_fields => [qw( meta_visibility )], value => 'show',
		}],
		...
	);
	
	# find the best engine for a given search configuration
	@engines = $repo->get_plugins({
			dataset => $repo->dataset( "archive" )
		},
		type => "Search",
		can_search => "simple/eprint",
	);
	@engines = sort {
			$b->param('qs') <=> $a->param('qs')
		} @engines;
	
	# render a search input form
	$form->appendChild(
		$searchexp->render_simple_fields
	);
	
	# read the user input terms
	$searchexp->from_form();
	
	# and execute to get some results
	$results = $searchexp->execute();

=head1 DESCRIPTION

Search plugins implement the features required to render search query form inputs, perform queries and return matching objects.

The main function of a search plugin is to retrieve objects from a L<dataset|EPrints::DataSet> based on a set of search criteria. The criteria are search fields and search filters. The terms used in search fields are usually provided by the user (e.g. from a Web form) while filters are defined by the search configuration. Search fields also define the "setness" of a search - if the user hasn't supplied any search terms the search is deemed to be empty. Filters tend to provide more options than those currently available from the Web UI, for instance testing whether a value is or is not set.

In the default EPrints configuration there are C<simple> and C<advanced> searches for objects of class L<EPrints::DataObj::EPrint>. These (at least) define the form input boxes provided to the user and the fields that those user-supplied values are matched against. The search configuration can also define the choice of ordering of results, additional filters etc. Not all options will be supported by every engine - see the engine-specific plugins for details.

There are currently two engines provided as part of the EPrints core:

=over 4

=item Internal

L<EPrints::Plugin::Search::Internal> is a wrapper around L<EPrints::Search>.

This supports querying any object type and in any search configuration (matches C<*/*>).

=item Xapian

L<EPrints::Plugin::Search::Xapian> is a wrapper around the L<Search::Xapian> module (must be installed separately). Xapian supports relevance matches, phrase searching, stemming and other advanced text index approaches.

Currently only C<simple> searches are supported.

=head1 METHODS

=over 4

=cut

=item $searchexp = EPrints::Plugin::Search->new( session => $session, dataset => $dataset, %opts )

Create a new Search plugin object. Options:

	custom_order - stringified order specification
	qs - quality score

=cut

sub new
{
	my( $class, %params ) = @_;

	$params{custom_order} = "" if !exists $params{custom_order};
	$params{filters} = [] if !exists $params{filters};

	# advertise this search engine
	$params{advertise} = exists $params{advertise} ? $params{advertise} : 1;
	# searches an external dataset
	$params{external} = exists $params{external} ? $params{external} : 0;

	my $self = $class->SUPER::new( %params );

	# distinguish plugins by a quality score
	$self->{qs} = 1;
	# supported datasets: simple/eprint advanced/eprint
	$self->{search} = [];
	# whether the search engine supports "result order" (e.g. relevance)
	$self->{result_order} = 0;
	# fully-qualified basename
	$self->{basename} = defined($params{prefix}) ? $params{prefix}."_" : "";

	return $self;
}

sub plugins
{
	my( $self, @args ) = @_;

	my @plugins = $self->{session}->get_plugins( @args, type => "Search", is_external => 0, );

	@plugins = sort { $b->param( "qs" ) <=> $a->param( "qs" ) } @plugins;

	return wantarray ? @plugins : $plugins[0];
}

sub matches
{
	my( $self, $test, $param ) = @_;

	if( $test eq "can_search" )
	{
		return $self->can_search( $param );
	}
	if( $test eq "is_advertised" )
	{
		return $self->param( "advertise" ) == $param;
	}
	if( $test eq "is_external" )
	{
		return $self->param( "external" ) == $param;
	}

	return $self->SUPER::matches( $test, $param );
}

sub can_search
{
	my( $self, $format ) = @_;

	foreach my $match (@{$self->param( "search" ) || []})
	{
		if( $match =~ m# ^(.*)\*$ #x )
		{
			return 1 if substr($format, 0, length($1)) eq $1;
		}
		elsif( $format eq $match )
		{
			return 1;
		}
	}

	return 0;
}

=item @probs = $searchexp->from_form()

Populate the query from an input form.

=cut

sub from_form {}

=item $ok = $searchexp->from_cache( $id )

Retrieve an existing query from a cache identified by $id.

The cache id is set via the L<EPrints::List> object returned by L</execute> (cache_id option).

=cut

sub from_cache {}

=item $ok = $searchexp->from_string( $exp )

Populate the search values from a previously L</serialise>d query $exp.

Will only set search values for those fields that have already been defined.

=cut

sub from_string
{
	my( $self, $exp, %opts ) = @_;

	my( $props, $fields, $filters ) = $self->split_exp( $exp );

	$fields = [] if !defined $fields;
	$filters = [] if !defined $filters;

	# allow_blank is ignored
	shift @$props;

	@{$self}{qw( satisfy_all custom_order dataset_id )} = @$props;
	if( !defined $self->{dataset} )
	{
		$self->{dataset} = $self->{session}->dataset( $self->{dataset_id} );
	}
	if( $self->{custom_order} eq "" )
	{
		delete $self->{custom_order};
	}
	
	$self->from_string_fields( $fields, %opts );
	$self->from_string_filters( $filters, %opts );

	return 1;
}

=item $searchexp->from_string_raw( $exp )

Populate the search values from a previously L</serialise>d query $exp.

This will add any L<EPrints::Search::Field>s that are in $exp.

=cut

sub from_string_raw
{
	my( $self, $exp ) = @_;

	return $self->from_string( $exp, init => 1 );
}

=item $searchexp->from_string_fields( $fields, %opts )

Populate the field values from serialised $fields (array ref).

Options:

	init - initialise the fields

=cut

sub from_string_fields {}

=item $searchexp->from_string_filters( $fields, %opts )

Populate the filter field values from serialised $fields (array ref).

Options:

	init - initialise the fields

=cut

sub from_string_filters {}

=item $exp = $searchexp->serialise( %opts )

Serialise the query and return it as a plain-string.

=cut

sub serialise
{
	my( $self, %opts ) = @_;

	my @sections;
	push @sections, 
		[
			$self->{allow_blank}?1:0,
			$self->{satisfy_all}?1:0,
			defined($self->{custom_order})?$self->{custom_order}:'',
			$self->{dataset}->id,
		];
	push @sections, [ $self->serialise_fields ];
	push @sections, [ $self->serialise_filters ];

	return $self->join_exp( @sections );
}

=item @fields = $searchexp->serialise_fields()

Returns a list of serialised field-values.

=cut

sub serialise_fields { () }

=item @fields = $searchexp->serialise_filters()

Returns a list of serialised filter field-values.

=cut

sub serialise_filters { () }

=item $spec = $searchexp->freeze()

Freeze this search spec.

=cut

sub freeze
{
	my( $self ) = @_;

	my $uri = URI->new( '', 'http' );
	$uri->query_form(
		plugin => substr($self->get_id,8),
		searchid => $self->{searchid},
		dataset => $self->{dataset}->id,
		exp => $self->serialise,
	);

	return "$uri";
}

=item $searchexp = $searchexp->thaw( $spec )

Unthaw a search spec into a new L<EPrints::Plugin::Search> object.

	$searchexp = $repo->plugin( "Search" )->thaw( ... );

Returns undef if $spec is invalid.

=cut

sub thaw
{
	my( $self, $spec ) = @_;

	# old-style spec
	if( $spec !~ /^\?/ )
	{
		my $uri = URI->new( '', 'http' );
		$uri->query_form(
			plugin => "Internal",
			searchid => "advanced",
			dataset => "archive",
			exp => $spec,
		);
		$spec = "$uri";
	}

	my $uri = URI->new( $spec );
	my %spec = $uri->query_form;

	my $dataset = $self->{session}->dataset( $spec{dataset} );
	my $sconf = $dataset->search_config( $spec{searchid} );

	my $plugin = $self->{session}->plugin( "Search::$spec{plugin}",
		searchid => $spec{searchid},
		dataset => $dataset,
		%$sconf,
	);

	return undef if !defined $plugin;

	$plugin->from_string( $spec{exp} );

	# make sure searchid sticks
	$plugin->{searchid} = $spec{searchid};

	return $plugin;
}

sub search_url
{
	my( $self ) = @_;

	my $path_info = "search/" . $self->{dataset}->id . "/" . $self->{searchid};

	my $url = $self->{session}->current_url( path => "cgi", $path_info );
	$url = URI->new( $url );
	$url->query_form(
		_action_search => 1,
		dataset => $self->{dataset}->id,
		exp => $self->serialise,
		order => $self->{custom_order},
	);

	return "$url";
}

=item $searchexp->is_blank()

Returns true if no query has been specified (ignoring any dataset-specific filters).

=cut

sub is_blank {}

=item $searchexp->clear()

Clears values from the query from e.g. L</from_form>.

=cut

sub clear {}

=item $results = $searchexp->execute()

Execute the query and return a L<EPrints::List> object (or subclass).

=cut

# backwards compatibility with EPrints::Search
sub perform_search
{
	shift->execute( @_ );
}
sub execute {}

=item $xhtml = $searchexp->render_description()

Return an XHTML DOM description of this search expression. This is the combination of the condition and sort options.

=cut

sub render_description
{
	my( $self ) = @_;

	my $xml = $self->{session}->xml;
	my $xhtml = $self->{session}->xhtml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->render_conditions_description );
	$frag->appendChild( $xml->create_text_node( ". " ) );
	$frag->appendChild( $self->render_order_description );
	$frag->appendChild( $xml->create_text_node( ". " ) );

	return $frag;
}

=item $xhtml = $searchexp->render_conditions_description()

Return an XHTML DOM description of this search expression's conditions.

=cut

sub render_conditions_description
{
	my( $self ) = @_;

	return $self->{session}->xml->create_document_fragment;
}

=item $xhtml = $searchexp->render_order_description()

Return an XHTML DOM description of how this search is ordered.

=cut

sub render_order_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	# empty if there is no order.
	return $frag unless( EPrints::Utils::is_set( $self->{custom_order} ) );

	my $first = 1;
	foreach my $orderid ( split( "/", $self->{custom_order} ) )
	{
		$frag->appendChild( $self->{session}->make_text( ", " ) ) if( !$first );
		my $desc = 0;
		if( $orderid=~s/^-// ) { $desc = 1; }
		$frag->appendChild( $self->{session}->make_text( "-" ) ) if( $desc );
		my $field = EPrints::Utils::field_from_config_string( $self->{dataset}, $orderid );
		$frag->appendChild( $field->render_name( $self->{session} ) );
		$first = 0;
	}

	return $self->{session}->html_phrase(
		"lib/searchexpression:desc_order",
		order => $frag );
}
	
=item $xhtml = $searchexp->render_simple_fields( [ %opts ] )

Renders the form input field(s) required for a simple search (typically just a single text input box).

Options are as passed to L<EPrints::XHTML/input_field>.

=cut

sub render_simple_fields
{
	my( $self, %opts ) = @_;

	my $xml = $self->{session}->xml;
	my $xhtml = $self->{session}->xhtml;

	return $xhtml->input_field(
		$self->{basename}."q",
		$self->{q},
		type => "text",
		size => 60,
		%opts,
	);
}

=item $xhtml = $searchexp->render_advanced_fields()

Renders a list of input fields for advanced input as table rows.

=cut

sub render_advanced_fields
{
	my( $self ) = @_;

	return $self->{session}->xml->create_document_fragment;
}

=item $exp = $searchexp->join_exp( @sections )

=cut

sub join_exp
{
	my( $self, @sections ) = @_;

	my @parts;
	for(@sections)
	{
		push @parts, "-", (@$_ ? @$_ : '');
	}
	shift @parts;

	s/([\\\|])/\\$1/g for @parts;

	return join '|', @parts;
}

=item @sections = $searchexp->split_exp( $exp )

=cut

sub split_exp
{
	my( $self, $exp ) = @_;

	$exp = "-|$exp" if length($exp);
	my @parts;
	while( $exp =~ /\G((?:\\.|[^\\\|]+)*)(?:\||$)/sg)
	{
		push @parts, $1;
	}

	s/\\(.)/$1/g for @parts;

	my @sections;
	for(@parts)
	{
		if( $_ eq "-" )
		{
			push @sections, [];
		}
		else
		{
			push @{$sections[$#sections]}, $_;
		}
	}

	return @sections;
}

=item $text = $searchexp->describe

Returns a text string describing this search query that will be executed (for debugging).

=cut

sub describe
{
	my( $self ) = @_;

	return "[No description available]";
}

1;

__END__

=head1 SEE ALSO

L<EPrints::Const/EP_TRIGGER_INDEX_FIELDS>, L<EPrints::Search>, L<EPrints::List>.

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2013 University of Southampton.

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

