
package EPrints::Plugin::Screen::EPrint;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{eprintid} = $self->{handle}->param( "eprintid" );
	$self->{processor}->{eprint} = $self->{handle}->get_eprint( $self->{processor}->{eprintid} );

	if( !defined $self->{processor}->{eprint} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{handle}->html_phrase(
			"cgi/users/edit_eprint:cant_find_it",
			id=>$self->{handle}->make_text( $self->{processor}->{eprintid} ) ) );
		return;
	}

	$self->{processor}->{dataset} = $self->{processor}->{eprint}->get_dataset;

	$self->SUPER::properties_from;
}

sub could_obtain_eprint_lock
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};

	return $self->{processor}->{eprint}->could_obtain_lock( $self->{handle}->current_user );
}

sub obtain_eprint_lock
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};

	return $self->{processor}->{eprint}->obtain_lock( $self->{handle}->current_user );
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{eprint};

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	$priv =~ s/^eprint\//eprint\/$status\//;	

	return 1 if( $self->{handle}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{handle}->current_user );
	return $self->{handle}->current_user->allow( $priv, $self->{processor}->{eprint} );
}

sub render_tab_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub render_title
{
	my( $self ) = @_;

	my $priv = $self->allow( "eprint/view" );
	my $owner  = $priv & 4;
	my $editor = $priv & 8;

	my $f = $self->{handle}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "title" ) );
	$f->appendChild( $self->{handle}->make_text( ": " ) );

	my $title = $self->{processor}->{eprint}->render_citation( "screen" );
	if( $owner && $editor )
	{
		$f->appendChild( $title );
	}
	else
	{
		my $a = $self->{handle}->render_link( "?screen=EPrint::View&eprintid=".$self->{processor}->{eprintid} );
		$a->appendChild( $title );
		$f->appendChild( $a );
	}
	return $f;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&eprintid=".$self->{processor}->{eprintid};
}

sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;

	my $eprint = $self->{processor}->{eprint};
	my $user = $self->{handle}->current_user;
	if( $eprint->is_locked )
	{
		my $my_lock = ( $eprint->get_value( "edit_lock_user" ) == $user->get_id );
		if( $my_lock )
		{
			$self->{processor}->before_messages( $self->{handle}->html_phrase( 
				"Plugin/Screen/EPrint:locked_to_you" ) );
		}
		else
		{
			$self->{processor}->before_messages( $self->{handle}->html_phrase( 
				"Plugin/Screen/EPrint:locked_to_other", 
				name => $eprint->render_value( "edit_lock_user" )) );
		}
	}

	my $priv = $self->allow( "eprint/view" );
	my $owner  = $priv & 4;
	my $editor = $priv & 8;

	unless( $owner && $editor )
	{
		return $self->{handle}->make_doc_fragment;
	}

	my $div = $self->{handle}->make_element( "div",class=>"ep_block" );
	my $a_owner = $self->{handle}->render_link( "?screen=EPrint::View::Owner&eprintid=".$self->{processor}->{eprintid} );
	my $a_editor = $self->{handle}->render_link( "?screen=EPrint::View::Editor&eprintid=".$self->{processor}->{eprintid} );
	$div->appendChild( $self->{handle}->html_phrase(
		"cgi/users/edit_eprint:view_as_either",
		owner_link=>$a_owner,
		editor_link=>$a_editor ) );

	if( defined $self->{staff} )
	{
		$div->appendChild( $self->{handle}->make_text( " " ) );
		if( $self->{staff} == 0 )
		{
			$div->appendChild( $self->{handle}->html_phrase(
				"cgi/users/edit_eprint:as_depositor" ));
		}
		else
		{
			$div->appendChild( $self->{handle}->html_phrase(
				"cgi/users/edit_eprint:as_editor" ));
		}
		
	}

	$self->{processor}->before_messages( $div );
}

sub register_error
{
	my( $self ) = @_;

	if( $self->{processor}->{eprint}->has_owner( $self->{handle}->current_user ) )
	{
		$self->{processor}->add_message( "error", $self->{handle}->html_phrase( 
			"Plugin/Screen/EPrint:owner_denied",
			screen=>$self->{handle}->make_text( $self->{processor}->{screenid} ) ) );
	}
	else
	{
		$self->SUPER::register_error;
	}
}


sub workflow
{
	my( $self, $staff ) = @_;

	my $cache_id = "workflow";
	$cache_id.= "_staff" if( $staff ); 

	if( !defined $self->{processor}->{$cache_id} )
	{
		my %opts = ( item=> $self->{processor}->{eprint}, handle =>$self->{handle} );
		$opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( $self->{handle}, $self->workflow_id, %opts );
	}

	return $self->{processor}->{$cache_id};
}

sub workflow_id
{
	return "default";
}

sub uncache_workflow
{
	my( $self ) = @_;

	delete $self->{handle}->{id_counter};
	delete $self->{processor}->{workflow};
	delete $self->{processor}->{workflow_staff};
}

sub render_blister
{
	my( $self, $sel_stage_id, $staff_mode ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $handle = $self->{handle};
	my $staff = 0;

	my $workflow = $self->workflow( $staff_mode );
	my $table = $handle->make_element( "table", cellpadding=>0, cellspacing=>0, class=>"ep_blister_bar" );
	my $tr = $handle->make_element( "tr" );
	$table->appendChild( $tr );
	my $first = 1;
	my @stages = $workflow->get_stage_ids;
	if( !$staff_mode && $eprint->get_value( "eprint_status" ) eq "inbox" )
	{
		push @stages, "deposit";
	}
	foreach my $stage_id ( @stages )
	{
		if( !$first )  
		{ 
			my $td = $handle->make_element( "td", class=>"ep_blister_join" );
			$tr->appendChild( $td );
		}
		
		my $td;
		$td = $handle->make_element( "td" );
		my $class = "ep_blister_node";
		if( $stage_id eq $sel_stage_id ) 
		{ 
			$class="ep_blister_node_selected"; 
		}
		my $phrase;
		if( $stage_id eq "deposit" )
		{
			$phrase = $handle->phrase( "Plugin/Screen/EPrint:deposit" );
		}
		else
		{
			$phrase = $handle->phrase( "metapage_title_".$stage_id );
		}
		my $button = $handle->render_button(
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

	my $chunk = $self->{handle}->make_doc_fragment;

	$chunk->appendChild( $self->{handle}->render_hidden_field( "eprintid", $self->{processor}->{eprintid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}
1;

