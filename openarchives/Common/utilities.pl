#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: utilities.pl
#
# Version: $Id$
#
# Description:
#       Generic utitilities
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

use strict;

sub File_modification_time {
    my ($pathname) = @_;
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
	   $atime, $mtime, $ctime, $blksize, $blocks) = stat ($pathname);
    return $mtime;}

sub File_size {
    my ($pathname) = @_;
    (-s $pathname);}

# List manipulation.

sub list_emptyp {
    my ($list) = @_;
    $#{$list} == -1;}

# 0 based index of position of string in list
# note that this will lose it item is a number.
sub list_position {
    my ($list, $item) = @_;
    my ($i) = 0;
    my $elt;
    foreach $elt (@$list) {
	if ($elt eq $item) {return $i;}
	$i++;}
    return -1;}

sub trim_whitespace {
    my ($string) = @_;
    $string =~ s/^[\s\r]+//;
    $string =~ s/[\s\r]+$//;
    $string;}

sub Send_Simple_Response_Code {
    my ($code, $message) = @_;
    print CGI::header(-type=>'text/plain', -status=>'200');
    print "$code $message\n";
}

sub Record_List_Header {
    my ($version, $count, $message) = @_;
    print CGI::header(-type=>'text/plain', -status=>'200');
    print "Version: $version\n";
    print "Count: $count $message\n";
}

sub Send_Simple_Record_List {
    my ($version, $list, $message) = @_;
    &Record_List_Header ($version, $#{$list} + 1, $message);
    my $item;
    foreach $item (@$list) {
	print $item, "\n";
    }
}

# split tokens of the field value on any non-quoted whitespace.  Stolen
# from shellwords.pl in perl library
sub splitwords {
    local ($_) = join('', @_) if @_;
    my (@words,$snippet,$field);

    s/^\s+//;
    while ($_ ne '') {
	$field = '';
	for (;;) {
	    if (s/^"(([^"\\]|\\.)*)"//) {
		($snippet = '"' . $1 . '"') =~ s#\\(.)#$1#g;
	    }
	    elsif (/^"/) {
		$_ = substr($_, 1);
                next;    # be tolerant, just drop it
	    }
	    elsif (s/^'(([^'\\]|\\.)*)'//) {
		($snippet = '"' . $1 . '"') =~ s#\\(.)#$1#g;
	    }
	    elsif (/^'/) {
		$_ = substr($_, 1);
                next;    # be tolerant, just drop it
	    }
	    elsif (s/^\\(.)//) {
		$snippet = $1;
	    }
	    elsif (s/^([^\s\\'"]+)//) {
		$snippet = $1;
	    }
	    else {
		s/^\s+//;
		last;
	    }
	    $field .= $snippet;
	}
	push(@words, $field);
    }
    @words;
}

sub program_error { #XXX (Figure out what to do about program_error)
    my ($code, $string) = @_;
    my $prev;
    my $message = "$string\nStack trace\n";
    my $i;
    for ($i=1;1;$i++) {
        my ($package, $filename, $line, $subr, $thing1, $thing2) = caller($i);
        if ($package eq "") {$message .= "$i: $prev\n"; last;}
	$message .= "$i: $subr $prev\n";
        $prev = "line $line of $filename  ($thing1, $thing2)";
    }

    &dienst::complaint ("$code", "$message" . $! . ":" . $@);
}

# compose and print a text error message
sub complaint {
    my ($code, $string) = @_;
    print CGI::header(-status=>$code, -type=>'text/plain');
    print "The server was unable to service your request.\n",
    "because of the following error:\n",
    $string, "\n";
}


sub exit{
    # Apache::exit(-2) will cause the server to exit gracefully,
    # once logging happens and protocol, etc  (-2 == Apache::Constants::DONE)
    if ($dienst::USE_MOD_PERL) {
	&Apache::exit(-2);
    }
    else {
	&CORE::exit(0);
    }
}
    
# Given a string, return the string with the 'special' characters decoded.
sub Decode_String {
    my ($string) = @_;
    $string =~ tr/+/ /;
    $string =~ s/%(..)/pack("c",hex($1))/ge;
    $string;
}

# Parse an options string, return an assoc array.  If $rs is the null
# string, then a duplicate option setting will override the previous
# setting.  If non-null then duplicates will be concatenated with $rs
# as the separator.  Note extra effort to handle embedded newlines.
sub parse_options {
    my ($string, $rs) = @_;
    my (%options, $name, $val, $field);

    foreach $field (split (/&/, $string)) {
	$field =~ /^(.+)=((.|\n)*)$/;
	$name = $1;
	$val = $2;

	if (defined($options{$name}) && $rs ne "") {
	    $options{$name} .= $rs . &dienst::Decode_String($val);
	}
	else {
	    $options{$name} = &dienst::Decode_String($val);
	}
    }
    %options;
}

# Format a list of objects.  Place commas after each name except
# the last.
sub NameList {
    my ($i) = 0;
    my ($string) = "";
    my $name;
    foreach $name (@_) {
	if ($i > 0) {
	    if ($i == $#_) {
		$string .= " and ";}
	    else {$string .= ", ";}}
	$string .= $name;
	$i++;}
    $string;}


1;










