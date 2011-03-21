=head1 NAME

EPrints::Plugin::Screen::FirstTool - the first screen to show

=head1 DESCRIPTION

This plugin is the screen shown by the ScreenProcessor if there is no 'screen' parameter.

This plugin redirects to the "Items" screen by default. To change this use:

	$c->{plugins}->{"Screen::FirstTool"}->{params}->{default} = "Screen::First";

=cut

package EPrints::Plugin::Screen::FirstTool;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	my $screenid = $self->param( "default" );
	$screenid = "Items" if !defined $screenid;
	my $screen = $self->{session}->plugin( "Screen::$screenid",
			processor => $self->{processor},
		);
	if( defined $screen )
	{
		$self->{processor}->{screenid} = $screenid;
		$screen->properties_from;
	}
}

sub render
{
	my( $self ) = @_;

	return $self->html_phrase( "no_tools" );
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

