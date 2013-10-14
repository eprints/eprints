package EPrints::Plugin::Screen::EPrint::IndexInfo;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 2000,
		},
	];

	$self->{disable} = !EPrints::Utils::require_if_exists( "Search::Xapian" ); 

	my $session = $self->{session};
	if( $session && $session->get_online )
	{
		$self->{title} = $session->make_element( "span" );
		$self->{title}->appendChild( $self->SUPER::render_tab_title );
	}

	return $self;
}

sub DESTROY
{
	my( $self ) = @_;

	if( $self->{title} )
	{
		$self->{session}->xml->dispose( $self->{title} );
	}
}

sub render_tab_title
{
	my( $self ) = @_;

	# Return a clone otherwise the DESTROY above will double-dispose of this
	# element when it is disposed by whatever called us
	return $self->{session}->xml->clone( $self->{title} );
}

sub can_be_viewed
{
	my( $self ) = @_;
		
	return $self->allow( "eprint/details" );
}

sub render
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $session = $eprint->{session};

	my $page = $session->make_doc_fragment;

	my $xapian;
	eval {
		my $path = $session->config( "variables_path" ) . "/xapian";
		$xapian = Search::Xapian::Database->new( $path );
	};

	return $session->make_text( 'no xapian' ) if( !$xapian || $@ );

	my $ds = $session->dataset( 'eprint' );

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

		my $eset = $enq->get_eset( 1_000_000, $rset );
		my @terms = map { $_->get_termname() } $eset->items;

		my $fieldsmap = {};

		foreach my $term (@terms)
		{
			if( $term =~ /^([^:]*):(.*)$/ )
			{
				my ($field, $term) = ($1,$2);
				if( $field =~ s/^Z// )
				{
					$term .= " (stemmed)";
				}

				push @{$fieldsmap->{$field}}, $term;
			}
			else
			{
				push @{$fieldsmap->{'FULLTEXT'}}, $term;
			}
		}

		my $table = $page->appendChild( $session->make_element( 'table' ) );
		
		foreach my $field (sort keys %$fieldsmap)
		{
			my $tr = $table->appendChild( $session->make_element( 'tr' ) );
		
			my $ftd = $tr->appendChild( $session->make_element( 'td' ) );
			$ftd->appendChild( $session->make_text( $field ) );
	
			my $ctd = $tr->appendChild( $session->make_element( 'td' ) );
			$ctd->appendChild( $session->make_text( join( " ", @{$fieldsmap->{$field}}) ) ); 
		}
	}
	return $page;
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

