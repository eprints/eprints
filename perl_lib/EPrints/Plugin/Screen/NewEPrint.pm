
package EPrints::Plugin::Screen::NewEPrint;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create /];

	$self->{appears} = [
		{
			place => "item_tools",
			action => "create",
			position => 100,
		}
	];

	return $self;
}

sub allow_create
{
	my ( $self ) = @_;

	return $self->allow( "create_eprint" );
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{session}->get_repository->get_dataset( "inbox" );

	my $user = $self->{session}->current_user;

	$self->{processor}->{eprint} = $ds->create_object( $self->{session}, { 
		userid => $user->get_value( "userid" ) } );

	if( !defined $self->{processor}->{eprint} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{eprintid} = $self->{processor}->{eprint}->get_id;
	$self->{processor}->{screenid} = "EPrint::Edit";

}



1;
