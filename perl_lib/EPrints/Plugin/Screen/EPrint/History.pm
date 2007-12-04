package EPrints::Plugin::Screen::EPrint::History;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{expensive} = 1;
	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 600,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/history" );
}



sub render
{
	my( $self ) = @_;

	my ($data,$title) = $self->{processor}->{eprint}->render_history; 

	return $data;
}	

1;
