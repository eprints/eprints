package EPrints::Plugin::Screen;

# Top level screen.
# Abstract.
# 

use strict;

our @ISA = qw/ EPrints::Plugin /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	if( !defined $self->{handle} ) 
	{
		$self->{handle} = $self->{processor}->{handle};
	}
	$self->{actions} = [];

	# flag to indicate that it takes some effort to make this screen, so
	# don't make it up as a tab. eg. EPrint::History.
	$self->{expensive} = 0; 

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $user = $self->{handle}->current_user;
	if( defined $user )
	{
		$self->{processor}->{user} = $user;
		$self->{processor}->{userid} = $user->get_value( "userid" );
	}

}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->{processor}->{url}."?screen=".$self->{processor}->{screenid};
}

sub render
{
	my( $self ) = @_;

	return $self->html_phrase( "no_render_subclass", screen => $self->{handle}->make_text( $self ) );
}

sub render_links
{
	my( $self ) = @_;

	return $self->{handle}->make_doc_fragment;
}

sub register_furniture
{
	my( $self ) = @_;

	return $self->{handle}->make_doc_fragment;
}

sub register_error
{
	my( $self ) = @_;

	$self->{processor}->add_message( "error", $self->{handle}->html_phrase( 
		"Plugin/Screen:screen_not_allowed",
		screen=>$self->{handle}->make_text( $self->{processor}->{screenid} ) ) );
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{handle}->make_doc_fragment;

	$chunk->appendChild( 
		$self->{handle}->render_hidden_field( 
			"screen", 
			substr($self->{id},8) ) );

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

	my $form = $self->{handle}->render_form( "post", $self->{processor}->{url}."#t" );

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
	return if( $action_id eq "login" );

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
			$self->{handle}->html_phrase( 
	      			"Plugin/Screen:unknown_action",
				action=>$self->{handle}->make_text( $action_id ),
				screen=>$self->{handle}->make_text( $self->{processor}->{screenid} ) ) );
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
	my( $self, $priv ) = @_;

	return 1 if( $self->{handle}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{handle}->current_user );
	return $self->{handle}->current_user->allow( $priv );
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

=item @screen_opts = $screen->list_items( $list_id )

Returns a list of screens that appear in list $list_id ordered by their position.

Each screen opt is a hash ref of:

	screen - screen plugin
	screen_id - screen id
	position - position (positive integer)
	action - the action, if this plugin is for an action list

=cut

sub list_items
{
	my( $self, $list_id ) = @_;

	my @screens = $self->{handle}->get_plugins( {
			processor => $self->{processor},
		},
		type => "Screen" );
	my @list_items = ();
	foreach my $screen ( @screens )
	{	
		my $screen_id = $screen->get_id;
		my $p_conf = $self->{handle}->get_repository->get_conf( 
				"plugins", $screen_id );

		if( exists $p_conf->{appears}->{$list_id} && 
			!defined $p_conf->{appears}->{$list_id} )
		{
			# set to undef
			next;
		}

		my @things_in_list = ();
		if( defined $screen->{appears} )
		{
			foreach my $opt ( @{$screen->{appears}} )
			{
				next if( $opt->{place} ne $list_id );
				if( defined $opt->{action} )
				{
					# skip if this action is disabled
					next if( $p_conf->{actions}->{$opt->{action}}->{disable} );
					# skip if this action/list has got an position
					# configured
					next if( defined $p_conf->{actions}->{$opt->{action}}->{appears}->{$list_id} );
				}
				else
				{
					# skip if this screen/list has got a position 
					# configured.
					next if( defined $p_conf->{appears}->{$list_id} );
				}	
				push @things_in_list, $opt;
			}
		}
		if( defined $p_conf->{appears}->{$list_id} )
		{
			push @things_in_list, 
				{
					place => $list_id,
					position => $p_conf->{appears}->{$list_id},
				};
		}
		if( defined $p_conf->{actions} )
		{
			foreach my $action_id ( keys %{$p_conf->{actions}} )
			{
				my $a_conf = $p_conf->{actions}->{$action_id};
				if( defined $a_conf->{appears}->{$list_id} )
				{
					push @things_in_list, 
						{
						place => $list_id,
						position => $a_conf->{appears}->{$list_id},
						action => $action_id,
						};
				}

			}
		}

		next if( scalar @things_in_list == 0 );

		# must be done after checking things in the list
		# to prevent actions looping.
		next if( !$screen->can_be_viewed );
	
		foreach my $opt ( @things_in_list )
		{	
			my $p = $opt->{position};
			$p = 999999 if( !defined $p );
			if( defined $opt->{action} )
			{
 				next if( !$screen->allow_action( $opt->{action} ) );
			}

			push @list_items, {
				screen => $screen,
				screen_id => $screen_id,
				action => $opt->{action},
				position => $p,
			};
		}
	}

	return sort { $a->{position} <=> $b->{position} } @list_items;
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

	my $icon = $self->{handle}->get_repository->get_conf( "plugins", $self->{id}, "actions", $action, "icon" );
	if( !defined $icon ) 
	{
		$icon = $self->{action_icon}->{$action};
	}

	return undef if !defined $icon;

	my $url = $self->{handle}->get_url( path => "images", $icon );

	return $url;
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
	
	my $handle = $self->{handle};
	
	my $method = "GET";	
	if( defined $params->{action} )
	{
		$method = "POST";
	}

	my $form = $handle->render_form( $method );

	$form->appendChild( 
		$handle->render_hidden_field( 
			"screen", 
			substr( $params->{screen_id}, 8 ) ) );
	foreach my $id ( @{$params->{hidden}} )
	{
		$form->appendChild( 
			$handle->render_hidden_field( 
				$id, 
				$self->{processor}->{$id} ) );
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
			$handle->make_element(
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
			$handle->render_button(
				class=>"ep_form_action_button",
				name=>"_action_$action", 
				value=>$title ));
	}

	return $form;
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
		return $self->{handle}->make_doc_fragment;
	}
}

sub render_action_list
{
	my( $self, $list_id, $hidden ) = @_;

	my $handle = $self->{handle};

	my $table = $handle->make_element( "table", class=>"ep_act_list" );
	foreach my $params ( $self->action_list( $list_id ) )
	{
		my $tr = $handle->make_element( "tr" );
		$table->appendChild( $tr );

		my $td = $handle->make_element( "td", class=>"ep_act_list_button" );
		$tr->appendChild( $td );
		$td->appendChild( $self->render_action_button( { %$params, hidden => $hidden } ) );

		my $td2 = $handle->make_element( "td", class=>"ep_act_list_join" );
		$tr->appendChild( $td2 );

		$td2->appendChild( $handle->make_text( " - " ) );

		my $td3 = $handle->make_element( "td", class=>"ep_act_list_desc" );
		$tr->appendChild( $td3 );
		$td3->appendChild( $self->get_description( $params ) );
	}

	return $table;
}


sub render_action_list_bar
{
	my( $self, $list_id, $hidden ) = @_;

	my $handle = $self->{handle};

	my $div = $self->{handle}->make_element( "div", class=>"ep_act_bar" );
	my $table = $handle->make_element( "table" );
	$div->appendChild( $table );
	my $tr = $handle->make_element( "tr" );
	$table->appendChild( $tr );
	foreach my $params ( $self->action_list( $list_id ) )
	{
		my $td = $handle->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $self->render_action_button( { %$params, hidden => $hidden } ) );
	}

	return $div;
}


sub render_action_list_icons
{
	my( $self, $list_id, $hidden ) = @_;

	my $handle = $self->{handle};

	my $div = $self->{handle}->make_element( "div", class=>"ep_act_icons" );
	my $table = $handle->make_element( "table" );
	$div->appendChild( $table );
	my $tr = $handle->make_element( "tr" );
	$table->appendChild( $tr );
	foreach my $params ( $self->action_list( $list_id ) )
	{
		my $td = $handle->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $self->render_action_icon( { %$params, hidden => $hidden } ) );
	}

	return $div;
}

1;

		
		
