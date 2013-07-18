=head1 NAME

EPrints::Plugin::Search::Xapian

=head1 PARAMETERS

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
			$qp->parse_query( $self->{q},
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

