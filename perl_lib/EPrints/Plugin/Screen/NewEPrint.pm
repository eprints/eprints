=head1 NAME

EPrints::Plugin::Screen::NewEPrint

=cut


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

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $url = URI->new($self->{processor}->{url});
	$url->query_form( 
		screen => $self->{processor}->{screenid},
		_action_create => 1
		);

	$session->redirect( $url );
	$session->terminate();
	exit(0);
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

