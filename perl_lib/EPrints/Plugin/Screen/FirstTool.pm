=head1 NAME

EPrints::Plugin::Screen::FirstTool - the first screen to show

=head1 DESCRIPTION

This plugin is the screen shown by the L<EPrints::ScreenProcessor> if there is no 'screen' parameter.

By default this plugin redirects to L<EPrints::Plugin::Screen::Items> or L<EPrints::Plugin::Screen::User::View> for minusers. To override this use:

	$c->{plugins}->{"Screen::FirstTool"}->{params}->{default} = "Screen::First";

Or for a customisable screen supply a callback (which will be passed the FirstTool screen):

	$c->{plugins}->{"Screen::FirstTool"}->{params}->{default} = sub {
		my( $screen ) = @_;

		return "Items";
	};

=cut

package EPrints::Plugin::Screen::FirstTool;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	my $screenid = $self->param( "default" );
	my $screen;

	# we will always try to show the custom screen even if it gets an access
	# denied
	if( defined $screenid )
	{
		if( ref($screenid) eq "CODE" )
		{
			$screenid = &$screenid( $self );
		}
		if( defined $screenid )
		{
			$screen = $self->{session}->plugin( "Screen::$screenid",
					processor => $self->{processor},
				);
		}
	}
	else
	{
		# the old behaviour was to pick out the first "key_tool" but that isn't
		# helpful when the first key_tool is now Login (/Logout)
		for(qw( Items User::View ))
		{
			$screenid = $_;
			$screen = $self->{session}->plugin( "Screen::$screenid",
					processor => $self->{processor},
				);
			next if !defined $screen;
			undef $screen if !$screen->can_be_viewed;
			last if defined $screen;
		}
	}
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

