package EPrints::Plugin::Screen::EPrint::TakeLock;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_actions",
			action => "take",
			position => 3000,
		},
		{
			place => "eprint_editor_actions",
			action => "take",
			position => 3000,
		},
		{
			place => "lock_tools",
			action => "take",
			position => 200,
		},
	];
	
	$self->{actions} = [qw/ take /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 if $self->could_obtain_eprint_lock;

	return $self->allow( "eprint/takelock" );
}

sub allow_take
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_take
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";

	my $session = $self->{session};
	my $eprint = $self->{processor}->{eprint};
	my $user = $session->current_user;

	my $title = $eprint->render_citation( "screen" );
	my $a = $session->render_link( "?screen=EPrint::View&eprintid=".$self->{processor}->{eprintid} );
	$a->appendChild( $title );

	$self->{session}->get_database->save_user_message( 
			$eprint->get_value( "edit_lock_user" ),
			"warning",
			$self->html_phrase( "lock_taken", user=>$user->render_citation, item=>$a ) );
	
	$eprint->set_value( "edit_lock_until", 0 );
	$eprint->obtain_lock( $user );
	$self->{processor}->add_message( "message", $self->html_phrase( "item_taken" ) );
}


1;
