#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: info.pl
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

sub list_services {
    my  ($optional, $Context) = @_;

    my $XMLOutputTempFile = POSIX::tmpnam();
    my $output1 = new IO::File(">$XMLOutputTempFile");
    $META::writer = new XML::Writer (OUTPUT => $output1, NEWLINES => 1);   
    $META::writer->xmlDecl();
    $META::writer->startTag ($Context->{'verb'}, 
		       "version" => $Context->{'version'});

    my $svc;
    foreach $svc (@dienst::supportedDienstServices) {
	$META::writer->startTag ("service");
	$META::writer->characters ("$svc");
	$META::writer->endTag ("service");
    }

    $META::writer->endTag ("$Context->{'verb'}");
    $META::writer->end ($Context->{'verb'});
    $output1->close();
    &dienst::xmit_file ("$XMLOutputTempFile", "text/plain", 1);
    unlink $XMLOutputTempFile;
}

sub identity {
    my  ($optional, $Context) = @_;

    my $XMLOutputTempFile = POSIX::tmpnam();
    my $output1 = new IO::File(">$XMLOutputTempFile");
    my $writer = new XML::Writer (OUTPUT => $output1, NEWLINES => 1);   
    $writer->xmlDecl();
    $writer->startTag ($Context->{'verb'}, 
		       "version" => $Context->{'version'});

    $writer->startTag ("server");
    $writer->characters ("$dienst::server");
    $writer->endTag ("server");

    $writer->startTag ("host");
    $writer->characters ("$dienst::localhost");
    $writer->endTag ("host");

    $writer->startTag ("port");
    $writer->characters ("$dienst::localport");
    $writer->endTag ("port");

    $writer->startTag ("maintainer");
    $writer->characters ("$dienst::maintainer");
    $writer->endTag ("maintainer");

    $writer->startTag ("standard_time_zone");
    $writer->characters ("$dienst::standard_time_zone");
    $writer->endTag ("standard_time_zone");

    $writer->startTag ("daylight_savings_time_zone");
    $writer->characters ("$dienst::daylight_savings_time_zone");
    $writer->endTag ("daylight_savings_time_zone");

    $writer->endTag ("$Context->{'verb'}");
    $writer->end ();
    $output1->close();
    &dienst::xmit_file ("$XMLOutputTempFile", "text/xml", 1);
    unlink $XMLOutputTempFile;

}

1;
