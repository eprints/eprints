#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: dienst_main_subs.pl
#
# Versions: $Id$
#
# Description:
#       Subroutines used by Main
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

sub dispatch_main {
    my (%dienstContext, $userid, $password, $query_string);

    # The query object is a global carried through the transaction (used for
    # other CGI calls
    undef $dienst::query;
    $dienst::query = CGI::new();

    my($request_method) = $dienst::query->request_method();;
    my($script_name) = $dienst::query->script_name();
    my($path_info)   = $dienst::query->path_info();
    my($accept) = $dienst::query->Accept();
    my($remote_host) = $dienst::query->remote_host();
    my($user_agent) = $dienst::query->user_agent();

    %dienstContext = (
		'request_method' => $request_method,
		'url' => $script_name,
		'accept' => $accept,
		'remote_host' => $remote_host,
		'remote_addr' => $user_agent,
		'agent' => $user_agent
		);

    if ($query_string = $dienst::query->query_string()) {
	$dienstContext{'url'} .= '?' . $query_string;
	
	$userid = $dienst::query->cookie(-name=>'ncstrl.userid');
	$password = $dienst::query->cookie(-name=>'ncstrl.password');
	if ($query_string !~ /password\=/ && $userid && $password) {
	    $dienstContext{'url'} .= "&" . "userid=$userid&password=$password";
	}
    }

    # handle a file upload for document submission.  It is put into a
    # temporary file and that filename is sent to dienst as one of the
    # query_string parpameters.  There is some uncleaness here since the
    # form parameter name 'uploaded_file' is hardcoded and the dienst
    # submit parameter name file is also hardcoded.
    my($filename) = $query->param('uploaded_file');
    my($tmpfile);
    my ($buffer, $bytesread);
    if ($filename ne "") {
	# get a temporary file name and open it
	$tmpfile = POSIX::tmpnam();
	open(TH, ">$tmpfile");

	# copy the POST to the temporary file
	while ($bytesread=read($filename, $buffer, 1024)) {
	    print TH $buffer;
	}

	close $filename;
	close TH;

	$dienstContext{'url'} .= "&file=$tmpfile";
    }

    $dienstContext{'body'} = (! ($dienstContext{'request_method'} eq "HEAD"));

#$dienstContext{'url'} = '/Dienst/Repository/2.0/List-Partitions';
    my ($ret, $msg) = $dienst::Dispatch->do_Dispatch_URL 
	($dienstContext{'url'}, \%dienstContext);


    if ($ret) {
	&dienst::complaint($ret, "$msg");
	return;
    }

    if ($tmpfile ne "") {
	unlink $tmpfile;
    }
}

# Load the remaining modules of the system.
sub LoadCode {

    my ($dir, $file);

    push(@INC, $perlLibs);

    # load in the core (non-service part) of the system
    foreach $dir ("Common",
		  "Config") {
	push(@INC, "$dienst::source_dir/$dir");
    }

    if (!do "files.pl") {
	&program_error("Could not find file definition file.");
    }

    foreach $file (@dienst::dienst_common_files) {
    	if (! do $file) {
	    print STDERR "Could not load $file.";
	    &exit(0);
	}
    }

    # load in the services
    if (!opendir SERVH, "$dienst::source_dir/Services") {
	&program_error("Could not open services directory.");
    }

    my (@services) = grep(!/^\.\.?$/, readdir(SERVH));
    my ($s);

    # Must load protocol definition first
    my ($loadfile);
    foreach $s (@services) {
	if (!grep(/^$s$/, @excludeServices)) {
	    push(@INC, "$dienst::source_dir/Services/$s");
	    push(@supportedDienstServices, $s);

	    $loadfile = $s . '_protocol.pl';
	    if (! do $loadfile) {
		print STDERR "Could not load $loadfile. '$@'";
		&exit(0);
	    }
	}
    }

    my ($loadfile);
    foreach $s (@services) {
	if (!grep(/^$s$/, @excludeServices)) {
	    push(@INC, "$dienst::source_dir/Services/$s");

	    $loadfile = $s . '_init.pl';
	    if (! do $loadfile) {
		print STDERR "Could not load $loadfile. '$@'";
		&exit(0);
	    }
	}
    }

    1;
}



1;
