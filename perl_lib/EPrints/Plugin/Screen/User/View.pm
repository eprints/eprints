=head1 NAME

EPrints::Plugin::Screen::User::View

=cut


package EPrints::Plugin::Screen::User::View;

use EPrints::Plugin::Screen::User;

@ISA = ( 'EPrints::Plugin::Screen::User' );

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

sub render
{
	my( $self ) = @_;
	
	my $session = $self->{session};

	my $page = $session->make_doc_fragment();

	my ($data,$title) = $self->{processor}->{user}->render; 

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	$page->appendChild( $div );
	$div->appendChild( $data );
	
	$page->appendChild( $self->render_action_list( "user_actions", ['userid'] ) );

	return $page;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/view" );
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

