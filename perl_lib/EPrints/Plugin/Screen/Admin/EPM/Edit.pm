=head1 NAME

EPrints::Plugin::Screen::Admin::EPM::Edit

=cut

package EPrints::Plugin::Screen::Admin::EPM::Edit;

use EPrints::Plugin::Screen::Workflow::Edit;
@ISA = ( 'EPrints::Plugin::Screen::Workflow::Edit' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ save stop /];
		
	$self->{appears} = [];

	return $self;
}

sub can_be_viewed { shift->EPrints::Plugin::Screen::Admin::EPM::can_be_viewed( @_ ) }
sub allow_stop { shift->can_be_viewed( @_ ) }
sub allow_save { shift->can_be_viewed( @_ ) }

sub properties_from
{
	shift->EPrints::Plugin::Screen::Admin::EPM::properties_from();
}

sub action_stop
{
	my( $self ) = @_;

	$self->{processor}->{notes}->{ep_tabs_current} = "Admin::EPM::Developer";

	$self->SUPER::action_stop;
}

sub action_save
{
	my( $self ) = @_;

	$self->{processor}->{notes}->{ep_tabs_current} = "Screen::Admin::EPM::Developer";

	$self->SUPER::action_save;
}

sub view_screen { "Admin::EPM" }

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

