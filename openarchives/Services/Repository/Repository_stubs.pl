#############################################################################
# Dienst - A protocol and server for a distributed digital technical report #
# library                                                                   #
# File: Repository_protocol.pl                                              #
#
# Version: $Id$
#                                                                           #
# Description:                                                              #
#      Stub handlers for Open Archives Repository Protocol                  #
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

use EPrints::OpenArchives;

use strict;
use XML::Writer;
use POSIX;
use IO::File;

# NOTE - This file consists of a set handlers for the prototol requests
# in the Open Archives Protocol.  As shipped the handlers have demo code
# in them to demonstrate formatting of the protocol response.  You will
# need to modify the code of these handlers to link to your respective archive.
# Search for the string "MUST BE MODIFIED TO LINK TO LOCAL REPOSITORY" 
# to find the subroutine that must be modified.

# Disseminate Verb
sub mr_disseminate {
    my ($fullID, $metaFormat, $contentType, $kwArgs, $Context) = @_;

    if ($contentType ne "xml") {
	&dienst::complaint(400, "xml is the only valid content type that can be specified");
	exit;
    }

    if ($metaFormat eq "#oams") {

	# Get the record from EPrints....
	my %oamsTags = EPrints::OpenArchives->disseminate( $fullID );

	# If the record doesn't exist, we will get an empty hash back
	if( scalar keys %oamsTags == 0 )
	{
		# If this is the case, return appropriate error code
		&dienst::complaint( 404, "Unknown record specified" );
	}
	else
	{
		# Have the record OK, return appropriate response
		my $XMLOutputTempFile = POSIX::tmpnam();
		my $output = new IO::File(">$XMLOutputTempFile");
		my $writer = 
		  new XML::Writer (OUTPUT => $output, NEWLINES => 1);   
		$writer->xmlDecl();
		$writer->startTag ("$Context->{'verb'}", 
				   "version" => $Context->{'version'});
		$writer->startTag("record", 
				  "format" => "oams", "identifier" => $fullID);
		&write_OAMS(\%oamsTags, $writer, $Context);
		$writer->endTag("record");
		$writer->endTag ($Context->{'verb'});
		$writer->end ();
		$output->close();
		&dienst::xmit_file("$XMLOutputTempFile", "text/xml", 1);
		unlink $XMLOutputTempFile;
	}
    }
    else {
	&dienst::complaint(400, "Invalid meta-format specified");
	exit;
    }

}

# List-Contents Verb - MUST BE MODIFIED TO LINK TO LOCAL REPOSITORY
sub mr_dump_contents {
    my ($kwArgs, $Context) = @_;
    my ($partitionSpec) = $kwArgs->{'partitionspec'};
    my ($fileAfter) = $kwArgs->{'file-after'};
    my ($metaFormat) = $kwArgs->{'meta-format'};

    # dummy list of contents for testing
    my (@contents) = qw\handlecorp/0001 handlecorp/0002 handlecorp/0002\;

    # start the XML output
    my $XMLOutputTempFile = POSIX::tmpnam();
    my $output = new IO::File(">$XMLOutputTempFile");
    my $writer = 
	new XML::Writer (OUTPUT => $output, NEWLINES => 1, NAMESPACES => 1);   
    $writer->xmlDecl();
    $writer->startTag ("$Context->{'verb'}", 
		       "version" => $Context->{'version'});

    # dump the contents
    my $c;
    foreach $c (@contents) {
	$writer->startTag("record");
	$writer->characters($c);

	# in this test version we only know how to dump oams
	if ($metaFormat eq 'oams') {
	    $writer->startTag('oams');

	    # dummy OAMS metadata for demo.
	    my %oamsTags = (
		     title => "Sample Title",
		     accession => "2000-01-01",
		     subject => "Any Subject",
		     fullID => $c,
		     abstract => "This is about anything",
		     displayID => ['http://foo.com/handlecorp/0001'],
		     subject => ['databases', 'ai'],
		     comment => ['just a comment'],
		     discovery => ['1900-01-01', '1971-01-01'],
		     # author is repeatable and has internal structure
		     author => [{'name' => 'Jane Doe', 
				 'organization' => "Big Company"},
				{'name' => 'John Doe',
                                 'organization' => "Big University"}]
		     );
	    &write_OAMS(\%oamsTags, $writer, $Context);
	    $writer->endTag('oams');
	}
	$writer->endTag("record");
    }
    
    # Close out the XML stream
    $writer->endTag ($Context->{'verb'});
    $writer->end ();
    $output->close();
    &dienst::xmit_file("$XMLOutputTempFile", "text/xml", 1);
    unlink $XMLOutputTempFile;
}

# List-Meta-Formats Verb
sub mr_list_meta_formats {
    my ($kwArgs, $Context) = @_;

    # start the XML output
    my $XMLOutputTempFile = POSIX::tmpnam();
    my $output = new IO::File(">$XMLOutputTempFile");
    my $writer = 
	new XML::Writer (OUTPUT => $output, NEWLINES => 1, NAMESPACES => 1);   
    $writer->xmlDecl();
    $writer->startTag ("$Context->{'verb'}", 
		       "version" => $Context->{'version'});


    # Only OAMS supported
    my @mFormats = ({name => 'oams', 
		     namespace => 'http://www.OpenArchives.org'});

    # output the metaformats
    my $f;
    foreach $f (@mFormats) {
	$writer->startTag("meta-format",
			  "name" => $f->{'name'},
			  "namespace" => $f->{'namespace'});
	$writer->endTag("meta-format");
    }

    # Close out the XML stream
    $writer->endTag ($Context->{'verb'});
    $writer->end ();
    $output->close();
    &dienst::xmit_file("$XMLOutputTempFile", "text/xml", 1);
    unlink $XMLOutputTempFile;
}

# List-Partitions Verb - MUST BE MODIFIED TO LINK TO LOCAL REPOSITORY
sub mr_list_partitions {
    my ($kwArgs, $Context) = @_; 

    # start the XML output
    my $XMLOutputTempFile = POSIX::tmpnam();
    my $output = new IO::File(">$XMLOutputTempFile");
    my $writer = 
	new XML::Writer (OUTPUT => $output, NEWLINES => 1, NAMESPACES => 1);   
    $writer->xmlDecl();
    $writer->startTag ("$Context->{'verb'}", 
		       "version" => $Context->{'version'});

    # get nested partitions
    my @partitions = EPrints::OpenArchives->partitions();

    # loop through the partitions and recursively dump them out.
    my $p;
    foreach $p (@partitions) {
	my $pname = $p->[0];
	my $pnest = $p->[1];
	&dumpPartition($writer, $pname, $pnest);
    }
       
    # Close out the XML stream
    $writer->endTag ($Context->{'verb'});
    $writer->end ();
    $output->close();
    &dienst::xmit_file("$XMLOutputTempFile", "text/xml", 1);
    unlink $XMLOutputTempFile;
}

# Common subroutine to dump out a partitions.  Called recursively to handle
# nested partitions
sub dumpPartition {
    my ($writer, $pname, $pnest) = @_;
    $writer->startTag('partition', 'name' => $pname->{'name'});
    $writer->startTag('display');
    $writer->characters($pname->{'display'});
    $writer->endTag('display');
    my $pp;
    foreach $pp (@$pnest) {
	&dumpPartition($writer, $pp->[0], $pp->[1]);
    }
    $writer->endTag('partition');
}

# Structure verb
sub mr_structure {
    my ($fullID, $kwArgs, $Context) = @_;
    my ($view) = $kwArgs->{'view'};
    if ($view ne '#') {
	&dienst::complaint(400, "# is the only valid view that can be specified");
	exit;
    }

    unless( EPrints::OpenArchives->valid_fullID( $fullID ) )
    {
	&dienst::complaint( 404, "Unknown record specified" );
	exit;
    }

    # start the XML output
    my $XMLOutputTempFile = POSIX::tmpnam();
    my $output = new IO::File(">$XMLOutputTempFile");
    my $writer = 
	new XML::Writer (OUTPUT => $output, NEWLINES => 1, NAMESPACES => 1);   
    $writer->xmlDecl();
    $writer->startTag ("$Context->{'verb'}", 
		       "version" => $Context->{'version'});

    # Only one meta-format
    my @metaFormats = qw/oams/;

    # dump out the meta formats
    $writer->startTag("meta-format");
    my $m;
    foreach $m (@metaFormats) {
	$writer->startTag($m);
	$writer->endTag($m);
    }
    $writer->endTag("meta-format");

    # Close out the XML stream
    $writer->endTag ($Context->{'verb'});
    $writer->end ();
    $output->close();
    &dienst::xmit_file("$XMLOutputTempFile", "text/xml", 1);
    unlink $XMLOutputTempFile;
}

sub dummy_XML_return {
    my ($Context) = @_;

    my $XMLOutputTempFile = POSIX::tmpnam();
    my $output = new IO::File(">$XMLOutputTempFile");
    my $writer = 
	new XML::Writer (OUTPUT => $output, NEWLINES => 1, NAMESPACES => 1);   
    $writer->xmlDecl();
    $writer->startTag ("$Context->{'verb'}", 
			     "version" => $Context->{'version'});
    $writer->endTag ($Context->{'verb'});
    $writer->end ();
    $output->close();
    &dienst::xmit_file("$XMLOutputTempFile", "text/xml", 1);
    unlink $XMLOutputTempFile;
}

# Create XML output of Open Archives Metadata.  Input is the XML::Writer
# object in which the OAMS output is to be created and a hash that contains
# the values of the Open Archives Metadata.
sub write_OAMS {
    my ($oamsTags, $writer, $Context) = @_;
    my $k;
    my $oamsns = "http://www.openarchives.org";
    foreach $k (keys(%$oamsTags)) {
	my $e = $oamsTags->{$k};

	# scalar value, non repeatable tag
	if (ref($e) eq '') {
	    $writer->startTag($k);
	    $writer->characters($e);
	    $writer->endTag($k);
	}	    
	
	# hash reference value, internal structure within the element.
	if (ref($e) eq 'HASH') {
	    my $kk;
	    my %h = $$e;
	    $writer->startTag($k);
	    foreach $kk (keys(%$e)) {
		$writer->startTag($kk);
		$writer->characters($$e->{$kk});
		$writer->endTag($kk);
	    }
	    $writer->endTag($k);
	}

	# array reference value, repeatable element.
	if (ref($e) eq 'ARRAY') {
	    my $a;
	    foreach $a (@$e) {
		$writer->startTag($k);

		# simple scalar values within repeatable element.
		if (ref($a) eq '') {
		    $writer->characters($a);
		}

		# hash reference, structured values within repeatable element.
		elsif (ref($a) eq 'HASH') {
		    my $kk;
		    foreach $kk (keys(%$a)) {
			$writer->startTag($kk);
			$writer->characters($a->{$kk});
			$writer->endTag($kk);
		    }
		}
		$writer->endTag($k);
		
	    }
	}

    }
}
    

1;
