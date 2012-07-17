=head1 NAME

EPrints::Plugin::Screen::EPrint::History

=cut

package EPrints::Plugin::Screen::EPrint::History;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{expensive} = 1;
	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 600,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/history" );
}



sub render
{
	my( $self, $basename ) = @_;

	my $repo = $self->repository;

	my $eprint = $self->{processor}->{eprint};

	my @filters = (
		{ meta_fields => [qw( datasetid )], value => 'eprint', },
		{ meta_fields => [qw( objectid )], value => $eprint->id, },
	);

	my $list = $repo->dataset( "history" )->search(
		filters => \@filters,
		custom_order=>"-historyid",
#		limit => 10,
	);

	return EPrints::Paginate->paginate_list(
		$repo,
		$basename,
		$list,
		params => {
			$self->{processor}->{screen}->hidden_bits,
		},
		container => $repo->make_element( "div" ),
		render_result => sub {
			my( undef, $item ) = @_;

			$item->set_parent( $eprint );
			return $item->render;
		},
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

