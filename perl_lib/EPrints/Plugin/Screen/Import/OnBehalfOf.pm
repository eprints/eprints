=head1 NAME

EPrints::Plugin::Screen::Import::OnBehalfOf

=cut


package EPrints::Plugin::Screen::Import::OnBehalfOf;

use base qw( EPrints::Plugin::Screen::Import::Upload );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
#		{
#			place => "user_view_action_links",
#			position => 500,
#		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	$self->{processor}->{screenid} = "Import::Upload";
}

sub hidden_bits
{
	my( $self ) = @_;

	local $self->{processor}->{dataset};
	local $self->{processor}->{results};

	return(
		$self->SUPER::hidden_bits,
		on_behalf_of => $self->{processor}->{dataobj}->id,
	);
}

sub render_title { shift->EPrints::Plugin::Screen::render_title }

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2012-2012 University of Southampton.

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

