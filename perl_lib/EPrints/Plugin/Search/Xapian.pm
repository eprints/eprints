=head1 NAME

EPrints::Plugin::Search::Xapian

=cut

package EPrints::Plugin::Search::Xapian;

@ISA = qw( EPrints::Plugin::Search );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "xapian";
	$self->{search} = [qw( simple/* )];
	$self->{result_order} = 1; # whether to default to showing by engine result order

	$self->{disable} = !EPrints::Utils::require_if_exists( "Search::Xapian" );
	
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

	return $self->{session}->make_text( $self->{q} );
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

