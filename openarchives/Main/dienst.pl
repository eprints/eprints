#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: dienst.pl
#
# Description:
#       This is the main entry point for DIENST.
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

package dienst;

use EPrintSite::SiteInfo;

use CGI qw(-oldstyle_urls);
use strict;
use POSIX;

# determine whether we are initialing this thread.  When in mod_perl this
# block will NOT be executed once the thread is associated with an apache
# thread.  However, if a new apache thread is started, this block will be
# executed on the first invocation.  Note that startup_flag is used in some
# other places to determine whether we are in the server or some external
# utility.
if (!defined ($dienst::startup_flag)) {

    $dienst::startup_flag = 0;
    # Auto-detect if we are running under mod_perl or CGI.
    $dienst::USE_MOD_PERL = (
			     (exists $ENV{'GATEWAY_INTERFACE'} && 
			      $ENV{'GATEWAY_INTERFACE'} =~ /CGI-Perl/)
			     || exists $ENV{'MOD_PERL'} ) ? 1 : 0;

    # read in the program constants at startup

    # AT INSTALLATION TIME YOU MUST CHANGE THIS TO THE FULL PATH WHERE YOUR
    # OPEN ARCHIVES SOFTWARE SITS.  THIS IS THE PATH UNDER WHICH THE Main,
    # Common, Config, and Services DIRECTORIES ARE
    $dienst::source_dir = "$EPrintSite::SiteInfo::local_root/openarchives";

    require "$dienst::source_dir/Config/config_constants.pl";

    # Unbuffered output.
    select(STDOUT); $| = 1;

    # load in the rest of myself
    do "dienst_main_subs.pl";
    require "Dispatch.pm";
    $dienst::Dispatch = new Dispatch();

    &LoadCode;
}

# Overides standard exit with our exit (which is defined in utilities.pl
use subs qw(exit);

&dispatch_main();

END {
}



