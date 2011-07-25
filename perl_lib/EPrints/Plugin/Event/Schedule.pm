package EPrints::Plugin::Event::Schedule;

@ISA = qw( EPrints::Plugin::Event );

use strict;

my @RANGES = (
	"0-59",
	"0-23",
	"1-31",
	"1-12",
	"0-6",
);

sub execute
{
	my( $self, $time_spec, $pluginid, $action, @params ) = @_;

	my $event = $self->{event};

	# queue the actual action
	EPrints::DataObj::EventQueue->create_unique( $self->{session}, {
		pluginid => $pluginid,
		action => $action,
		params => \@params,
	});

	my $next_t = $self->next_execution_time( $time_spec );
	$event->set_value( "start_time", EPrints::Time::iso_datetime( $next_t ) );

	return EPrints::Const::HTTP_RESET_CONTENT;
}

sub next_execution_time
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

	my @t = (gmtime($t))[0..7];
	$t[4]++; # month

	# month
	if( !exists $entry[3]{$t[4]} )
	{
		$_[0] -= 86400 * $t[3];
		$_[0] -= $_[0] % 86400;
		if( $t[3] == 12 )
		{
			$_[0] = Time::Local::timegm(@t[0..3],0,$t[5]+1);
		}
		else
		{
			$_[0] = Time::Local::timegm(@t[0..5]);
		}
		return 1;
	}

	# day of week / day of month
	if( !exists $entry[4]{$t[6]} && !exists $entry[2]{$t[3]} )
	{
		$_[0] -= $_[0] % 86400;
		$_[0] += 86400;
		return 1;
	}

	# hour
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
