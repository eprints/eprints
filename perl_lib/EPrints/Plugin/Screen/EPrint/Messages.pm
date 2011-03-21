=head1 NAME

EPrints::Plugin::Screen::EPrint::Messages

=cut

package EPrints::Plugin::Screen::EPrint::Messages;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 550,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	if( $self->get_messages->count == 0 )
	{
		return 0;
	}

	return $self->allow( "eprint/messages" );
}


sub get_messages
{
	my( $self ) = @_;

	my $cache_id = "messages_".$self->{processor}->{eprint}->get_id;

	if( !defined $self->{processor}->{$cache_id} )
	{
		my $ds = $self->{session}->get_repository->get_dataset( "history" );
		my $searchexp = EPrints::Search->new(
			session=>$self->{session},
			dataset=>$ds,
			custom_order=>"-timestamp/-historyid" );
		
		$searchexp->add_field(
			$ds->get_field( "objectid" ),
			$self->{processor}->{eprint}->get_id );
		$searchexp->add_field(
			$ds->get_field( "datasetid" ),
			'eprint' );
		$searchexp->add_field(
			$ds->get_field( "action" ),
			'mail_owner note',
			'IN',
			'ANY' );
		
		$self->{processor}->{$cache_id} = $searchexp->perform_search;
	}
	return $self->{processor}->{$cache_id};
}

sub render
{
	my( $self ) = @_;

	my $page = $self->{session}->make_doc_fragment;

	my $results = $self->get_messages;

	if( $results->count )
	{
		$results->map( sub {
			my( $session, $dataset, $item ) = @_;
		
			$page->appendChild( $item->render );
		} );
	}
	else
	{
		$page->appendChild( $self->html_phrase( "no_messages" ) );
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

