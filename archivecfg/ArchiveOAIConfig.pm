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

use EPrints::OpenArchives;

sub get_oai_conf { my $oai={};

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/ for existing identifiers.

$oai->{archive_id} = "GenericEPrints";

# All three of the following configuration elements should have the same
# keys. To support OAI you must offer basic dublic core as "oai_dc".

# Exported metadata formats. The hash should map format ids to namespaces.
$oai->{metadata_namespaces} =
{
	"oai_dc"    =>  "http://purl.org/dc/elements/1.1/"
};

# Exported metadata formats. The hash should map format ids to schemas.
$oai->{metadata_schemas} =
{
	"oai_dc"    =>  "http://www.openarchives.org/OAI/1.1/dc.xsd"
};

# Each supported metadata format will need a function to turn
# the eprint record into XML representing that format. The function(s)
# are defined later in this file.
$oai->{metadata_functions} = 
{
	"oai_dc"    =>  \&make_metadata_oai_dc
};

# Base URL of OAI
$oai->{base_url} = $oai->{perl_url}."/oai";

$oai->{sample_identifier} = EPrints::OpenArchives::to_oai_identifier(
	$oai->{archive_id},
	"23" );

# Set Configuration
# Rather than harvest the entire archive, a harvester may harvest only
# one set. Sets are usually subjects, but can be anything you like and are
# defined in the same manner as "browse_views". Only id, allow_null, fields
# are used.
$oai->{sets} = [
#	{ id=>"year", allow_null=>1, fields=>"year" },
#	{ id=>"person", allow_null=>0, fields=>"authors.id/editors.id" },
	{ id=>"subjects", allow_null=>0, fields=>"subjects" }
];

# Number of results to display on a single search results page

# Information for "Identify" responses.

# "content" : Text and/or a URL linking to text describing the content
# of the repository.  It would be appropriate to indicate the language(s)
# of the metadata/data in the repository.

$oai->{content}->{"text"} = latin1( <<END );
OAI Site description has not been configured.
END
$oai->{content}->{"url"} = undef;

# "metadataPolicy" : Text and/or a URL linking to text describing policies
# relating to the use of metadata harvested through the OAI interface.

# metadataPolicy{"text"} and/or metadataPolicy{"url"} 
# MUST be defined to comply to OAI.

$oai->{metadata_policy}->{"text"} = latin1( <<END );
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

$oai->{data_policy}->{"text"} = latin1( <<END );
No data policy defined. 
This server has not yet been fully configured.
Please contact the admin for more information, but if in doubt assume that
NO rights at all are granted to this data.
END
$oai->{data_policy}->{"url"} = undef;

# "submissionPolicy" : Text and/or a URL linking to text describing
# policies relating to the submission of content to the repository (or
# other accession mechanisms).

$oai->{submission_policy}->{"text"} = latin1( <<END );
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
	latin1( "This system is running eprints server software (".
		EPrints::Config::get( "version" ).") developed at the ".
		"University of Southampton. For more information see ".
		"http://www.eprints.org/" ) 
];

return $oai; }

######################################################################
#
# $domfragment = make_metadata_oai_dc( $eprint, $session )
#
######################################################################
# $eprint
# - the EPrints::EPrint to be converted
# $session
# - the current EPrints::Session
#
# returns: ( $xhtmlfragment, $title )
# - a DOM tree containing the metadata from $eprint in oai_dc - 
# unqualified dublin-core.
######################################################################
# This subroutine takes an eprint object and renders the XML DOM
# to export as the oai_dc default format in OAI.
#
# If supporting other metadata formats, it's probably best to start
# by copying this method, and modifying it.
#
######################################################################

sub make_metadata_oai_dc
{
	my( $eprint, $session ) = @_;

	my $archive = $session->get_archive();

	# return undef, if you don't support this metadata format for this
	# eprint.  ( But this is "oai_dc" so we have to support it! )

	# Get the namespace & schema.
	# We could hard code them here, but getting the values from our
	# own configuration should avoid getting our knickers in a twist.
	
	my $namespace = $archive->get_conf( "metadata_namespaces" )->{oai_dc};
	my $schema = $archive->get_conf( "metadata_schemas" )->{oai_dc};

	my $dc = $session->make_element(
		"dc",
		"xmlns" => $namespace,
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => $namespace." ".$schema );
	
	$dc->appendChild(  $session->render_data_element( 
		8,
		"title",
		$eprint->get_value( "title" ) ) );


	# grab the authors without the ID parts so if the site admin
	# sets or unsets authors to having and ID part it will make
	# no difference to this bit.

	my $author;
	foreach $author ( @{$eprint->get_value( "authors", 1 )} )
	{
		$dc->appendChild(  $session->render_data_element( 
			8,
			"creator",
			EPrints::Utils::tree_to_utf8( EPrints::Utils::render_name( $session, $author, 0 ) ) ) );
	}

	my $subjectid;
	foreach $subjectid ( @{$eprint->get_value( "subjects" )} )
	{
		my $subject = EPrints::Subject->new( $session, $subjectid );
		$dc->appendChild(  $session->render_data_element( 
			8,
			"subject",
			EPrints::Utils::tree_to_utf8( $subject->render_description() ) ) );
	}

	$dc->appendChild(  $session->render_data_element( 
		8,
		"description",
		$eprint->get_value( "abstract" ) ) );

	## Date for discovery. For a month/day we don't have, assume 01.
	my $year = $eprint->get_value( "year" );
	my $month = "01";

	if( $eprint->is_set( "month" ) )
	{
		my %month_numbers = (
			jan  =>  "01", feb  =>  "02", mar  =>  "03",
			apr  =>  "04", may  =>  "05", jun  =>  "06",
			jul  =>  "07", aug  =>  "08", sep  =>  "09",
			oct  =>  "10", nov  =>  "11", dec  =>  "12" );

		$month = $month_numbers{$eprint->get_value( "month" )};
	}

	$dc->appendChild(  $session->render_data_element( 
		8,
		"date",
		"$year-$month-01" ) );

	my $ds = $eprint->get_dataset();
	$dc->appendChild(  $session->render_data_element( 
		8,
		"type",
		$ds->get_type_name( $session, $eprint->get_value( "type" ) ) ) );

	$dc->appendChild(  $session->render_data_element( 
		8,
		"identifier",
		$eprint->get_url() ) );

	return $dc;
}

1;
