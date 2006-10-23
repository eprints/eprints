package EPrints::Plugin::Screen::Admin::Indexer;

@ISA = ( 'EPrints::Plugin::Screen::Status' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ start_indexer stop_indexer /]; 

	$self->{appears} = [
		{ 
			place => "indexer_actions", 	
			action => "start_indexer",
			position => 100, 
		},
		{ 
			place => "indexer_actions", 	
			action => "stop_indexer",
			position => 200, 
		},
	];


	return $self;
}

sub render_common_action_buttons
{
	my( $self ) = @_;
	return $self->render_action_list_bar( "indexer_actions" );
}

sub allow_stop_indexer
{
	my( $self ) = @_;
	return 0 if( !EPrints::Index::is_running );
	return $self->allow( "indexer/stop" );
}

sub action_stop_indexer
{
	my( $self ) = @_;

	my $result = EPrints::Index::stop( $self->{session} );

	if( $result == 1 )
	{
		$self->{processor}->add_message( 
			"message", 
			$self->html_phrase( "indexer_stopped" ) 
		);
	}
	else
	{
		$self->{processor}->add_message( 
			"error", 
			$self->html_phrase( "cant_stop_indexer" ) 
		);
	}
}

sub allow_start_indexer
{
	my( $self ) = @_;
	return 0 if( EPrints::Index::is_running );
	return $self->allow( "indexer/start" );
}

sub action_start_indexer
{
	my( $self ) = @_;
	my $result = EPrints::Index::start( $self->{session} );

	if( $result == 1 )
	{
		$self->{processor}->add_message( 
			"message", 
			$self->html_phrase( "indexer_started" ) 
		);
	}
	else
	{
		$self->{processor}->add_message( 
			"error", 
			$self->html_phrase( "cant_start_indexer" ) 
		);
	}
}


1;
