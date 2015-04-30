=head1 NAME

EPrints::Plugin::Event

=for Pod2Wiki

=head1 DESCRIPTION

Event plugins are called by the indexer to actually do work. L<EPrints::DataObj::EventQueue> objects are stored in the database and executed once their start_time is due. The object contains the plugin ID, action and optionally parameters.

Action is the sub called on the plugin. This sub must return undef or a valid response constant recognised by L<EPrints::DataObj::EventQueue/execute>.

Parameters can contain any Perl data structure that can be serialised by L<Storable>. As a special case parameters that look like an internal id are re-instantiated as the referenced object before the plugin action is called.

Events also support scheduled (or repeating) events by calling L</cron> on this class with the actual plugin id/action/parameters to call. The scheduled event isn't called directly but is triggered via a new event object with a start_time of now.

=head1 SYNOPSIS

	EPrints::DataObj::EventQueue->create_unique( $repo, {
		pluginid => "Event::Hello",
		action => "hello",
		params => ["John Smith"],
	});
	
	EPrints::DataObj::EventQueue->create_unique( $repo, {
		pluginid => "Event",
		action => "cron",
		params => ["0,15,30,45 * * * *",
			"Event::Hello",
			"hello",
			"John Smith",
		],
	});

=cut

package EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin );

use strict;

my @RANGES = (
	"0-59",
	"0-23",
	"1-31",
	"1-12",
	"0-6",
);

sub new
{
	my( $class, %params ) = @_;

	$params{visible} = exists $params{visible} ? $params{visible} : "all";
	$params{advertise} = exists $params{advertise} ? $params{advertise} : 1;

	return $class->SUPER::new(%params);
}

# debug utility, just log whatever the parameters are
sub echo
{
	my( $class, @params ) = @_;

	for(@params)
	{
		$_ = $_->internal_uri if UNIVERSAL::isa( $_, "EPrints::DataObj" );
	}

	warn join ', ', @params;

	return;
}

sub cron
{
	my( $self, $time_spec, $pluginid, $action, @params ) = @_;

	my $event = $self->{event};

	# queue the actual action
	EPrints::DataObj::EventQueue->create_unique( $self->{session}, {
		pluginid => $pluginid,
		action => $action,
		params => \@params,
	});

	my $next_t = $self->_next_execution_time( $time_spec );
	$event->set_value( "start_time", EPrints::Time::iso_datetime( $next_t ) );

	return EPrints::Const::HTTP_RESET_CONTENT;
}

sub _next_execution_time
{
	my( $self, $time_spec ) = @_;

	my @entry = split /\s+/, $time_spec;
	Carp::croak( "Error in $time_spec: expected 5 entries but got ".@entry )
		if @entry != 5;

	local $_;

	my $i = 0;
	for(@entry)
	{
		$_ = $RANGES[$i] if $_ eq '*';
		$_ =~ s/([0-9]{1,2})-([0-9]{1,2})/join(',',$1 .. $2)/eg;
		$_ = {
			map { $_ => 1 }
			split /,/, $_
		};
		$i++;
	}

	my $next_t = time();
	$next_t -= $next_t % 60;
	$next_t += 60;

	# this algorithm increments $next_t until it is an acceptable value for the
	# cron entry
	# for better efficiency it increments by the largest non-matching criteria
	# (e.g. a month if the current month is no good)
	while(_increment( $next_t, @entry ))
	{
		EPrints->abort( "Out of cron range" )
			if $next_t > time() + 31622400;
	}

	return $next_t;
}

# return true if we incremented $t
sub _increment
{
	my( $t, @entry ) = @_;

	# @entry[0] = hash of minutes to run
        # @entry[1] =    "    hours to run
        #       [2] =    "    days of month
        #       [3] =    "    months to run
        #       [4] =    "    days of week to run

	my @t = (gmtime($t))[0..7];
	$t[4]++; # month

	# month: if this month isn't in the months we should run
	#  increment to midnight of the start of next month.
	if( !exists $entry[3]{$t[4]} )
	{
		$_[0] -= 86400 * ($t[3] - 1);
		$_[0] -= $_[0] % 86400;
		if( $t[4] == 12 )
		{
			@t = (gmtime($_[0]))[0..7];
			$t[4] = 0; # month
			$t[5]++; # year
			$_[0] = Time::Local::timegm(@t);
		}
		else
		{
			@t = (gmtime($_[0]))[0..7];
			$t[4]++; # month
			$_[0] = Time::Local::timegm(@t);
		}
		return 1;
	}

	# day of week / day of month
	# if today isn't a day of the week we should run
	#      OR
	#    today isn't a day of the month we should run
	# increment to tomorrow.
	if( !exists $entry[4]{$t[6]} || !exists $entry[2]{$t[3]} )
	{
		$_[0] -= $_[0] % 86400;
		$_[0] += 86400;
		return 1;
	}

	# hour: if this hour isn't an hour we should run, increment to the next hour
	if( !exists $entry[1]{$t[2]} )
	{
		$_[0] -= $_[0] % 3600;
		$_[0] += 3600;
		return 1;
	}

	# minute
	if( !exists $entry[0]{$t[1]} )
	{
		$_[0] += 60;
		return 1;
	}

	return 0;
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

