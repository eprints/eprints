=head1 NAME

EPrints::Plugin::Screen::User::Remove

=cut

package EPrints::Plugin::Screen::User::Remove;

our @ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "user_actions",
			position => 1600,
		}
	];
	
	$self->{actions} = [qw/ remove cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/remove" );
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_delete", 
		title=>$self->{processor}->{user}->render_description() ) );

	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		remove => $self->{session}->phrase(
				"lib/submissionform:action_remove" ),
		_order => [ "remove", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub allow_remove
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "User::View";
}

sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "FirstTool";

	if( !$self->{processor}->{user}->remove )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( "DB error removing User ".$self->{processor}->{user}->get_value( "userid" ).": $db_error" );
		$self->{processor}->add_message( "message", $self->html_phrase( "user_not_removed" ) );
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "user_removed" ) );
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

