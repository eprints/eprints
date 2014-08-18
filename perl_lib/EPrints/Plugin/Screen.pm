=head1 NAME

EPrints::Plugin::Screen

=cut

package EPrints::Plugin::Screen;

# Top level screen.
# Abstract.
# 

use strict;

our @ISA = qw/ EPrints::Plugin /;

sub new
{
	my( $class, %params ) = @_;

	$params{actions} = exists $params{actions} ? $params{actions} : [];
	$params{session} = exists $params{session} ? $params{session} : $params{processor}->{session};

	# flag to indicate that it takes some effort to make this screen, so
	# don't make it up as a tab. eg. EPrint::History.
	$params{expensive} = exists $params{expensive} ? $params{expensive} : 0; 

	return $class->SUPER::new(%params);
}

sub properties_from
{
	my( $self ) = @_;

}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->{processor}->{url}."?screen=".$self->{processor}->{screenid};
}

sub render
{
	my( $self ) = @_;

	my $phraseid = substr(__PACKAGE__, 9);
	$phraseid =~ s/::/\//g;
	$phraseid .= ":no_render_subclass";

	return $self->{session}->html_phrase( $phraseid, screen => $self->{session}->make_text( $self ) );
}

sub render_links
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub register_furniture
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub register_error
{
	my( $self ) = @_;

	$self->{processor}->add_message( "error", $self->{session}->html_phrase( 
		"Plugin/Screen:screen_not_allowed",
		screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
}

=item @params = $screen->hidden_bits()

Returns a key-value list of values that must be set when referring to this screen.

At the top-level this is just the 'screen' id.

=cut

sub hidden_bits
{
	my( $self ) = @_;

	return(
		screen => $self->get_subtype
	);
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	my @params = $self->hidden_bits;
	for(my $i = 0; $i < @params; $i+=2)
	{
		$chunk->appendChild( $self->{session}->render_hidden_field( 
				@params[$i,$i+1]
			) );
	}

	return $chunk;
}

sub wishes_to_export
{
	my( $self ) = @_;

	return 0;
}

sub export
{
	my( $self ) = @_;

	print "Needs to be subclassed\n";
}
sub export_mimetype
{
	my( $self ) = @_;

	return "text/plain";
}

	
sub render_form
{
	my( $self ) = @_;

	my $form = $self->{session}->render_form( "post", $self->{processor}->{url}."#t" );

	$form->appendChild( $self->render_hidden_bits );

	return $form;
}

sub about_to_render 
{
	my( $self ) = @_;
}

sub obtain_edit_lock
{
	my( $self ) = @_;

	return $self->obtain_lock;
}

sub obtain_view_lock
{
	my( $self ) = @_;

	return $self->obtain_lock;
}

sub obtain_lock
{
	my( $self ) = @_;
	
	return 1;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub allow_action
{
	my( $self, $action_id ) = @_;
	my $ok = 0;
	foreach my $an_action ( @{$self->{actions}} )
	{
		if( $an_action eq $action_id )
		{
			$ok = 1;
			last;
		}
	}

	return( 0 ) if( !$ok );

	my $fn = "allow_".$action_id;
	return $self->$fn;
}

sub render_tab_title
{
	my( $self ) = @_;

	return $self->render_title;
}

sub from
{
	my( $self ) = @_;

	my $action_id = $self->{processor}->{action};

	return if( !defined $action_id || $action_id eq "" );

	return if( $action_id eq "null" );

	# If you hit reload after login you can cause a
	# login action, so we'll just ignore it.
#	return if( $action_id eq "login" );

	my $ok = 0;
	foreach my $an_action ( @{$self->{actions}} )
	{
		if( $an_action eq $action_id )
		{
			$ok = 1;
			last;
		}
	}

	if( !$ok )
	{
		$self->{processor}->add_message( "error",
			$self->{session}->html_phrase( 
	      			"Plugin/Screen:unknown_action",
				action=>$self->{session}->make_text( $action_id ),
				screen=>$self->{session}->make_text( $self->{processor}->{screenid} ) ) );
		return;
	}

	if( $self->allow_action( $action_id ) )
	{
		my $fn = "action_".$action_id;
		$self->$fn;
	}
	else
	{
		$self->{processor}->action_not_allowed( 
			$self->html_phrase( "action:$action_id:title" ) );
	}
}

sub allow
{
	my( $self, $priv, $item ) = @_;

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv, $item );
}


# these methods all could be properties really


sub matches 
{
	my( $self, $test, $param ) = @_;

	return $self->SUPER::matches( $test, $param );
}

sub render_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

=item @screen_opts = $screen->list_items( $list_id, %opts )

Returns a list of screens that appear in list $list_id ordered by their position.

Each screen opt is a hash ref of:

	screen - screen plugin
	screen_id - screen id
	position - position (positive integer)
	action - the action, if this plugin is for an action list

Incoming opts:

	filter => 1 or 0 (default 1)
	params => {}

=cut

sub list_items
{
	my( $self, $list_id, %opts ) = @_;

	return $self->{processor}->list_items( $list_id, %opts );
}	

sub action_allowed
{
	my( $self, $item ) = @_;
	my $who_allowed;
	if( defined $item->{action} )
	{
 		$who_allowed = $item->{screen}->allow_action( $item->{action} );
	}
	else
	{
		$who_allowed = $item->{screen}->can_be_viewed;
	}

	return 0 unless( $who_allowed & $self->who_filter );
	return 1;
}

sub action_list
{
	my( $self, $list_id ) = @_;

	my @list = ();
	foreach my $item ( $self->list_items( $list_id ) )
	{
		next unless $self->action_allowed( $item );

		push @list, $item;
	}

	return @list;
}


sub who_filter { return 255; }

sub get_description
{
	my( $self, $params ) = @_;
	my $description;
	if( defined $params->{action} )
	{
		my $action = $params->{action};
		$description = $params->{screen}->html_phrase( "action:$action:description" );
	}
	else
	{
		$description = $params->{screen}->html_phrase( "description" );
	}
	return $description;
}

=item $url = $screen->action_icon_url( $action )

Returns the relative URL to the $action icon for this screen.

=cut

sub action_icon_url
{
	my( $self, $action ) = @_;

	my $icon = $self->{session}->get_repository->get_conf( "plugins", $self->{id}, "actions", $action, "icon" );
	if( !defined $icon ) 
	{
		$icon = $self->{action_icon}->{$action};
	}

	return undef if !defined $icon;

	my $url = $self->{session}->get_url( path => "images", $icon );

	return $url;
}

=item $frag = $screen->render_action_link()

Returns a link to this screen.

=cut

sub render_action_link
{
	my( $self, %opts ) = @_;

	my $uri = URI->new( $self->{session}->config( "http_cgiurl" ) . "/users/home" );
	$uri->query_form(
		screen => substr($self->{id},8),
	);

	my $link = $self->{session}->render_link( $uri );
	$link->appendChild( $self->render_title );

	return $link;
}

sub render_action_icon
{
	my( $self, $params ) = @_;

	return $self->_render_action_aux( $params, 1 );
}

sub render_action_button
{
	my( $self, $params ) = @_;

	return $self->_render_action_aux( $params, 0 );
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

	my @query = (screen => substr( $params->{screen_id}, 8 ));

	my $hidden = $params->{hidden};
	if( ref($hidden) eq "ARRAY" )
	{
		foreach my $id ( @$hidden )
		{
			push @query, $id => $self->{processor}->{$id};
		}
	}
	else
	{
		foreach my $id (keys %$hidden)
		{
			push @query, $id => $hidden->{$id};
		}
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
		$action = "";
		$title = $params->{screen}->phrase( "title" );
		$icon = $params->{screen}->icon_url();
	}
	
	my $path = $session->current_url( path => "cgi" ) . "/users/home";

	my $frag;

	if( $method eq "GET" && defined $icon && $asicon )
	{
		push @query, "_action_$action" => 1 if length($action);
		my $uri = URI->new( $path );
		$uri->query_form( @query );
		$frag = $session->render_link( $uri );
		if( defined $icon && $asicon )
		{
			$frag->appendChild( $session->make_element( "img",
				src=>$icon,
				title=>$title,
				alt=>$title,
				class=>"ep_form_action_icon",
			) );
		}
		# never called because mixing <input> and <href> is ugly
		else
		{
			$frag->setAttribute( class => "ep_form_action_button" );
			$frag->appendChild( $session->make_text( $title ) );
		}
	}
	else
	{
		$frag = $session->render_form( $method, $path );
		foreach my $i (0..$#query)
		{
			next if $i % 2;
			$frag->appendChild( $session->render_hidden_field( 
				@query[$i, $i+1] ) );
		}
		if( defined $icon && $asicon )
		{
			$frag->appendChild( 
				$session->make_element(
					"input",
					type=>"image",
					class=>"ep_form_action_icon",
					($action ? (name=>"_action_$action") : ()),
					src=>$icon,
					title=>$title,
					alt=>$title,
					value=>$title ));
		}
		else
		{
			$frag->appendChild( 
				$session->render_button(
					class=>"ep_form_action_button",
					($action ? (name=>"_action_$action") : ()),
					value=>$title ));
		}
	}

	return $frag;
}

sub render_action_button_if_allowed
{
	my( $self, $params, $hidden ) = @_;

	if( $self->action_allowed( $params ) )
	{
		return $self->render_action_button( { %$params, hidden => $hidden } ); 
	}
	else
	{
		return $self->{session}->make_doc_fragment;
	}
}

sub render_action_list
{
	my( $self, $list_id, $hidden ) = @_;

	my $repo = $self->repository;

	my( @actions, @definitions );
	foreach my $params ($self->action_list( $list_id ))
	{
		push @actions, $self->render_action_button( { %$params, hidden => $hidden } );
		push @definitions, $self->get_description( $params );
	}

	return $repo->xhtml->action_definition_list( \@actions, \@definitions );
}


sub render_action_list_bar
{
	my( $self, $list_id, $hidden ) = @_;

	my $repo = $self->repository;

	my @actions;
	foreach my $params ($self->action_list( $list_id ))
	{
		push @actions, $self->render_action_button( { %$params, hidden => $hidden } );
	}

	my $div = $repo->xml->create_element( "div", class => "ep_block" );
	$div->appendChild( $repo->xhtml->action_list( \@actions ) );

	return $div;
}


sub render_action_list_icons
{
	my( $self, $list_id, $hidden ) = @_;

	my $repo = $self->repository;

	my @actions;
	foreach my $params ($self->action_list( $list_id ))
	{
		push @actions, $self->render_action_icon( { %$params, hidden => $hidden } );
	}

	return $repo->xhtml->action_list( \@actions );
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

