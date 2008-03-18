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
