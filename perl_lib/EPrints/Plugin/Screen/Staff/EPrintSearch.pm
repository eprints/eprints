=head1 NAME

EPrints::Plugin::Screen::Staff::EPrintSearch

=cut


package EPrints::Plugin::Screen::Staff::EPrintSearch;

use EPrints::Plugin::Screen::Search;
@ISA = ( 'EPrints::Plugin::Screen::Search' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "admin_actions_editorial",
			position => 500,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "staff/eprint_search" );
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{dataset} = $self->repository->dataset( "eprint" );
	$self->{processor}->{searchid} = "staff";

	$self->SUPER::properties_from;
}

sub default_search_config
{
	my( $self ) = @_;

	my $sconf = EPrints::Utils::clone(
			$self->repository->config( "search", "advanced" )
		);

	delete $sconf->{preamble_phrase};
	delete $sconf->{title_phrase};

	$sconf->{staff} = 1;

	unshift @{$sconf->{search_fields}},
			{ meta_fields => [qw( eprintid )] },
			{ meta_fields => [qw( userid.username )] },
			{ meta_fields => [qw( userid.name )] },
			{ meta_fields => [qw( eprint_status )], default=>"archive buffer" },
			{ meta_fields => [qw( dir )] };

	if( $self->param( "extra_fields" ) )
	{
		unshift @{$sconf->{search_fields}}, @{$self->param( "extra_fields" )};
	}

	return $sconf;
}

# suppress dataset=
sub hidden_bits
{
	return shift->EPrints::Plugin::Screen::AbstractSearch::hidden_bits();
}

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

