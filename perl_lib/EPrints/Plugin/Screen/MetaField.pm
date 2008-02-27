
package EPrints::Plugin::Screen::MetaField;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{metafieldid} = $self->{session}->param( "metafieldid" );
	$self->{processor}->{metafield} = new EPrints::DataObj::MetaField( $self->{session}, $self->{processor}->{metafieldid} );

	if( !defined $self->{processor}->{metafield} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{session}->html_phrase(
			"cgi/users/edit_metafield:cant_find_it",
			id=>$self->{session}->make_text( $self->{processor}->{metafieldid} ) ) );
		return;
	}

	$self->{processor}->{dataset} = $self->{processor}->{metafield}->get_dataset;

	$self->SUPER::properties_from;
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{metafield};

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv, $self->{processor}->{metafield} );
}

sub render_tab_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub render_title
{
	my( $self ) = @_;

	my $priv = $self->allow( "metafield/view" );

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "title" ) );
	$f->appendChild( $self->{session}->make_text( ": " ) );

	my $title = $self->{session}->make_text( $self->{processor}->{metafieldid} );
	my $a = $self->{session}->render_link( "?screen=MetaField::View&metafieldid=".$self->{processor}->{metafieldid} );
	$a->appendChild( $title );
	$f->appendChild( $a );
	return $f;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&metafieldid=".$self->{processor}->{metafieldid};
}

sub workflow
{
	my( $self, $staff ) = @_;

	my $cache_id = "workflow";

	if( !defined $self->{processor}->{$cache_id} )
	{
		my %opts = ( item=> $self->{processor}->{metafield}, session=>$self->{session} );
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

	my $metafield = $self->{processor}->{metafield};
	my $session = $self->{session};
	my $staff = 0;

	my $workflow = $self->workflow( $staff_mode );
	my $table = $session->make_element( "table", cellpadding=>0, cellspacing=>0, class=>"ep_blister_bar" );
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	my $first = 1;
	my @stages = $workflow->get_stage_ids;
	push @stages, "commit";
	foreach my $stage_id ( @stages )
	{
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
		my $phrase;
		if( $stage_id eq "commit" )
		{
			$phrase = $session->phrase( "Plugin/Screen/MetaField:commit" );
		}
		else
		{
			$phrase = $session->phrase( "metapage_title_".$stage_id );
		}
		my $button = $session->render_button(
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

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "metafieldid", $self->{processor}->{metafieldid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}
1;

