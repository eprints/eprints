#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: time.pl
#
# Description:
#       Routines for Unix time and RFC 1036 (or 850) format.
#
#############################################################################
# Copyright (C) 2000, Cornell University, Xerox Incorporated                #
#                                                                           #
# This software is copyrighted by Cornell University (CU), and ownership of #
# this software remains with CU.                                            #
#                                                                           #
# This software was written as part of research work by:                    #
#   Cornell Digital Library Research Group                                  #
#   Department of Computer Science                                          #
#   Upson Hall                                                              #
#   Ithaca, NY 14853                                                        #
#   USA                                                                     #
#   email: info@prism.cornell.edu                                           #
# 									    #
# Pursuant to government funding guidelines, CU grants you a noncommercial, #
# nonexclusive license to use this software for academic, research, and	    #
# internal business purposes only.  There is no fee for this license.	    #
# You may distribute binary and source code to third parties provided	    #
# that this copyright notice is included with all copies and that no	    #
# charge is made for such distribution.					    #
# 									    #
# You may make and distribute derivative works providing that: 1) You	    #
# notify the Project at the above address of your intention to do so; and   #
# 2) You clearly notify those receiving the distribution that this is a	    #
# modified work and not the original version as distributed by the Cornell  #
# Digital Library Research Group.					    #
# 									    #
# Anyone wishing to make commercial use of this software should contact	    #
# the Cornell Digital Library Rsearch Group at the above address.	    #
# 									    #
# This software was created as part of an ongoing research project and is   #
# made available strictly on an "AS IS" basis.  NEITHER CORNELL UNIVERSITY  #
# NOR ANY OTHER MEMBERS OF THE CS-TR PROJECT MAKE ANY WARRANTIES, EXPRESSED #
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY IMPLIED WARRANTY OF	    #
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.  NEITHER CORNELL	    #
# NOR ANY OTHER MEMBERS OF THE CS-TR PROJECT SHALL BE LIABLE TO USERS OF    #
# THIS SOFTWARE FOR ANY INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES OR    #
# LOSS, EVEN IF ADVISED OF THE POSSIBILITY THEREOF.			    #
# 									    #
# This work was supported in part by the Defense Advanced Research Projects #
# Agency under Grant No. MDA972-92-J-1029 and Grant No. N66001-98-1-8908    #
# with the Corporation for National Research Initiatives (CNRI).  Support   #
# was also provided by the National Science Foundation under Grant No.      #
# IIS-9817416. Its content does not necessarily reflect                     #
# the position or the policy of the Government or CNRI, and no official	    #
# endorsement should be inferred.					    #
#############################################################################

#############################################################################
#
# File: time.pl
#
# Description: Routines to manipulate time values.
#              
#              
#
# Subroutines: (called externally)                     General Description:
#
#     Time_to_String
#     Parse_Time_String 
#     Encode_Time 
#     get_current_year
# 
#############################################################################


# Note, this code does not know about leap seconds or leap centuries.


#############################################################################
# Time_to_String()
#
# Accepts a time value (seconds since January 1, 1970) and an optional 
#         timezone.
#
# Formats a string consisting of day of week, day, month, and time.
#
#                    Thu, 28 Sep 95 14:01:14
#
# From RFC 1306: Wdy, DD Mon YY HH:MM:SS TIMEZONE
#
#       Note that we are not appending the TIMESZONE for "local" zone.
#
#############################################################################

sub Time_to_String {

    local ($time, $zone) = @_;
    local ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $iddst);
    local ($zone_string);
    my(@day_names) = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    my(@month_names) = 	     ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
			      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");

    if ($zone eq "local") {

	$zone_string = "";
	($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $iddst) = 
	    localtime ($time);

    } elsif ($zone eq "" || $zone eq "GMT") {

	$zone_string = " GMT";
	($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $iddst) = 
	    gmtime($time);

    } else {
	&program_error("Time zone $zone is not supported");
    }

    sprintf ("%s, %d %s %02d %02d:%02d:%02d%s",
	     $day_names[$wday],
	     $mday,
	     $month_names [$mon],
	     $year, $hour, $min, $sec,
	     $zone_string);

}


sub current_local_time_zone {
    (localtime)[8] ? $standard_time_zone : $daylight_savings_time_zone;}

# Convert an ISO8601 date to an RFC1306, ignore time portion
sub ISO8601_to_RFC1306 {
    my ($time) = @_;
    my ($month, $year, $day);
    my(@month_names) = 	     ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
			      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
    $time =~ /^\d{2}(\d{2})(\d{2})(\d{2})/;
    $year = $1;
    $month = $2;
    $day = $3;
    sprintf ("%d %s %02d", $day, $month_names[$month], $year);
}
    
# Convert an RFC1306 date to an ISO8601, ignore time portion
sub RFC1306_to_ISO8601 {
    my ($string) = @_;
    my ($mday, $month_name, $year, $hour, $min, $sec, $zone);
    my(@month_names) = 	     ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
			      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");

    #
    # Parse 'DD Mon [YY}YY' portion of date/time string
    #
    if ($string !~ /([0-9]+)[- ](...)[- ]([0-9]?[0-9]?[0-9][0-9])/) 
    {return -1;}

    $mday = $1; $month_name = $2; $year= $3;

    #
    # Adjust two digit years to appropriate century.
    #
    if ($year < 100) {		
	if ($year < 70) {$year += 2000;} else {$year += 1900;}
    }

    #
    # Determine month number
    #
    local ($month);
    for ($month = 0; ($month_names[$month] !~ /$month_name/i) ;  $month++) {}

    sprintf("%4d%02d%02d", $year, $month, $mday);
}
    

#############################################################################
# Parse_Time_String()
#
#     Parse time string of the forms:
#
#                Wdy, DD Mon YY HH:MM:SS TIMEZONE
#
#     where TIMEZONE is either a a neumonic or a 4 digit offset.
#     - year may be 2 or 4 digits.
#     - we ignore dayname.
#
#############################################################################

sub Parse_Time_String {

    local ($string) = @_;
    local ($mday, $month_name, $year, $hour, $min, $sec, $zone);
    my(@month_names) = 	     ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
			      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");

    #
    # Parse 'DD Mon [YY}YY' portion of date/time string
    #
    if ($string !~ /([0-9]+)[- ](...)[- ]([0-9]?[0-9]?[0-9][0-9])/) 
    {return -1;}

    $mday = $1; $month_name = $2; $year= $3;

    #
    # Adjust two digit years to appropriate century.
    #
    if ($year < 100) {		
	if ($year < 70) {$year += 2000;} else {$year += 1900;}
    }

    #
    # Parse time and timezone portion if string, which follow the date.
    #                    'HH:MM:SS TIMEZONE'
    #
    if ($' =~ /([0-9]+):([0-9]+):([0-9]+) *(.*)/) {
	$hour = $1;
	$min = $2;
	$sec = $3;
	$zone = $4;
    }

    #
    # Determine month number
    #
    local ($month);
    for ($month = 0; ($month_names[$month] !~ /$month_name/i) ;  $month++) {}

    #
    # Convert time to seconds since January 1st, 1970
    #
    &Encode_Time ($sec, $min, $hour, $mday, $month, $year, $zone);}


#############################################################################
# Encode_Time()
#
#############################################################################

# Some smarts to try to handle 20th and 21rst century.  Years 00-69 are
# assumed to be 21rst century.  years 70-99 are 20th century.  

sub Encode_Time {
    local ($sec, $min, $hour, $mday, $mon, $year, $zone) = @_;
    local ($offset, $total);
    local ($message);

    my %zone = (
		"" => 0,
		GMT => 0,
		EST => -5 * 60,
		EDT => -4 * 60,
		CST => -6 * 60,
		CDT => -5 * 60,
		MST => -7 * 60,
		MDT => -6 * 60,
		PST => -8 * 60,
		PDT => -7 * 60
		);

    #
    # Check if timezone has an offset that we know about. If not,
    # try to parse zone as 4 digit offset.
    #
    if (! defined $zone{$zone}) {
	
	#
	# Only acceptable value of timezone is [signed] 4 digit numeric offset
	#
	if ($zone =~ /([+-])([0-9][0-9])([0-9][0-9])/) {

	    #
	    # Checks timezone offset for reasonable values
	    #
	    if ($3 > 59) { 
		$message = "Timezone offset: $zone minute specification out";
		$message .= " of range [0-59]";
		&program_error($message);
	    }
	    if ($2 < -13 || $2 > 12) { 
		$message = "Timezone offset: $zone hour specification out";
		$message .= " of range [-13 to 12]";
		&program_error($message);
	    }

	    #
	    # Calculate timezone offset in minutes
	    #
	    $offset = $2 * 60 + $3;
	    if ($1 eq '-') { $offset = -$offset;}
	    $zone{$zone} = $offset;

	} else {
	    $message = "Undefined timezone $zone. Please use numeric timezone";
	    $message .= " specification of the form [-+]HHMM.\n";
	    &program_error($message);
	}
    }

  
    if ($year < 70) {$year += 2000;}
    if ($year < 100) {$year += 1900;}

    $total = $sec + ($min * 60) + $hour * (3600) + 
	&day_number ($mday, $mon, $year) * (24 * 3600) -
	    $zone{$zone} * 60;
}


#############################################################################
# day_number()
#
#############################################################################
# number of days since Jan 1 1970
sub day_number {
    local ($mday, $month, $year) = @_;
    local ($days) = $mday - 1;
    my(@days_in_month) = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    my(@days_in_month_leap) = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    for ($i = 0 ; $i < $month ; $i++) {
	if (&leap_year($year)) {
	    $days += $days_in_month_leap[$i];}
	else {
	    $days += $days_in_month[$i];}}
    $years =  ($year - 1970);
    $leaps = int (($year - 1 - 1968) / 4);
    $days + $years * 365 + $leaps;}


#############################################################################
# leap_year()
#
#############################################################################
# As I recall, centuries are not leap years.  Fix this by 1999.

sub leap_year {
    local ($year) = @_;
    $year % 4 == 0;}


#############################################################################
# Duration_string()
#
#############################################################################

sub Duration_string {
    local ($seconds) = @_;

    local ($days, $hours, $minutes);
    $days =  int($seconds / (60*60*24));
    $seconds = $seconds % (60*60*24);
    $hours = int($seconds / (60*60));
    $seconds = $seconds % (60*60);
    $minutes = int($seconds / 60);
    $seconds = $seconds % 60;

    local ($string) = "";

    if ($days > 0) {
	if ($string ne "") {$string = $string . " ";}
	$string = $string . &unit_string ($days, "day");}
    if ($hours > 0) {
	if ($string ne "") {$string = $string . " ";}
	$string = $string . &unit_string ($hours, "hour");}
    if ($minutes > 0) {
	if ($string ne "") {$string = $string . " ";}
	$string = $string . &unit_string ($minutes, "minute");}
    if ($seconds > 0) {
	if ($string ne "") {$string = $string . " ";}
	$string = $string . &unit_string ($seconds, "second");}
    $string;
}


sub unit_string {
    local ($n, $unit) = @_;
    $n . " " . $unit . ($n>=1&&$n<2?"":"s");
}

# Parse a time specification string.
# return (ut, message) where ut is time in Universal Time (== GMT)
# or -1 if error, and message is a complaint.
sub get_valid_time_string {
    local ($string) = @_;
    local ($ut) = &Parse_Time_String ($string);
    local ($message) = "";
    if ($ut < 0) {
        $message = sprintf ($time_complaint_string, $string);}
    ($ut, $message);}

1;






