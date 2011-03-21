=head1 NAME

EPrints::Plugin::Screen::User::History

=cut

package EPrints::Plugin::Screen::User::History;

our @ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{expensive} = 1;
	$self->{appears} = [
		{
			place => "user_actions",
			position => 300,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	if( $self->get_history->count == 0 )
	{
		return 0;
	}

	return $self->allow( "user/history" );
}

sub get_history
{
	my( $self ) = @_;

	my $cache_id = "history_".$self->{processor}->{user}->get_id;

	if( !defined $self->{processor}->{$cache_id} )
	{
		my $ds = $self->{session}->get_repository->get_dataset( "history" );
		my $searchexp = EPrints::Search->new(
			session=>$self->{session},
			dataset=>$ds,
			custom_order=>"-timestamp/-historyid" );
		
		$searchexp->add_field(
			$ds->get_field( "userid" ),
			$self->{processor}->{user}->get_id );
		$searchexp->add_field(
			$ds->get_field( "datasetid" ),
			'eprint' );
		
		$self->{processor}->{$cache_id} = $searchexp->perform_search;
	}
	return $self->{processor}->{$cache_id};
}



sub render
{
	my( $self ) = @_;

	my $list = $self->get_history;


	my $cacheid = $list->{cache_id};

	my $container = $self->{session}->make_element( 
				"div", 
				class=>"ep_paginate_list" );
	my %opts =
	(
		params => { 
			screen => $self->{processor}->{screenid},
			_cache => $cacheid,
		},
		render_result => sub { return $self->render_result_row( @_ ); },
		render_result_params => $self,
		page_size => 50,
		container => $container,
	);



	my $page = $self->{session}->render_form( "GET" );
	$page->appendChild( 
		EPrints::Paginate->paginate_list( 
			$self->{session}, 
			"_history", 
			$list,
			%opts ) );

	return $page;
}	


sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	my $div = $session->make_element( "div", class=>"ep_search_result" );
	$div->appendChild( $result->render_citation( "default" ) );
	return $div;
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

