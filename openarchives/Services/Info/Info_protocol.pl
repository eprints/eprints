#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: Info_protocol.pl
#
# Description:
#       Info protocol definition
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

package Info;

use strict;

# Avoid reloading
if (defined $Info::protocol_loaded) {
    return 1;
} else {
    $Info::protocol_loaded = 1;
}

my (%info);
$info{'name'} = "Info";
$info{'software-version'} = "1.0";
$info{'description'} = "Implements Info service protocol requests";
$dienst::Dispatch->Register_Service_Class (\%info);

# List-Services
my $ref_ls = {'service-class' => "Info",
	   'verb-class'=>"List-Services",
	   'description' => "List services supported at this site",
	   'versions' =>	# used to map remote requests
	   {
	       '1.0' => {	
		   'request' => "/Dienst/Info/3.0/List-Services",
		   'service' => "Info",
		   'verb' => "List-Services",
		   'version' => "3.0",
		   'fixed' => "",
		   'handler' => "Info::list_services"
		   # no fixed args
		   # no optional args
	       }
	   }};
$dienst::Dispatch->Register ($ref_ls);

my $ref_id = {'service-class' => "Info",
	   'verb-class'=>"Identity",
	   'description' => "Identify Server",
	   'versions' =>	# used to map remote requests
	   {
	       '1.0' => {	
		   'request' => "/Dienst/Info/1.0/Identity",
		   'service' => "Info",
		   'verb' => "Identity",
		   'version' => "1.0",
		   'fixed' => "",
		   'handler' => "Info::identity"
		   # no fixed args
		   # no optional args
	       }
	   }};
$dienst::Dispatch->Register ($ref_id);

1;
