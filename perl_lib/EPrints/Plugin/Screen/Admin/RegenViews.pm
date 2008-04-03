package EPrints::Plugin::Screen::Admin::RegenViews;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ regen_views /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1270, 
			action => "regen_views",
		},
	];

	return $self;
}

sub allow_regen_views
{
	my( $self ) = @_;

	return $self->allow( "config/regen_views" );
}

sub action_regen_views
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $file = $session->get_repository->get_conf( "variables_path" )."/views.timestamp";
	unless( open( CHANGEDFILE, ">$file" ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "failed" ) );
		$self->{processor}->{screenid} = "Admin";
		return;
	}
	print CHANGEDFILE "This file last poked at: ".EPrints::Time::human_time()."\n";
	close CHANGEDFILE;

	$self->{processor}->add_message( "message",
		$self->html_phrase( "ok" ) );
	$self->{processor}->{screenid} = "Admin";
}	




1;
