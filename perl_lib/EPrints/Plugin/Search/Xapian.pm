=for Pod2Wiki

=head1 NAME

EPrints::Plugin::Search::Xapian - simple searches

=head1 SYNOPSIS

	# 'q' is shown here for demonstration and may change in future!
	$searchexp = $repo->plugin('Search::Xapian',
		dataset => $repo->dataset('archive'),
		search_fields => [{
			meta_fields => [qw( title )],
		}],
		q => 'title:(ameri* eagle)',
	);
	
	$list = $searchexp->execute;
	
	warn 'About ' . $list->count . ' matches';
	$list->map(sub {
		...
	});

=head1 DESCRIPTION

	Xapian is a highly adaptable toolkit which allows developers to easily add
	advanced indexing and search facilities to their own applications. It supports
	the Probabilistic Information Retrieval model and also supports a rich set of
	boolean query operators.

Xapian simple searches are parsed by the Xapian query parser which supports prefixes for search terms:

	title:(eagle buzzard) abstract:"london wetlands"

The field prefixes are taken from the search configuration and constrain the following term (or bracketed terms) to that field only. If no prefix is given the entire Xapian index will be used i.e. it will search any indexed term, not just those from the search configuration fields. For example, the following simple search configuration:

	search_fields => [
		{
			id => "q",
			   meta_fields => [
				   "documents",
				   "title",
				   "abstract",
				   "creators_name",
				   "date"
			   ]
		},
	],

Allows the user to specify "documents", "title", "abstract", "creators_name" or "date" as a prefix to a search term. Omitting a prefix will match any field e.g. "publisher".

Terms can be negated by prefixing the term with '-':

	eagle -buzzard

Phrases can be specified by using quotes, for example  "Southampton University" won't match I<University of Southampton>.

Terms are stemmed by default ('bubbles' becomes 'bubble') except if you use the term in a phrase.

Partial matches are supported by using '*':

	ameri* - americans, americas, amerillo etc.

Xapian search results are returned in a sub-class of L<EPrints::List> (a wrapper around a Xapian enquire object). Calling L<EPrints::List/count> will return an B<estimate> of the total matches.

As Xapian has a higher 'qs' score than Internal it will (once enabled) override the default EPrints simple search. You can override this behaviour in B<cfg.d/plugins.pl>:

	$c->{plugins}{'Search::Xapian'}{params}{qs} = .1;

Or disable completely (including disabling indexing):

	$c->{plugins}{'Search::Xapian'}{params}{disable} = 1;

=head1 USAGE

Install the L<Search::Xapian> extension. Note: there are two Perl bindings available for Xapian. The CPAN version is older and based on Perl-XS. xapian-bindings-perl available from xapian.org is based on SWIG and has better coverage of the API. Regardless, for the best feature support/performance it is highly recommended to have the latest stable version of the Xapian library.

Xapian uses a separate (from MySQL) index that is stored in F<archives/[archiveid]/var/xapian>. To build the Xapian index you will need to reindex:

	./bin/epadmin reindex [archiveid] eprint

(Repeat for any other datasets you expect to use Xapian with.)

The F</var/xapian/> directory should contain something like:

	flintlock  position.baseA  position.DB     postlist.baseB  record.baseA  record.DB       termlist.baseB
	iamchert   position.baseB  postlist.baseA  postlist.DB     record.baseB  termlist.baseA  termlist.DB

The indexing process for Xapian is in F<lib/cfg.d/search_xapian.pl>. This can be overridden by dropping the same-named file into your repository F<cfg.d/>. If the Xapian search is not matching what you might expect it to, you probably need to fix the indexing process (and re-index!). Terms indexed by Xapian can also be weighted to e.g. give names a higher weighting than abstract text.

You will need to restart your Apache server to enable the Xapian search plugin and dependencies.

If the Xapian search is working correctly you will have a "by relevance" option available in the ordering of simple search results.

=head2 Lock Files

Xapian maintains a lock file in F<var/xapian>. If you see indexing errors about not being able to lock the database ensure you aren't running multiple copies of the EPrints L<indexer|bin/indexer>. If no other processes are running you may need to manually remove the lock file from the F<var/xapian> directory. While only one process may modify the Xapian index at a time, any number of processes may concurrently read.

=head1 PARAMETERS

All but the first C<search_field> entry are ignored.

Filters are applied as boolean terms, so complex matches like names won't work.

Ordervalues are supported.

=over 4

=item lang

Override the default language used for stemming.

=item stopwords

An array reference of stop words to use (defaults to English).

=back

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Search::Xapian;

@ISA = qw( EPrints::Plugin::Search );

use strict;

# Freely available stopword list.  This stopword
# list provides a nice balance between coverage
# and size.
our @STOPWORDS = qw(
	a
	about
	above
	across
	after
	again
	against
	all
	almost
	alone
	along
	already
	also
	although
	always
	among
	an
	and
	another
	any
	anybody
	anyone
	anything
	anywhere
	are
	area
	areas
	around
	as
	ask
	asked
	asking
	asks
	at
	away
	b
	back
	backed
	backing
	backs
	be
	became
	because
	become
	becomes
	been
	before
	began
	behind
	being
	beings
	best
	better
	between
	big
	both
	but
	by
	c
	came
	can
	cannot
	case
	cases
	certain
	certainly
	clear
	clearly
	come
	could
	d
	did
	differ
	different
	differently
	do
	does
	done
	down
	down
	downed
	downing
	downs
	during
	e
	each
	early
	either
	end
	ended
	ending
	ends
	enough
	even
	evenly
	ever
	every
	everybody
	everyone
	everything
	everywhere
	f
	face
	faces
	fact
	facts
	far
	felt
	few
	find
	finds
	first
	for
	four
	from
	full
	fully
	further
	furthered
	furthering
	furthers
	g
	gave
	general
	generally
	get
	gets
	give
	given
	gives
	go
	going
	good
	goods
	got
	great
	greater
	greatest
	group
	grouped
	grouping
	groups
	h
	had
	has
	have
	having
	he
	her
	here
	herself
	high
	high
	high
	higher
	highest
	him
	himself
	his
	how
	however
	i
	if
	important
	in
	interest
	interested
	interesting
	interests
	into
	is
	it
	its
	itself
	j
	just
	k
	keep
	keeps
	kind
	knew
	know
	known
	knows
	l
	large
	largely
	last
	later
	latest
	least
	less
	let
	lets
	like
	likely
	long
	longer
	longest
	m
	made
	make
	making
	man
	many
	may
	me
	member
	members
	men
	might
	more
	most
	mostly
	mr
	mrs
	much
	must
	my
	myself
	n
	necessary
	need
	needed
	needing
	needs
	never
	new
	new
	newer
	newest
	next
	no
	nobody
	non
	noone
	not
	nothing
	now
	nowhere
	number
	numbers
	o
	of
	off
	often
	old
	older
	oldest
	on
	once
	one
	only
	open
	opened
	opening
	opens
	or
	order
	ordered
	ordering
	orders
	other
	others
	our
	out
	over
	p
	part
	parted
	parting
	parts
	per
	perhaps
	place
	places
	point
	pointed
	pointing
	points
	possible
	present
	presented
	presenting
	presents
	problem
	problems
	put
	puts
	q
	quite
	r
	rather
	really
	right
	right
	room
	rooms
	s
	said
	same
	saw
	say
	says
	second
	seconds
	see
	seem
	seemed
	seeming
	seems
	sees
	several
	shall
	she
	should
	show
	showed
	showing
	shows
	side
	sides
	since
	small
	smaller
	smallest
	so
	some
	somebody
	someone
	something
	somewhere
	state
	states
	still
	still
	such
	sure
	t
	take
	taken
	than
	that
	the
	their
	them
	then
	there
	therefore
	these
	they
	thing
	things
	think
	thinks
	this
	those
	though
	thought
	thoughts
	three
	through
	thus
	to
	today
	together
	too
	took
	toward
	turn
	turned
	turning
	turns
	two
	u
	under
	until
	up
	upon
	us
	use
	used
	uses
	v
	very
	w
	want
	wanted
	wanting
	wants
	was
	way
	ways
	we
	well
	wells
	went
	were
	what
	when
	where
	whether
	which
	while
	who
	whole
	whose
	why
	will
	with
	within
	without
	work
	worked
	working
	works
	would
	x
	y
	year
	years
	yet
	you
	young
	younger
	youngest
	your
	yours
	z
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "xapian";
	$self->{search} = [qw( simple/* )];
	$self->{result_order} = 1; # whether to default to showing by engine result order
	if( defined $self->{session} )
	{
		$self->{lang} = $self->{session}->config( "defaultlanguage" );
	}
	$self->{stopwords} = \@STOPWORDS;

	$self->{disable} = !EPrints::Utils::require_if_exists( "Search::Xapian" );
	
	return $self;
}

=item $stemmer = $plugin->stemmer()

Returns a L<Search::Xapian::Stem> for the default language.

=cut

sub stemmer
{
	my( $self ) = @_;

	my $langid = $self->param( "lang" );

        my $stemmer;
        eval { $stemmer = Search::Xapian::Stem->new( $langid ); };
        if( $@ || UNIVERSAL::isa( $stemmer, "Search::Xapian::Error" ) )
        {
		$self->{session}->log( "'$langid' is not a supported Xapian stem language, using English instead" );
		$stemmer = Search::Xapian::Stem->new( 'en' );
	}

	return $stemmer;
}

=item $stopper = $plugin->stopper()

Returns a L<Search::Xapian::SimpleStopper> for C<stopwords>.

=cut

sub stopper
{
	my( $self ) = @_;

	return Search::Xapian::SimpleStopper->new(
			@{$self->param( "stopwords" )}
		);
}

sub from_cache
{
	my( $self ) = @_;

	return 0;
}

sub from_form
{
	my( $self ) = @_;

	$self->{q} = $self->{session}->param( $self->{basename}."q" );

	return ();
}

sub from_string_fields
{
	my( $self, $fields, %opts ) = @_;

	$self->{q} = @$fields ? (split /:/, $fields->[0], 5)[4] : "";
}

sub serialise_fields
{
	my( $self ) = @_;

	return( join ':',
		'q',
		'',
		'ALL',
		'IN',
		$self->{q} );
}

sub is_blank
{
	my( $self ) = @_;

	return !EPrints::Utils::is_set( $self->{q} );
}

sub clear
{
	my( $self ) = @_;

	undef $self->{q};
}

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $path = $session->config( "variables_path" ) . "/xapian";
	my $xapian = Search::Xapian::Database->new( $path );

	my $qp = Search::Xapian::QueryParser->new( $xapian );
	$qp->set_stemmer( $self->stemmer );
	$qp->set_stopper( $self->stopper );
	$qp->set_stemming_strategy( Search::Xapian::STEM_SOME() );
	$qp->set_default_op( Search::Xapian::OP_AND() );

	for(@{$self->{search_fields}->[0]->{meta_fields}})
	{
		$qp->add_prefix( $_, "$_:" );
	}

	my $query = Search::Xapian::Query->new( "_dataset:".$self->{dataset}->base_id );
	for(
		@{$self->{dataset}->{filters}||[]},
		@{$self->{filters}||[]},
	   )
	{
		my $fieldname = $_->{meta_fields}->[0];
		$query = Search::Xapian::Query->new(
			Search::Xapian::OP_AND(),
			$query,
			Search::Xapian::Query->new( $fieldname . ':' . $_->{value} )
		);
	}
	if( EPrints::Utils::is_set( $self->{q} ) )
	{
		$query = Search::Xapian::Query->new(
			Search::Xapian::OP_AND(),
			$query,
			$qp->parse_query( lc( $self->{q} ),
				Search::Xapian::FLAG_PHRASE() |
				Search::Xapian::FLAG_BOOLEAN() | 
				Search::Xapian::FLAG_LOVEHATE() | 
				Search::Xapian::FLAG_WILDCARD()
			)
		);
	}
	my $enq = $xapian->enquire( $query );

	if( $self->{custom_order} )
	{
		my $sorter = Search::Xapian::MultiValueSorter->new;
		for(split /\//, $self->{custom_order})
		{
			my $reverse = $_ =~ s/^-// ? 1 : 0;
			my $key = join '.',
				$self->{dataset}->base_id,
				$_,
				$session->{lang}->get_id;
			my $idx = $xapian->get_metadata( $key );
			if( !length($idx) )
			{
				$session->log( "Search::Xapian can't sort by $key: unknown sort key" );
				next;
			}
			$sorter->add( $idx, $reverse );
		}
		$enq->set_sort_by_key_then_relevance( $sorter );
	}

	return EPrints::Plugin::Search::Xapian::ResultSet->new(
		session => $session,
		dataset => $self->{dataset},
		enq => $enq,
		count => $enq->get_mset( 0, $xapian->get_doccount )->get_matches_estimated,
		ids => [],
		limit => $self->{limit} );
}

sub render_description
{
	my( $self ) = @_;

	return $self->{session}->make_text( $self->{q} );
}

sub render_conditions_description
{
	my( $self ) = @_;

	return $self->html_phrase( 'results:title', 
		q => $self->{repository}->make_text( $self->{q} ) 
	);
}

package EPrints::Plugin::Search::Xapian::ResultSet;

our @ISA = qw( EPrints::List );

sub _get_records
{
	my( $self, $offset, $size, $ids_only ) = @_;

	$offset = 0 if !defined $offset;

	if( defined $self->{limit} )
	{
		if( $offset > $self->{limit} )
		{
			$size = 0;
		}
		elsif( !defined $size || $offset+$size > $self->{limit} )
		{
			$size = $self->{limit} - $offset;
		}
	}

	my @ids;
	if( defined $size )
	{
		@ids = grep { length($_) } map { $_->get_document->get_data } $self->{enq}->matches( $offset, $size );
	}
	else
	{
		# retrieve matches 1000 ids at a time
		while((@ids % 1000) == 0)
		{
			push @ids, grep { length($_) } map { $_->get_document->get_data } $self->{enq}->matches( $offset, 1000 );
			$offset += 1000;
		}
	}

	return $ids_only ? \@ids : $self->{session}->get_database->get_dataobjs( $self->{dataset}, @ids );
}

sub count
{
	my( $self ) = @_;

	return (defined $self->{limit} && $self->{limit} < $self->{count}) ?
		$self->{limit} :
		$self->{count};
}

sub reorder
{
	my( $self, $new_order ) = @_;

	$self->{ids} = $self->ids;

	return $self->SUPER::reorder( $new_order );
}

1;

=back

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

