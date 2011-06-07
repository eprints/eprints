=head1 NAME

EPrints::Plugin::Screen::Import::View

=cut

package EPrints::Plugin::Screen::Import::View;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub get_dataset_id { "import" }

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "import_item_actions",
			position => 200,
		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $dataobj = $self->{processor}->{dataobj};

	my $page = $session->make_doc_fragment;

	my $ul = $session->make_element( "ul" );
	$page->appendChild( $ul );

	$dataobj->map(sub {
		my( undef, undef, $item ) = @_;

		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );

		$li->appendChild( $item->render_citation_link() );
	});

	return $page;
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

