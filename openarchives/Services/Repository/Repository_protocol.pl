#############################################################################
# Dienst - A protocol and server for a distributed digital technical report #
# library                                                                   #
# File: Repository_protocol.pl                                              #
#
# Version: $Id$
#                                                                           #
# Description:                                                              #
#      Repository protocol spec.
#
#                                                                           #
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
package Repository;

use strict;

# New Protocol Registration Declarations
if (defined $Repository::protocol_loaded) {
    return 1;
} else {
    $Repository::protocol_loaded = 1;
}

my (%info);
$info{'name'} = "Repository";
$info{'software-version'} = "1.0";
$info{'description'} = "Implements document repository protocol requests";
$dienst::Dispatch->Register_Service_Class (\%info);

# Disseminate Declaration
my $ref_dis = {'service-class' => "Repository",
	       'verb-class'=>"Disseminate",
	       'description'=>"Create customized content from document",
	       'versions' =>		# used to map remote requests
	       {'1.0' => {
		   'request' => "/Dienst/Repository/1.0/Disseminate/%s/%s/%s",
		   'service' => "Repository",
		   'verb' => "Disseminate",
		   'version' => "1.0",
		   'fixed' => "handle:meta-format:content-type",
		   'handler' => 'Repository::mr_disseminate',
		   'returns' => "XML",
	       }
	    }
	   };

$dienst::Dispatch->Register ($ref_dis);

# List-Contents
my $ref_lc = {'service-class' => "Repository",
	      'verb-class'=>"List-Contents",
	      'description'=>"List repository contents",
	      'osyntax' => "Multiple",
	      'versions' =>		# used to map remote requests
	      {'1.0' => {
		  'request' => "/Dienst/Repository/4.0/List-Contents",
		  'service' => "Repository",
		  'verb' => "List-Contents",
		  'version' => "4.0",
		  'optional' => "file-after:partition-spec:meta-format",
		  'description' => "List the contents of the repository. Default returns list of handles. Supports filtering by file-after, partition. Supports various meta formats",
		  'handler' => "Repository::mr_dump_contents",
		  'return' => "XML",
		  'note' => "Replaces Index service List-Contents",
	      },
	   }
	  };

$dienst::Dispatch->Register ($ref_lc);

# List-Meta-Formats
my $mf_ref = {'service-class' => "Repository",
	      'verb-class'=>"List-Meta-Formats",
	      'description'=>"Return available metadata formats",
	      'versions' =>		# used to map remote requests
	      {'1.0' => { 
		  'request' => "/Dienst/Repository/1.0/List-Meta-Formats/%s",
		  'service' => "Repository",
		  'verb' => "List-Meta-Formats",
		  'version' => "1.0",
		  'fixed' => "",
		  'optional' => "",
		  'handler'=> "Repository::mr_list_meta_formats",
		  'return' => "XML",
		  'description' => "",
	      },
	   },
	  };

$dienst::Dispatch->Register ($mf_ref);

# List-Partitions
my $ref = {'service-class' => "Repository",
	   'verb-class'=>"List-Partitions",
	   'description'=>"List repository partitions",
	   'versions' =>		# used to map remote requests
	   {'2.0' => { 
	       'request' => "/Dienst/Repository/2.0/List-Partitions",
	       'service' => "Repository",
	       'verb' => "List-Partitions",
	       'version' => "2.0",
	       'handler' => "Repository::mr_list_partitions",
	       'returns' => "XML",
	       'description' => "List partitions",
	   },
	}
       };

$dienst::Dispatch->Register ($ref);

# Structure Declaration
my $ref_str = {'service-class' => "Repository",
	       'verb-class'=>"Structure",
	       'description'=>"Get Document Structure",
	       'versions' =>		# used to map remote requests
	       {'4.0' => { # XML version
		   'request' => "/Dienst/Repository/1.0/Structure/%s",
		   'service' => "Repository",
		   'verb' => "Structure",
		   'version' => "1.0",
		   'fixed' => "handle",
		   'optional' => "view",
		   'handler' => 'Repository::mr_structure',
		   'returns' => "XML",
		   'description' => "list available metadata formats",
		   # no incoming request implemented
	       }
	    }
	   };

$dienst::Dispatch->Register ($ref_str);

#List-Verbs
my $ref_lsv = {'service-class' => "Repository",
	   'verb-class'=>"List-Verbs",
	   'description' => "List Repository Verbs",
	   'versions' =>	# used to map remote requests
	   {
	       '2.0' => {	
		   'request' => "/Dienst/Repository/2.0/List-Verbs",
		   'service' => "Repository",
		   'verb' => "List-Verbs",
		   'version' => "2.0",
		   # no fixed args
		   # no optional args
		   'handler' => 'Repository::list_verbs'
	       }
	   }};

$dienst::Dispatch->Register ($ref_lsv);

#Describe-Verbs
my $ref_dv = {'service-class' => "Repository",
	   'verb-class'=>"Describe-Verbs",
	   'description' => "",
	   'versions' =>	# used to map remote requests
	   {
	       '2.0' => {	
		   'request' => "/Dienst/Repository/2.0/Describe-Verbs",
		   'service' => "Repository",
		   'verb' => "Describe-Verbs",
		   'version' => "2.0",
		   'fixed' => "verb",
		   'returns' => "XML",
		   'handler' => "Repository::describe_verb"
		   # no fixed args
		   # no optional args
	       }
	   }};

$dienst::Dispatch->Register ($ref_dv);

# End Protocol Declarations

1;
