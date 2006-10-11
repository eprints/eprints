
package EPrints::Plugin::Screen::Subscription::List;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 300,
		}
	];

	$self->{actions} = [qw/ create /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "subscription" );
}

sub allow_create
{
	my( $self ) = @_;

	return $self->allow( "create_subscription" );
}

sub action_create
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my $subscribe_ds = $session->get_repository->get_dataset( "subscription" );

	$self->{processor}->{subscription} = $subscribe_ds->create_object( $session, { userid=>$user->get_id } );
	$self->{processor}->{subid} = $self->{processor}->{subscription}->get_id;

	# change screen
	$self->{processor}->{screenid} = "Subscription::Edit";
}	

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	
	my $page = $session->make_doc_fragment;

	$page->appendChild( $self->html_phrase( "intro" ) );

	$page->appendChild( $self->render_subscription_list );

	my $form = $self->render_form;
	$form->appendChild(
		$session->render_action_buttons( 	
			create => $self->phrase( "new" ) ) );
	$page->appendChild( $form );

	return $page;
}

sub render_subscription_list
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my @subs = $user->get_subscriptions;
	my $subscribe_ds = $session->get_repository->get_dataset( "subscription" );

	if( scalar @subs == 0 )
	{
		return $self->html_phrase( "no_subs" );
	}

	my( $table, $tr, $td, $th );
	$table = $session->make_element( 
		"table",
		style => "margin-bottom: 12pt",
		cellpadding => 4,
		cellspacing => 0,
		border => 1 );
	
	foreach my $subscr ( @subs )
	{
		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );

		my $id = $subscr->get_id;
		
		$td = $session->make_element( 
			"td",
			width=>"20%",
			align=>"center" );
		$tr->appendChild( $td );
		my $form = $session->render_form( "GET" );
		$form->appendChild( $session->render_hidden_field( "subid", $id ) );
		$form->appendChild( $session->render_hidden_field( "screen", "Subscription::Edit" ) );
		$td->appendChild( $form );
		$form->appendChild( 
			$session->make_element( 
				"input", 
				type=>"submit",
				class=>"ep_form_action_button",
				name=>"_action_null",
				value=>$self->phrase( "edit" )));
		$form->appendChild( 
			$session->make_element( 
				"input", 
				type=>"submit",
				class=>"ep_form_action_button",
				name=>"_action_remove",
				value=>$self->phrase( "remove" )));
	
	
		$td = $session->make_element( "td" );
		$tr->appendChild( $td );

		foreach( "frequency","spec","mailempty" )
		{
			my $strong;
			$strong = $session->make_element( "strong" );
			$strong->appendChild( $subscribe_ds->get_field( $_ )->render_name( $session ) );
			$strong->appendChild( $session->make_text( ": " ) );
			$td->appendChild( $strong );
			$td->appendChild( $subscr->render_value( $_ ) );
			$td->appendChild( $session->make_element( "br" ) );
		}

	}
	
	return $table;
}
	

1;
