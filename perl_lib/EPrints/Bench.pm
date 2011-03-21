=head1 NAME

EPrints::Bench

=cut

package EPrints::Bench;

use Time::HiRes qw( gettimeofday );

our @ids = ();

our $totals = {};

our $starts = {};

sub clear
{
	@ids = ();
	$totals = {};
	$starts = {};
}

sub hitime
{
	my( $s,$ms ) = gettimeofday();

	return $s*1000000+$ms;
}

sub enter
{
	my( $id ) = @_;

	if( defined $starts->{$id} )
	{
		die "Double entry in $id";
	}

	push @ids, $id;
	$starts->{$id} = hitime();
}

sub leave
{
	my( $id ) = @_;

	if( !defined $starts->{$id} )
	{
		die "Leave without enter in $id";
	}

	$totals->{$id}+=hitime()-$starts->{$id};	
	delete $starts->{$id};
}

sub totals
{
	print STDERR "TOTALS\n";
	my %seen;
	foreach ( @ids )
	{
		next if $seen{$_};
		$seen{$_} = 1;
		print STDERR sprintf("%16d - %s\n", $totals->{$_} , $_);
	}
}
BEGIN {
	enter( "MAIN" );
}
END {
	totals();
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

