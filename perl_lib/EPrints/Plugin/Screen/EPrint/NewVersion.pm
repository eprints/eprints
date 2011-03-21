=head1 NAME

EPrints::Plugin::Screen::EPrint::NewVersion

=cut

package EPrints::Plugin::Screen::EPrint::NewVersion;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	#	$self->{priv} = # no specific priv - one per action

	$self->{actions} = [qw/ new_version /];

	$self->{appears} = [
{ place => "eprint_actions", 	action => "new_version", 	position => 500, },
	];

	return $self;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub allow_new_version
{
	my( $self ) = @_;

	return $self->allow( "eprint/derive_version" );
}

sub action_new_version
{
	my( $self ) = @_;

	my $inbox_ds = $self->{session}->get_archive()->get_dataset( "inbox" );
	my $copy = $self->{processor}->{eprint}->clone( $inbox_ds, 1 );
	$copy->set_value( "userid", $self->{session}->current_user->get_value( "userid" ) );
	$copy->commit();

	$self->{processor}->add_message( "message",
		$self->html_phrase( "success" ) );

	$self->{processor}->{eprint} = $copy;
	$self->{processor}->{eprintid} = $copy->get_id;
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

