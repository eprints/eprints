
package EPrints::Plugin::Screen::EPrint::View;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{staff} = 0;

	$self->{icon} = "action_view.png";

	if( $class eq "EPrints::Plugin::Screen::EPrint::View" )
	{
		# don't add this for subclasses!
		$self->{appears} = [
			{
				place => "eprint_summary_page_actions",
				position => 100,
			},
		];
	}

	return $self;
}


sub render_status
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/Screen/EPrint/View:no_subclass" );
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/view" ) & $self->who_filter;
}

sub who_filter { return 15; }

sub about_to_render 
{
	my( $self ) = @_;

	my $cuser  = $self->{session}->current_user;

	my $priv = $self->allow( "eprint/view" );
	my $owner  = $priv & 4;
	my $editor = $priv & 8;

	if( $editor )
	{
		$self->{processor}->{screenid} = "EPrint::View::Editor";	
		return;
	}
	if( $owner )
	{
		$self->{processor}->{screenid} = "EPrint::View::Owner";	
		return;
	}
	$self->{processor}->{screenid} = "EPrint::View::Other";	
}

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->render_status );
	$chunk->appendChild( $self->render_common_action_buttons );

	# if in archive and can request delete then do that here TODO

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;
	
	my $view = $self->{session}->param( "view" );
	if( defined $view )
	{
		$view = "Screen::$view";
	}

	my $id_prefix = "ep_eprint_views";

#	my @views = qw/ summary full actions export export_staff edit edit_staff history /;


	my $tabs = [];
	my $labels = {};
	my $links = {};
	my $slowlist = [];
	my $position = {};
	foreach my $item ( $self->list_items( "eprint_view_tabs" ) )
	{
		if( !($item->{screen}->can_be_viewed & $self->who_filter) )
		{
			next;
		}
		if( $item->{screen}->{expensive} )
		{
			push @{$slowlist}, $item->{screen_id};
		}

		push @{$tabs}, $item->{screen_id};
		$position->{$item->{screen_id}} = $item->{position};
		$labels->{$item->{screen_id}} = $item->{screen}->render_tab_title;
		$links->{$item->{screen_id}} = "?screen=".$self->{processor}->{screenid}."&eprintid=".$self->{processor}->{eprintid}."&view=".substr( $item->{screen_id}, 8 );
	}

	@{$tabs} = sort { $position->{$a} <=> $position->{$b} } @{$tabs};
	if( !defined $view )
	{
		$view = $tabs->[0] 
	}

	$chunk->appendChild( 
		$self->{session}->render_tabs( 
			id_prefix => $id_prefix,
			current => $view,
			tabs => $tabs,
			labels => $labels,
			links => $links,
			slow_tabs => $slowlist ) );
			
	my $panel = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panels", 
			class => "ep_tab_panel" );
	$chunk->appendChild( $panel );
	my $view_div = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panel_$view" );

	my $screen = $self->{session}->plugin( 
			$view,
			processor => $self->{processor} );
	if( !defined $screen )
	{
		$view_div->appendChild( 
			$self->{session}->html_phrase(
				"cgi/users/edit_eprint:view_unavailable" ) ); # error
	}
	elsif(! ($screen->can_be_viewed & $self->who_filter ) )
	{
		$view_div->appendChild( 
			$self->{session}->html_phrase(
				"cgi/users/edit_eprint:view_unavailable" ) );
	}
	else
	{
		$view_div->appendChild( $screen->render );
	}

	$panel->appendChild( $view_div );

	my $view_slow = 0;
	foreach my $slow ( @{$slowlist} )
	{
		$view_slow = 1 if( $slow eq $view );
	}
	return $chunk if $view_slow;
	
	# don't render the other tabs if this is a slow tab - they must reload
	foreach my $screen_id ( @{$tabs} )
	{
		next if $screen_id eq $view;
		my $other_view = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panel_$screen_id", 
			style => "display: none" );
		$panel->appendChild( $other_view );

		my $screen = $self->{session}->plugin( 
			$screen_id,
			processor=>$self->{processor} );
		if( $screen->{expensive} )
		{
			$other_view->appendChild( $self->{session}->html_phrase( 
					"cgi/users/edit_eprint:loading" ) );
			next;
		}

		$other_view->appendChild( $screen->render );
	}

	$chunk->appendChild( $self->render_common_action_buttons );
	return $chunk;
}

sub render_common_action_buttons
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}


# move somewhere else
sub derive_version
{
	my( $self ) = @_;

	my $ds_inbox = $self->{session}->get_repository->get_dataset( "inbox" );
	my $new_eprint = $self->{processor}->{eprint}->clone( $ds_inbox, 1, 0 );

	if( !defined $new_eprint )
	{
		$self->{processor}->add_message( "error", 
			$self->{session}->html_phrase( "Plugin/Screen/EPrint/View:failed" ) );
		return;
	}
	
	$self->{processor}->{eprint} = $new_eprint;
	$self->{processor}->{eprintid} = $new_eprint->get_id;
	$self->{processor}->{screenid} = "EPrint::Edit";
}

sub derive_clone
{
	my( $self ) = @_;

	my $ds_inbox = $self->{session}->get_repository->get_dataset( "inbox" );
	my $new_eprint = $self->{processor}->{eprint}->clone( $ds_inbox, 0, 1 );

	if( !defined $new_eprint )
	{
		$self->{processor}->add_message( "error", 
			$self->{session}->html_phrase( "Plugin/Screen/EPrint/View:failed" ) );
		return;
	}
	
	$self->{processor}->{eprint} = $new_eprint;
	$self->{processor}->{eprintid} = $new_eprint->get_id;
	$self->{processor}->{screenid} = "EPrint::Edit";
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return defined $self->{processor}->{view} ?
		$self->SUPER::redirect_to_me_url."&view=".$self->{processor}->{view} :
		$self->SUPER::redirect_to_me_url;
}


1;

