=head1 NAME

EPrints::Plugin::Screen::EPrint::TakeLock

=cut

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

	my $edit_lock_user = $session->user( $eprint->value( "edit_lock_user" ) );
	if( defined $edit_lock_user )
	{
		$edit_lock_user->create_subdataobj( "messages", {
			type => "warning",
			message => $self->html_phrase( "lock_taken", user=>$user->render_citation, item=>$a ),
		});
	}
	
	$eprint->set_value( "edit_lock_until", 0 );
	$eprint->obtain_lock( $user );
	$self->{processor}->add_message( "message", $self->html_phrase( "item_taken" ) );
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

