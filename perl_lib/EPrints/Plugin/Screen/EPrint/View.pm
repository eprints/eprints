=head1 NAME

EPrints::Plugin::Screen::EPrint::View

=cut


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

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{tab_prefix} = "ep_eprint_view";

	$self->SUPER::properties_from;
}

sub wishes_to_export { shift->{repository}->param( "ajax" ) }

sub export_mime_type { "text/html;charset=utf-8" }

sub export
{
	my( $self ) = @_;

	my $id_prefix = $self->{processor}->{tab_prefix};

	my $current = $self->{session}->param( "${id_prefix}_current" );
	$current = 0 if !defined $current;

	my @screens;
	foreach my $item ( $self->list_items( "eprint_view_tabs", filter => 0 ) )
	{
		next if !($item->{screen}->can_be_viewed & $self->who_filter);
		next if $item->{action} && !$item->{screen}->allow_action( $item->{action} );
		push @screens, $item->{screen};
	}

	local $self->{processor}->{current} = $current;

	my $content = $screens[$current]->render( "${id_prefix}_$current" );
	binmode(STDOUT, ":utf8");
	print $self->{repository}->xhtml->to_xhtml( $content );
	$self->{repository}->xml->dispose( $content );
}

sub register_furniture
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $user = $self->{session}->current_user;
	if( $eprint->is_locked )
	{
		my $my_lock = ( $eprint->get_value( "edit_lock_user" ) == $user->get_id );
		if( $my_lock )
		{
			$self->{processor}->add_message( "warning", $self->{session}->html_phrase( 
				"Plugin/Screen/EPrint:locked_to_you" ) );
		}
	}

	return $self->SUPER::register_furniture;
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		$self->{processor}->{tab_prefix} . "_current" => $self->{processor}->{current},
	);
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

sub who_filter { return 14; }

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->render_status );
	my $div = $self->{session}->make_element( "div", class => "ep_block" );
	my $buttons = $self->render_common_action_buttons;
	$div->appendChild( $buttons );
	$chunk->appendChild( $div );

	# if in archive and can request delete then do that here TODO

	my $id_prefix = $self->{processor}->{tab_prefix};

	my $current = $self->{session}->param( "${id_prefix}_current" );
	$current = 0 if !defined $current;

	my @screens;
	foreach my $item ( $self->list_items( "eprint_view_tabs", filter => 0 ) )
	{
		next if !($item->{screen}->can_be_viewed & $self->who_filter);
		next if $item->{action} && !$item->{screen}->allow_action( $item->{action} );
		push @screens, $item->{screen};
	}

	my @labels;
	my @contents;
	my @expensive;

	for(my $i = 0; $i < @screens; ++$i)
	{
		# allow hidden_bits to point to the correct tab for local links
		local $self->{processor}->{current} = $i;

		my $screen = $screens[$i];
		push @labels, $screen->render_tab_title;
		push @expensive, $i if $screen->{expensive};
		if( $screen->{expensive} && $i != $current )
		{
			push @contents, $self->{session}->html_phrase(
				"cgi/users/edit_eprint:loading"
			);
		}
		else
		{
			push @contents, $screen->render( "${id_prefix}_$i" );
		}
	}

	$chunk->appendChild( $self->{session}->xhtml->tabs(
		\@labels,
		\@contents,
		basename => $id_prefix,
		current => $current,
		expensive => \@expensive,
		) );

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


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

