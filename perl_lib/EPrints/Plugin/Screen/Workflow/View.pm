package EPrints::Plugin::Screen::Workflow::View;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "dataobj_actions",
			position => 200,
		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( $self->{processor}->{dataset}->id."/view" );
}

sub render
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{dataset};

	my $chunk = $self->{session}->make_doc_fragment;

#	$chunk->appendChild( $self->render_status );
	my $buttons = $self->render_common_action_buttons;
	$chunk->appendChild( $buttons );

	# if in archive and can request delete then do that here TODO

	my $view = $self->{session}->param( "view" );
	if( defined $view )
	{
		$view = "Screen::$view";
	}

	my $id_prefix = "ep_workflow_views";

	my @items = (
		$self->list_items( "dataobj_view_tabs", filter => 0 ),
		$self->list_items( "dataobj_".$dataset->id."_view_tabs", filter => 0 ),
		);

	my $current;
	my @screens;
	my @tabs;
	my %labels;
	my %links;
	my @slowlist;
	foreach my $item ( @items )
	{
		next if !($item->{screen}->can_be_viewed & $self->who_filter);
		next if $item->{action} && !$item->{screen}->allow_action( $item->{action} );
		if( $item->{screen}->{expensive} )
		{
			push @slowlist, $item->{screen_id};
		}

		if( defined $view && $view eq $item->{screen_id} )
		{
			$current = $item->{screen};
		}

		push @screens, $item->{screen};
		push @tabs, $item->{screen_id};
		$labels{$item->{screen_id}} = $item->{screen}->render_tab_title;
		$links{$item->{screen_id}} = "?screen=".$self->{processor}->{screenid}."&dataset=".$self->{processor}->{dataset}->id."&dataobj=".$self->{processor}->{dataobj}->id."&view=".substr( $item->{screen_id}, 8 );
	}

	if( !@screens )
	{
		return $chunk;
	}

	$current = $screens[0] if !defined $current;
	$view = $current->get_id if !defined $view;

	$chunk->appendChild( 
		$self->{session}->render_tabs( 
			id_prefix => $id_prefix,
			current => $view,
			tabs => \@tabs,
			labels => \%labels,
			links => \%links,
			slow_tabs => \@slowlist ) );
			
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

#	$chunk->appendChild( $buttons->cloneNode(1) );
	return $chunk;
}

sub render_common_action_buttons
{
	my( $self ) = @_;

	return $self->render_action_list_bar( "dataobj_view_actions", {
					dataset => $self->{processor}->{dataset}->id,
					dataobj => $self->{processor}->{dataobj}->id,
				} );
}

1;
