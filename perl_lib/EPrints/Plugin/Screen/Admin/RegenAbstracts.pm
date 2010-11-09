package EPrints::Plugin::Screen::Admin::RegenAbstracts;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ regen_abstracts /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions_system", 
			position => 1260, 
			action => "regen_abstracts",
		},
	];

	return $self;
}

sub allow_regen_abstracts
{
	my( $self ) = @_;

	return $self->allow( "config/regen_abstracts" );
}

sub action_regen_abstracts
{
	my( $self ) = @_;

	my $session = $self->{session};
	
	unless( $session->expire_abstracts() )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "failed" ) );
		$self->{processor}->{screenid} = "Admin";
		return;
	}
	
	$self->{processor}->add_message( "message",
		$self->html_phrase( "ok" ) );
	$self->{processor}->{screenid} = "Admin";
}	




1;
