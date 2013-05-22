=head1 NAME

EPrints::Plugin::Screen::EPrint::Box::RelatedItems

This shows some related items on the summary page. 

Note that this only works with Xapian

=cut

package EPrints::Plugin::Screen::EPrint::Box::RelatedItems;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Box' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{appears} = [
		{
			place => "summary_bottom",
			position => 1000,
		},
	];

	# it will be automatically enabled via the conf if Xapian is used
	$self->{disable} = 1;

	# the threshold for including items - expressed as a percentage of matching
	$self->{threshold} = 50;

	# the number of items to include
	$self->{max} = 5;

	return $self;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	my $done_any = 0;
	my $xapian;
	eval {
		my $path = $session->config( "variables_path" ) . "/xapian";
		$xapian = Search::Xapian::Database->new( $path );
	};

	if( defined $xapian )
	{
		my $eprint = $self->{processor}->{eprint};

		my $key = "_id:/id/eprint/" . $eprint->get_id;

		my $enq = $xapian->enquire( Search::Xapian::Query->new(
			Search::Xapian::OP_AND(),
			"_dataset:eprint",
			$key,
		) );

		my $rset = Search::Xapian::RSet->new();
		my( $match ) = $enq->matches(0, 1);

		if( defined $match )
		{
			$rset->add_document( $match->get_docid );

			$enq = Search::Xapian::Enquire->new( $xapian );

			my $stopper = Search::Xapian::SimpleStopper->new();
			my $eset = $enq->get_eset( 40, $rset, sub {
				my( $term ) = @_;

				# Reject terms with a prefix
				return 0 if $term =~ /^[A-Z]/;

				# Don't suggest stopwords
				return 0 if $stopper->stop_word( $term );

				# Reject small numbers
				return 0 if $term =~ /^[0-9]{1,3}$/;

				# Reject terms containing a space
				return 0 if $term =~ /\s/;

				# Ignore terms that only occur once
				return 0 if $xapian->get_termfreq( $term ) <= 1;

				# Ignore the unique term used to retrieve the query
				return 0 if $term eq $key;

				return 1;
			} );
			my @terms = map { $_->get_termname() } $eset->items;

			$enq = Search::Xapian::Enquire->new( $xapian );
			$enq->set_query(
				Search::Xapian::Query->new(
					Search::Xapian::OP_AND(),
					"eprint_status:archive",
					Search::Xapian::Query->new(
						Search::Xapian::OP_AND_NOT(),
						"_dataset:eprint",
						$key,
					),
					Search::Xapian::Query->new(
						Search::Xapian::OP_OR(),
						@terms
					),
			) );

			my $ul = $frag->appendChild( $session->make_element( "ul", class => "ep_act_list" ) );
	
			my $threshold = $self->param( 'threshold' );	
			foreach my $rel ( $enq->matches( 0, $self->param( 'max' ) ) )
			{
				last if( !defined $rel );
				my $score = $rel->get_percent;
				next if( $score < $threshold );
				
				my $eprint = $session->dataset( 'archive')->dataobj( $rel->get_document->get_data ) or next;
				my $li = $session->make_element( "li" );
				$ul->appendChild( $li );
				$li->appendChild( $eprint->render_citation_link( "brief" ) );
				$done_any++;
			}
		}
	}

	if( !$done_any )
	{
		return $self->html_phrase( 'none_found' );
	}

	return $frag;
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

