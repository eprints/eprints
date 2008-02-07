package EPrints::Plugin::Screen::Admin::IndexerControl;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ start_indexer force_start_indexer stop_indexer /]; 

	$self->{appears} = [
		{ 
			place => "admin_actions", 	
			action => "start_indexer",
			position => 1100, 
		},
		{ 
			place => "admin_actions", 	
			action => "force_start_indexer",
			position => 1100, 
		},
		{ 
			place => "admin_actions", 	
			action => "stop_indexer",
			position => 1100, 
		},
	];

	$self->{daemon} = EPrints::Index::Daemon->new(
		session => $self->{session},
		Handler => $self->{processor},
		logfile => EPrints::Index::logfile(),
		noise => ($self->{session}->{noise}||1),
	);

	return $self;
}

sub get_daemon
{
	my( $self ) = @_;
	return $self->{daemon};
}

sub about_to_render
{
	my( $self ) = @_;
	$self->{processor}->{screenid} = "Admin";
}

sub allow_stop_indexer
{
	my( $self ) = @_;

	return 0 if( !$self->get_daemon->is_running || $self->get_daemon->has_stalled );
	return $self->allow( "indexer/stop" );
}

sub action_stop_indexer
{
	my( $self ) = @_;

	my $result = $self->get_daemon->stop( $self->{session} );

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
			$self->html_phrase( "cant_stop_indexer", 
				logpath => $self->{session}->make_text( EPrints::Index::logfile() ) 
			)
		);
	}
}

sub allow_start_indexer
{
	my( $self ) = @_;

	return 0 if( $self->get_daemon->is_running() );

	return $self->allow( "indexer/start" );
}

sub action_start_indexer
{
	my( $self ) = @_;

	my $result = $self->get_daemon->start( $self->{session} );

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
			$self->html_phrase( "cant_start_indexer", 
				logpath => $self->{session}->make_text( EPrints::Index::logfile() ) 
			)
		);
	}
}

sub allow_force_start_indexer
{
	my( $self ) = @_;
	return 0 if( !EPrints::Index::has_stalled() );
	return $self->allow( "indexer/force_start" );
}

sub action_force_start_indexer
{
	my( $self ) = @_;
	my $result = EPrints::Index::force_start( $self->{session} );

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
			$self->html_phrase( "cant_start_indexer", logpath => EPrints::Index::logfile() ) 
		);
	}
}


1;
