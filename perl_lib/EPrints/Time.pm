######################################################################
#
# EPrints::Time
#
######################################################################
#
#
######################################################################

package EPrints::Time;

use POSIX qw( strftime );
use Time::Local qw( timegm_nocheck timelocal_nocheck );

=for Pod2Wiki

=head1 NAME

B<EPrints::Time> - Time and Date-related functions 

=head1 SYNOPSIS

	($year) = EPrints::Time::utc_datetime()
	# 2010

	($year,$month) = EPrints::Time::local_datetime()
	# 2010, 6

	EPrints::Time::iso_datetime(); 
	# 2008-05-15T14:40:24Z
	
	EPrints::Time::iso_date()
	# 2010-06-23

	EPrints::Time::month_label( $repo, 11 ) 
	# returns "November"
	
	EPrints::Time::short_month_label( $repo, 11 ) 
	# returns "Nov"

	EPrints::Time::render_date( $repo, "2001-01-12T00:00:00Z" ) 
	# returns XML containing 12 January 2001 00:00

	EPrints::Time::render_short_date( $repo, "2001-01-12T00:00:00Z" ) 
	# returns XML containing 12 Jan 2001 00:00
	
=head1 DESCRIPTION

This package contains functions related to time/date functionality. 

=head1 FORMATS USED IN EPRINTS

=head2 Internal format

Time zone: UTC (database), server local time (embargoes)

Format: YYYY or YYYY-MM or YYYY-MM-DD or "YYYY-MM-DD hh" or "YYYY-MM-DD hh:mm" or "YYYY-MM-DD hh:mm:ss"

These are used in the database and when setting and getting values. They can contain any fractional part of a date time.

=head2 ISO 8601-style date/times

Time zone: UTC

Format: YYYY-MM-DD or YYYY-MM-DDThh:mm:ssZ

These are primarily used in XML output where times that conform to the standard XSD date/time are required.

=head2 Epoch time

Time zone: UTC

Format: integer

Time in seconds since system epoch. Used in the login tickets table and when performing date calculations.

=head1 METHODS

=over 4

=cut

=back

=head2 Parsing

=over 4

=item @t = split_value( $value )

Splits internal or ISO format $value into years, months, days, hours, minutes, seconds.

=cut

sub split_value
{
	my( $value ) = @_;

	my @t = $value =~ /([0-9]+)/g;

	return @t;
}

=item $time = datetime_local( @t )

Returns local time @t as the number of seconds since epoch, where @t is years, months etc.

=cut

sub datetime_local
{
	my( $year, $mon, $day, $hour, $min, $sec ) = @_;

	return timelocal_nocheck( $sec||0, $min||0, $hour||0, $day||1, ($mon||1)-1, ($year||1900)-1900 );
}

=item $time = datetime_utc( @t )

Returns UTC time @t as the number of seconds since epoch, where @t is years, months etc.

=cut

sub datetime_utc
{
	my( $year, $mon, $day, $hour, $min, $sec ) = @_;

	return timegm_nocheck( $sec||0, $min||0, $hour||0, $day||1, ($mon||1)-1, ($year||1900)-1900 );
}

=back

=head2 Formatting

=over 4

=item $datetime = EPrints::Time::join_value( @t )

Return a time @t in internal format.

Returns undef if no parts are defined.

=cut

sub join_value
{
	return if !defined $_[0];

	my $r = sprintf('%04d', shift(@_));
	$r .= "-".sprintf('%02d', shift(@_)) if defined $_[0];
	$r .= "-".sprintf('%02d', shift(@_)) if defined $_[0];
	$r .= " ".sprintf('%02d', shift(@_)) if defined $_[0];
	$r .= ":".sprintf('%02d', shift(@_)) if defined $_[0];
	$r .= ":".sprintf('%02d', shift(@_)) if defined $_[0];

	return $r;
}

=item ($year,$mon,$day,$hour,$min,$sec) = EPrints::Time::local_datetime( [ $seconds ] )

Returns the local date-time as an array, see L<perlfunc/localtime>.

$seconds is seconds since epoch or now if not given.

=cut

sub local_datetime
{
	my @t = localtime(@_ ? $_[0] : time());
	@t = reverse @t[0..5];
	$t[0] += 1900;
	$t[1] += 1;

	return @t;
}

=item ($year,$mon,$day,$hour,$min,$sec) = EPrints::Time::utc_datetime( [ $seconds ] )

Returns the UTC date-time as an array, see L<perlfunc/gmtime>.

$seconds is seconds since epoch or now if not given.

=cut

sub utc_datetime
{
	my @t = gmtime(@_ ? $_[0] : time());
	@t = reverse(@t[0..5]);
	$t[0] += 1900;
	$t[1] += 1;

	return @t;
}

=item $date = EPrints::Time::iso_date( [ $seconds ] )

Return a UTC date of the form YYYY-MM-DD.

$seconds is seconds since epoch or now if not given.

=cut

sub iso_date
{
	return strftime( '%Y-%m-%d', gmtime(@_ == 1 ? $_[0] : time()));
}

=item $datetime = EPrints::Time::iso_datetime( [ $seconds ] );

Return a UTC date-time of the form YYYY-MM-DDTHH:MM:SSZ

$seconds is seconds since epoch or now if not given.

=cut

sub iso_datetime
{
	return strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime(@_ ? $_[0] : time()));
}

=item $datetime = EPrints::Time::rfc822_datetime( [ $seconds ] )

Return the local date-time in RFC 822 format (used by e.g. RSS).

$seconds is seconds since epoch or now if not given.

=cut

sub rfc822_datetime
{
	return strftime( "%a, %d %b %Y %H:%M:%S %z", localtime(@_ == 1 ? $_[0] : time()));
}

=item $timestamp = EPrints::Time::human_time( [$time] )

Return a string describing the current local date and time in the
current locale's format, see L<perlfunc/localtime>.

=cut

sub human_time
{
	return sprintf("%s %s",
		scalar(localtime(@_ ? $_[0] : time())),
		strftime("%Z", localtime(@_ == 1 ? $_[0] : time()))
	);
}

=item $timestamp = EPrints::Time::human_delay( $hours );

Returns a human readable amount of time. 

$hours the number of hours representing the time you want to be human readable.

=cut

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

=back

=head2 Phrases

=over 4

=item $label = EPrints::Time::month_label( $repo, $monthid )

Return a UTF-8 string describing the month, in the current lanugage.

$monthid is an integer from 1 to 12.

=cut

sub month_label
{
	my( $session, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_%02d", $monthid );

	return $session->phrase( $code );
}

=item $label = EPrints::Time::short_month_label( $repo, $monthid )

Return a UTF-8 string of a short representation in month, in the current lanugage.

$monthid is an integer from 1 to 12.

=cut

sub short_month_label
{
	my( $session, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_short_%02d", $monthid );

	return $session->phrase( $code );
}


=item $label = EPrints::Time::dow_label( $repo, $dowid )

Return a UTF-8 string of a short representation of the day of the week, in the current lanugage.

$dowid is an integer from 1 to 7.

=cut

sub dow_label
{
	my( $session, $dowid ) = @_;
	
	my $code = sprintf( "lib/utils:dow_%01d", $dowid );

	return $session->phrase( $code );
}

=back

=head2 Rendering

=over 4

=item $xhtml = EPrints::Time::render_date_with_dow( $repo, $value )

Same as L<EPrints::Time::render_date> but adds the day of the week.

Month and DoW names are taken from the current repository language.

E.g.

	Tuesday 16 July 2013
=cut

sub render_date_with_dow
{
	my( $session, $datevalue ) = @_;
	return _render_date( $session, $datevalue, 0, 1 );
}

=back

=head2 Rendering

=over 4

=item $xhtml = EPrints::Time::render_date( $repo, $value )

Renders a L<EPrints::MetaField::Date> or L<EPrints::MetaField::Time> value in a human-friendly form in the current locale's time zone.

Month names are taken from the current repository language.

E.g.

	5 June 2010 10:35:12 +02:00
	12 December 1912 # no time
	1954 # no month/day

=cut

sub render_date
{
	my( $session, $datevalue) = @_;
	return _render_date( $session, $datevalue, 0 );
}

######################################################################
=pod

=item $xhtml = EPrints::Time::render_short_date( $repo, $value )

Render a shorter form of L</render_date>.

E.g.

	05 Jun 2010 10:35:12
	12 Dec 1912 # no time
	1954 # no month/day

=cut
######################################################################

sub render_short_date
{
	my( $session, $datevalue) = @_;
	return _render_date( $session, $datevalue, 1 );
}

sub _render_date
{
	my( $session, $datevalue, $short, $dow ) = @_;

	if( !defined $datevalue )
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	my @l = split_value( $datevalue );

	if( @l == 0 )
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	my( $year, $mon, $day, $hour, $min, $sec ) = @l;

	# 1999
	my $r = $year;

	if( @l > 1 )
	{
		my $month_name;
		if( $short )	
		{
			$month_name = short_month_label( $session, $mon );
		}
		else
		{
			$month_name = month_label( $session, $mon );
		}
		$r = "$month_name $r";
	}
	if( @l > 2 )
	{
		$r = ($short ? sprintf( "%02d", $day ) : 0+$day)." $r";
	
		# we can only render the day of the week if we have values for year, month and day
		if( defined $dow && $dow )
		{
			$r = dow_label( $session, strftime( "%u", 0, 0, 0, $day, $mon - 1, $year - 1900, -1, -1, -1 ) ) . " " . $r;
		}
	}

	if( @l > 3 )
	{
		$r = "$r ".sprintf("%02d", $hour);
	}
	if( @l > 4 )
	{
		$r = "$r:".sprintf("%02d", $min);
	}
	if( @l > 5 )
	{
		$r = "$r:".sprintf("%02d", $sec);
	}

	if( @l > 3 && !$short )
	{
		$r .= " UTC";
	}

	return $session->make_text( $r );
}

# BackCompatibility
sub get_iso_date { &iso_date }
sub get_iso_timestamp { &iso_datetime }
sub get_month_label { &month_label }
sub get_month_label_short { &short_month_label }
sub datestring_to_timet { datetime_utc( split_value( $_[1] ) ) }
sub get_date { &local_datetime }
sub get_date_array { &local_datetime }

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

