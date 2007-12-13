package EPrints::Plugin::Screen::QA;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "key_tools",
			position => 1050,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless scalar $self->action_list( "qa_actions" );
	return 1;
}

sub render
{
	my( $self ) = @_;
	return $self->render_action_list( "qa_actions" );
}

1;
