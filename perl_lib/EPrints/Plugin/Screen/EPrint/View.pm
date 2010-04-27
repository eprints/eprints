
package EPrints::Plugin::Screen::EPrint::View;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "eprint_summary_page_actions",
			position => 100,
		},
		{
			place => "eprint_item_actions",
			position => 10,
		},
		{
			place => "eprint_review_actions",
			position => 10,
		},
	];

	return $self;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";	
}

sub render_status
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $url = $self->{processor}->{eprint}->get_url;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	$div->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status,
		link => $self->{session}->render_link( $url ), 
		url  => $self->{session}->make_text( $url ) ) );

	return $div;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/view" ) & $self->who_filter;
}

sub who_filter { return 15; }

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->render_status );
	my $buttons = $self->render_common_action_buttons;
	$chunk->appendChild( $buttons );

	# if in archive and can request delete then do that here TODO

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" ) || 0;
	
	my $view = $self->{session}->param( "view" );
	if( defined $view )
	{
		$view = "Screen::$view";
	}

	my $id_prefix = "ep_eprint_views";

#	my @views = qw/ summary full actions export export_staff edit edit_staff history /;


	my $current;
	my @screens;
	my $tabs = [];
	my $labels = {};
	my $links = {};
	my $slowlist = [];
	foreach my $item ( $self->list_items( "eprint_view_tabs", filter => 0 ) )
	{
		next if !($item->{screen}->can_be_viewed & $self->who_filter);
		next if $item->{action} && !$item->{screen}->allow_action( $item->{action} );
		if( $item->{screen}->{expensive} )
		{
			push @{$slowlist}, $item->{screen_id};
		}

		$current = $item->{screen} if defined $view && $view eq $item->{screen_id};
		push @screens, $item->{screen};
		push @{$tabs}, $item->{screen_id};
		$labels->{$item->{screen_id}} = $item->{screen}->render_tab_title;
		$links->{$item->{screen_id}} = "?screen=".$self->{processor}->{screenid}."&eprintid=".$self->{processor}->{eprintid}."&view=".substr( $item->{screen_id}, 8 );
	}

	$current = $screens[0] if !defined $current;
	$view = $current->get_id if !defined $view;

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

	if( $view ne $current->get_id )
	{
		my $view_div = $self->{session}->make_element( "div", 
				id => "${id_prefix}_panel_$view" );
		$panel->appendChild( $view_div );
		$view_div->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:view_unavailable" ) ); # error
	}

	# don't render the other tabs if this is a slow tab - they must reload
	foreach my $screen (@screens)
	{
		my $view_div = $self->{session}->make_element( "div", 
			id => "${id_prefix}_panel_".$screen->get_id, 
			style => "display: none" );
		$panel->appendChild( $view_div );
		if( $screen eq $current )
		{
			$view_div->setAttribute( style => "display: block" );
			$view_div->appendChild( $screen->render );
		}
		elsif( $screen->{expensive} )
		{
			$view_div->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:loading" ) );
		}
		else
		{
			$view_div->appendChild( $screen->render );
		}
	}

	$chunk->appendChild( $buttons->cloneNode(1) );
	return $chunk;
}

sub render_common_action_buttons
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $frag = $self->{session}->make_doc_fragment;

#	$frag->appendChild( $self->render_action_list_bar( "eprint_actions_editor_$status", ['eprintid'] ) );

#	$frag->appendChild( $self->render_action_list_bar( "eprint_actions_owner_$status", ['eprintid'] ) );

	$frag->appendChild( $self->render_action_list_bar( "eprint_actions_bar_$status", ['eprintid'] ) );

	return $frag;
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

