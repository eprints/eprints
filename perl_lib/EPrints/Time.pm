######################################################################
#
# EPrints::Time
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Time> - Time and Date-related functions 

=head1 SYNOPSIS

	EPrints::Time::render_date( $handle, "2001-01-12T00:00:00Z" ) 
	# returns XML containing 12 January 2001 00:00

	EPrints::Time::render_short_date( $handle, "2001-01-12T00:00:00Z" ) 
	# returns XML containing 12 Jan 2001 00:00
	
	EPrints::Time::get_iso_timestamp( ); 
	# returns NOW in the form YYYY-MM-DDTHH:MM:SSZ
	
	EPrints::Time::human_delay( 28 ); 
	# returns "1 day"
	
	EPrints::Time::get_month_label( $handle, 11 ) 
	# returns November
	
	EPrints::Time::get_month_label_short( $handle, 11 ) 
	# returns Nov

=head1 DESCRIPTION

This package contains functions related to time/date functionality. 



=cut

package EPrints::Time;

use POSIX qw(strftime);
use Time::Local 'timegm_nocheck';

######################################################################
=pod

=over 4

=item $xhtml = EPrints::Time::render_date( $handle, $datevalue )

Render the given date or date and time as a chunk of XHTML.

$datevalue is given in a UTC timestamp of the form YYYY-MM-DDTHH:MM:SSZ but it will be rendered in the local offset.

e.g EPrints::Time::render_date( $handle, "2001-01-12T00:00:00Z" ) #returns XML containing 12 January 2001 00:00

=cut
######################################################################

sub render_date
{
	my( $handle, $datevalue) = @_;
	return _render_date( $handle, $datevalue, 0 );
}

######################################################################
=pod

=item $xhtml = EPrints::Time::render_short_date( $handle, $datevalue )

Renders a short version of the given date or date and time as a chunk of XHTML.

$datevalue is given in UTC timestamp of the form YYYY-MM-DDTHH:MM:SSZ but it will be rendered in the local offset.

e.g EPrints::Time::render_short_date( $handle, "2001-01-12T00:00:00Z" ) #returns XML containing 12 Jan 2001 00:00

=cut
######################################################################

sub render_short_date
{
	my( $handle, $datevalue) = @_;
	return _render_date( $handle, $datevalue, 1 );
}

######################################################################
=pod

=item $xhtml = EPrints::Time::datestring_to_timet( $handle, $datevalue )

Returns an interger number of seconds since 1970-01-01:00:00

$datevalue - in the format YYYY-MM-DDTHH:MM:SSZ 

=cut
######################################################################

sub datestring_to_timet
{
	my( $handle, $datevalue ) = @_;

	my( $year,$mon,$day,$hour,$min,$sec ) = split /[- :TZ]/, $datevalue;

	my $t = timegm_nocheck $sec||0,$min||0,$hour,$day,$mon-1,$year-1900;

	return $t;
}

sub _render_date
{
	my( $handle, $datevalue, $short ) = @_;

	if( !defined $datevalue )
	{
		return $handle->html_phrase( "lib/utils:date_unspecified" );
	}

	# remove 0'd days and months
	$datevalue =~ s/(-0+)+$//;

	# the is the gmtime
	my( $year,$mon,$day,$hour,$min,$sec ) = split /[- :TZ]/, $datevalue;

	if( defined $hour )
	{
		# if we have a time as well as a date then shift it to
		# localtime.
		my $t = timegm_nocheck $sec||0,$min||0,$hour,$day,$mon-1,$year-1900;
		my @l = localtime( $t );
		$l[0] = undef unless defined $sec;
		$l[1] = undef unless defined $min;
		( $sec,$min,$hour,$day,$mon,$year ) = ( $l[0], $l[1], $l[2], $l[3], $l[4]+1, $l[5]+1900 );
	}


	if( !defined $year || $year eq "undef" || $year eq "" || $year == 0 ) 
	{
		return $handle->html_phrase( "lib/utils:date_unspecified" );
	}

	# 1999
	my $r = $year;

	my $month_name;
	if( defined $mon )
	{
		if( $short )	
		{
			$month_name = EPrints::Time::get_month_label_short( $handle, $mon );
		}
		else
		{
			$month_name = EPrints::Time::get_month_label( $handle, $mon );
		}
		$r = "$month_name $r";
	}
	if( $short ) 
	{
		$r = sprintf( "%02d",$day)." $r" if( defined $day );
	}
	else
	{
		$r = "$day $r" if( defined $day );
	}

	if( !defined $hour )
	{
		return $handle->make_text( $r );
	}

	my $time;
	if( defined $sec ) 
	{
		$time = sprintf( "%02d:%02d:%02d",$hour,$min,$sec );
	}
	elsif( defined $min )
	{
		$time = sprintf( "%02d:%02d",$hour,$min );
	}
	else
	{
		$time = sprintf( "%02d",$hour );
	}
	$r .= " ".$time;

	my $gmt_off = gmt_off();
	my $hour_diff = $gmt_off/60/60;
	my $min_diff = ($gmt_off/60)%60;
	my $c = "";
	if( $hour_diff >= 0 ) { $c="+"; }
	my $off = sprintf( ' %s%02d:%02d', $c, $hour_diff, $min_diff );

	$r .= " ".$off if( !$short );

	return $handle->make_text( $r );
}

######################################################################
=pod

=item $xhtml = EPrints::Time::gmt_off()

Render the current time offset in seconds. This just diffs gmtime
and localtime.

=cut
######################################################################

sub gmt_off
{
	my $time = time;
	my( @local ) = localtime($time);
	my( @gmt ) = gmtime($time);
 
	my @diff;
 
	for(0..2) { $diff[$_] = $local[$_] - $gmt[$_]; }

	my $local_cmp_code = $local[3]+$local[4]*100+$local[5]*10000; 
	my $gmt_cmp_code = $gmt[3]+$gmt[4]*100+$gmt[5]*10000; 
	if( $local_cmp_code > $gmt_cmp_code ) { $diff[2] += 24; }
	if( $local_cmp_code < $gmt_cmp_code ) { $diff[2] -= 24; }
 
	return $diff[2]*60*60 + $diff[1]*60 + $diff[0];
}


######################################################################
=pod

=item $label = EPrints::Time::get_month_label( $handle, $monthid )

Return a UTF-8 string describing the month, in the current lanugage.

$monthid is an integer from 1 to 12.

e.g EPrints::Time::get_month_label( $handle, 11 ) # returns November

=cut
######################################################################

sub get_month_label
{
	my( $handle, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_%02d", $monthid );

	return $handle->phrase( $code );
}

######################################################################
=pod

=item $label = EPrints::Time::get_month_label_short( $handle, $monthid )

Return a UTF-8 string of a short representation in  month, in the current lanugage.

$monthid is an integer from 1 to 12.

e.g EPrints::Time::get_month_label_short( $handle, 11 ) # returns Nov

=cut
######################################################################

sub get_month_label_short
{
	my( $handle, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_short_%02d", $monthid );

	return $handle->phrase( $code );
}

######################################################################
=pod

=item ($year,$month,$day) = EPrints::Time::get_date_array( [$time] )

Static method that returns the given time (in UNIX time, seconds 
since 1.1.79) in an array.

This is the local date not the UTC date.

=cut
######################################################################
sub get_date { return get_date_array( @_ ); }

sub get_date_array
{
	my( $time ) = @_;

	$time = time unless defined $time;

	my @date = localtime( $time );

	return( 
		sprintf( "%02d", $date[5]+1900 ),
		sprintf( "%02d", $date[4]+1 ),
		sprintf( "%02d", $date[3] ) );
}



######################################################################
=pod

=item  $datestamp = EPrints::Time::get_iso_date( [$time] )

Method that returns the given time (in UNIX time, seconds 
since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).

This is the localtime date, not UTC.

=cut
######################################################################

sub get_iso_date
{
	my( $time ) = @_;

	$time = time unless defined $time;

	my( $year, $month, $day ) = EPrints::Time::get_date( $time );

	return( $year."-".$month."-".$day );
}


######################################################################
=pod

=item $timestamp = EPrints::Time::human_time( [$time] )

Return a string describing the current local date and time in the
current locale's format (see Perl's 'localtime).

=cut
######################################################################

sub human_time
{
	my( $time ) = @_;

	$time = time unless defined $time;

	my $stamp = sprintf("%s %s",
		scalar(localtime($time)),
		strftime("%Z", localtime($time))
	);

	return $stamp;
}

######################################################################
=pod

=item $timestamp = EPrints::Time::get_iso_timestamp( [$time] );

Return a UTC timestamp of the form YYYY-MM-DDTHH:MM:SSZ

e.g. 2005-02-12T09:23:33Z

$time in seconds from 1970. If not defined then assume current time.


=cut
######################################################################

sub get_iso_timestamp
{
	my( $time ) = @_;

	$time = time unless defined $time;

	my( $sec, $min, $hour, $mday, $mon, $year ) = gmtime($time);

	return sprintf( "%04d-%02d-%02dT%02d:%02d:%02dZ", 
			$year+1900, $mon+1, $mday, 
			$hour, $min, $sec );
}

######################################################################
=pod

=item $timestamp = EPrints::Time::human_delay( $hours );

Returns a human readable amount of time. 

$hours the number of hours representing the time you want to be human readable.

e.g. EPrints::Time::human_delay( 28 ); # returns "1 day"

e.g. EPrints::Time::human_delay( 400 ); # returns "2 weeks"

=cut
######################################################################
sub human_delay
{
	my( $hours ) = @_;
	
	if( $hours < 24 )
	{
		return $hours." hour".($hours>1?"s":"");
	}

	my $days = int( $hours / 24 );

	if( $days < 7 )
	{
		return $days." day".($days>1?"s":"");
	}

	my $weeks = int( $days / 7 );

	return $weeks." week".($weeks>1?"s":"");
}

1;

######################################################################
=pod

=back

=cut
