=head1 NAME

EPrints::Plugin::Screen::Logout

=cut

package EPrints::Plugin::Screen::Logout;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
# See cfg.d/dynamic_template.pl
#		{
#			place => "key_tools",
#			position => 10000,
#		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return defined $self->{session}->current_user;
}

sub render_action_link
{
	my( $self, %opts ) = @_;

	my $link = $self->SUPER::render_action_link( %opts );
	$link->setAttribute( href => $self->{session}->get_url( path => "cgi", "logout" ) );

	return $link;
}

sub render
{
	my( $self ) = @_;

	my $xml = $self->{session}->xml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->{session}->render_message(
		"message",
		$self->html_phrase( "success" )
	) );

	$frag->appendChild( $self->{session}->html_phrase( "general:frontpage_link" ) );

	return $frag;
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

