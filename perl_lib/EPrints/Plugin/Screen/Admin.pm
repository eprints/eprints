=head1 NAME

EPrints::Plugin::Screen::Admin

=cut

package EPrints::Plugin::Screen::Admin;

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
			position => 1000,
		},
	];
	$self->{action_lists} = [qw(
		admin_actions_editorial
		admin_actions_system
		admin_actions_config
		admin_actions
	)];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;
	
	foreach my $list_id ( @{$self->param( "action_lists" )} )
	{
		return 1 if scalar $self->action_list( $list_id );
	}
	return 0;
}

sub render
{
	my( $self ) = @_;

	my @labels;
	my @panels;

	foreach my $list_id ( @{$self->param( "action_lists" )} )
	{
		next unless scalar $self->action_list( $list_id );
		push @labels, $self->html_phrase( $list_id );
		push @panels, $self->render_action_list( $list_id );
	}

	return $self->{repository}->xhtml->tabs(
		\@labels,
		\@panels,
		basename => "ep_admin_tabs",
	);
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

