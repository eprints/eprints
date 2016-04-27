=head1 NAME

EPrints::Plugin::Screen::EPrint::Edit

=cut

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

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	$self->{processor}->{stage} = $self->{session}->param( "stage" );
	$self->{processor}->{component} = $self->{session}->param( "component" );
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
		if( my $component = $self->current_component )
		{
			$component->update_from_form( $self->{processor} );
		}
		else
		{
			$self->workflow->update_from_form( $self->{processor}, undef, 1 );
		}
		$self->workflow->{item}->commit;
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

		# not checking that this succeeded. Maybe we should.
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

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->current_component->wishes_to_export($self->{processor})
		if $self->current_component;

	return $self->SUPER::wishes_to_export;
}

sub export_mimetype
{
	my( $self ) = @_;

	return $self->current_component->export_mimetype($self->{processor})
		if $self->current_component;

	return $self->SUPER::export_mimetype;
}

sub export
{
	my( $self ) = @_;

	return $self->current_component->export($self->{processor})
		if $self->current_component;

	return $self->SUPER::export;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef if $self->current_component;

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

	if( my $component = $self->current_component )
	{
		$form->appendChild( $component->render );
		return $form;
	}

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

sub current_component
{
	my( $self ) = @_;

	return unless $self->{processor}->{component};
	my $stage = $self->workflow->get_stage( $self->workflow->get_stage_id );
	return unless $stage;
	foreach my $component ($stage->get_components)
	{
		return $component if $component->{prefix} eq $self->{processor}->{component};
	}
	return undef;
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		stage => $self->workflow->get_stage_id,
	);
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

