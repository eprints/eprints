=head1 NAME

EPrints::Plugin::Screen::User::View

=cut


package EPrints::Plugin::Screen::User::View;

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
			position => 200,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 if !defined $self->{session}->current_user;
	return $self->{session}->current_user->allow( "user/view", $self->{session}->current_user );
}

sub from
{
	my( $self ) = @_;

	my $url = $self->{session}->current_url( path => "cgi", "users/home" );
	$url->query_form(
		screen => 'Workflow::View',
		dataset => 'user',
		dataobj => $self->{session}->current_user->id
	);

	$self->{session}->redirect( $url );
	exit;
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

