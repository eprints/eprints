package EPrints::Plugin::Screen::EPrint::Edit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{icon} = "action_edit.png";

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 1500,
		},
		{
			place => "eprint_item_actions",
			position => 200,
		},
		{
			place => "eprint_review_actions",
			position => 100,
		},
	];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->obtain_eprint_lock;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless $self->could_obtain_eprint_lock;

	return $self->allow( "eprint/edit" );
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
	if( defined $action_id && $action_id =~ m/^jump_(.*)$/ )
	{
		my $jump_to = $1;

		if( defined $self->{session}->param( "stage" ) )
		{
			$self->workflow->update_from_form( $self->{processor},$jump_to );
			$self->uncache_workflow;
		}

		if( $jump_to eq "deposit" )
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

sub allow_stop
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_stop
{
	my( $self ) = @_;

	# reload to discard changes
	$self->{processor}->{eprint} = new EPrints::DataObj::EPrint( $self->{session}, $self->{processor}->{eprintid} );
	$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
	$self->{processor}->{eprint}->commit;

	$self->{processor}->{screenid} = "EPrint::View";
}	


sub allow_save
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_save
{
	my( $self ) = @_;

	$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
	$self->workflow->update_from_form( $self->{processor} );
	$self->uncache_workflow;

	$self->{processor}->{screenid} = "EPrint::View";

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


sub allow_next
{
	my( $self ) = @_;

	return $self->can_be_viewed;
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
		if( $self->{processor}->{screenid} eq "EPrint::View" )
		{
			$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
			$self->{processor}->{eprint}->commit;
		}
		
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

	my $eprint = $self->{processor}->{eprint};

	if( $eprint->get_value( "eprint_status" ) eq "inbox" )
	{
		return "EPrint::Deposit";
	}
	else
	{
		return "EPrint::View";
	}
}


sub render
{
	my( $self ) = @_;

	my $cur_stage_id = $self->workflow->get_stage_id;
	my $stage = $self->workflow->get_stage( $cur_stage_id );

	my $form = $self->render_form;

	my $blister = $self->render_blister( $cur_stage_id );
	$form->appendChild( $blister );

	my $action_buttons = $stage->{action_buttons};

	if( $action_buttons eq "top" || $action_buttons eq "both" )
	{
		$form->appendChild( $self->render_buttons );
	}
	$form->appendChild( $self->workflow->render );
	if( $action_buttons eq "bottom" || $action_buttons eq "both" )
	{
		$form->appendChild( $self->render_buttons );
	}
	
	return $form;
}


sub render_buttons
{
	my( $self ) = @_;

	my $session = $self->{session};

	my %buttons = ( _order=>[], _class=>"ep_form_button_bar" );

	if( defined $self->workflow->get_prev_stage_id )
	{
		push @{$buttons{_order}}, "prev";
		$buttons{prev} = $session->phrase( "lib/submissionform:action_prev" );
	}

	my $eprint = $self->{processor}->{eprint};
	if( $eprint->value( "eprint_status" ) eq "inbox" )
	{
		push @{$buttons{_order}}, "save";
		$buttons{save} = $session->phrase( "lib/submissionform:action_save" );
	}
	else
	{
		push @{$buttons{_order}}, "save";
		$buttons{save} = $session->phrase( "lib/submissionform:action_staff_save" );
	}

	push @{$buttons{_order}}, "stop";
	$buttons{stop} = $session->phrase( "lib/submissionform:action_stop" );

	push @{$buttons{_order}}, "next";
	$buttons{next} = $session->phrase( "lib/submissionform:action_next" );

	return $session->render_action_buttons( %buttons );
}

1;
