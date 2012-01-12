=head1 NAME

EPrints::Plugin::Issues::SimilarTitles

=cut

package EPrints::Plugin::Issues::SimilarTitles;

use EPrints::Plugin::Issues::ExactTitleDups;

@ISA = ( "EPrints::Plugin::Issues::ExactTitleDups" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Similar titles";
	$self->{accept} = [qw( list/eprint )];

	return $self;
}

sub process_dataobj
{
	my( $self, $eprint, %opts ) = @_;

	my $title = $eprint->value( "title" );
	return if !EPrints::Utils::is_set( $title );

	push @{$self->{titles}->{make_code( $title )}}, $eprint->id;
}

sub make_code
{
	my( $string ) = @_;

	local $_;
	for($string) {

	# Lowercase string
	$_ = lc;

	# remove one and two character words
	s/\b\p{Alnum}{1,2}\b//g; 

	# turn one-or more non-alphanumerics into a single space.
	s/\P{Alnum}+/ /g;

	# remove leading and ending spaces
	s/^ //;
	s/ $//;

	# remove double characters
	s/([^ ])\1/$1/g;

	# remove English vowels 
	s/[aeiou]//g;

	} # end of $_-alias

	return $string;
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

