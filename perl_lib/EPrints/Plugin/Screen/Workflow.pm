
package EPrints::Plugin::Screen::Workflow;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
#		{
#			place => "import_item_actions",
#			position => 200,
#		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub view_screen
{
	my( $self ) = @_;

	return "Workflow::View";
}

sub edit_screen
{
	my( $self ) = @_;

	return "Workflow::Edit";
}

sub listing_screen
{
	my( $self ) = @_;

	return "Listing";
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" );
	my $id = $session->param( "dataobj" );

	my $dataset = $self->{processor}->{dataset};
	$dataset = $session->dataset( $datasetid ) if !defined $dataset;
	if( !defined $dataset )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $session->html_phrase(
			"lib/history:no_such_item",
			datasetid=>$session->make_text( $datasetid ),
			objectid=>$session->make_text( $id ) ) );
		return;
	}

	$processor->{"dataset"} = $dataset;

	my $dataobj = $self->{processor}->{dataobj};
	$dataobj = $dataset->dataobj( $id ) if !defined $dataobj;
	if( !defined $dataobj )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $session->html_phrase(
			"lib/history:no_such_item",
			datasetid=>$session->make_text( $datasetid ),
			objectid=>$session->make_text( $id ) ) );
		return;
	}

	$processor->{"dataobj"} = $dataset->dataobj( $id );

	my $plugin = $self->{session}->plugin(
		"Screen::" . $self->edit_screen,
		processor => $self->{processor},
		);
	$self->{processor}->{can_be_edited} = $plugin->can_be_viewed();

	$self->SUPER::properties_from;
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{dataobj};

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv, $self->{processor}->{dataobj} );
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( $self->{processor}->{dataset}->id."/edit" );
}

sub allow_action
{
	my( $self, $action ) = @_;

	return $self->can_be_viewed();
}

sub dataset
{
	my( $self ) = @_;

	return $self->{processor}->{dataset};
}

sub dataobj
{
	my( $self ) = @_;

	return $self->{processor}->{dataobj};
}

sub render_tab_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $url = $self->SUPER::redirect_to_me_url;
	$url .= "&dataset=".$self->{processor}->{dataset}->id if defined $self->{processor}->{dataset};
	$url .= "&dataobj=".$self->{processor}->{dataobj}->id if defined $self->{processor}->{dataobj};

	return $url;
}

sub has_workflow
{
	my( $self ) = @_;

	my $xml = $self->{session}->get_workflow_config( $self->{processor}->{dataset}->base_id, "default" );

	return defined $xml;
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
	foreach my $stage_id ( @stages )
	{
		my $stage = $workflow->get_stage( $stage_id );

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
		my $title = $stage->render_title();
		my $button = $session->render_button(
			name  => "_action_jump_$stage_id", 
			value => $session->xhtml->to_text_dump( $title ),
			class => $class );
		$session->xml->dispose( $title );

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

	$chunk->appendChild( $self->{session}->render_hidden_field( "dataset", $self->{processor}->{dataset}->id ) );
	$chunk->appendChild( $self->{session}->render_hidden_field( "dataobj", $self->{processor}->{dataobj}->id ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

sub _render_action_aux
{
	my( $self, $params, $asicon ) = @_;
	
	my $session = $self->{session};
	
	my $method = "GET";	
	if( defined $params->{action} )
	{
		$method = "POST";
	}

	my $form = $session->render_form( $method, $session->current_url( path => "cgi" ) . "/users/home" );

	$form->appendChild( 
		$session->render_hidden_field( 
			"screen", 
			substr( $params->{screen_id}, 8 ) ) );
	foreach my $id ( keys %{$params->{hidden}} )
	{
		$form->appendChild( 
			$session->render_hidden_field( 
				$id, 
				$params->{hidden}->{$id} ) );
	}
	my( $action, $title, $icon );
	if( defined $params->{action} )
	{
		$action = $params->{action};
		$title = $params->{screen}->phrase( "action:$action:title" );
		$icon = $params->{screen}->action_icon_url( $action );
	}
	else
	{
		$action = "null";
		$title = $params->{screen}->phrase( "title" );
		$icon = $params->{screen}->icon_url();
	}
	if( defined $icon && $asicon )
	{
		$form->appendChild( 
			$session->make_element(
				"input",
				type=>"image",
				class=>"ep_form_action_icon",
				name=>"_action_$action", 
				src=>$icon,
				title=>$title,
				alt=>$title,
				value=>$title ));
	}
	else
	{
		$form->appendChild( 
			$session->render_button(
				class=>"ep_form_action_button",
				name=>"_action_$action", 
				value=>$title ));
	}

	return $form;
}

1;

