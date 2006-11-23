package EPrints::Plugin::Screen::Admin::Reload;

@ISA = ( 'EPrints::Plugin::Screen::Status' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ reload_config /]; 
		
	$self->{appears} = [
		{ 
			place => "config_actions", 	
			action => "reload_config",
			position => 1200, 
		},
	];

	return $self;
}

sub allow_reload_config
{
	my( $self ) = @_;
	return 1;
}

sub action_reload_config
{
	my( $self ) = @_;
}


1;
