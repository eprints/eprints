=head1 NAME

EPrints::Plugin::Screen::Admin::Config::Edit::XPage

=cut

package EPrints::Plugin::Screen::Admin::Config::Edit::XPage;

use EPrints::Plugin::Screen::Admin::Config::Edit::XML;

@ISA = ( 'EPrints::Plugin::Screen::Admin::Config::Edit::XML' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
# See cfg.d/dynamic_template.pl
#		{
#			place => "key_tools",
#			position => 1250,
#			action => "edit",
#		},
	];

	push @{$self->{actions}}, qw( edit );

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/edit/static" );
}

sub allow_edit
{
	my( $self ) = @_;

	$self->{processor}->{conffile} ||= $self->{session}->get_static_page_conf_file;

	return defined $self->{processor}->{conffile};
}
sub action_edit {} # dummy action for key_tools

sub render_action_link
{
	my( $self ) = @_;

	my $conffile = $self->{processor}->{conffile};

	my $uri = URI->new( $self->{session}->current_url( path => 'cgi' , "users/home" ) );
	$uri->query_form(
		screen => substr($self->{id},8),
		configfile => $conffile,
	);

	my $link = $self->{session}->render_link( $uri );
	$link->appendChild( $self->{session}->html_phrase( "lib/session:edit_page" ) );

	return $link;
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

