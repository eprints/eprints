=head1 NAME

EPrints::Profiler

=cut

package EPrints::Profiler;
require Exporter;

use strict;
use Time::HiRes qw( gettimeofday tv_interval );

our @ISA = qw( Exporter );
our @EXPORT_OK = qw( start_timer stop_timer lap_timer get_total_time print_timers );

my $timers = {};
my @timer_order = ();
sub start_timer
{
	my( $key ) = @_;
	my $timer = {};
	my @time = gettimeofday;

	if( !$timers->{$key} )
	{
		push @timer_order, $key;
	}
	
	$timer->{laps}->[0]->{start} = \@time;
	$timer->{currlap} = 0;
	$timers->{$key} = $timer;
}

sub stop_timer
{
	my( $key ) = @_; 
	
	if( $timers->{$key} )
	{
		my $timer = $timers->{$key};
		my $lap = $timer->{currlap};
		if( $lap > -1 )
		{
			my @time = gettimeofday;
			$timer->{laps}->[$lap]->{end} = \@time;
			$timer->{currlap} = -1;
		}
	}
}

sub lap_timer
{
	my( $key ) = @_; 
	
	if( $timers->{$key} )
	{
		my $timer = $timers->{$key};
		my $lap = $timer->{currlap};
		if( $lap > -1 )
		{
			my @time = gettimeofday;
			$timer->{laps}->[$lap]->{end} = \@time;
			$lap++;
			$timer->{laps}->[$lap]->{start} = \@time;
			$timer->{currlap} = $lap;
		}
	}
}

sub get_total_time
{
	my( $key ) = @_; 
	my $total = 0;
	if( $timers->{$key} )
	{
		my $timer = $timers->{$key};
		foreach my $lap ( @{$timer->{laps}} )
		{
			$total += tv_interval( $lap->{start}, $lap->{end} );
		}
	}
	return $total;
}

sub print_timers
{
	foreach my $key ( @timer_order )
	{
		my $timer = $timers->{$key};
		print "Timer: $key\n";
		my $n = 1;
		foreach my $lap ( @{$timer->{laps}} )
		{
			print "Lap $n: ".tv_interval( $lap->{start}, $lap->{end} )."\n";
			$n++;
		}
	}
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

