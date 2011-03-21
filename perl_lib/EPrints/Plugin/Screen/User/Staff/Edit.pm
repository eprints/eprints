=head1 NAME

EPrints::Plugin::Screen::User::Staff::Edit

=cut


package EPrints::Plugin::Screen::User::Staff::Edit;

use EPrints::Plugin::Screen::User::Edit;

@ISA = ( 'EPrints::Plugin::Screen::User::Edit' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{appears} = [
		{
			place => "user_actions",
			position => 1000,
		}
	];

	$self->{staff} = 1;

	return $self;
}

sub workflow
{
	my( $self ) = @_;

	return $self->SUPER::workflow( 1 );
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/staff/edit" );
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

