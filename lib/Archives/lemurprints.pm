######################################################################
#
#  Site Information
#
#   Constants and information about the local EPrints site
#   *PATHS SHOULD NOT END WITH SLASHES, LEAVE THEM OUT*
#
######################################################################
#
#
######################################################################

package EPrints::Archives::lemurprints;


use XML::DOM;
use Unicode::String qw(utf8 latin1 utf16);

use EPrints::Archives::General;
use EPrints::Version;
use EPrints::Document;
use EPrints::OpenArchives;
use EPrints::EPrint;
use EPrints::User;
use EPrints::Session;
use EPrints::Subject;
use EPrints::Name;

use strict;


## WP1: BAD
sub get_conf
{
print STDERR "LEMURPRINTS:getconf\n";
	my $c = {};


######################################################################
#
#  General site information
#
######################################################################

$c->{archivename} = latin1( "Lemur Prints Archive" );
 
$c->{archiveid} = "lemurprints";

# Short text description
$c->{description} = latin1( "Your Site Description Here" );

# E-mail address for human-read administration mail
$c->{admin} = "admin\@lemur.ecs.soton.ac.uk";

# Host the machine is running on
$c->{host} = "HOSTNAME";

# hack cus of CVS. This makes the same config file more or less
# work for me at home and work...
my $host = `hostname`;
chomp $host;
if( $host eq "lemur" ) {
	$c->{host} = "lemur.ecs.soton.ac.uk";
} else {
	$c->{host} = "localhost";
}


# Stem for local ID codes
$c->{eprint_id_stem} = "zook";

# If 1, users can request the removal of their submissions from the archive
$c->{allow_user_removal_request} = 1;


######################################################################
#
#  Site information that shouldn't need changing
#
######################################################################


######################################################################
# paths

$c->{archive_root} = "$EPrints::Archives::General::base_path/sites/$c->{archiveid}";
$c->{bin_root} = "$EPrints::Archives::General::base_path/bin";
$c->{phrases_path} = "$c->{archive_root}/phrases";
$c->{static_html_root} = "$c->{archive_root}/static";
$c->{local_html_root} = "$c->{archive_root}/html";
$c->{local_document_root} = "$c->{archive_root}/documents";

######################################################################
# URLS

# Mod_perl script server, including port
$c->{server_perl} = "http://$c->{host}/perl";

# Server of static HTML + images, including port
$c->{server_static} = "http://$c->{host}";

# Site "home page" address
$c->{frontpage} = "$c->{server_static}/";

# Corresponding URL of document file hierarchy
$c->{server_document_root} = "$c->{server_static}/archive"; 

#################################################################
#  Files
#################################################################

$c->{template_user_intro} 	= "$c->{archive_root}/cfg/template.user-intro";
$c->{subject_config} 	= "$c->{archive_root}/cfg/subjects";

######################################################################
#
# Local users customisations
#
######################################################################

# Field to use to associate papers with authors in username and
# nameusername fields. Set to undef to use normal username.
# The named field should be of type "text".

$c->{useridfield} = "ecsid";


######################################################################
#
#  Document file upload information
#
######################################################################

# Supported document storage formats, given as an array and a hash value,
#  so that some order of preference can be imposed.
#cjg should these have screenable names?
$c->{supported_formats} =
[
	"HTML",
	"PDF",
	"PS",
	"ASCII"
];

# AT LEAST one of the following formats will be required. Include
# $EPrints::Document::OTHER as well as those in your list if you want to
# allow any format. Leave this list empty if you don't want to require that
# full text is deposited.
$c->{required_formats} =
[
	"HTML",
	"PDF",
	"PS",
	"ASCII"
];

#  If 1, will allow non-listed formats to be uploaded.
$c->{allow_arbitrary_formats} = 1;

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$c->{diskspace_error_threshold} = 20480;

# If ever the amount of free space drops below this threshold, the
# archive administrator is sent a warning email. In kilobytes.
$c->{diskspace_warn_threshold} = 512000;

# A list of compressed/archive formats that are accepted
$c->{supported_archive_formats} =
[
	"ZIP",
	"TARGZ"
];


# Executables for unzip and wget
$c->{unzip_executable} = "/usr/bin/unzip";
$c->{wget_executable} = "/usr/bin/wget";

# Command lines to execute to extract files from each type of archive.
# Note that archive extraction programs should not ever do any prompting,
# and should be SILENT whatever the error.  _DIR_ will be replaced with the 
# destination dir, and _ARC_ with the full pathname of the .zip. (Each
# occurence will be replaced if more than one of each.) Make NO assumptions
# about which dir the command will be run in. Exit code is assumed to be zero
# if everything went OK, non-zero in the case of any error.
$c->{archive_extraction_commands} =
{
	"ZIP"    =>  "$c->{unzip_executable} 1>/dev/null 2>\&1 -qq -o -d _DIR_ _ARC_",
	"TARGZ"  =>  "gunzip -c < _ARC_ 2>/dev/null | /bin/tar xf - -C _DIR_ >/dev/null 2>\&1"
};

# The extensions to give the temporary uploaded file for each format.
$c->{archive_extensions} =
{
	"ZIP"    =>  ".zip",
	"TARGZ"  =>  ".tar.gz"
};

#  Command to run to grab URLs. Should:
#  - Produce no output
#  - only follow relative links to same or subdirectory
#  - chop of the number of top directories _CUTDIRS_, so a load of pointlessly
#    deep directories aren't created
#  - start grabbing at _URL_
#
$c->{wget_command} =
	"$c->{wget_executable} -r -L -q -m -nH -np --execute=\"robots=off\" --cut-dirs=_CUTDIRS_ _URL_";


######################################################################
#
#  Miscellaneous
#
######################################################################

# Command for sending mail
$c->{sendmail_executable} = "/usr/sbin/sendmail";
$c->{sendmail} =
	"$c->{sendmail_executable} -oi -t -odb";

# Database information: Since we hold the password here unencrypted, this
# file should have suitable strict read permissions
$c->{db_name} = "eprints";
$c->{db_host} = "localhost";
$c->{db_port} = undef;
$c->{db_sock} = undef;
$c->{db_user} = "eprints";
$c->{db_pass} = "fnord";


######################################################################
#
#  Open Archives interoperability
#
######################################################################

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/sfc/sfc_archives.htm for existing identifiers.

$c->{oai_archive_id} = "lemurid";


# Exported metadata formats. The hash should map format ids to namespaces.
$c->{oai_metadata_formats} =
{
	"oai_dc"    =>  "http://purl.org/dc/elements/1.1/"
};

# Exported metadata formats. The hash should map format ids to schemas.
$c->{oai_metadata_schemas} =
{
	"oai_dc"    =>  "http://www.openarchives.org/OAI/dc.xsd"
};

# Base URL of OAI
$c->{oai_base_url} = $c->{server_perl}."/oai";

$c->{oai_sample_identifier} = EPrints::OpenArchives::to_oai_identifier(
	$c->{oai_archive_id},
	$c->{eprint_id_stem}."00000023" );

# Information for "Identify" responses.

# "content" : Text and/or a URL linking to text describing the content
# of the repository.  It would be appropriate to indicate the language(s)
# of the metadata/data in the repository.

$c->{oai_content}->{"text"} = $c->{description};
$c->{oai_content}->{"url"} = undef;

# "metadataPolicy" : Text and/or a URL linking to text describing policies
# relating to the use of metadata harvested through the OAI interface.

# oai_metadataPolicy{"text"} and/or oai_metadataPolicy{"url"} 
# MUST be defined to comply to OAI.

$c->{oai_metadata_policy}->{"text"} = latin1( <<END );
No metadata policy defined. 
This server has not yet been fully configured.
END
$c->{oai_metadata_policy}->{"url"} = undef;

# "dataPolicy" : Text and/or a URL linking to text describing policies
# relating to the data held in the repository.  This may also describe
# policies regarding downloading data (full-content).

# oai_dataPolicy{"text"} and/or oai_dataPolicy{"url"} 
# MUST be defined to comply to OAI.

$c->{oai_data_policy}->{"text"} = latin1( <<END );
No data policy defined. 
This server has not yet been fully configured.
END
$c->{oai_data_policy}->{"url"} = undef;

# "submissionPolicy" : Text and/or a URL linking to text describing
# policies relating to the submission of content to the repository (or
# other accession mechanisms).

$c->{oai_submission_policy}->{"text"} = latin1( <<END );
No submission-data policy defined. 
This server has not yet been fully configured.
END
$c->{oai_submission_policy}->{"url"} = undef;

# "comment" : Text and/or a URL linking to text describing anything else
# that is not covered by the fields above. It would be appropriate to
# include additional contact details (additional to the adminEmail that
# is part of the response to the Identify request).

# An array of comments to be returned. May be empty.

$c->{oai_comments} = [
	latin1( "System is EPrints ").
	$EPrints::Version::eprints_software_version.
	" (http://www.eprints.org)" ];




###########################################
#  Language

# List of supported languages is in EPrints::Archives::General.pm
# Default Language for this archive
$c->{default_language} = "english";

$c->{lang_cookie_domain} = $c->{host};
$c->{lang_cookie_name} = "lang";

###########################################
#  User Types
#

# We need to calculate the connection string, so we can pass it
# into the AuthDBI config. 
my $connect_string = EPrints::Database::build_connection_string(
	db_name  =>  $c->{db_name}, 
	db_port  =>  $c->{db_port},
	db_sock  =>  $c->{db_sock}, 
	db_host  =>  $c->{db_host}  );

my $userdata = EPrints::DataSet->new_stub( "user" );
 
$c->{userauth} = {
	user => { 
		routine  =>  \&Apache::AuthDBI::authen,
		conf  =>  {
			Auth_DBI_data_source  =>  $connect_string,
			Auth_DBI_username  =>  $c->{db_user},
			Auth_DBI_password  =>  $c->{db_pass},
			Auth_DBI_pwd_table  =>  $userdata->get_sql_table_name(),
			Auth_DBI_uid_field  =>  "username",
			Auth_DBI_pwd_field  =>  "passwd",
			Auth_DBI_grp_field  =>  "usertype",
			Auth_DBI_encrypted  =>  "off" },
		priv  =>  [ "user" ] },
	staff => { 
		routine  =>  \&Apache::AuthDBI::authen,
		conf  =>  {
			Auth_DBI_data_source  =>  $connect_string,
			Auth_DBI_username  =>  $c->{db_user},
			Auth_DBI_password  =>  $c->{db_pass},
			Auth_DBI_pwd_table  =>  $userdata->get_sql_table_name(),
			Auth_DBI_uid_field  =>  "username",
			Auth_DBI_pwd_field  =>  "passwd",
			Auth_DBI_grp_field  =>  "usertype",
			Auth_DBI_encrypted  =>  "off" }, 
		priv  =>  [ "tester", "subscription" ] }
};



######################################################################
# METADATA CONFIGURATION
######################################################################
# The archive specific fields for users and eprints.
#
# "editable" is almost always true (1), but there are times you
# might not want this. For example if you have a system which 
# imports information about users from another database, you
# may not wish them to be able to change those fields.
#
######################################################################


$c->{archivefields}->{user} = [

	{ name => "name", type => "name", required => 1 },

	{ name => "dept", type => "text", required => 0 },

	{ name => "org", type => "text", required => 0 },

	{ name => "address", type => "longtext", displaylines => 5,
		required => 0 },

	{ name => "oook", type => "text", multiple => 1 },

	{ name => "country", type => "text", required => 0 },

	{ name => "url", type => "url", required => 0, multiple => 1 },

	{ name => "filter", type => "subject", required => 0, showall => 1, multiple => 1 }
];

$c->{archivefields}->{eprint} = [
	{ name => "abstract", displaylines => 10, type => "longtext" },

	{ name => "altloc", displaylines => 3, type => "url", multiple => 1 },

	{ name => "authors", type => "name", multiple => 1 },

	{ name => "chapter", type => "text", maxlength => 5 },

	{ name => "comments", type => "longtext", displaylines => 3 },

	{ name => "commref", type => "text" },

	{ name => "confdates", type => "text" },

	{ name => "conference", type => "text" },

	{ name => "confloc", type => "text" },

	{ name => "department", type => "text" },

	{ name => "editors", type => "name", multiple => 1 },

	{ name => "institution", type => "text" },

	{ name => "ispublished", type => "set", 
			options => [ "unpub","inpress","pub" ] },

	{ name => "keywords", type => "longtext", displaylines => 2 },

	{ name => "month", type => "set",
		options => [ "unspec","jan","feb","mar","apr","may","jun",
			"jul","aug","sep","oct","nov","dec" ] },

	{ name => "number", type => "text", maxlength => 6 },

	{ name => "pages", type => "pagerange" },

	{ name => "pubdom", type => "boolean" },

	{ name => "publication", type => "text" },

	{ name => "publisher", type => "text" },

	{ name => "refereed", type => "boolean" },

	{ name => "referencetext", type => "longtext", displaylines => 3 },

	{ name => "reportno", type => "text" },

	{ name => "thesistype", type => "text" },

	{ name => "title", type => "text" },

	{ name => "volume", type => "text", maxlength => 6 },

	{ name => "year", type => "year" }
];
	
$c->{types}->{eprint} = {
	"bookchapter" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"chapter",
		"pages",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"confpaper" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"REQUIRED:abstract",
		"REQUIRED:conference",
		"pages",
		"confdates",
		"confloc",
		"volume",
		"number",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"confposter" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"REQUIRED:abstract",
		"REQUIRED:conference",
		"pages",
		"confdates",
		"confloc",
		"volume",
		"number",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"techreport" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:department",
		"REQUIRED:institution",
		"reportno",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"journale" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"volume",
		"number",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"journalp" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"volume",
		"number",
		"pages",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"newsarticle" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:publication",
		"volume",
		"number",
		"pages",
		"editors",
		"publisher",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"other" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"preprint" => [
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	],
	"thesis" => [
		"REQUIRED:ispublished",
		"REQUIRED:refereed",
		"REQUIRED:pubdom",
		"REQUIRED:authors",
		"REQUIRED:title",
		"REQUIRED:year",
		"month",
		"REQUIRED:abstract",
		"REQUIRED:thesistype",
		"REQUIRED:department",
		"REQUIRED:institution",
		"commref",
		"altloc",
		"keywords",
		"comments",
		"referencetext"
	]
};

$c->{types}->{user} = { 
	staff  =>  [],
	user  =>  []
};

######################################################################
#
#  Site Look and Feel
#
######################################################################

# parameters to generate the HTML header with.
# TITLE will be set by the system as appropriate.
# See the CGI.pm manpage for more info ( man CGI ).

# This is the HTML put at the top of every page. It will be put in the <BODY>,
#  so shouldn't include a <BODY> tag.

$c->{htmlpage}->{english} = parse_html( <<END );
<html>
<head>
  <title><titlehere/></title>
  <link rel="stylesheet" type="text/css" href="/eprints.css" title="screen stylesheet" media="screen"/>
</head>

<body bgcolor="#ffffff" text="#000000">

<div class="header">
<table  cellpadding="5" border="0" cellspacing="0" width="100%">
<tr><td align="left" width="100%" bgcolor="#cccccc">
<h1 class="sitetitle">$c->{archivename}</h1>
</td><td align="right" bgcolor="#cccccc">
<a href="$c->{server_perl}/setlang"><img border="0" src="/images/english.png" width="60" height="40" alt="english mode" /></a>
</td></tr>
<tr>
<td bgcolor="#333333">
<div class="pagetitle"><titlehere /></div>
</td>
<td bgcolor="#333333">
<div class="menu">

            <a class="menulink" href="$c->{frontpage}">Home</a> ||
            <a class="menulink" href="$c->{server_static}/information.html">About</a> ||
            <a class="menulink" href="$c->{server_static}/view/">Browse</a> ||
            <a class="menulink" href="$c->{server_perl}/search">Search</a> ||
            <a class="menulink" href="$c->{server_static}/register.html">Register</a> ||
            <a class="menulink" href="$c->{server_perl}/users/subscribe">Subscriptions</a> ||
            <a class="menulink" href="$c->{server_perl}/users/home">Deposit Items</a> ||
            <a class="menulink" href="$c->{server_static}/help">Help</a>
</div>
</td></tr></table>
</div>
<div class="main">
<pagehere />
 <hr noshade="noshade" size="2"/>
      <p>Contact site administrator at: <a href="mailto:$c->{admin}">$c->{admin}</a></p>
 <p>
    <a href="http://validator.ecs.soton.ac.uk/check/referer"><img
        src="http://www.w3.org/Icons/valid-xhtml10"
	border="0"
        alt="Valid XHTML 1.0!" height="31" width="88" /></a>
  </p>
</div></body>

</html>

END

#########################################################################################


$c->{htmlpage}->{french} = parse_html( <<END );
<html>
<head>
  <title><titlehere/></title>
  <link rel="stylesheet" type="text/css" href="/eprints.css" title="screen stylesheet" media="screen"/>
</head>

<body bgcolor="#ffffff" text="#000000">

<div class="header">
<table  cellpadding="5" border="0" cellspacing="0" width="100%"><tr><td bgcolor=
"#cccccc">
      <a href="http://lemur.ecs.soton.ac.uk/"><img border="0" width="100" height
="100" src="http://lemur.ecs.soton.ac.uk/images/logo_sidebar.gif" alt="" /></a>
</td><td align="left" width="100%" bgcolor="#cccccc">
<h1 class="sitetitle">$c->{archivename}</h1>
<h2 class="pagetitle"><titlehere /></h2>
</td><td align="right" bgcolor="#cccccc">
<a href="$c->{server_perl}/setlang"><img border="0" src="/images/french.png" width="60" height="40" alt="l'mode francais" /></a>
</td></tr>
<tr><td colspan="3" bgcolor="#333333">
<div class="menu">

            <a class="menulink" href="$c->{frontpage}">l'Home</a> ||
            <a class="menulink" href="$c->{server_static}/information.html">l'About</a> ||
            <a class="menulink" href="$c->{server_static}/view/">l'Browse</a> ||
            <a class="menulink" href="$c->{server_perl}/search">l'Search</a> ||
            <a class="menulink" href="$c->{server_static}/register.html">l'Register</a> ||
            <a class="menulink" href="$c->{server_perl}/users/subscribe">l'Subscriptions</a> ||
            <a class="menulink" href="$c->{server_perl}/users/home">l'Deposit Items</a> ||
            <a class="menulink" href="$c->{server_static}/help">l'Help</a>
</div>
</td></tr></table>
</div>
<div class="main">
<pagehere />
 <hr noshade="noshade" size="2"/>
      <p>Contact site administrator at: <a href="mailto:$c->{admin}">$c->{admin}</a></p>
 <p>
    <a href="http://validator.ecs.soton.ac.uk/check/referer"><img
        src="http://www.w3.org/Icons/valid-xhtml10"
	border="0"
        alt="Valid XHTML 1.0!" height="31" width="88" /></a>
  </p>
</div></body>

</html>

END


#  E-mail signature, appended to every email sent by the software
$c->{signature} = <<END;
--
 $c->{archivename}
 $c->{frontpage}
 $c->{admin}

END
#########################################################################################


$c->{htmlpage}->{dummy} = parse_html( <<END );
<html>
<head>
  <title><titlehere/></title>
  <link rel="stylesheet" type="text/css" href="/eprints.css" title="screen stylesheet" media="screen"/>
</head>

<body bgcolor="#ffffff" text="#000000">

<div class="header">
<table  cellpadding="5" border="0" cellspacing="0" width="100%"><tr><td bgcolor=
"#cccccc">
      <a href="http://lemur.ecs.soton.ac.uk/"><img border="0" width="100" height
="100" src="http://lemur.ecs.soton.ac.uk/images/logo_sidebar.gif" alt="" /></a>
</td><td align="left" width="100%" bgcolor="#cccccc">
<h1 class="sitetitle">$c->{archivename}</h1>
<h2 class="pagetitle"><titlehere /></h2>
</td><td align="right" bgcolor="#cccccc">
<a href="$c->{server_perl}/setlang"><img border="0" src="/images/dummy.png" width="60" height="40" alt="DUMMY MODE" /></a>
</td></tr>
<tr><td colspan="3" bgcolor="#333333">
<div class="menu">

            <a class="menulink" href="$c->{frontpage}">HOME</a> ||
            <a class="menulink" href="$c->{server_static}/information.html">ABOUT</a> ||
            <a class="menulink" href="$c->{server_subject}/view/">BROWSE</a> ||
            <a class="menulink" href="$c->{server_perl}/search">SEARCH</a> ||
            <a class="menulink" href="$c->{server_static}/register.html">REGISTER</a> ||
            <a class="menulink" href="$c->{server_perl}/users/subscribe">SUBSCRIPTIONS</a> ||
            <a class="menulink" href="$c->{server_perl}/users/home">DEPOSIT ITEMS</a> ||
            <a class="menulink" href="$c->{server_static}/help">HELP</a>
</div>
</td></tr></table>
</div>
<div class="main">
<pagehere />
 <hr noshade="noshade" size="2"/>
      <p>CONTACT SITE ADMINISTRATOR AT: <a href="mailto:$c->{admin}">$c->{admin}</a></p>
 <p>
    <a href="http://validator.ecs.soton.ac.uk/check/referer"><img
        src="http://www.w3.org/Icons/valid-xhtml10"
	border="0"
        alt="Valid XHTML 1.0!" height="31" width="88" /></a>
  </p>
</div></body>

</html>

END

#########cjg latin etc not done from here...

#  E-mail signature, appended to every email sent by the software
$c->{signature} = <<END;
--
 $c->{archivename}
 $c->{frontpage}
 $c->{admin}

END

#  Default text to send a user when "bouncing" a submission back to their
#  workspace. It should leave some space for staff to give a reason.
$c->{default_bounce_reason} = <<END;
Unfortunately your eprint:

  _SUBMISSION_TITLE_

could not be accepted into $c->{archivename} as-is.


The eprint has been returned to your workspace. If you
visit your item depositing page you will be able to
edit your eprint, fix the problem and redeposit.

END

#  Default text to send a user when rejecting a submission outright.
$c->{default_delete_reason} = <<END;
Unfortunately your eprint:

  _SUBMISSION_TITLE_

could not be accepted into $c->{archivename}.



The eprint has been deleted.

END

#  Agreement text, for when user completes the depositing process.
#  Set to "undef" if you don't want it to appear.
$c->{deposit_agreement_text} = <<END;

<P><EM><STRONG>For work being deposited by its own author:</STRONG> 
In self-archiving this collection of files and associated bibliographic 
metadata, I grant $c->{archivename} the right to store 
them and to make them permanently available publicly for free on-line. 
I declare that this material is my own intellectual property and I 
understand that $c->{archivename} does not assume any 
responsibility if there is any breach of copyright in distributing these 
files or metadata. (All authors are urged to prominently assert their 
copyright on the title page of their work.)</EM></P>

<P><EM><STRONG>For work being deposited by someone other than its 
author:</STRONG> I hereby declare that the collection of files and 
associated bibliographic metadata that I am archiving at 
$c->{archivename}) is in the public domain. If this is 
not the case, I accept full responsibility for any breach of copyright 
that distributing these files or metadata may entail.</EM></P>

<P>Clicking on the deposit button indicates your agreement to these 
terms.</P>
END

	
######################################################################
#
#  Search and subscription information
#
#   Before the site goes live, ensure that these are correct and work OK.
#
#   To specify a search field that will search >1 metadata field, enter
#   all of the fields to be searched separated by slashes "/" as a single
#   entry. e.g.  "title/abstract/keywords".
#
#   When specifying ordering, separate the fields with a comma, and specify
#   ASC for ascending order, or DESC for descending. Ascending order is
#   the default.  e.g. "year DESC, authors ASC, title"
#
######################################################################

# Fields for a simple user search
$c->{simple_search_fields} =
[
	"title/abstract/keywords",
	"authors/editors",
	"publication",
	"year"
];

# Fields for an advanced user search
$c->{advanced_search_fields} =
[
	"title",
	"authors",
	"abstract",
	"keywords",
	"subjects",
	"type",
	"conference",
	"department",
	"editors",
	"ispublished",
	"refereed",
	"publication",
	"year"
];

# Fields used for specifying a subscription
$c->{subscription_fields} =
[
	"subjects",
	"refereed",
	"ispublished"
];



# Ways of ordering search results
$c->{order_methods}->{eprint} =
{
	"byyear" 	 =>  \&eprint_cmp_by_year,
	"byyearoldest"	 =>  \&eprint_cmp_by_year_oldest_first,
	"byname"  	 =>  \&eprint_cmp_by_author,
	"bytitle" 	 =>  \&eprint_cmp_by_title 
};

# The default way of ordering a search result
#   (must be key to %eprint_order_methods)
$c->{default_order}->{eprint} = "byname";

# How to order the articles in a "browse by subject" view.
$c->{subject_view_order} = \&eprint_cmp_by_author;

# Fields for a staff user search.
$c->{user_search_fields} =
[
	"name",
	"dept/org",
	"address/country",
	"usertype",
	"email"
];

# Ways to order the results of a staff user search.
# cjg needs doing....
$c->{user_order_methods} =
{
	"by surname"                           =>  "name",
	"by joining date (most recent first)"  =>  "joined DESC, name",
	"by joining date (oldest first)"       =>  "joined ASC, name",
	"by group"                             =>  "group, name "
};

# Default order for a staff user search (must be key to user_order_methods)
$c->{default_user_order} = "by surname";	

# How to display articles in "version of" and "commentary" threads.
#  See lib/Citation.pm for information on how to specify this.
$c->{thread_citation_specs} =
{
	"succeeds"    =>  "{title} (deposited {datestamp})",
	"commentary"  =>  "{authors}. {title}. (deposited {datestamp})"
};

	return $c;
}

######################################################################
#
# Sort Routines
#
#  The following routines are used to sort lists of eprints according
#  to different schemes. They are linked to text descriptions of ways
#  of ordering eprints lists in SiteInfo.
#
#  Each method has two automatic parameters $_[0] and $_[1], both of which 
#  are eprint objects. The routine should return 
#   -1 if $_[0] is earlier in the ordering scheme than $_[1]
#    1 if $_[0] is later in the ordering scheme than $_[1]
#    0 if $_[0] is at the same point in the ordering scheme than $_[1]
#
#  These routines are not called by name, but by reference (see above)
#  so you can create your own methods as long as you add them to the
#  hash of sort methods.
#
######################################################################

## WP1: BAD
sub eprint_cmp_by_year
{
	return ( $_[1]->{year} <=> $_[0]->{year} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

## WP1: BAD
sub eprint_cmp_by_year_oldest_first
{
	return ( $_[0]->{year} <=> $_[1]->{year} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

## WP1: BAD
sub eprint_cmp_by_author
{
	
	return EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[1]->{year} <=> $_[0]->{year} ) || # largest year first
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

## WP1: BAD
sub eprint_cmp_by_title
{
	return ( $_[0]->{title} cmp $_[1]->{title} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[1]->{year} <=> $_[0]->{year} ) ; # largest year first
}

######################################################################
#
#  Free Text search configuration
#
######################################################################

# These values control what words do and don't make it into
# the free text search index. They are used by the extract_words
# method in the cjg SiteRoutines file which you can edit directly for
# finer control.

# Minimum size word to normally index.
my $FREETEXT_MIN_WORD_SIZE = 3;

# We use a hash rather than an array for good and bad
# words as we only use these to lookup if words are in
# them or not. If we used arrays and we had lots of words
# it might slow things down.

# Words to never index, despite their length.
my $FREETEXT_NEVER_WORDS = {
		"the" => 1,
		"you" => 1,
		"for" => 1,
		"and" => 1 
};

# Words to always index, despite their length.
my $FREETEXT_ALWAYS_WORDS = {
		"ok" => 1 
};

# This map is used to convert ASCII characters over
# 127 to characters below 127, in the word index.
# This means that the word Fête is indexed as 'fete' and
# "fete" or "fête" will match it.
# There's no reason mappings have to be a single character.

my $FREETEXT_CHAR_MAPPING = {
"¡" => "!",	"¢" => "c",	"£" => "L",	"¤" => "o",	
"¥" => "Y",	"¦" => "|",	"§" => "S",	"¨" => "\"",	
"©" => "(c)",	"ª" => "a",	"«" => "<<",	"¬" => "-",	
"­" => "-",	"®" => "(R)",	"¯" => "-",	"°" => "o",	
"±" => "+-",	"²" => "2",	"³" => "3",	"´" => "'",	
"µ" => "u",	"¶" => "q",	"·" => ".",	"¸" => ",",	
"¹" => "1",	"º" => "o",	"»" => ">>",	"¼" => "1/4",	
"½" => "1/2",	"¾" => "3/4",	"¿" => "?",	"À" => "A",	
"Á" => "A",	"Â" => "A",	"Ã" => "A",	"Ä" => "A",	
"Å" => "A",	"Æ" => "AE",	"Ç" => "C",	"È" => "E",	
"É" => "E",	"Ê" => "E",	"Ë" => "E",	"Ì" => "I",	
"Í" => "I",	"Î" => "I",	"Ï" => "I",	"Ð" => "D",	
"Ñ" => "N",	"Ò" => "O",	"Ó" => "O",	"Ô" => "O",	
"Õ" => "O",	"Ö" => "O",	"×" => "x",	"Ø" => "O",	
"Ù" => "U",	"Ú" => "U",	"Û" => "U",	"Ü" => "U",	
"Ý" => "Y",	"Þ" => "b",	"ß" => "B",	"à" => "a",	
"á" => "a",	"â" => "a",	"ã" => "a",	"ä" => "a",	
"å" => "a",	"æ" => "ae",	"ç" => "c",	"è" => "e",	
"é" => "e",	"ê" => "e",	"ë" => "e",	"ì" => "i",	
"í" => "i",	"î" => "i",	"ï" => "i",	"ð" => "d",	
"ñ" => "n",	"ò" => "o",	"ó" => "o",	"ô" => "o",	
"õ" => "o",	"ö" => "o",	"÷" => "/",	"ø" => "o",	
"ù" => "u",	"ú" => "u",	"û" => "u",	"ü" => "u",	
"ý" => "y",	"þ" => "B",	"ÿ" => "y" };



######################################################################
#
# extract_words( $text )
#
#  This method is used when indexing a record, to decide what words
#  should be used as index words.
#  It is also used to decide which words to use when performing a
#  search. 
#
#  It returns references to 2 arrays, one of "good" words which should
#  be used, and one of "bad" words which should not.
#
######################################################################

#cjg NOT UTF-8
## WP1: BAD
sub extract_words
{
	my( $text ) = @_;

	# convert acute's etc to their simple version using the map
	# from SiteInfo.
	my $mapped_chars = join( "", keys %{$FREETEXT_CHAR_MAPPING} );
	# escape [, ], \ and ^ because these mean something in a 
	# regexp charlist.
	$mapped_chars =~ s/\[\]\^\\/\\$&/g;
	# apply the map to $text
	$text =~ s/[$mapped_chars]/$FREETEXT_CHAR_MAPPING->{$&}/g;
	
	# Remove single quotes so "don't" becomes "dont"
	$text =~ s/'//g;

	# Normalise acronyms eg.
	# The F.B.I. is like M.I.5.
	# becomes
	# The FBI  is like MI5
	my $a;
	$text =~ s#[A-Z0-9]\.([A-Z0-9]\.)+#$a=$&;$a=~s/\.//g;$a#ge;

	# Remove hyphens from acronyms
	$text=~ s#[A-Z]-[A-Z](-[A-Z])*#$a=$&;$a=~s/-//g;$a#ge;

	# Replace any non alphanumeric characters with a space instead
	$text =~ s/[^a-zA-Z0-9]/ /g;

	# Iterate over every word (space seperated values) 
	my @words = split  /\s+/ , $text;
	# We use hashes rather than arrays at this point to make
	# sure we only get each word once, not once for each occurance.
	my %good = ();
	my %bad = ();
	foreach( @words )
	{	
		# skip if this is nothing but whitespace;
		next if /^\s*$/;

		# calculate the length of this word
		my $wordlen = length $_;

		# $ok indicates if we should index this word or not

		# First approximation is if this word is over or equal
		# to the minimum size set in SiteInfo.
		my $ok = $wordlen >= $FREETEXT_MIN_WORD_SIZE;
	
		# If this word is at least 2 chars long and all capitals
		# it is assumed to be an acronym and thus should be indexed.
		if( m/^[A-Z][A-Z0-9]+$/ )
		{
			$ok=1;
		}

		# Consult list of "never words". Words which should never
		# be indexed.	
		if( $FREETEXT_NEVER_WORDS->{lc $_} )
		{
			$ok = 0;
		}
		# Consult list of "always words". Words which should always
		# be indexed.	
		if( $FREETEXT_ALWAYS_WORDS->{lc $_} )
		{
			$ok = 1;
		}
	
		# Add this word to the good list or the bad list
		# as appropriate.	
		if( $ok )
		{
			# Only "bad" words are used in display to the
			# user. Good words can be normalised even further.

			# non-acronyms (ie not all UPPERCASE words) have
			# a trailing 's' removed. Thus in searches the
			# word "chair" will match "chairs" and vice-versa.
			# This isn't perfect "mose" will match "moses" and
			# "nappy" still won't match "nappies" but it's a
			# reasonable attempt.
			s/s$//;

			# If any of the characters are lowercase then lower
			# case the entire word so "Mesh" becomes "mesh" but
			# "HTTP" remains "HTTP".
			if( m/[a-z]/ )
			{
				$_ = lc $_;
			}
	
			$good{$_}++;
		}
		else 
		{
			$bad{$_}++;
		}
	}
	# convert hash keys to arrays and return references
	# to these arrays.
	my( @g ) = keys %good;
	my( @b ) = keys %bad;
	return( \@g , \@b );
}





######################################################################
#
# $title = eprint_short_title( $eprint )
#
#  Return a single line concise title for an EPrint, for rendering
#  lists
#
######################################################################

## WP1: BAD
sub eprint_short_title
{
	my( $eprint ) = @_;
	
	if( !defined $eprint->{title} || $eprint->{title} eq "" )
	{
		return( "Untitled (ID: $eprint->{eprintid})" );
	}
	else
	{
		return( $eprint->{title} );
	}
}


######################################################################
#
# $title = eprint_render_full( $eprint, $for_staff )
#
#  Return HTML for rendering an EPrint. If $for_staff is non-zero,
#  extra information appropriate for only staff may be shown.
#
######################################################################

## WP1: BAD
sub eprint_render_full
{
	my( $eprint, $for_staff ) = @_;

	#my $succeeds_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "succeeds" );
	#my $commentary_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "commentary" );
	#my $has_multiple_versions = $eprint->in_thread( $succeeds_field );

	my $session = $eprint->get_session();

	my $page = $session->make_doc_fragment;

	# Citation
	my $p = $session->make_element( "p" );
	$p->appendChild( $eprint->to_html() );
	$page->appendChild( $p );

	# Available formats
	#my @documents = $eprint->get_all_documents();
	
	#$html .= "<TABLE BORDER=0 CELLPADDING=5><TR><TD VALIGN=TOP><STRONG>Full ".
		#"text available as:</STRONG></TD><TD>";
	
	#foreach (@documents)
	#{
		#my $description = EPrints::Document::format_name( $eprint->{session}, $_->{format} );
		#$description = $_->{formatdesc}
			#if( $_->{format} eq $EPrints::Document::OTHER );
#
		#$html .= "<A href=\"".$_->url."\">$description</A><BR>";
	#}
#
	#$html .= "</TD></TR></TABLE>\n";

	# Put in a message describing how this document has other versions
	# in the archive if appropriate
	#if( $has_multiple_versions)
	#{
		#my $latest = $eprint->last_in_thread( $succeeds_field );
#
		#if( $latest->{eprintid} eq $eprint->{eprintid} )
		#{
			#$html .= "<P ALIGN=CENTER><EM>This is the latest version of this ".
				#"eprint.</EM></P>\n";
		#}
		#else
		#{
			#$html .= "<P ALIGN=CENTER><EM>There is a later version of this ".
				#"eprint available: <A href=\"" . $latest->static_page_url() . 
				#"\">Click here to view it.</A></EM></P>\n";
		#}
	#}		
#
	# Then the abstract

	my $h2 = $session->make_element( "h2" );
	$h2->appendChild( $session->make_text( "Abstract" ) ); # not langed #cjg

	$p = $session->make_element( "p" );
	$p->appendChild( $session->make_text( $eprint->get_value( "abstract" ) ) );
	$page->appendChild( $p );
	
	my( $table, $tr, $td );	# this table needs more class cjg
	$table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );

	#commentary	
	#if( defined $eprint->{commref} && $eprint->{commref} ne "" )
	#{
	#	$html .= "<TR><TD VALIGN=TOP><STRONG>Commentary on:</STRONG></TD><TD>".
	#		$eprint->{commref}."</TD></TR>\n";
	#}

	# Keywords
	my $keywords = $eprint->get_value( "keywords ");
	if( defined $keywords && $keywords ne "" )
	{
		$tr = $session->make_element( "tr" );
		$td = $session->make_element( "td" ); 
		$td->appendChild( $session->make_text( "Keywords:" ) ); #cjg i18l
		$tr->appendChild( $td );
		$td = $session->make_element( "td" ); 
		$td->appendChild( $session->make_text( $keywords ) );
		$tr->appendChild( $td );
		$table->appendChild( $tr );	
	}

	# Comments:
	#if( defined $eprint->{comments} && $eprint->{comments} ne "" )
	#{
		#$html .= "<TR><TD VALIGN=TOP><STRONG>Comments:</STRONG></TD><TD>".
			#$eprint->{comments}."</TD></TR>\n";
	#}

	# Subjects...
	#$html .= "<TR><TD VALIGN=TOP><STRONG>Subjects:</STRONG></TD><TD>";

	# NO MORE SUBJECT LIST!!!
	#my $subject_list = new EPrints::SubjectList( $eprint->{subjects} );
	#my @subjects = $subject_list->get_subjects( $eprint->{session} );

	#foreach (@subjects)
	#{
		#$html .= $eprint->{session}->{render}->subject_desc( $_, 1, 1, 0 );
		#$html .= "<BR>\n";
	#}

	# ID code...
	#$html .= "</TD><TR>\n<TD VALIGN=TOP><STRONG>ID code:</STRONG></TD><TD>".
		#$eprint->{eprintid}."</TD></TR>\n";

	# And who submitted it, and when.
	#$html .= "<TR><TD VALIGN=TOP><STRONG>Deposited by:</STRONG></TD><TD>";
	#my $user = new EPrints::User( $eprint->{session}, $eprint->{username} );
	#if( defined $user )
	#{
		#$html .= "<A href=\"".$eprint->{session}->get_archive()->get_conf( "server_perl" )."/user?username=".
			#$user->{username}."\">".$user->full_name()."</A>";
	#}
	#else
	#{
		#$html .= "INVALID USER";
	#}
#
	#if( $eprint->{table} eq $EPrints::Database::table_archive )
	#{
		#my $date_field = $eprint->{session}->{metainfo}->find_table_field( "eprint","datestamp" );
		#$html .= " on ".$eprint->{session}->{render}->format_field(
			#$date_field,
			#$eprint->{datestamp} );
	#}
	#$html .= "</TD></TR>\n";
#
	# Alternative locations
	#if( defined $eprint->{altloc} && $eprint->{altloc} ne "" )
	#{
		#$html .= "<TR><TD VALIGN=TOP><STRONG>Alternative Locations:".
			#"</STRONG></TD><TD>";
		#my $altloc_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "altloc" );
		#$html .= $eprint->{session}->{render}->format_field(
			#$altloc_field,
			#$eprint->{altloc} );
		#$html .= "</TD></TR>\n";
	#}
#
	#$html .= "</TABLE></P>\n";
#
	# If being viewed by a staff member, we want to show any suggestions for
	# additional subject categories
	if( $for_staff )
	{
		#my $additional_field = 
			#$eprint->{session}->{metainfo}->find_table_field( "eprint", "additional" );
		#my $reason_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "reasons" );
#
		## Write suggested extra subject category
		#if( defined $eprint->{additional} )
		#{
			#$html .= "<TABLE BORDER=0 CELLPADDING=3>\n";
			#$html .= "<TR><TD><STRONG>".$additional_field->display_name( $session ).":</STRONG>".
				#"</TD><TD>$eprint->{additional}</TD></TR>\n";
			#$html .= "<TR><TD><STRONG>".$reason_field->display_name( $session ).":</STRONG>".
				#"</TD><TD>$eprint->{reasons}</TD></TR>\n";
#
			#$html .= "</TABLE>\n";
		#}
	}
			
	# Now show the version and commentary response threads
	#if( $has_multiple_versions )
	#{
		#$html .= "<h3>Available Versions of This Item</h3>\n";
		#$html .= $eprint->{session}->{render}->write_version_thread(
			#$eprint,
			#$succeeds_field );
	#}
	#
	#if( $eprint->in_thread( $commentary_field ) )
	#{
		#$html .= "<h3>Commentary/Response Threads</h3>\n";
		#$html .= $eprint->{session}->{render}->write_version_thread(
			#$eprint,
			#$commentary_field );
	#}
#
	return( $page );
}


######################################################################
#
# $citation = eprint_render_citation( $eprint, $html )
#
#  Return text for rendering an EPrint in a form suitable for a
#  bibliography. If $html is non-zero, HTML formatting tags may be
#  used. Otherwise, only plain text should be returned.
#
######################################################################

my %OLD_CITATION_SPECS =
(
	"bookchapter"  =>  "{authors} [({year}) ]<i>{title}</i>, in [{editors}, Eds. ][<i>{publication}</i>][, chapter {chapter}][, pages {pages}]. [{publisher}.]",
	"confpaper"    =>  "{authors} [({year}) ]{title}. In [{editors}, Eds. ][<i>Proceedings {conference}</i>][ <B>{volume}</B>][({number})][, pages {pages}][, {confloc}].",
	"confposter"   =>  "{authors} [({year}) ]{title}. In [{editors}, Eds. ][<i>Proceedings {conference}</i>][ <B>{volume}</B>][({number})][, pages {pages}][, {confloc}].",
	"techreport"   =>  "{authors} [({year}) ]{title}. Technical Report[ {reportno}][, {department}][, {institution}].",
	"journale"     =>  "{authors} [({year}) ]{title}. <i>{publication}</i>[ {volume}][({number})].",
	"journalp"     =>  "{authors} [({year}) ]{title}. <i>{publication}</i>[ {volume}][({number})][:{pages}].",
	"newsarticle"  =>  "{authors} [({year}) ]{title}. In <i>{publication}</i>[, {volume}][({number})][ pages {pages}][, {publisher}].",
	"other"        =>  "{authors} [({year}) ]{title}.",
	"preprint"     =>  "{authors} [({year}) ]{title}.",
	"thesis"       =>  "{authors} [({year}) ]<i>{title}</i>. {thesistype},[ {department},][ {institution}]."
);

my %CITATION_SPECS =
(
	"bookchapter"  =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<i><FIELD name="title" /></i>, in [<FIELD name="editors" />, Eds. ][<i><FIELD name="publication" /></i>][, chapter <FIELD name="chapter" />][, pages <FIELD name="pages" />]. [<FIELD name="publisher" />.]
END
	"confpaper"    =>  <<END,
<FIELD name="authors"/> <IF name="year">(<FIELD name="year"/>) </IF><FIELD name="title"/>. In <IF name="editors"><FIELD name="editors"/>, Eds. </IF><IF name="conference"><I>Proceedings <FIELD name="conference" /></I></IF><IF name="volume"> <B><FIELD name="volume" /></B></IF><IF name="number">(<FIELD name="number" />)</IF><IF name="pages">, pages <FIELD name="pages" /></IF><IF name="confloc">, <FIELD name="confloc" /></IF>.
END

	"confposter"   =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<FIELD name="title" />. In [<FIELD name="editors" />, Eds. ][<i>Proceedings <FIELD name="conference" /></i>][ <B><FIELD name="volume" /></B>][(<FIELD name="number" />)][, pages <FIELD name="pages" />][, <FIELD name="confloc" />].
END

	"techreport"   =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<FIELD name="title" />. Technical Report[ <FIELD name="reportno" />][, <FIELD name="department" />][, <FIELD name="institution" />].
END

	"journale"     =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<FIELD name="title" />. <i><FIELD name="publication" /></i>[ <FIELD name="volume" />][(<FIELD name="number" />)].
END

	"journalp"     =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<FIELD name="title" />. <i><FIELD name="publication" /></i>[ <FIELD name="volume" />][(<FIELD name="number" />)][:<FIELD name="pages" />].
END

	"newsarticle"  =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<FIELD name="title" />. In <i><FIELD name="publication" /></i>[, <FIELD name="volume" />][(<FIELD name="number" />)][ pages <FIELD name="pages" />][, <FIELD name="publisher" />].
END

	"other"        =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<FIELD name="title" />.
END

	"preprint"     =>  <<END,
<FIELD name="authors" /> [(<FIELD name="year" />) ]<FIELD name="title" />.
END

	"thesis"       =>  <<END
<FIELD name="authors" /> [(<FIELD name="year" />) ]<i><FIELD name="title" /></i>. <FIELD name="thesistype" />,[ <FIELD name="department" />,][ <FIELD name="institution" />]."
)" />
END

);



my %CITATION_SPEC_DOMTREE;
foreach( keys %CITATION_SPECS )
{
	$CITATION_SPEC_DOMTREE{$_} = parse_html(
		"<span class=\"citation\">".$CITATION_SPECS{$_}."</span>" );

}




## WP1: BAD
sub get_eprint_citation_style 
{
	my( $eprint ) = @_;

## Crash if unknown style... cjg

	my $style = $CITATION_SPEC_DOMTREE{$eprint->get_value( "type" )}->cloneNode( 1 );
	$eprint->{session}->take_ownership( $style );
	
	return $style;
}




######################################################################
#
# $name = user_display_name( $user )
#
#  Return the user's name in a form appropriate for display.
#
######################################################################

## WP1: BAD
sub user_display_name
{
	my( $user ) = @_;

	# If no surname, just return the username
	my $name = $user->get_value( "name" );

	if( !defined $name || $name->{family} eq "" ) 
	{
		return( "User ".$user->get_value( "username" ) );
	} 

	return( EPrints::Name::format_name( $name, 1 ) );
}


######################################################################
#
# $html = user_render_full( $user, $public )
#
#  Render the full record for $user. If $public, only public fields
#  should be shown.
#
######################################################################

## WP1: BAD
sub user_render_full
{
	my( $user, $public ) = @_;

	my $html;	

	if( $public )
	{
		# Title + name
		$html = "<P>";
		$html .= $user->{title} if( defined $user->{title} );
		$html .= " ".$user->full_name()."</P>\n<P>";

		# Address, Starting with dept. and organisation...
		$html .= "$user->{dept}<BR>" if( defined $user->{dept} );
		$html .= "$user->{org}<BR>" if( defined $user->{org} );
		
		# Then the snail-mail address...
		my $address = $user->{address};
		if( defined $address )
		{
			$address =~ s/\r?\n/<BR>\n/s;
			$html .= "$address<BR>\n";
		}
		
		# Finally the country.
		$html .= $user->{country} if( defined $user->{country} );
		
		# E-mail and URL last, if available.
		my @user_fields = $user->{session}->{metainfo}->get_user_fields();
		my $email_field = EPrints::MetaInfo::find_field( \@user_fields, "email" );
		my $url_field = EPrints::MetaInfo::find_field( \@user_fields, "url" );

		$html .= "</P>\n";
		
		$html .= "<P>".$user->{session}->{render}->format_field(
			$email_field,
			$user->{email} )."</P>\n" if( defined $user->{email} );

		$html .= "<P>".$user->{session}->{render}->format_field(
			$url_field,
			$user->{url} )."</P>\n" if( defined $user->{url} );
	}
	else
	{
		# Render the more comprehensive staff version, that just prints all
		# of the fields out in a table.

		$html= "<p><table border=0 cellpadding=3>\n";

		# Lob the row data into the relevant fields
		my @fields = $user->{session}->{metainfo}->get_user_fields();
		my $field;

		foreach $field (@fields)
		{
			$html .= "<TR><TD VALIGN=TOP><STRONG>".$field->display_name( $user->{session} ).
				"</STRONG></TD><TD>";

			if( defined $user->{$field->{name}} )
			{
				$html .= $user->{session}->{render}->format_field(
					$field,
					$user->{$field->{name}} );
			}
			$html .= "</TD></TR>\n";
		}

		$html .= "</table></p>\n";
	}	

	return( $html );
}


######################################################################
#
# session_init( $session, $offline )
#        EPrints::Session  boolean
#
#  Invoked each time a new session is needed (generally one per
#  script invocation.) $session is a session object that can be used
#  to store any values you want. To prevent future clashes, prefix
#  all of the keys you put in the hash with site_.
#
#  If $offline is non-zero, the session is an `off-line' session, i.e.
#  it has been run as a shell script and not by the web server.
#
######################################################################

## WP1: BAD
sub session_init
{
	my( $session, $offline ) = @_;
}


######################################################################
#
# session_close( $session )
#
#  Invoked at the close of each session. Here you should clean up
#  anything you did in session_init().
#
######################################################################

## WP1: BAD
sub session_close
{
	my( $session ) = @_;
}


######################################################################
#
# update_submitted_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the inbox (the author's workspace) to the submission buffer.
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
######################################################################

## WP1: BAD
sub update_submitted_eprint
{
	my( $eprint ) = @_;
}


######################################################################
#
# update_archived_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the submission buffer to the real archive (i.e. when it is
#  actually "archived".)
#
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the author or administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
######################################################################

## WP1: BAD
sub update_archived_eprint
{
	my( $eprint ) = @_;
}


######################################################################
#
#  OPEN ARCHIVES INTEROPERABILITY ROUTINES
#
######################################################################


######################################################################
#
# @formats = oai_list_metadata_formats( $eprint )
#
#  This should return the metadata formats we can export for the given
#  eprint. If $eprint is undefined, just return all the metadata
#  formats supported by the archive.
#
#  The returned values must be keys to
#  the config element: oai_metadata_formats.
#
######################################################################

## WP1: BAD
sub oai_list_metadata_formats
{
	my( $eprint ) = @_;
	
	# This returns the list of all metadata formats, suitable if we
	# can export any of those metadata format for any record.
	return( keys %{$eprint->{session}->get_archive()->get_conf( "oai_metadata_formats" )} );
}


######################################################################
#
# %metadata = oai_get_eprint_metadata( $eprint, $format )
#
#  Return metadata for the given eprint in the given format.
#  The value of each key should be either a scalar value (string)
#  indicating the value for that string, e.g:
#
#   "title"  =>  "Full Title of the Paper"
#
#  or it can be a reference to a list of scalars, indicating multiple
#  values:
#
#   "author"  =>  [ "J. R. Hartley", "J. N. Smith" ]
#
#  it can also be nested:
#
#   "nested"  =>  [
#                  {
#                    "nested_key 1"  =>  "nested value 1",
#                    "nested_key 2"  =>  "nested value 2"
#                  },
#                  {
#                    "more nested values"
#                  }
#               ]
#
#  Return undefined if the metadata format requested is not available
#  for the given eprint.
#
######################################################################

## WP1: BAD
sub oai_get_eprint_metadata
{
	my( $eprint, $format ) = @_;

	if( $format eq "oai_dc" )
	{
		my %tags;
		
		$tags{title} = $eprint->{title};

		my @authors = EPrints::Name::extract( $eprint->{authors} );
		$tags{creator} = [];

		foreach (@authors)
		{
			my( $surname, $firstnames ) = @$_;
			push @{$tags{creator}},"$surname, $firstnames";
		}

		# Subject field will just be the subject descriptions

		#cjg SubjectList deprecated do it another way?
		#my $subject_list = new EPrints::SubjectList( $eprint->{subjects} );
		my @subjects    ;#   = $subject_list->get_subjects( $eprint->{session} );
		$tags{subject} = [];

		foreach (@subjects)
		{
			push @{$tags{subject}},
		   	  $eprint->{session}->{render}->subject_desc( $_, 0, 1, 0 );
		}

		$tags{description} = $eprint->{abstract};
		
		# Date for discovery. For a month/day we don't have, assume 01.
		my $year = $eprint->{year};
		my $month = "01";

		if( defined $eprint->{month} )
		{
			my %month_numbers = (
				unspec  =>  "01",
				jan  =>  "01",
				feb  =>  "02",
				mar  =>  "03",
				apr  =>  "04",
				may  =>  "05",
				jun  =>  "06",
				jul  =>  "07",
				aug  =>  "08",
				sep  =>  "09",
				oct  =>  "10",
				nov  =>  "11",
				dec  =>  "12" );

			$month = $month_numbers{$eprint->{month}};
		}

		$tags{date} = "$year-$month-01";
		$tags{type} = $eprint->{session}->{metainfo}->get_type_name( $eprint->{session}, "archive" , $eprint->{type} );
		$tags{identifier} = $eprint->static_page_url();

		return( %tags );
	}
	else
	{
		return( undef );
	}
}

######################################################################
#
# oai_write_eprint_metadata( $eprint, $format, $writer )
#
# This routine receives a handle to an XML::Writer it should
# write the entire XML output for the format; Everything between
# <metadata> and </metadata>.
#
# Ensure that all tags are closed in the order you open them.
#
# This routine is more low-level that oai_get_eprint_metadata
# and as such gives you more control, but is more work too.
#
# See the XML::Writer manual page for more useful information.
#
# You should use the EPrints::OpenArchives::to_utf8() function
# on your data to convert latin1 to UTF-8.
#
######################################################################


## WP1: BAD
sub oai_write_eprint_metadata
{
	my( $eprint, $format, $writer ) = @_;

	# This block of code is a minimal example
	# to get you started
	if ($format eq "not-a-real-format") {
		$writer->startTag("notaformat");
		$writer->dataElement(
			"title",
			EPrints::OpenArchives::to_utf8($eprint->{title}));
		$writer->dataElement(
			"description",
			EPrints::OpenArchives::to_utf8($eprint->{abstract}));
		$writer->endTag("notaformat");
	}
}




######################################################################
#
# $problem = validate_user_field( $field, $value )
#   str                         MetaField  str
#
#  Validate a particular field of a user's metadata. Should return
#  undef if the field is OK, otherwise should return a textual
#  description of the problem. This description should make sense on
#  its own (i.e. should include the name of the field.)
#
#  The "required" field is checked elsewhere, no need to check that
#  here.
#
######################################################################

## WP1: BAD
sub validate_user_field
{
	my( $field, $value, $session ) = @_;

	my $problem;

	# CHECKS IN HERE

	# Ensure that a URL is valid (i.e. has the initial scheme like http:)
#	if( $field->is_type( "url" ) && defined $value && $value ne "" )
#	{
#		$problem = "The URL given for ".$field->display_name( $session )." is invalid.  ".
#			"Have you included the initial <STRONG>http://</STRONG>?"
#			if( $value !~ /^\w+:/ );
#	}

	return( (!defined $problem || $problem eq "" ) ? undef : $problem );
}


######################################################################
#
# $problem = validate_eprint_field( $field, $value )
#   str                         MetaField  str
#
#  Validate a particular field of an eprint's metadata. Should return
#  undef if the field is OK, otherwise should return a textual
#  description of the problem. This description should make sense on
#  its own (i.e. should include the name of the field.)
#
#  The "required" field is checked elsewhere, no need to check that
#  here.
#
######################################################################

## WP1: BAD
sub validate_eprint_field
{
	my( $field, $value );

	my $problem;

	# CHECKS IN HERE

	return( (!defined $problem || $problem eq "" ) ? undef : $problem );
}


######################################################################
#
# $problem = validate_subject_field( $field, $value )
#   str                            MetaField  str
#
#  Validate the subjects field of an eprint's metadata. Should return
#  undef if the field is OK, otherwise should return a textual
#  description of the problem. This description should make sense on
#  its own (i.e. should include the name of the field.)
#
#  The "required" field is checked elsewhere, no need to check that
#  here.
#
######################################################################

## WP1: BAD
sub validate_subject_field
{
	my( $field, $value ) = @_;

	my $problem;

	# CHECKS IN HERE


	return( (!defined $problem || $problem eq "" ) ? undef : $problem );
}


######################################################################
#
# validate_document( $document, $problems )
#                                array_ref
#
#  Validate the given document. $document is an EPrints::Document
#  object. $problems is a reference to an array in which any identified
#  problems with the document can be put.
#
#  Any number of problems can be put in the array but it's probably
#  best to keep the number down so the user's heart doesn't sink!
#
#  If no problems are identified and everything's fine then just
#  leave $problems alone.
#
######################################################################

## WP1: BAD
sub validate_document
{
	my( $document, $problems ) = @_;

	# CHECKS IN HERE
}


######################################################################
#
# validate_eprint( $eprint, $problems )
#                           array_ref
#
#  Validate a whole EPrint record. $eprint is an EPrints::EPrint object.
#  
#  Any number of problems can be put in the array but it's probably
#  best to keep the number down so the user's heart doesn't sink!
#
#  If no problems are identified and everything's fine then just
#  leave $problems alone.
#
######################################################################

## WP1: BAD
sub validate_eprint
{
	my( $eprint, $problems ) = @_;

	# CHECKS IN HERE
}


######################################################################
#
# validate_eprint_meta( $eprint, $problems )
#                                 array_ref
#
#  Validate the site-specific EPrints metadata. $eprint is an
#  EPrints::EPrint object.
#  
#  Any number of problems can be put in the array but it's probably
#  best to keep the number down so the user's heart doesn't sink!
#
#  If no problems are identified and everything's fine then just
#  leave $problems alone.
#
######################################################################

## WP1: BAD
sub validate_eprint_meta
{
	my( $eprint, $problems ) = @_;

	# CHECKS IN HERE

	# We check that if a journal article is published, then it has the volume
	# number and page numbers.
	if( $eprint->{type} eq "journalp" && $eprint->{ispublished} eq "pub" )
	{
		push @$problems, "You haven't specified any page numbers"
			unless( defined $eprint->{pages} && $eprint->{pages} ne "" );
	}
	
	if( ( $eprint->{type} eq "journalp" || $eprint->{type} eq "journale" )
		&& $eprint->{ispublished} eq "pub" )
	{	
		push @$problems, "You haven't specified the volume number"
			unless( defined $eprint->{volume} && $eprint->{volume} ne "" );
	}
}

## WP1: BAD
sub log
{
	my( $archive, $message ) = @_;
	print STDERR "EPRINTS:".$archive->get_conf("siteid").": ".$message."\n";
}

## WP1: BAD
sub parse_html
{
	my( $html ) = @_;
	my $parser = new XML::DOM::Parser();
	my $doc = $parser->parse( $html );
	my $element = $doc->getFirstChild;	
	$doc->removeChild( $element );
	$doc->dispose();
	return $element;
}

1;
