package EPrints::Plugin::Screen::MetaField::Commit;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use EPrints::Plugin::Screen::Admin::Reload;

use strict;

sub get_dataset_id { "metafield" }

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_deposit.png";

	$self->{appears} = [ ];

	$self->{actions} = [qw/ commit save /];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	$self->{processor}->{dataset} = $self->{processor}->{dataobj}->get_dataset;
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
		$self->{processor}->{screenid} = "MetaField::Edit";
		$self->workflow->set_stage( $jump_to );
		return;
	}

	$self->EPrints::Plugin::Screen::from;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "metafield/edit" );
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
		$self->workflow->link_problem_xhtml( $dom_problems, "MetaField::Edit" );
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
		$self->workflow->link_problem_xhtml( $dom_warnings, "MetaField::Edit" );
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
		$form->appendChild( $self->html_phrase( "commit_help" ) );
	
		$form->appendChild( $self->{handle}->render_action_buttons(
			commit => $self->{handle}->phrase( "priv:action/metafield/commit" ),
			save => $self->{handle}->phrase( "priv:action/metafield/save" ),
			_order => [qw( commit save )],
		) );
	}

	return $page;
}

sub allow_commit
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_save
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_commit
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "MetaField::View";
	$self->{processor}->{datasetid} = $self->{processor}->{dataobj}->get_value( "mfdatasetid" );

	my $problems = $self->{processor}->{dataobj}->validate( $self->{processor}->{for_archive} );
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
		$self->workflow->link_problem_xhtml( $warnings, "MetaField::Edit" );
		$self->{processor}->add_message( "warning", $warnings );
		return;
	}

	# OK, no problems, submit it to the archive

	my $ok = 1; # TODO write it to the config file!

	my $dataobj = $self->{processor}->{dataobj};
	$ok &&= $dataobj->move_to_archive();
	$ok &&= EPrints::DataObj::MetaField::save_all( $self->{handle} );

	if( !$dataobj->add_to_phrases() )
	{
		$self->{processor}->add_message( "warning", $self->html_phrase( "add_to_phrases_failed" ) );
	}

	if( !$dataobj->add_to_workflow() )
	{
		$self->{processor}->add_message( "warning", $self->html_phrase( "add_to_workflow_failed" ) );
	}

	if( $ok )
	{
		$self->{processor}->add_message( "message", $self->html_phrase( "metafield_committed",
			fieldid => $self->{handle}->make_text( $dataobj->get_value( "name" ) ),
			datasetid => $self->{handle}->make_text( $dataobj->get_value( "mfdatasetid" ) )
		) );

		if( my $plugin = $self->{handle}->plugin( "Screen::Admin::Reload" ) )
		{
			my $screenid = $self->{processor}->{screenid};
			$plugin->{processor} = $self->{processor};
			$plugin->action_reload_config;
			$plugin->{processor}->{screenid} = $screenid;
		}
	}
	else
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "commit_failed" ) );
	}
}

sub action_save
{
	my( $self ) = @_;

	$self->uncache_workflow;

	$self->{processor}->{screenid} = "MetaField::View";
	$self->{processor}->{datasetid} = $self->{processor}->{dataobj}->get_value( "mfdatasetid" );
}

1;
