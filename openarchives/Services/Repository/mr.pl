#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: mr.pl
#
# Description:
#       Repository
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
package Repository;

use strict;

use CGI qw(-oldstyle_urls);
use POSIX;
use XML::Writer;
use IO;

# Standard protocol information requests

# List-Verbs
sub list_verbs {
    my ($optional, $Context) = @_;
    my ($XMLOutputTempFile, $output, $writer);

    if (keys  %{$optional}) {
	my $msg = "No optional arguments allowed";
	&dienst::complaint(400, "$msg");
	return;
    }

    # Hash key is verb, value is $; separated version numbers
    my (%verbs, @list, $v, $genXML);
    $dienst::Dispatch->service_verb_versions ($Context->{'service'}, \%verbs);

    $genXML = 1 if ($Context->{'version'} > "1.0");

    if ($genXML) {
	$XMLOutputTempFile = POSIX::tmpnam();
	$output = new IO::File(">$XMLOutputTempFile");
	$writer = new XML::Writer (OUTPUT => $output, NEWLINES => 1);   
	$writer->xmlDecl();
	$writer->startTag ("$Context->{'verb'}", 
			     "version" => $Context->{'version'});
    }

    foreach $v (keys %verbs) {
	if ($genXML) {
	    $writer->startTag ("verb");
	    $writer->characters ("$v");
	    $writer->endTag ("verb");
	} else {
	    push @list, $v;
	}
    }
    if (! $genXML) {
	&dienst::Send_Simple_Record_List ($Context->{'version'}, \@list, "");
    } else {
	$writer->endTag ("$Context->{'verb'}");
	$writer->end (); 
	$output->close();
	&dienst::xmit_file ("$XMLOutputTempFile", "text/xml", 1);
	unlink $XMLOutputTempFile;
    }
    1;
}

# Describe-Verbs
sub describe_verb {
    my ($verb, $optional, $Context) = @_;
    my ($info, $argl, $aservice, $averb, $version, $arglist, $subr);
    my ($xmlobj, $XMLOutputTempFile, $output);
    my $service = $Context->{'service'};

    if (keys  %{$optional}) {
	my $msg = "No optional arguments allowed";
	&dienst::complaint(400, "$msg");
	return;
    }

    my (@list);
    my (%dispatch_info) = $dienst::Dispatch->get_dispatch_info();

    if ($Context->{'version'} eq "1.0") {

	while (($info, $argl) = each %dispatch_info) {
	    ($aservice, $averb, $version) = split ($;, $info);
	    if (($aservice eq $service) && ($averb eq $verb)) {
		($arglist, $subr) = split ($;, $argl);

		my %info = %{$argl};
		
		next if (!$info{'handler'});

		if ($info{'fixed'}) {
		    $arglist = $info{'fixed'};
		}
		push (@list, "$version $arglist");
	    }
	}

	    &dienst::Send_Simple_Record_List ($Context->{'version'}, 
					      \@list, "");
    } else {

	my (%verb_set, @sorted_verb_list);
	# Create a list of sorted verbs
	while (($info, $argl) = each %dispatch_info) {
	    ($aservice, $averb, $version) = split ($;, $info);
	    if (($aservice eq $service) && ($averb eq $verb)) {
		($arglist, $subr) = split ($;, $argl);

		$verb_set{"$version"} = $argl;
	    }
	}

	@sorted_verb_list = sort rnumeric keys %verb_set;

	# XML 
	$XMLOutputTempFile = POSIX::tmpnam();
	$output = new IO::File(">$XMLOutputTempFile");
	$xmlobj = new XML::Writer (OUTPUT => $output, NEWLINES => 1);   
	$xmlobj->xmlDecl();
	$xmlobj->startTag ("$Context->{'verb'}", 
			   "version" => $Context->{'version'});

	# Add global information
	my $sc = $dienst::Dispatch->get_class_for_service ($service);
	my $vc = $dienst::Dispatch->get_class_for_verb ($verb);

	my $gdescription = 
	    $dienst::Dispatch->get_service_verb_class_field ($sc, $vc, 
						     "description");
	if ($gdescription || 1) {
	    $xmlobj->startTag ("description");
	    $xmlobj->characters ("$gdescription");
	    $xmlobj->endTag ("description");
	}
	my $gnote = 
	    $dienst::Dispatch->get_service_verb_class_field ($sc, $vc, 
						     "note");
	if ($gnote || 1) {
	    $xmlobj->startTag ("description");
	    $xmlobj->characters ("$gnote");
	    $xmlobj->endTag ("description");
	}

	$xmlobj->startTag ("versions");
	my $v;
	foreach $v (@sorted_verb_list) {

	    my %info = %{$verb_set{$v}};
	    next if (!$info{'handler'} && ! $optional->{'all'});
	    $aservice = $info{'service'};
	    $averb = $info{'verb'};
	    $version = $info{'version'};

	    $xmlobj->startTag ("version", 'id' => "$version");
	    
	    # Give command template
	    my $example = "http://$dienst::localhost:$dienst::localport";
	    my $req = 
		"/Dienst/$info{'service'}/$info{'version'}/$info{'verb'}";
	    my $f;
	    foreach $f (split /:/, $info{fixed}) {
		$req .= "/<$f>";
	    }
	    $example .= $req;

	    if ($info{'note'}) {
		$xmlobj->startTag ("note");
		$xmlobj->characters ("$info{'note'}");
		$xmlobj->endTag ("note");
	    }

	    $xmlobj->startTag ("example");
	    $xmlobj->characters ("$example");
	    $xmlobj->endTag ("example");

	    $xmlobj->startTag ("arguments");
	    if ($info{'fixed'}) {
		$xmlobj->startTag ("fixed");
		my $f;
		foreach $f (split (":", $info{'fixed'})) {
		    $xmlobj->emptyTag ("arg", 'name' => "$f");
		}
		$xmlobj->endTag ("fixed");
	    }

	    if ($info{'optional'}) {
		$xmlobj->startTag ("keyword");
		my $k;
		foreach $k (split (":", $info{'optional'})) {
		    $xmlobj->emptyTag ("arg", 'name' => "$k");
		}
		$xmlobj->endTag ("keyword");
	    }
	    $xmlobj->endTag ("arguments");

	    if ($info{'description'}) {
		$xmlobj->startTag ("description");
		$xmlobj->characters	("$info{'description'}");
		$xmlobj->endTag ("description");
	    }
	    if ($info{'returns'}) {
		$xmlobj->startTag ("returns", 'note' => "unstructured");
		$xmlobj->characters	("$info{'returns'}");
		$xmlobj->endTag ("returns");
	    }
	    $xmlobj->endTag ("version");
	    
	} # while
	$xmlobj->endTag ("versions");
	$xmlobj->endTag ("$Context->{'verb'}");
	$xmlobj->end ();

	$output->close();
	&dienst::xmit_file ("$XMLOutputTempFile", "text/xml", 1);
	unlink $XMLOutputTempFile;
    }
}

sub rnumeric {
    $a <=> $b;
}

1;
