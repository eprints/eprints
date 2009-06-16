
package EPrints::Plugin::Screen::NewUser;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create cancel /];

	$self->{appears} = [
		{ 
			place => "admin_actions_system", 	
			position => 1000, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my ( $self ) = @_;

	return $self->allow( "create_user" );
}

sub allow_cancel
{
	my ( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin";
}

sub allow_create
{
	my ( $self ) = @_;

	return $self->allow( "create_user" );
}

sub action_create
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "user" );

	my $candidate_username = $session->param( "username" );

	unless( EPrints::Utils::is_set( $candidate_username ) )
	{
		$self->{processor}->add_message( 
			"warning",
			$self->html_phrase( "no_username" ) );
		return;
	}

	if( defined EPrints::DataObj::User::user_with_username( $session, $candidate_username ) )
	{
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "user_exists",
				username=>$session->make_text( $candidate_username ) ) );
		return;
	}

	my $usertype = $session->get_repository->get_conf( "default_user_type" ); 

	# Attempt to create a new account

	$self->{processor}->{user} = $ds->create_object( $self->{session}, { 
		username=>$candidate_username,
		usertype=>$usertype } );

	if( !defined $self->{processor}->{user} )
	{
		my $db_error = session->get_database->error;
		$session->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{userid} = $self->{processor}->{user}->get_id;
	$self->{processor}->{screenid} = "User::Staff::Edit";
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $page = $session->make_element( "div", class=>"ep_block" );

	$page->appendChild( $self->html_phrase( "blurb" ) );

	my %buttons = (
		cancel => $self->phrase( "action:cancel:title" ),
		create => $self->phrase( "action:create:title" ),
		_order => [ "create", "cancel" ]
	);

	my $form = $session->render_form( "GET" );
	$form->appendChild( 
		$session->render_hidden_field ( "screen", "NewUser" ) );		
	my $ds = $session->get_repository->get_dataset( "user" );
	my $username_field = $ds->get_field( "username" );
	my $usertype_field = $ds->get_field( "usertype" );
	my $div = $session->make_element( "div", style=>"margin-bottom: 1em" );
	$div->appendChild( $username_field->render_name( $session ) );
	$div->appendChild( $session->make_text( ": " ) );
	$div->appendChild( 
		$session->make_element( 
			"input",
			"maxlength"=>"255",
			"name"=>"username",
			"id"=>"username",
			"class"=>"ep_form_text",
			"size"=>"20", ));
	$form->appendChild( $div );
	$form->appendChild( $session->render_action_buttons( %buttons ) );
	
	$page->appendChild( $form );

	return( $page );
}	

1;
