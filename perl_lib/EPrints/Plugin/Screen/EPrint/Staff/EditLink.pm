package EPrints::Plugin::Screen::EPrint::Staff::EditLink;

use EPrints::Plugin::Screen::EPrint::EditLink;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::EditLink' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 400,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/staff/edit" );
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", style=>"padding-top: 4em; padding-bottom: 4em" );
	my $form = $self->{session}->render_form( "get" );
	$div->appendChild( $form );
	$form->appendChild( 
		$self->{session}->render_hidden_field( "screen", "EPrint::Staff::Edit" ) );
	$form->appendChild( 
		$self->{session}->render_hidden_field( 
			"eprintid", 
			$self->{processor}->{eprintid} ) );
	$form->appendChild( $self->render_blister( "", 1 ) );
	return $div;
}


1;

