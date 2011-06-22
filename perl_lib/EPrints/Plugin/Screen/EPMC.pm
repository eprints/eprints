=head1 NAME

EPrints::Plugin::Screen::EPMC - Package manager controller

=head1 DESCRIPTION

This screen is a controller for installed packages. It allows the user to enable, disable or configure an installed package.

Configuration is the default view for this screen.

=cut

package EPrints::Plugin::Screen::EPMC;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{actions} = [qw( enable disable )];

	return $self;
}

sub reload_config
{
	my( $self ) = @_;

	my $plugin = $self->{repository}->plugin( "Screen::Admin::Reload",
		processor => $self->{processor}
	);
	if( defined $plugin )
	{
		local $self->{processor}->{screenid};
		$plugin->action_reload_config;
	}
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "repository/epm" );
}
sub allow_enable { shift->can_be_viewed( @_ ) }
sub allow_disable { shift->can_be_viewed( @_ ) }
sub allow_uninstall { shift->can_be_viewed( @_ ) }

sub properties_from
{
	shift->EPrints::Plugin::Screen::Admin::EPM::properties_from();
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		epm => $self->{processor}->{dataobj}->id,
	);
}

sub action_enable
{
	my( $self, $skip_reload ) = @_;

	$self->{processor}->{dataobj}->enable( $self->{processor} );

	$self->reload_config if !$skip_reload;

	$self->{processor}->{screenid} = "Admin::EPM";
}

sub action_disable
{
	my( $self, $skip_reload ) = @_;

	$self->{processor}->{dataobj}->disable( $self->{processor} );

	$self->reload_config if !$skip_reload;

	$self->{processor}->{screenid} = "Admin::EPM";
}

sub render_action_link
{
	my( $self ) = @_;

	return $self->{repository}->xml->create_document_fragment;
}

sub render
{
	my( $self ) = @_;

	return $self->{repository}->xml->create_document_fragment;
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

