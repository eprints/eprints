######################################################################
#
# EPrints::Script
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::ScreenProcessor;

use strict;

=item $processor = EPrints::ScreenProcessor->new( %opts )

=cut

sub new
{
	my( $class, %self ) = @_;

	$self{messages} = [];
	$self{after_messages} = [];
	$self{before_messages} = [];

	if( !defined $self{handle} ) 
	{
		EPrints::abort( "session not passed to EPrints::ScreenProcessor->process" );
	}

	my $self = bless \%self, $class;

	return $self;
}

=item EPrints::ScreenProcessor->process( %opts )

Process and send a response to a Web request.

=cut

sub process
{
	my( $class, %opts ) = @_;

	my $self = $class->new( %opts );

	if( !defined $self->{screenid} ) 
	{
		$self->{screenid} = $self->{handle}->param( "screen" );
	}
	if( !defined $self->{screenid} ) 
	{
		$self->{screenid} = "FirstTool";
	}

	# This loads the properties of what the screen is about,
	# Rather than parameters for the action, if any.
	$self->screen->properties_from; 
	
	$self->{action} = $self->{handle}->get_action_button;
	$self->{internal} = $self->{handle}->get_internal_button;
	delete $self->{action} if( $self->{action} eq "" );
	delete $self->{internal} if( $self->{internal} eq "" );

	if( !$self->screen->can_be_viewed )
	{
		$self->screen->register_error;
		$self->{screenid} = "Error";
	}
	elsif( !$self->screen->obtain_edit_lock )
	{
		$self->add_message( "error", $self->{handle}->html_phrase( 
			"Plugin/Screen:item_locked" ) );
		$self->{screenid} = "Error";
	}
	else
	{
		$self->screen->from;
	}

	if( defined $self->{redirect} )
	{
		$self->{handle}->redirect( $self->{redirect} );
		return;
	}

	# used to swap to a different screen if appropriate
	$self->screen->about_to_render;

	my $current_user = $self->{handle}->current_user;
	if( $ENV{REQUEST_METHOD} eq "POST" && defined $current_user )
	{
		my $url = $self->screen->redirect_to_me_url;
		if( defined $url )
		{
			foreach my $message ( @{$self->{messages}} )
			{
				$self->{handle}->get_database->save_user_message( 
					$current_user->get_id,
					$message->{type},
					$message->{content} );
			}
			$self->{handle}->redirect( $url );
			return;
		}
	}
		
	
	# rendering

	if( !$self->screen->can_be_viewed )
	{
		$self->add_message( "error", $self->{handle}->html_phrase( 
			"Plugin/Screen:screen_not_allowed",
			screen=>$self->{handle}->make_text( $self->{screenid} ) ) );
		$self->{screenid} = "Error";
	}
	elsif( !$self->screen->obtain_view_lock )
	{
		$self->add_message( "error", $self->{handle}->html_phrase( 
			"Plugin/Screen:item_locked" ) );
		$self->{screenid} = "Error";
	}

	# XHTML or special format?
	
	if( $self->screen->wishes_to_export )
	{
		$self->{handle}->send_http_header( "content_type"=>$self->screen->export_mimetype );
		$self->screen->export;
		return;
	}

	$self->screen->register_furniture;

	my $content = $self->screen->render;
	my $links = $self->screen->render_links;
#	my $toolbar = $self->{handle}->render_toolbar;
	my $title = $self->screen->render_title;

	my $page = $self->{handle}->make_doc_fragment;

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

	$self->{handle}->prepare_page(  
		{
			title => $title, 
			page => $page,
			head => $links,
#			toolbar => $toolbar,
		},
		template => $self->{template},
 	);
	$self->{handle}->send_page();
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
	$self->{screen} = $self->{handle}->plugin( $plugin_id, processor=>$self );

	if( !defined $self->{screen} )
	{
		if( $screen ne "Error" )
		{
			$self->add_message( 
				"error", 
				$self->{handle}->html_phrase( 
					"Plugin/Screen:unknown_screen",
					screen=>$self->{handle}->make_text( $screen ) ) );
			$self->{screenid} = "Error";
			return $self->screen;
		}
	}

	return $self->{screen};
}

sub render_messages
{	
	my( $self ) = @_;

	my $chunk = $self->{handle}->make_doc_fragment;

	my @old_messages;
	my $cuser = $self->{handle}->current_user;
	if( defined $cuser )
	{
		my $db = $self->{handle}->get_database;
		@old_messages = $db->get_user_messages( $cuser->get_id );
		$db->clear_user_messages( $cuser->get_id );
	}
	foreach my $message ( @old_messages, @{$self->{messages}} )
	{
		if( !defined $message->{content} )
		{
			# parse error!
			next;
		}
		my $dom_message = $self->{handle}->render_message( 
				$message->{type},
				$message->{content});
		$chunk->appendChild( $dom_message );
	}

	return $chunk;
}


sub action_not_allowed
{
	my( $self, $action ) = @_;

	$self->add_message( "error", $self->{handle}->html_phrase( 
		"Plugin/Screen:action_not_allowed",
		action=>$action ) );
}


1;
