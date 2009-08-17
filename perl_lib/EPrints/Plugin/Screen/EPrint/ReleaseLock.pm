package EPrints::Plugin::Screen::EPrint::ReleaseLock;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_actions",
			action => "release",
			position => 3100,
		},
		{
			place => "lock_tools",
			action => "release",
			position => 100,
		},
	];
	
	$self->{actions} = [qw/ release /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	return 0 if !defined $eprint;
	return 0 if !$eprint->is_locked();
	return 15 if( $eprint->get_value( "edit_lock_user" ) == $self->{handle}->current_user->get_id );

	return 0;
}

sub allow_release
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_release
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";
	
	$self->{processor}->{eprint}->set_value( "edit_lock_until", 0 );
	$self->{processor}->{eprint}->commit;

	$self->{processor}->add_message( "message", $self->html_phrase( "item_released" ) );
}


1;
