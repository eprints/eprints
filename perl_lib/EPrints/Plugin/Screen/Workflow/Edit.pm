package EPrints::Plugin::Screen::Workflow::Edit;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{icon} = "action_edit.png";

	$self->{appears} = [
		{
			place => "dataobj_actions",
			position => 250,
		},
		{
			place => "dataobj_view_actions",
			position => 250,
		},
	];

	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 if !$self->has_workflow();

	return $self->allow( $self->{processor}->{dataset}->id."/edit" );
}

sub from
{
	my( $self ) = @_;


	if( defined $self->{processor}->{internal} )
	{
		$self->workflow->update_from_form( $self->{processor}, undef, 1 );
		$self->uncache_workflow;
		return;
	}

	my $action_id = $self->{processor}->{action};
	if( $action_id =~ m/^jump_(.*)$/ )
	{
		my $jump_to = $1;

		if( defined $self->{session}->param( "stage" ) )
		{
			$self->workflow->update_from_form( $self->{processor},$jump_to );
			$self->uncache_workflow;
		}

		if( $jump_to eq "commit" )
		{
			$self->{processor}->{screenid} = $self->screen_after_flow;
			return;
		}

		$self->workflow->set_stage( $jump_to );

		# not checking that this succeded. Maybe we should.
		return;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub action_stop
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Workflow::View";
}	

sub action_save
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;

	$self->{processor}->{screenid} = "Workflow::View";
}


sub allow_prev
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}
	
sub action_prev
{
	my( $self ) = @_;

	$self->workflow->update_from_form( $self->{processor}, $self->workflow->get_prev_stage_id );
	$self->uncache_workflow;

	$self->workflow->prev;
}

sub action_next
{
	my( $self ) = @_;

	my $from_ok = $self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;

	return unless $from_ok;

	if( !defined $self->workflow->get_next_stage_id )
	{
		$self->{processor}->{screenid} = $self->screen_after_flow;
		return;
	}

	$self->workflow->next;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url.$self->workflow->get_state_params( $self->{processor} );
}

sub screen_after_flow
{
	my( $self ) = @_;

	return "Workflow::Commit";
}

sub render
{
	my( $self ) = @_;

	my $form = $self->render_form;

	my $blister = $self->render_blister( $self->workflow->get_stage_id, 0 );
	my $toolbox = $self->{session}->render_toolbox( undef, $blister );
	$form->appendChild( $toolbox );

	$form->appendChild( $self->render_buttons );
	$form->appendChild( $self->workflow->render );
	$form->appendChild( $self->render_buttons );
	
	return $form;
}


sub render_buttons
{
	my( $self ) = @_;

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	if( defined $self->workflow->get_prev_stage_id )
	{
		push @{$buttons{_order}}, "prev";
		$buttons{prev} = 
			$self->{session}->phrase( "lib/submissionform:action_prev" );
	}

	push @{$buttons{_order}}, "save";
	$buttons{save} = 
		$self->{session}->phrase( "lib/submissionform:action_save" );

	push @{$buttons{_order}}, "next";
	$buttons{next} = 
		$self->{session}->phrase( "lib/submissionform:action_next" );

	return $self->{session}->render_action_buttons( %buttons );
}

1;
