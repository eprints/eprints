#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: config_constants.pl
#
# Version: $Id$
#
# Description:
#       configuration settings
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

###################################################################
# SERVER INFORMATION THAT SHOULD BE CHANGED AT INSTALLATION TIME
###################################################################

# AT INSTALLATION CHANGE THIS TO A DESCRIPTIVE NAME FOR YOUR SERVER.  DON'T
# WORRY WHETHER THIS IS UNIQUE, IT IS USED FOR ONLY INFORMATION PURPOSES.
$server = "Prototype Open Archives Server";

# AT INSTALLATION TIME, CHANGE THIS TO THE DOMAIN NAME OF THE HOST ON WHICH
# THIS SOFTWARE WILL BE RUNNING.
$localhost = "yourhost.org";

# AT INSTALLATION TIME CHANGE THIS TO THE PORT ON WHICH THE HTTP SERVER WILL
# BE RUNNING
$localport = "8090";

# AT INSTALLATION TIME CHANGE THIS TO THE EMAIL ADDRESS OF SOMEONE WHO SHOULD
# BE CONTACTED IN CASE OF PROBLEMS.  NOTE THAT THE @ must be escaped with a \.
$maintainer = qq/support@yourhost.org/;

# AT INSTALLATION TIME CHANGE THIS TO THE APPROPRIATE TIME ZONES
$daylight_savings_time_zone = "EDT";
$standard_time_zone = "EST";


###################################################################
# Constants that you should NOT CHANGE at the time of installation.
###################################################################

# Any services in this array will not be registered at load time even if they
# are present in the Services Directory
@excludeServices = qw/Index Collection QM LibMgt UI/;

# establish my identity
$server_name = "Dienst";	
$server_version='vOA1-0-0';

# The dienst services supported here.  Automatically accumulated at load time
# from the contents of the Directory
@supportedDienstServices = ();

@supported_optional_syntaxes = qw/Keyword Multiple Positional/;

1;
