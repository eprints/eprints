=head1 NAME

EPrints::Plugin::Screen::MetaField::View

=cut

package EPrints::Plugin::Screen::MetaField::View;

use EPrints::Plugin::Screen::Workflow::View;
@ISA = qw( EPrints::Plugin::Screen::Workflow::View );

sub edit_screen { "MetaField::Edit" }
sub view_screen { "MetaField::View" }
sub listing_screen { "MetaField::Listing" }
sub can_be_viewed
{
	my( $self ) = @_;

	return $self->{processor}->{dataobj}->isa( "EPrints::DataObj::MetaField" ) && $self->allow( "config/edit/perl" );
}

sub render_title
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $screen = $self->view_screen();

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};

	my $url = URI->new( $session->current_url );
	$url->query_form(
		screen => $self->listing_screen,
		dataset => $dataobj->value( "mfdatasetid" ),
	);
	my $listing = $session->render_link( $url );
	$listing->appendChild( $dataset->render_name( $session ) );

	my $desc = $dataobj->render_description();
	if( $self->{id} ne "Screen::$screen" )
	{
		$url->query_form(
			screen => $screen,
			dataset => $dataset->id,
			dataobj => $dataobj->id
		);
		my $link = $session->render_link( $url );
		$link->appendChild( $desc );
	}

	return $self->html_phrase( "page_title",
		listing => $listing,
		desc => $desc,
	);
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

