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
		my $ds = $self->{handle}->get_repository->get_dataset( "history" );
		my $searchexp = EPrints::Search->new(
			handle =>$self->{handle},
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

	my $container = $self->{handle}->make_element( 
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



	my $page = $self->{handle}->render_form( "GET" );
	$page->appendChild( 
		EPrints::Paginate->paginate_list( 
			$self->{handle}, 
			"_history", 
			$list,
			%opts ) );

	return $page;
}	


sub render_result_row
{
	my( $self, $handle, $result, $searchexp, $n ) = @_;

	my $div = $handle->make_element( "div", class=>"ep_search_result" );
	$div->appendChild( $result->render_citation( "default" ) );
	return $div;
}




1;
