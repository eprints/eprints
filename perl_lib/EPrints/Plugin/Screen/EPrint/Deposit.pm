=head1 NAME

EPrints::Plugin::Screen::EPrint::Deposit

=cut

package EPrints::Plugin::Screen::EPrint::Deposit;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_deposit.png";

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 100,
		},
		{ 
			place => "eprint_actions_bar_inbox", 
			position => 100, 
		},
		{
			place => "eprint_item_actions",
			position => 300,
		},
	];

	$self->{actions} = [qw/ deposit move_buffer move_archive save /];

	return $self;
}

sub from
{
	my( $self ) = @_;

	my $action_id = $self->{processor}->{action};
	if( $action_id =~ m/^jump_(.*)$/ )
	{
		my $jump_to = $1;

		if( $jump_to eq "deposit" )
		{
			return;
		}

		# not checking that this succeeded. Maybe we should.
		$self->{processor}->{screenid} = "EPrint::Edit";
		$self->workflow->set_stage( $jump_to );
		return;
	}

	$self->{processor}->{skip_buffer} = $self->{session}->config( "skip_buffer" ) || 0;	

	$self->EPrints::Plugin::Screen::from;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->obtain_eprint_lock;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};
	return 0 unless $self->could_obtain_eprint_lock;
	return 0 unless $self->{processor}->{eprint}->get_value( "eprint_status" ) eq "inbox";

	return $self->allow( "eprint/deposit" );
}

sub render
{
	my( $self ) = @_;

	my $problems = $self->{processor}->{eprint}->validate( $self->{processor}->{for_archive}, $self->workflow_id );
	if( scalar @{$problems} > 0 )
	{
		my $dom_problems = $self->{session}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $self->{session}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$dom_problems->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $dom_problems, "EPrint::Edit" );
		$self->{processor}->add_message( "warning", $dom_problems );
	}

	my $warnings = $self->{processor}->{eprint}->get_warnings;
	if( scalar @{$warnings} > 0 )
	{
		my $dom_warnings = $self->{session}->make_element( "ul" );
		foreach my $warning_xhtml ( @{$warnings} )
		{
			my $li = $self->{session}->make_element( "li" );
			$li->appendChild( $warning_xhtml );
			$dom_warnings->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $dom_warnings, "EPrint::Edit" );
		$self->{processor}->add_message( "warning", $dom_warnings );
	}


	my $page = $self->{session}->make_doc_fragment;
	my $form = $self->render_form;
	$page->appendChild( $form );

	my $blister = $self->render_blister( "deposit", 0 );
	$form->appendChild( $blister );

	my $priv = $self->allow( "eprint/view" );
	my $owner  = $priv & 4;
	my $editor = $priv & 8;

	my $div = $self->{session}->make_element("div",class=>"ep_form_button_bar");

	if( scalar @{$problems} == 0 || $editor )
	{
		my $action = "deposit";

		if( scalar @{$problems} && $editor )
		{
			if( $self->{processor}->{skip_buffer} )
			{
				$action = "move_archive";
				$form->appendChild( $self->html_phrase( "action:move_archive:description" ) );
			}
			else
			{
				$action = "move_buffer";
				$form->appendChild( $self->html_phrase( "action:move_buffer:description" ) );
			}
		}

		$form->appendChild( $self->{session}->html_phrase( "deposit_agreement_text" ) );
	
		$div->appendChild( $self->{session}->render_action_buttons(
			$action => $self->{session}->phrase( "priv:action/eprint/deposit" ),
			save => $self->{session}->phrase( "priv:action/eprint/deposit_later" ),
			_order => [$action, "save"],
		) );
		
		$form->appendChild($div);
	}
	else
	{
		$form->appendChild( $self->html_phrase( "action:save:description" ) );

		$div->appendChild( $self->{session}->render_action_buttons(
			save => $self->{session}->phrase( "priv:action/eprint/deposit_later" ),
			_order => [qw( save )],
		) );

		$form->appendChild($div);
	}

	return $page;
}

sub allow_deposit
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_move_buffer
{
	my( $self ) = @_;

	return $self->allow( "eprint/move_buffer" );
}

sub allow_move_archive
{
	my( $self ) = @_;

	return $self->allow( "eprint/move_archive" );
}

sub allow_save
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_deposit
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";	

	my $problems = $self->{processor}->{eprint}->validate( $self->{processor}->{for_archive} );
	if( scalar @{$problems} > 0 )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "validation_errors" ) ); 
		my $warnings = $self->{session}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $self->{session}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$warnings->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $warnings, "EPrint::Edit" );
		$self->{processor}->add_message( "warning", $warnings );
		return;
	}

	# OK, no problems, submit it to the archive

	$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
	my $ok = 0;
	if( $self->{processor}->{skip_buffer} )
	{
		$ok = $self->{processor}->{eprint}->move_to_archive;
	}
	else
	{
		$ok = $self->{processor}->{eprint}->move_to_buffer;
	}

	if( $ok )
	{
		$self->{processor}->add_message( "message", $self->html_phrase( "item_deposited" ) );
		if( !$self->{processor}->{skip_buffer} ) 
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( "in_buffer" ) );
		}
	}
	else
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "item_not_deposited" ) );
	}
}

sub action_move_buffer
{
	my( $self ) = @_;

	$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
	$self->{processor}->{eprint}->commit;

	$self->uncache_workflow;

	$self->{processor}->{screenid} = "EPrint::Move";
	$self->{processor}->{redirect} = $self->redirect_to_me_url() . "&_action_move_buffer=1";
}

sub action_move_archive
{
	my( $self ) = @_;

	$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
	$self->{processor}->{eprint}->commit;

	$self->uncache_workflow;

	$self->{processor}->{screenid} = "EPrint::Move";
	$self->{processor}->{redirect} = $self->redirect_to_me_url() . "&_action_move_archive=1";
}

sub action_save
{
	my( $self ) = @_;

	$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
	$self->{processor}->{eprint}->commit;
	
	$self->uncache_workflow;

	$self->{processor}->{screenid} = "EPrint::View";
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

