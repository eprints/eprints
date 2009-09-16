
package EPrints::Plugin::Screen::Workflow;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub get_view_screen
{
	my( $self ) = @_;

	my $screenid = $self->{id};
	$screenid =~ s/^Screen:://;
	$screenid =~ s/::[^:]+$/::View/;

	return $screenid;
}

sub get_edit_screen
{
	my( $self ) = @_;

	my $screenid = $self->{id};
	$screenid =~ s/^Screen:://;
	$screenid =~ s/::[^:]+$/::Edit/;

	return $screenid;
}

sub get_commit_screen
{
	my( $self ) = @_;

	my $screenid = $self->{id};
	$screenid =~ s/^Screen:://;
	$screenid =~ s/::[^:]+$/::Commit/;

	return $screenid;
}

sub get_save_screen
{
	my( $self ) = @_;

	my $screenid = $self->{id};
	$screenid =~ s/^Screen:://;
	$screenid =~ s/::[^:]+$/::Save/;

	return $screenid;
}

sub get_dataset_id
{
	my( $class ) = @_;

	Carp::croak( "get_dataset_id must be overriden by $class" );
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	my $dataset = $self->{session}->get_repository->get_dataset(
			$self->get_dataset_id()
		);
	my $key_field = $dataset->get_key_field();

	my $id = $self->{session}->param( "dataobj_id" );

	$processor->{"dataset"} = $dataset;
	$processor->{"dataobj_id"} = $id;
	$processor->{"dataobj"} = $dataset->get_object( $self->{session}, $id );

	if( !defined $processor->{"dataobj"} )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $self->{session}->html_phrase(
			"Plugin/Screen/Workflow:cant_find_it",
			dataset=>$self->{session}->make_text( $dataset->confid ),
			id=>$self->{session}->make_text( $id ) ) );
		return;
	}

	$self->SUPER::properties_from;
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{"dataobj"};

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv, $self->{processor}->{"dataobj"} );
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( $self->get_dataset_id()."/edit" );
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

sub render_tab_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub render_title
{
	my( $self ) = @_;

	my $priv = $self->allow( $self->get_dataset_id()."/view" );

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "title" ) );
	$f->appendChild( $self->{session}->make_text( ": " ) );

	my $screen = $self->get_view_screen();

	my $title = $self->{session}->make_text( $self->{processor}->{"dataobj_id"} );
	my $a = $self->{session}->render_link( "?screen=$screen&dataobj_id=".$self->{processor}->{"dataobj_id"} );
	$a->appendChild( $title );
	$f->appendChild( $a );
	return $f;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&dataobj_id=".$self->{processor}->{dataobj_id};
}

sub workflow
{
	my( $self, $staff ) = @_;

	my $cache_id = "workflow";

	if( !defined $self->{processor}->{$cache_id} )
	{
		my %opts = ( item=> $self->{processor}->{"dataobj"}, session=>$self->{session} );
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( $self->{session}, "default", %opts );
	}

	return $self->{processor}->{$cache_id};
}

sub uncache_workflow
{
	my( $self ) = @_;

	delete $self->{session}->{id_counter};
	delete $self->{processor}->{workflow};
	delete $self->{processor}->{workflow_staff};
}

sub render_blister
{
	my( $self, $sel_stage_id, $staff_mode ) = @_;

	my $session = $self->{session};
	my $staff = 0;

	my $workflow = $self->workflow( $staff_mode );
	my $table = $session->make_element( "table", cellpadding=>0, cellspacing=>0, class=>"ep_blister_bar" );
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	my $first = 1;
	my @stages = $workflow->get_stage_ids;
	push @stages, "commit";
	foreach my $stage_id ( @stages )
	{
		if( !$first )  
		{ 
			my $td = $session->make_element( "td", class=>"ep_blister_join" );
			$tr->appendChild( $td );
		}
		
		my $td;
		$td = $session->make_element( "td" );
		my $class = "ep_blister_node";
		if( $stage_id eq $sel_stage_id ) 
		{ 
			$class="ep_blister_node_selected"; 
		}
		my $phrase;
		if( $stage_id eq "commit" )
		{
			$phrase = $session->phrase( "Plugin/Screen/MetaField:commit" );
		}
		else
		{
			$phrase = $session->phrase( "metapage_title_".$stage_id );
		}
		my $button = $session->render_button(
			name  => "_action_jump_$stage_id", 
			value => $phrase,
			class => $class );

		$td->appendChild( $button );
		$tr->appendChild( $td );
		$first = 0;
	}

	return $table;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "dataobj_id", $self->{processor}->{"dataobj_id"} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}
1;

