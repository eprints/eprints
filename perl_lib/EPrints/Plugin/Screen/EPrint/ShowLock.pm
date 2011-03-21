=head1 NAME

EPrints::Plugin::Screen::EPrint::ShowLock

=cut

package EPrints::Plugin::Screen::EPrint::ShowLock;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "locked.png";
	$self->{appears} = [
		{
			place => "eprint_item_actions",
			position => -100,
		},
		{
			place => "eprint_review_actions",
			position => -100,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};
	return 0 if $self->could_obtain_eprint_lock;
	return 1 if $self->{processor}->{eprint}->is_locked;

	return 0;
}

sub render_title
{
	my( $self ) = @_;

	return $self->{processor}->{eprint}->render_value( "edit_lock_user" );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{processor}->{eprint};

	my $page = $session->make_doc_fragment;

	$page->appendChild( $self->render_action_list_bar( "lock_tools", ['eprintid'] ) );

	my $since = $eprint->get_value( "edit_lock_since" ); 
	my $until = $eprint->get_value( "edit_lock_until" ); 

	$page->appendChild( $self->html_phrase( "item_locked",
		locked_by => $eprint->render_value( "edit_lock_user" ),
		locked_since => $session->make_text( EPrints::Time::human_time( $since ) ),
		locked_until => $session->make_text( EPrints::Time::human_time( $until ) ),
		locked_remaining => $session->make_text( $until - time ), ));

	return $page;
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

