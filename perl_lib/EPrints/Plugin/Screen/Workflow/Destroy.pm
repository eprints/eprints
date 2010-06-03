package EPrints::Plugin::Screen::Workflow::Destroy;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ remove cancel /];

	$self->{icon} = "action_remove.png";

	$self->{appears} = [
		{
			place => "dataobj_actions",
			position => 1600,
		},
		{
			place => "dataobj_view_actions",
			position => 1600,
		},
	];
	
	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( $self->{processor}->{dataset}->id."/destroy" );
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_delete",
		title=>$self->{processor}->{dataobj}->render_description() ) );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		remove => $self->{session}->phrase(
				"lib/submissionform:action_remove" ),
		_order => [ "remove", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = $self->view_screen;
}

sub action_remove
{
	my( $self ) = @_;

	if( !$self->{processor}->{dataobj}->remove )
	{
		$self->{processor}->add_message( "message", $self->html_phrase( "item_not_removed" ) );
		$self->{processor}->{screenid} = $self->view_screen;
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) );

	$self->{processor}->{screenid} = $self->listing_screen;
}

1;
