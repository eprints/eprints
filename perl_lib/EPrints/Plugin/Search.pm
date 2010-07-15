package EPrints::Plugin::Search;

@ISA = qw( EPrints::Plugin );

use strict;

=head1 NAME

EPrints::Plugin::Search - pluggable search engines

=head1 SYNOPSIS

	$search = $repo->plugin( "Search::XXX",
		dataset => $repo->dataset( "archive" ),
		...
	);

	# methods to set up query

	$results = $search->execute();

=head1 DESCRIPTION

Search plugins implement the features required to render search query inputs, perform queries and return resulting objects.

=head1 METHODS

=over 4

=cut

=item $plugin = EPrints::Plugin::Search->new( session => $session, dataset => $dataset, %opts )

Create a new Search plugin object. Options:

	custom_order - stringified order specification

=cut

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	# distinguish plugins by a quality score
	$self->{qs} = 1;
	# supported datasets: simple/eprint advanced/eprint
	$self->{search} = [];
	# whether the search engine supports "result order" (e.g. relevance)
	$self->{result_order} = 0;

	return $self;
}

sub matches
{
	my( $self, $test, $param ) = @_;

	if( $test eq "can_search" )
	{
		return $self->can_search( $param );
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

=item @probs = $plugin->from_form()

Populate the query from an input form.

=cut

sub from_form {}

=item $ok = $plugin->from_cache( $id )

Retrieve an existing query from a cache identified by $id.

The cache id is set via the L<EPrints::List> object returned by L</execute> (cache_id option).

=cut

sub from_cache {}

=item $ok = $plugin->from_string( $exp )

Populate the query from a previously L</serialise>d query $exp.

=cut

sub from_string {}

=item $exp = $plugin->serialise()

Serialise the query and return it as a plain-string.

=cut

sub serialise {}

=item $plugin->is_blank()

Returns true if no query has been specified (ignoring any dataset-specific filters).

=cut

sub is_blank {}

=item $results = $plugin->execute()

Execute the query and return a L<EPrints::List> object (or subclass).

=cut

# backwards compatibility with EPrints::Search
sub perform_search
{
	shift->execute( @_ );
}
sub execute {}

=item $xhtml = $plugin->render_description()

Return an XHTML DOM description of this search expression.

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

=item $xhtml = $plugin->render_conditions_description()

Return an XHTML DOM description of just this search expression's conditions.

=cut

sub render_conditions_description
{
	my( $self ) = @_;

	return $self->{session}->xml->create_document_fragment;
}

=item $xhtml = $plugin->render_order_description()

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
	
=item $xhtml = $plugin->render_simple_fields()

Renders a single-line set of input fields for single-box input (e.g. AND/OR [text input]).

=cut

sub render_simple_fields
{
	my( $self ) = @_;

	my $xml = $self->{session}->xml;
	my $xhtml = $self->{session}->xhtml;

	return $xhtml->input_field( "q", $self->{q}, type => "text", size => 60 );
}

=item $xhtml = $plugin->render_advanced_fields()

Renders a list of input fields for advanced input as table rows.

=cut

sub render_advanced_fields
{
	my( $self ) = @_;

	return $self->{session}->xml->create_document_fragment;
}

1;

__END__

=head1 SEE ALSO

L<EPrints::Const/EP_TRIGGER_INDEX_FIELDS>, L<EPrints::Search>, L<EPrints::List>.
