=head1 NAME

EPrints::Plugin::Screen::EPrint::Box

=cut

package EPrints::Plugin::Screen::EPrint::Box;

our @ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	# Register sub-classes but not this actual class.
	if( $class ne "EPrints::Plugin::Screen::EPrint::Box" )
	{
		$self->{appears} = [
			{
				place => "summary_right",
				position => 1000,
			},
		];
	}

	return $self;
}

sub render_collapsed { return 0; }

sub can_be_viewed { return 1; }

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_text( "Please add a 'render' method to this box!" );
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

