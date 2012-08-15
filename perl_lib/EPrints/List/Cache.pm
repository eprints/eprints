=pod

=head1 NAME

EPrints::List::Cache

=head1 METHODS

=cut

package EPrints::List::Cache;

@ISA = qw( EPrints::List );

use strict;

sub new
{
	my( $class, %self ) = @_;

	my $self = bless \%self, $class;

	my $dataset = $self->{repository}->dataset( "cachemap" );

	if( defined $self->{cache_id} )
	{
		$self->{cache} = $dataset->dataobj( $self->{cache_id} );
	}
	elsif( defined $self->{ids} )
	{
		$self->cache;
	}

	return $self;
}

=item $list->cache()

Cache the matching items in this list in the database.

=cut

sub cache
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	return if defined $self->{cache};

	my $user = $repo->current_user;

	my $dataset = $repo->dataset( "cachemap" );

	my $cache = $dataset->create_dataobj( {
		userid => (defined $user ? $user->id : undef),
	} );

	$cache->store( $self->{dataset}, $self->{ids} );

	$self->{cache} = $cache;
}

=item $id = $list->cache_id()

Returns the id of the cache object (if cached).

=cut

sub cache_id
{
	my( $self ) = @_;

	if( defined $self->{cache} )
	{
		return $self->{cache}->id;
	}

	return;
}

1;

######################################################################
=pod

=back

=cut


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

