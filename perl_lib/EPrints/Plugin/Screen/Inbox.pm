=head1 NAME

EPrints::Plugin::Screen::Inbox

=cut


package EPrints::Plugin::Screen::Inbox;

use EPrints::Plugin::Screen::Listing;

@ISA = ( 'EPrints::Plugin::Screen::Review'); 

use strict;

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{session};

	$processor->{dataset} = $repo->dataset( "inbox" );
	$processor->{columns_key} = "screen.review.columns";

	$self->SUPER::properties_from;
}

sub get_filters
{
	my( $self ) = @_;

	return(
		{ meta_fields => [qw( eprint_status )], value => "inbox", },
	);
}

1;

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

