package EPrints::Plugin::Search::Xapian;

@ISA = qw( EPrints::Plugin::Search );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "xapian";
	$self->{search} = [qw( simple/* )];
	$self->{disable} = 1; # enabled by cfg.d/search_xapian.pl
	$self->{result_order} = 1; # whether to default to showing by engine result order
	
	return $self;
}

sub from_cache
{
	my( $self ) = @_;

	return 0;
}

sub from_form
{
	my( $self ) = @_;

	$self->{q} = $self->{session}->param( "q" );

	return ();
}

sub from_string
{
	my( $self, $exp ) = @_;

	($self->{custom_order}, $self->{q}) = split /\|/, $exp;

	return 1;
}

sub serialise
{
	my( $self ) = @_;

	return join '|', $self->{custom_order}, $self->{q};
}

sub is_blank
{
	my( $self ) = @_;

	return !EPrints::Utils::is_set( $self->{q} );
}

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $path = $session->config( "variables_path" ) . "/xapian";
	my $xapian = Search::Xapian::Database->new( $path );

	my $qp = Search::Xapian::QueryParser->new( $xapian );
	$qp->set_stemmer( Search::Xapian::Stem->new( "english" ) );
	$qp->set_stopper( Search::Xapian::SimpleStopper->new() );
	$qp->set_stemming_strategy( Search::Xapian::STEM_SOME() );
	$qp->set_default_op( Search::Xapian::OP_AND() );

	for(@{$self->{search_fields}->[0]->{meta_fields}})
	{
		$qp->add_prefix( $_, "$_:" );
	}

	my $query = Search::Xapian::Query->new( "_dataset:".$self->{dataset}->base_id );
	for(@{$self->{dataset}->{filters}||[]})
	{
		my $fieldname = $_->{meta_fields}->[0];
		$query = Search::Xapian::Query->new(
			Search::Xapian::OP_AND(),
			$query,
			Search::Xapian::Query->new( $fieldname . ':' . $_->{value} )
		);
	}
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
	my $enq = $xapian->enquire( $query );

	if( my $order = $self->{custom_order} )
	{
		my @fields = split m#/#, $order;
		for(@fields)
		{
			my $reverse = $_ =~ s/^\-//;
			my $key = $self->{dataset}->id . '.' . $_ . '.' . $session->{lang}->get_id;
			$enq->set_sort_by_value_then_relevance( $xapian->get_metadata( $key ), $reverse );
			last;
		}
	}

	return EPrints::Plugin::Search::Xapian::ResultSet->new(
		session => $session,
		dataset => $self->{dataset},
		enq => $enq,
		count => $enq->get_mset( 0, $xapian->get_doccount )->get_matches_estimated,
		ids => [] );
}

sub render_description
{
	my( $self ) = @_;

	return $self->{session}->make_text( $self->{q} );
}

sub render_conditions_description
{
	my( $self ) = @_;

	return $self->{session}->make_text( $self->{q} );
}

package EPrints::Plugin::Search::Xapian::ResultSet;

our @ISA = qw( EPrints::List );

sub _get_records
{
	my( $self, $offset, $size, $ids_only ) = @_;

	$offset = 0 if !defined $offset;

	my @ids;
	if( defined $size )
	{
		@ids = grep { $_ } map { $_->get_document->get_data + 0 } $self->{enq}->matches( $offset, $size );
	}
	else
	{
		# retrieve matches 1000 ids at a time
		while((@ids % 1000) == 0)
		{
			push @ids, grep { $_ } map { $_->get_document->get_data + 0 } $self->{enq}->matches( $offset, 1000 );
			$offset += 1000;
		}
	}

	return $ids_only ? \@ids : $self->{session}->get_database->get_dataobjs( $self->{dataset}, @ids );
}

sub count
{
	my( $self ) = @_;

	return $self->{count};
}

1;
