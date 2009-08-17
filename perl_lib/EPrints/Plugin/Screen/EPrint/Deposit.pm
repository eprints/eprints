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
			place => "eprint_actions_owner_inbox", 
			position => 100, 
		},
		{
			place => "eprint_item_actions",
			position => 300,
		},
	];

	$self->{actions} = [qw/ deposit save /];

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

		# not checking that this succeded. Maybe we should.
		$self->{processor}->{screenid} = "EPrint::Edit";
		$self->workflow->set_stage( $jump_to );
		return;
	}

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
		my $dom_problems = $self->{handle}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $self->{handle}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$dom_problems->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $dom_problems, "EPrint::Edit" );
		$self->{processor}->add_message( "warning", $dom_problems );
	}

	my $warnings = $self->{processor}->{eprint}->get_warnings;
	if( scalar @{$warnings} > 0 )
	{
		my $dom_warnings = $self->{handle}->make_element( "ul" );
		foreach my $warning_xhtml ( @{$warnings} )
		{
			my $li = $self->{handle}->make_element( "li" );
			$li->appendChild( $warning_xhtml );
			$dom_warnings->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $dom_warnings, "EPrint::Edit" );
		$self->{processor}->add_message( "warning", $dom_warnings );
	}


	my $page = $self->{handle}->make_doc_fragment;
	my $form = $self->render_form;
	$page->appendChild( $form );

	my $blister = $self->render_blister( "deposit", 0 );
	my $toolbox = $self->{handle}->render_toolbox( undef, $blister );
	$form->appendChild( $toolbox );


	if( scalar @{$problems} == 0 )
	{
		$form->appendChild( $self->{handle}->html_phrase( "deposit_agreement_text" ) );
	
		$form->appendChild( $self->{handle}->render_action_buttons(
			deposit => $self->{handle}->phrase( "priv:action/eprint/deposit" ),
			save => $self->{handle}->phrase( "priv:action/eprint/deposit_later" ),
			_order => [qw( deposit save )],
		) );
	}

	return $page;
}

sub allow_deposit
{
	my( $self ) = @_;

	return $self->can_be_viewed;
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
		my $warnings = $self->{handle}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $self->{handle}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$warnings->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $warnings, "EPrint::Edit" );
		$self->{processor}->add_message( "warning", $warnings );
		return;
	}

	# OK, no problems, submit it to the archive

	my $sb = $self->{handle}->get_repository->get_conf( "skip_buffer" ) || 0;	
	my $ok = 0;
	if( $sb )
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
		if( !$sb ) 
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( "in_buffer" ) );
		}
	}
	else
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "item_not_deposited" ) );
	}
}

sub action_save
{
	my( $self ) = @_;

	$self->uncache_workflow;

	$self->{processor}->{screenid} = "EPrint::View";
}

1;
