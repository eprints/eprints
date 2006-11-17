package EPrints::Plugin::Screen::EPrint::UseAsTemplate;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	#	$self->{priv} = # no specific priv - one per action

	$self->{actions} = [qw/ use_as_template /];

	$self->{appears} = [
{ place => "eprint_actions", 	action => "use_as_template", 	position => 500, },
	];

	return $self;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub allow_use_as_template
{
	my( $self ) = @_;

	return $self->allow( "eprint/use_as_template" );
}

sub action_use_as_template
{
	my( $self ) = @_;

	my $inbox_ds = $self->{session}->get_archive()->get_dataset( "inbox" );
	my $copy = $self->{processor}->{eprint}->clone( $inbox_ds, 0, 1 );
	$copy->set_value( "userid", $self->{session}->current_user->get_value( "userid" ) );
	$copy->commit();

	$self->{processor}->add_message( "message",
		$self->html_phrase( "success" ) );

	$self->{processor}->{eprint} = $copy;
	$self->{processor}->{eprintid} = $copy->get_id;
}


1;
