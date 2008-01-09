package EPrints::Bench;

use Time::HiRes qw( gettimeofday );

our $totals = {};

our $starts = {};

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
	print "TOTALS\n";
	foreach ( sort keys %{$totals} )
	{
		printf(  "%16d - %s\n",$totals->{$_},$_ );
	}
}
BEGIN {
	enter( "MAIN" );
}
END {
	totals();
}
1;
