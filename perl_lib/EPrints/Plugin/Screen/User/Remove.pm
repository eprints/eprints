package EPrints::Plugin::Screen::User::Remove;

our @ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "user_actions",
			position => 1600,
		}
	];
	
	$self->{actions} = [qw/ remove cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/remove" );
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{handle}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_delete", 
		title=>$self->{processor}->{user}->render_description() ) );

	my %buttons = (
		cancel => $self->{handle}->phrase(
				"lib/submissionform:action_cancel" ),
		remove => $self->{handle}->phrase(
				"lib/submissionform:action_remove" ),
		_order => [ "remove", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{handle}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub allow_remove
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "User::View";
}

sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "FirstTool";

	if( !$self->{processor}->{user}->remove )
	{
		my $db_error = $self->{handle}->get_database->error;
		$self->{handle}->get_repository->log( "DB error removing User ".$self->{processor}->{user}->get_value( "userid" ).": $db_error" );
		$self->{processor}->add_message( "message", $self->html_phrase( "user_not_removed" ) );
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "user_removed" ) );
}


1;
