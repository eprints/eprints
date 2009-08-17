package EPrints::Plugin::Screen::Import::Commit;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub get_dataset_id { "import" }

sub get_view_screen { "Imports" }
sub get_save_screen { "Imports" }

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_deposit.png";

	$self->{appears} = [ ];

	$self->{actions} = [qw/ save /];

	return $self;
}

sub from
{
	my( $self ) = @_;

	my $action_id = $self->{processor}->{action};
	if( $action_id =~ m/^jump_(.*)$/ )
	{
		my $jump_to = $1;

		if( $jump_to eq "commit" )
		{
			return;
		}

		# not checking that this succeded. Maybe we should.
		$self->{processor}->{screenid} = $self->get_edit_screen();
		$self->workflow->set_stage( $jump_to );
		return;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub render
{
	my( $self ) = @_;

	my $problems = $self->{processor}->{dataobj}->validate( $self->{processor}->{for_archive} );
	if( scalar @{$problems} > 0 )
	{
		my $dom_problems = $self->{handle}->make_element( "ul" );
		foreach my $problem_xhtml ( @{$problems} )
		{
			my $li = $self->{handle}->make_element( "li" );
			$li->appendChild( $problem_xhtml );
			$dom_problems->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $dom_problems, $self->get_edit_screen() );
		$self->{processor}->add_message( "warning", $dom_problems );
	}

	my $warnings = $self->{processor}->{dataobj}->get_warnings;
	if( scalar @{$warnings} > 0 )
	{
		my $dom_warnings = $self->{handle}->make_element( "ul" );
		foreach my $warning_xhtml ( @{$warnings} )
		{
			my $li = $self->{handle}->make_element( "li" );
			$li->appendChild( $warning_xhtml );
			$dom_warnings->appendChild( $li );
		}
		$self->workflow->link_problem_xhtml( $dom_warnings, $self->get_edit_screen() );
		$self->{processor}->add_message( "warning", $dom_warnings );
	}


	my $page = $self->{handle}->make_doc_fragment;
	my $form = $self->render_form;
	$page->appendChild( $form );

	my $blister = $self->render_blister( "commit", 0 );
	my $toolbox = $self->{handle}->render_toolbox( undef, $blister );
	$form->appendChild( $toolbox );


	if( scalar @{$problems} == 0 )
	{
		$form->appendChild( $self->{handle}->render_action_buttons(
			save => $self->phrase( "save" ),
			_order => [qw( save )],
		) );
	}

	return $page;
}

sub action_save
{
	my( $self ) = @_;

	$self->uncache_workflow;

	$self->{processor}->{screenid} = $self->get_view_screen();
}

1;
