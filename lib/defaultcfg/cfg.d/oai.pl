######################################################################
#
#  OAI Configutation for Archive.
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################

my $oai = {};
$c->{oai} = $oai;

##########################################################################
# OAI-PMH 2.0 
#
# 2.0 requires slightly different schemas and XML to v1.1
##########################################################################

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/ for existing identifiers.
# This may be different for OAI v2.0
# It should contain a dot (.) which v1.1 can't. This means you can use your
# sites domain as (part of) the base ID - which is pretty darn unique.

# IMPORTANT: Do not register an archive with the default archive_id! 
#$oai->{v2}->{archive_id} = "generic.eprints.org";

# Base URL of OAI 2.0
$oai->{v2}->{base_url} = $c->{perl_url}."/oai2";

##########################################################################
# GENERAL OAI CONFIGURATION
# 
# This applies to all versions of OAI.
##########################################################################



# Set Configuration
# Rather than harvest the entire archive, a harvester may harvest only
# one set. Sets are usually subjects, but can be anything you like and are
# defined in the same manner as "browse_views". Only id, allow_null, fields
# are used.
$oai->{sets} = [
#	{ id=>"year", allow_null=>1, fields=>"date" },
#	{ id=>"person", allow_null=>0, fields=>"creators_id/editors_id" },
	{ id=>"status", allow_null=>0, fields=>"ispublished" },
	{ id=>"subjects", allow_null=>0, fields=>"subjects" },
	{ id=>"types", allow_null=>0, fields=>"type" },
];

# Custom sets allow you to create a specific search query related to a set
# e.g. for the EU DRIVER conformance
$oai->{custom_sets} = [
	{ spec => "driver", name => "Open Access DRIVERset", filters => [
		{ meta_fields => [ "full_text_status" ], value => "public", },
	] },
];

# Filter OAI export. If you want to stop certain records being exported
# you can add filters here. These work the same as for a search filter.

$oai->{filters} = [

# Example: don't export any OAI records from before 2003.
#	{ meta_fields => [ "date-effective" ], value=>"2003-" }
];


# This maps eprints document types to mime types if they are not the
# same.
$oai->{mime_types} = {};



########################################################################
#
# Information for "Identify" responses.
# 
# TIP: There is an online tool which we recommend you used to 
#      generate the remainder of this configuration file.
#
#      http://www.opendoar.org/tools/en/policies.php
#
########################################################################

# "content" : Text and/or a URL linking to text describing the content
# of the repository.  It would be appropriate to indicate the language(s)
# of the metadata/data in the repository.

$oai->{content}->{"text"} = undef;
$oai->{content}->{"url"} = $c->{base_url} . "/policies.html";

# "metadataPolicy" : Text and/or a URL linking to text describing policies
# relating to the use of metadata harvested through the OAI interface.

# metadataPolicy{"text"} and/or metadataPolicy{"url"} 
# MUST be defined to comply to OAI.

$oai->{metadata_policy}->{"text"} = <<END;
No metadata policy defined. 
This server has not yet been fully configured.
Please contact the admin for more information, but if in doubt assume that
NO rights at all are granted to this data.
END
$oai->{metadata_policy}->{"url"} = undef;

# "dataPolicy" : Text and/or a URL linking to text describing policies
# relating to the data held in the repository.  This may also describe
# policies regarding downloading data (full-content).

# dataPolicy{"text"} and/or dataPolicy{"url"} 
# MUST be defined to comply to OAI.

$oai->{data_policy}->{"text"} = <<END;
No data policy defined. 
This server has not yet been fully configured.
Please contact the admin for more information, but if in doubt assume that
NO rights at all are granted to this data.
END
$oai->{data_policy}->{"url"} = undef;

# "submissionPolicy" : Text and/or a URL linking to text describing
# policies relating to the submission of content to the repository (or
# other accession mechanisms).

$oai->{submission_policy}->{"text"} = <<END;
No submission-data policy defined. 
This server has not yet been fully configured.
END
$oai->{submission_policy}->{"url"} = undef;

# "comment" : Text and/or a URL linking to text describing anything else
# that is not covered by the fields above. It would be appropriate to
# include additional contact details (additional to the adminEmail that
# is part of the response to the Identify request).

# An array of comments to be returned. May be empty.

$oai->{comments} = [ 
	"This system is running eprints server software (".
		EPrints::Config::get( "version" ).") developed at the ".
		"University of Southampton. For more information see ".
		"http://www.eprints.org/"
];

########################################################################
# This is the end of the block which the DOAR policy tool can help you
# generate.
########################################################################



