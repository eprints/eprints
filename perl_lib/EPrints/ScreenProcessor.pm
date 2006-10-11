package EPrints::ScreenProcessor;

use strict;

sub process
{
	my( $class, %opts ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{messages} = [];
	$self->{after_messages} = [];
	$self->{before_messages} = [];

	if( !defined $opts{session} ) 
	{
		EPrints::abort( "session not passed to EPrints::ScreenProcessor->process" );
	}

	foreach my $k ( keys %opts )
	{
		$self->{$k} = $opts{$k};
	}

	$self->{screenid} = $self->{session}->param( "screen" );
	$self->{screenid} = "FirstTool" unless EPrints::Utils::is_set( $self->{screenid} );

	# This loads the properties of what the screen is about,
	# Rather than parameters for the action, if any.
	$self->screen->properties_from; 
	
	$self->{action} = $self->{session}->get_action_button;
	$self->{internal} = $self->{session}->get_internal_button;
	delete $self->{action} if( $self->{action} eq "" );
	delete $self->{internal} if( $self->{internal} eq "" );

	if( !$self->screen->can_be_viewed )
	{
		$self->add_message( "error", $self->{session}->html_phrase( 
			"Plugin/Screen:screen_not_allowed",
			screen=>$self->{session}->make_text( $self->{screenid} ) ) );
		$self->{screenid} = "Error";
	}
	else
	{
		$self->screen->from;
	}

	if( defined $self->{redirect} )
	{
		$self->{session}->redirect( $self->{redirect} );
		return;
	}

	# used to swap to a different screen if appropriate
	$self->screen->about_to_render;
	
	# rendering

	if( !$self->screen->can_be_viewed )
	{
		$self->add_message( "error", $self->{session}->html_phrase( 
			"Plugin/Screen:screen_not_allowed",
			screen=>$self->{session}->make_text( $self->{screenid} ) ) );
		$self->{screenid} = "Error";
	}
	
	$self->screen->register_furniture;

	my $content = $self->screen->render;
	my $title = $self->screen->render_title;

	my $page = $self->{session}->make_doc_fragment;

	foreach my $chunk ( @{$self->{before_messages}} )
	{
		$page->appendChild( $chunk );
	}
	$page->appendChild( $self->render_messages );
	foreach my $chunk ( @{$self->{after_messages}} )
	{
		$page->appendChild( $chunk );
	}

	$page->appendChild( $content );

	$self->{session}->build_page( $title, $page );
	$self->{session}->send_page();
}

sub before_messages
{
	my( $self, $chunk ) = @_;

	push @{$self->{before_messages}},$chunk;
}

sub after_messages
{
	my( $self, $chunk ) = @_;

	push @{$self->{after_messages}},$chunk;
}

sub add_message
{
	my( $self, $type, $message ) = @_;

	push @{$self->{messages}},{type=>$type,content=>$message};
}


sub screen
{
	my( $self ) = @_;

	my $screen = $self->{screenid};
	my $plugin_id = "Screen::".$screen;
	$self->{screen} = $self->{session}->plugin( $plugin_id, processor=>$self );

	if( !defined $self->{screen} )
	{
		if( $screen ne "Error" )
		{
			$self->add_message( 
				"error", 
				$self->{session}->html_phrase( 
					"Plugin/Screen:unknown_screen",
					screen=>$self->{session}->make_text( $screen ) ) );
			$self->{screenid} = "Error";
			return $self->screen;
		}
	}

	return $self->{screen};
}

sub render_messages
{	
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	foreach my $message ( @{$self->{messages}} )
	{
		my $id = "m".$self->{session}->get_next_id;
		my $div = $self->{session}->make_element( "div", class=>"ep_msg_".$message->{type}, id=>$id );
		my $content_div = $self->{session}->make_element( "div", class=>"ep_msg_".$message->{type}."_content" );
		my $table = $self->{session}->make_element( "table" );
		my $tr = $self->{session}->make_element( "tr" );
		$table->appendChild( $tr );
		my $td1 = $self->{session}->make_element( "td" );
		$td1->appendChild( $self->{session}->make_element( "img", src=>"/style/images/".$message->{type}.".png", alt=>$self->{session}->phrase( "Plugin/Screen:message_".$message->{type} ) ) );
		$tr->appendChild( $td1 );
		my $td2 = $self->{session}->make_element( "td" );
		$tr->appendChild( $td2 );
		$td2->appendChild( $message->{content} );
		$content_div->appendChild( $table );
#		$div->appendChild( $title_div );
		$div->appendChild( $content_div );
		$chunk->appendChild( $div );
	}

	return $chunk;
}


sub action_not_allowed
{
	my( $self, $action ) = @_;

	$self->add_message( "error", $self->{session}->html_phrase( 
		"Plugin/Screen:action_not_allowed",
		action=>$action ) );
}


1;
