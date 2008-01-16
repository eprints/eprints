package EPrints::Plugin::Screen::Admin::Reload;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ reload_config /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1250, 
			action => "reload_config",
		},
	];

	return $self;
}

sub allow_reload_config
{
	my( $self ) = @_;

	return $self->allow( "config/reload" );
}

sub action_reload_config
{
	my( $self ) = @_;

	my $session = $self->{session};

	my( $result, $msg ) = $session->get_repository->test_config;

	if( $result != 0 )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( 
				"reload_bad_config",
				output=>$self->{session}->make_text( $msg ) ) );
		$self->{processor}->{screenid} = "Admin";
		return;
	}

	my $file = $session->get_repository->get_conf( "variables_path" )."/last_changed.timestamp";
	unless( open( CHANGEDFILE, ">$file" ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "reload_write_failed" ) );
		$self->{processor}->{screenid} = "Admin";
		return;
	}
	print CHANGEDFILE "This file last poked at: ".EPrints::Time::human_time()."\n";
	close CHANGEDFILE;

	$self->{processor}->add_message( "message",
		$self->html_phrase( "reloaded" ) );
	$self->{processor}->{screenid} = "Admin";
}	




1;
