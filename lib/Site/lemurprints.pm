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

package EPrints::Site::lemurprints;

use CGI qw/:standard/;

use EPrints::Site::General;
use EPrints::Version;
use EPrints::Document;
use EPrints::OpenArchives;
use EPrints::Citation;
use EPrints::EPrint;
use EPrints::User;
use EPrints::Session;
use EPrints::Subject;
use EPrints::SubjectList;
use EPrints::Name;


sub new
{
	my( $class ) = @_;

	my $self = {};
	bless $self, $class;


######################################################################
#
#  General site information
#
######################################################################

$self->{sitename} = "Lemur Prints Archive";

$self->{siteid} = "lemurprints";

# Short text description
$self->{description} = "Your Site Description Here";

# E-mail address for human-read administration mail
$self->{admin} = "admin\@lemur.ecs.soton.ac.uk";

# Host the machine is running on
$self->{host} = "HOSTNAME";

# hack cus of CVS. This makes the same config file more or less
# work for me at home and work...
my $host = `hostname`;
chomp $host;
if( $host eq "lemur" ) {
	$self->{host} = "lemur.ecs.soton.ac.uk";
} else {
	$self->{host} = "localhost";
}


# Stem for local ID codes
$self->{eprint_id_stem} = "zook";

# If 1, users can request the removal of their submissions from the archive
$self->{allow_user_removal_request} = 1;


######################################################################
#
#  Site information that shouldn't need changing
#
######################################################################


######################################################################
# paths

$self->{site_root} = "$EPrints::Site::General::base_path/sites/$self->{siteid}";
$self->{bin_root} = "$EPrints::Site::General::base_path/bin";
$self->{phrases_path} = "$self->{site_root}/phrases";
$self->{static_html_root} = "$self->{site_root}/static";
$self->{local_html_root} = "$self->{site_root}/html";
$self->{local_document_root} = "$self->{local_html_root}/documents";

######################################################################
# URLS

# Mod_perl script server, including port
$self->{server_perl} = "http://$self->{host}/perl";

# Server of static HTML + images, including port
$self->{server_static} = "http://$self->{host}";

# Site "home page" address
$self->{frontpage} = "$self->{server_static}/";

# Corresponding URL of document file hierarchy
$self->{server_document_root} = "$self->{server_static}/documents"; 

# Corresponding URL stem for "browse by subject" HTML files
$self->{server_subject_view_stem} = "$self->{server_static}/view-";

#################################################################
#  Files
#################################################################

$self->{template_user_intro} 	= "$self->{site_root}/cfg/template.user-intro";
$self->{subject_config} 	= "$self->{site_root}/cfg/subjects";

######################################################################
#
# Local users customisations
#
######################################################################

# Field to use to associate papers with authors in username and
# nameusername fields. Set to undef to use normal username.
# The named field should be of type "text".

$self->{useridfield} = "ecsid";


######################################################################
#
#  Document file upload information
#
######################################################################

# Supported document storage formats, given as an array and a hash value,
#  so that some order of preference can be imposed.
$self->{supported_formats} =
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
$self->{required_formats} =
[
	"HTML",
	"PDF",
	"PS",
	"ASCII"
];

#  If 1, will allow non-listed formats to be uploaded.
$self->{allow_arbitrary_formats} = 1;

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$self->{diskspace_error_threshold} = 20480;

# If ever the amount of free space drops below this threshold, the
# archive administrator is sent a warning email. In kilobytes.
$self->{diskspace_warn_threshold} = 512000;

# A list of compressed/archive formats that are accepted
$self->{supported_archive_formats} =
[
	"ZIP",
	"TARGZ"
];


# Executables for unzip and wget
$self->{unzip_executable} = "/usr/bin/unzip";
$self->{wget_executable} = "/usr/bin/wget";

# Command lines to execute to extract files from each type of archive.
# Note that archive extraction programs should not ever do any prompting,
# and should be SILENT whatever the error.  _DIR_ will be replaced with the 
# destination dir, and _ARC_ with the full pathname of the .zip. (Each
# occurence will be replaced if more than one of each.) Make NO assumptions
# about which dir the command will be run in. Exit code is assumed to be zero
# if everything went OK, non-zero in the case of any error.
$self->{archive_extraction_commands} =
{
	"ZIP"   => "$self->{unzip_executable} 1>/dev/null 2>\&1 -qq -o -d _DIR_ _ARC_",
	"TARGZ" => "gunzip -c < _ARC_ 2>/dev/null | /bin/tar xf - -C _DIR_ >/dev/null 2>\&1"
};

# The extensions to give the temporary uploaded file for each format.
$self->{archive_extensions} =
{
	"ZIP"   => ".zip",
	"TARGZ" => ".tar.gz"
};

#  Command to run to grab URLs. Should:
#  - Produce no output
#  - only follow relative links to same or subdirectory
#  - chop of the number of top directories _CUTDIRS_, so a load of pointlessly
#    deep directories aren't created
#  - start grabbing at _URL_
#
$self->{wget_command} =
	"$self->{wget_executable} -r -L -q -m -nH -np --execute=\"robots=off\" --cut-dirs=_CUTDIRS_ _URL_";


######################################################################
#
#  Miscellaneous
#
######################################################################

# Command for sending mail
$self->{sendmail_executable} = "/usr/sbin/sendmail";
$self->{sendmail} =
	"$self->{sendmail_executable} -oi -t -odb";

# Database information: Since we hold the password here unencrypted, this
# file should have suitable strict read permissions
$self->{db_name} = "eprints";
$self->{db_host} = "localhost";
$self->{db_port} = undef;
$self->{db_sock} = undef;
$self->{db_user} = "eprints";
$self->{db_pass} = "fnord";


######################################################################
#
#  Open Archives interoperability
#
######################################################################

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/sfc/sfc_archives.htm for existing identifiers.

$self->{oai_archive_id} = "lemurid";


# Exported metadata formats. The hash should map format ids to namespaces.
$self->{oai_metadata_formats} =
{
	"oai_dc"   => "http://purl.org/dc/elements/1.1/"
};

# Exported metadata formats. The hash should map format ids to schemas.
$self->{oai_metadata_schemas} =
{
	"oai_dc"   => "http://www.openarchives.org/OAI/dc.xsd"
};

# Base URL of OAI
$self->{oai_base_url} = $self->{server_perl}."/oai";

$self->{oai_sample_identifier} = EPrints::OpenArchives::to_oai_identifier(
	$self->{oai_archive_id},
	$self->{eprint_id_stem}."00000023" );

# Information for "Identify" responses.

# "content" : Text and/or a URL linking to text describing the content
# of the repository.  It would be appropriate to indicate the language(s)
# of the metadata/data in the repository.

$self->{oai_content}->{"text"} = $self->{description};
$self->{oai_content}->{"url"} = undef;

# "metadataPolicy" : Text and/or a URL linking to text describing policies
# relating to the use of metadata harvested through the OAI interface.

# oai_metadataPolicy{"text"} and/or oai_metadataPolicy{"url"} 
# MUST be defined to comply to OAI.

$self->{oai_metadata_policy}->{"text"} = <<END;
No metadata policy defined. 
This server has not yet been fully configured.
END
$self->{oai_metadata_policy}->{"url"} = undef;

# "dataPolicy" : Text and/or a URL linking to text describing policies
# relating to the data held in the repository.  This may also describe
# policies regarding downloading data (full-content).

# oai_dataPolicy{"text"} and/or oai_dataPolicy{"url"} 
# MUST be defined to comply to OAI.

$self->{oai_data_policy}->{"text"} = <<END;
No data policy defined. 
This server has not yet been fully configured.
END
$self->{oai_data_policy}->{"url"} = undef;

# "submissionPolicy" : Text and/or a URL linking to text describing
# policies relating to the submission of content to the repository (or
# other accession mechanisms).

$self->{oai_submission_policy}->{"text"} = <<END;
No submission-data policy defined. 
This server has not yet been fully configured.
END
$self->{oai_submission_policy}->{"url"} = undef;

# "comment" : Text and/or a URL linking to text describing anything else
# that is not covered by the fields above. It would be appropriate to
# include additional contact details (additional to the adminEmail that
# is part of the response to the Identify request).

# An array of comments to be returned. May be empty.

$self->{oai_comments} = [
	"System is EPrints ".
	$EPrints::Version::eprints_software_version.
	" (http://www.eprints.org)" ];




###########################################
#  Language

# List of supported languages is in EPrints::Site::General.pm
# Default Language for this archive
$self->{default_language} = "english";

$self->{lang_cookie_domain} = $self->{host};
$self->{lang_cookie_name} = $self->{siteid}."_lang";

###########################################
#  User Types
#

# We need to calculate the connection string, so we can pass it
# into the AuthDBI config. 
my $connect_string = EPrints::Database::build_connection_string(
	{ db_name => $self->{db_name}, db_port => $self->{db_port},
 	  db_sock => $self->{db_sock}, db_host => $self->{db_host} } );
 
$self->{userauth} = {
	User=>{ 
		routine => \&Apache::AuthDBI::authen,
		conf => {
			Auth_DBI_data_source => $connect_string,
			Auth_DBI_username => $self->{db_user},
			Auth_DBI_password => $self->{db_pass},
			Auth_DBI_pwd_table => EPrints::Database::table_name( "user" ),
			Auth_DBI_uid_field => "username",
			Auth_DBI_pwd_field => "passwd",
			Auth_DBI_grp_field => "groups",
			Auth_DBI_encrypted => "off" },
		priv => [ "user" ] },
	Staff=>{ 
		routine => \&Apache::AuthDBI::authen,
		conf => {
			Auth_DBI_data_source => $connect_string,
			Auth_DBI_username => $self->{db_user},
			Auth_DBI_password => $self->{db_pass},
			Auth_DBI_pwd_table => EPrints::Database::table_name( "user" ),
			Auth_DBI_uid_field => "username",
			Auth_DBI_pwd_field => "passwd",
			Auth_DBI_grp_field => "groups",
			Auth_DBI_encrypted => "off" }, 
		priv => [ "user" ] }
};

######################################################################
# USER FIELDS
######################################################################

$self->{sitefields}->{user} = [
	{
		name=>"name",
		type=>"name",
		required=>1,
		editable=>1,
		visible=>1
	},
	{
		name=>"dept",
		type=>"text",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"org",
		type=>"text",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"address",
		type=>"longtext",
		displaylines=>"5",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"country",
		type=>"text",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"url",
		type=>"url",
		required=>0,
		editable=>1,
		visible=>1
	},
	{
		name=>"filter",
		type=>"subject",
		required=>0,
		editable=>1,
		visible=>1,
		multiple=>1
	}
];

$self->{sitefields}->{eprint} = [
	{
		name=>"abstract",
		type=>"longtext",
		displaylines=>"10",
		editable=>1,
		visible=>1
	},
	{
		name=>"altloc",
		type=>"url",
		displaylines=>"3",
		editable=>1,
		multiple=>1,
		visible=>1
	},
	{
		name=>"authors",
		type=>"name",
		editable=>1,
		visible=>1,
		multiple=>1
	},
	{
		name=>"chapter",
		type=>"text",
		editable=>1,
		visible=>1,
		maxlength=>5
	},
	{
		name=>"comments",
		type=>"longtext",
		editable=>1,
		displaylines=>"3",
		visible=>1
	},
	{
		name=>"commref",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"confdates",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"conference",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"confloc",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"department",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"editors",
		type=>"name",
		editable=>1,
		visible=>1,
		multiple=>1
	},
	{
		name=>"institution",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"ispublished",
		type=>"set",
		editable=>1,
		visible=>1,
		options=>[ "unpub","inpress","pub" ]
	},
	{
		name=>"keywords",
		type=>"longtext",
		editable=>1,
		displaylines=>2,
		visible=>1
	},
	{
		name=>"month",
		type=>"set",
		editable=>1,
		visible=>1,
		options=>[ "unspec","jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec" ]
	},
	{
		name=>"number",
		type=>"text",
		maxlength=>"6",
		editable=>1,
		visible=>1
	},
	{
		name=>"pages",
		type=>"pagerange",
		editable=>1,
		visible=>1
	},
	{
		name=>"pubdom",
		type=>"boolean",
		editable=>1,
		visible=>1
	},
	{
		name=>"publication",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"publisher",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"refereed",
		type=>"boolean",
		editable=>1,
		visible=>1
	},
	{
		name=>"referencetext",
		type=>"longtext",
		editable=>1,
		visible=>1,
		displaylines=>3
	},
	{
		name=>"reportno",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"thesistype",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"title",
		type=>"text",
		editable=>1,
		visible=>1
	},
	{
		name=>"volume",
		type=>"text",
		maxlength=>"6",
		editable=>1,
		visible=>1
	},
	{
		name=>"year",
		type=>"year",
		editable=>1,
		visible=>1
	}
];
	
$self->{sitetypes}->{eprint} = {
	"bookchapter"=>[
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
	"confpaper"=>[
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
	"confposter"=>[
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
	"techreport"=>[
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
	"journale"=>[
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
	"journalp"=>[
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
	"newsarticle"=>[
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
	"other"=>[
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
	"preprint"=>[
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
	"thesis"=>[
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

$self->{sitetypes}->{user} = { 
	Staff => [],
	User => []
};

######################################################################
#
#  Site Look and Feel
#
######################################################################

# Location of the root of the subject tree
#$EPrintSite::SiteInfo::server_subject_view_root = 
#	$EPrintSite::SiteInfo::server_subject_view_stem."ROOT.html";

# parameters to generate the HTML header with.
# TITLE will be set by the system as appropriate.
# See the CGI.pm manpage for more info ( man CGI ).

$self->{start_html_params}  = {
	-BGCOLOR=>"#ffffff",
	-FGCOLOR=>"#000000",
	-HEAD=>[ Link( {-rel=>'stylesheet',
			-type=>'text/css',
			-href=>'/eprints.css',
			-title=>'screen stylesheet',
			-media=>'screen'} ) ],
	-AUTHOR=>$self->{admin},
	-TOPMARGIN=>"0",
	-LEFTMARGIN=>"0",
	-MARGINWIDTH=>"0",
	-MARGINHEIGHT=>"0" };

# This is the HTML put at the top of every page. It will be put in the <BODY>,
#  so shouldn't include a <BODY> tag.
$self->{html_banner} = <<END;
<table border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td align="center" valign="top" bgcolor="#dddddd" fgcolor="white">
      <br>
      <a href="$self->{frontpage}"><IMG border="0" width="100" height="100" src="$self->{server_static}/images/logo_sidebar.gif" ALT="$self->{sitename}"></a>
    </td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderr.gif"></td>
    <td>
      &nbsp;&nbsp;&nbsp;&nbsp;
    </td>
    <td>
      <BR>
      <H1>TITLE_PLACEHOLDER</H1>
    </td>
  </tr>
  <tr>
    <td bgcolor="#dddddd" align="center" valign="top">
      <table border="0" cellpadding="0" cellspacing="0">
        <tr>
          <td align=center valign=top>
            <A HREF="$self->{frontpage}">Home</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_static}/information.html">About</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_subject_view_stem}"."ROOT.html">Browse</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_perl}/search">Search</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_static}/register.html">Register</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_perl}/users/subscribe">Subscriptions</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_perl}/users/home">Deposit\&nbsp;Items</A>\&nbsp;<BR><BR>
            <A HREF="$self->{server_static}/help">Help</A><BR><BR><BR><BR>
            <I><A HREF="$self->{server_perl}/setlang?langid=english">English</A></I><BR><BR>
            <I><A HREF="$self->{server_perl}/setlang?langid=french">Français</A></I><BR><BR>
            <I><A HREF="$self->{server_perl}/setlang?langid=dummy">Test Lang</A></I><BR><BR>
          </td>
        </tr>
      </table>
      <br>
    </td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderr.gif"></td>
    <td>
      &nbsp;&nbsp;&nbsp;&nbsp;
    </td>
    <td valign="top" width="95%">
<BR>
END

# This is the HTML put at the bottom of every page. Obviously, it should close
#  up any tags left open in html_banner.
$self->{html_tail} = <<END;
<BR>
<HR noshade size="2">
<address>
Contact site administrator at: <a href=\"mailto:$self->{admin}\">$self->{admin}</a>
</address>
<BR><BR>
    </td>
  </tr>
  <tr>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderb.gif"></td>
    <td background="http://lemur.ecs.soton.ac.uk/~cjg/eborderc.gif"></td>
  </tr>
</table>
END

#  E-mail signature, appended to every email sent by the software
$self->{signature} = <<END;
--
 $self->{sitename}
 $self->{frontpage}
 $self->{admin}

END

#  Default text to send a user when "bouncing" a submission back to their
#  workspace. It should leave some space for staff to give a reason.
$self->{default_bounce_reason} = <<END;
Unfortunately your eprint:

  _SUBMISSION_TITLE_

could not be accepted into $self->{sitename} as-is.


The eprint has been returned to your workspace. If you
visit your item depositing page you will be able to
edit your eprint, fix the problem and redeposit.

END

#  Default text to send a user when rejecting a submission outright.
$self->{default_delete_reason} = <<END;
Unfortunately your eprint:

  _SUBMISSION_TITLE_

could not be accepted into $self->{sitename}.



The eprint has been deleted.

END

#  Agreement text, for when user completes the depositing process.
#  Set to "undef" if you don't want it to appear.
$self->{deposit_agreement_text} = <<END;

<P><EM><STRONG>For work being deposited by its own author:</STRONG> 
In self-archiving this collection of files and associated bibliographic 
metadata, I grant $self->{sitename} the right to store 
them and to make them permanently available publicly for free on-line. 
I declare that this material is my own intellectual property and I 
understand that $self->{sitename} does not assume any 
responsibility if there is any breach of copyright in distributing these 
files or metadata. (All authors are urged to prominently assert their 
copyright on the title page of their work.)</EM></P>

<P><EM><STRONG>For work being deposited by someone other than its 
author:</STRONG> I hereby declare that the collection of files and 
associated bibliographic metadata that I am archiving at 
$self->{sitename}) is in the public domain. If this is 
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
$self->{simple_search_fields} =
[
	"title/abstract/keywords",
	"authors/editors",
	"publication",
	"year"
];

# Fields for an advanced user search
$self->{advanced_search_fields} =
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
$self->{subscription_fields} =
[
	"subjects",
	"refereed",
	"ispublished"
];



# Ways of ordering search results
$self->{order_methods}->{archive} =
{
	"byyear" 	=> \&eprint_cmp_by_year,
	"byyearoldest"	=> \&eprint_cmp_by_year_oldest_first,
	"byname"  	=> \&eprint_cmp_by_author,
	"bytitle" 	=> \&eprint_cmp_by_title 
};

# The default way of ordering a search result
#   (must be key to %eprint_order_methods)
$self->{default_order}->{archive} = "byname";

# How to order the articles in a "browse by subject" view.
$self->{subject_view_order} = \&eprint_cmp_by_author;

# Fields for a staff user search.
$self->{user_search_fields} =
[
	"name",
	"dept/org",
	"address/country",
	"groups",
	"email"
];

# Ways to order the results of a staff user search.
# cjg needs doing....
$self->{user_order_methods} =
{
	"by surname"                          => "name",
	"by joining date (most recent first)" => "joined DESC, name",
	"by joining date (oldest first)"      => "joined ASC, name",
	"by group"                            => "group, name "
};

# Default order for a staff user search (must be key to user_order_methods)
$self->{default_user_order} = "by surname";	

# How to display articles in "version of" and "commentary" threads.
#  See lib/Citation.pm for information on how to specify this.
$self->{thread_citation_specs} =
{
	"succeeds"   => "{title} (deposited {datestamp})",
	"commentary" => "{authors}. {title}. (deposited {datestamp})"
};

	return $self;
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

sub eprint_cmp_by_year
{
	return ( $_[1]->{year} <=> $_[0]->{year} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

sub eprint_cmp_by_year_oldest_first
{
	return ( $_[0]->{year} <=> $_[1]->{year} ) ||
		EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

sub eprint_cmp_by_author
{
	
	return EPrints::Name::cmp_names( $_[0]->{authors} , $_[1]->{authors} ) ||
		( $_[1]->{year} <=> $_[0]->{year} ) || # largest year first
		( $_[0]->{title} cmp $_[1]->{title} ) ;
}

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
		"the"=>1,
		"you"=>1,
		"for"=>1,
		"and"=>1 
};

# Words to always index, despite their length.
my $FREETEXT_ALWAYS_WORDS = {
		"ok"=>1 
};

# This map is used to convert ASCII characters over
# 127 to characters below 127, in the word index.
# This means that the word Fête is indexed as 'fete' and
# "fete" or "fête" will match it.
# There's no reason mappings have to be a single character.

my $FREETEXT_CHAR_MAPPING = {
"¡"=>"!",	"¢"=>"c",	"£"=>"L",	"¤"=>"o",	
"¥"=>"Y",	"¦"=>"|",	"§"=>"S",	"¨"=>"\"",	
"©"=>"(c)",	"ª"=>"a",	"«"=>"<<",	"¬"=>"-",	
"­"=>"-",	"®"=>"(R)",	"¯"=>"-",	"°"=>"o",	
"±"=>"+-",	"²"=>"2",	"³"=>"3",	"´"=>"'",	
"µ"=>"u",	"¶"=>"q",	"·"=>".",	"¸"=>",",	
"¹"=>"1",	"º"=>"o",	"»"=>">>",	"¼"=>"1/4",	
"½"=>"1/2",	"¾"=>"3/4",	"¿"=>"?",	"À"=>"A",	
"Á"=>"A",	"Â"=>"A",	"Ã"=>"A",	"Ä"=>"A",	
"Å"=>"A",	"Æ"=>"AE",	"Ç"=>"C",	"È"=>"E",	
"É"=>"E",	"Ê"=>"E",	"Ë"=>"E",	"Ì"=>"I",	
"Í"=>"I",	"Î"=>"I",	"Ï"=>"I",	"Ð"=>"D",	
"Ñ"=>"N",	"Ò"=>"O",	"Ó"=>"O",	"Ô"=>"O",	
"Õ"=>"O",	"Ö"=>"O",	"×"=>"x",	"Ø"=>"O",	
"Ù"=>"U",	"Ú"=>"U",	"Û"=>"U",	"Ü"=>"U",	
"Ý"=>"Y",	"Þ"=>"b",	"ß"=>"B",	"à"=>"a",	
"á"=>"a",	"â"=>"a",	"ã"=>"a",	"ä"=>"a",	
"å"=>"a",	"æ"=>"ae",	"ç"=>"c",	"è"=>"e",	
"é"=>"e",	"ê"=>"e",	"ë"=>"e",	"ì"=>"i",	
"í"=>"i",	"î"=>"i",	"ï"=>"i",	"ð"=>"d",	
"ñ"=>"n",	"ò"=>"o",	"ó"=>"o",	"ô"=>"o",	
"õ"=>"o",	"ö"=>"o",	"÷"=>"/",	"ø"=>"o",	
"ù"=>"u",	"ú"=>"u",	"û"=>"u",	"ü"=>"u",	
"ý"=>"y",	"þ"=>"B",	"ÿ"=>"y" };



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

sub extract_words
{
	my( $self , $text ) = @_;

	# convert acute's etc to their simple version using the map
	# from SiteInfo.
	my $mapped_chars = join( "", keys %{$FREETEXT_CHAR_MAPPING} );
	# escape [, ], \ and ^ because these mean something in a 
	# regexp charlist.
	$mapped_chars =~ s/\[\]\^\\/\\$&/g;
	# apply the map to $text
	$text =~ s/[$mapped_chars]/$FREETEXT_CHAR_MAPPING{$&}/g;
	
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
		if( $FREETEXT_NEVER_WORDS{lc $_} )
		{
			$ok = 0;
		}
		# Consult list of "always words". Words which should always
		# be indexed.	
		if( $FREETEXT_ALWAYS_WORDS{lc $_} )
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

sub eprint_short_title
{
	my( $self , $eprint ) = @_;
	
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

sub eprint_render_full
{
	my( $self , $eprint, $for_staff ) = @_;
	my $html = "";

	my $succeeds_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "succeeds" );
	my $commentary_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "commentary" );
	my $has_multiple_versions = $eprint->in_thread( $succeeds_field );

	# Citation
	$html .= "<P>";
	$html .= $eprint->{session}->{render}->render_eprint_citation(
		$eprint,
		1,
		0 );
	$html .= "</P>\n";

	# Available formats
	my @documents = $eprint->get_all_documents();
	
	$html .= "<TABLE BORDER=0 CELLPADDING=5><TR><TD VALIGN=TOP><STRONG>Full ".
		"text available as:</STRONG></TD><TD>";
	
	foreach (@documents)
	{
		my $description = EPrints::Document::format_name( $eprint->{session}, $_->{format} );
		$description = $_->{formatdesc}
			if( $_->{format} eq $EPrints::Document::OTHER );

		$html .= "<A HREF=\"".$_->url()."\">$description</A><BR>";
	}

	$html .= "</TD></TR></TABLE>\n";

	# Put in a message describing how this document has other versions
	# in the archive if appropriate
	if( $has_multiple_versions)
	{
		my $latest = $eprint->last_in_thread( $succeeds_field );

		if( $latest->{eprintid} eq $eprint->{eprintid} )
		{
			$html .= "<P ALIGN=CENTER><EM>This is the latest version of this ".
				"eprint.</EM></P>\n";
		}
		else
		{
			$html .= "<P ALIGN=CENTER><EM>There is a later version of this ".
				"eprint available: <A HREF=\"" . $latest->static_page_url() . 
				"\">Click here to view it.</A></EM></P>\n";
		}
	}		

	# Then the abstract
	$html .= "<H2>Abstract</H2>\n";
	$html .= "<P>$eprint->{abstract}</P>\n";
	
	$html .= "<P><TABLE BORDER=0 CELLPADDING=3>\n";
	
	# Keywords
	if( defined $eprint->{commref} && $eprint->{commref} ne "" )
	{
		$html .= "<TR><TD VALIGN=TOP><STRONG>Commentary on:</STRONG></TD><TD>".
			$eprint->{commref}."</TD></TR>\n";
	}

	# Keywords
	if( defined $eprint->{keywords} && $eprint->{keywords} ne "" )
	{
		$html .= "<TR><TD VALIGN=TOP><STRONG>Keywords:</STRONG></TD><TD>".
			$eprint->{keywords}."</TD></TR>\n";
	}

	# Comments:
	if( defined $eprint->{comments} && $eprint->{comments} ne "" )
	{
		$html .= "<TR><TD VALIGN=TOP><STRONG>Comments:</STRONG></TD><TD>".
			$eprint->{comments}."</TD></TR>\n";
	}

	# Subjects...
	$html .= "<TR><TD VALIGN=TOP><STRONG>Subjects:</STRONG></TD><TD>";

	my $subject_list = new EPrints::SubjectList( $eprint->{subjects} );
	my @subjects = $subject_list->get_subjects( $eprint->{session} );

	foreach (@subjects)
	{
		$html .= $eprint->{session}->{render}->subject_desc( $_, 1, 1, 0 );
		$html .= "<BR>\n";
	}

	# ID code...
	$html .= "</TD><TR>\n<TD VALIGN=TOP><STRONG>ID code:</STRONG></TD><TD>".
		$eprint->{eprintid}."</TD></TR>\n";

	# And who submitted it, and when.
	$html .= "<TR><TD VALIGN=TOP><STRONG>Deposited by:</STRONG></TD><TD>";
	my $user = new EPrints::User( $eprint->{session}, $eprint->{username} );
	if( defined $user )
	{
		$html .= "<A HREF=\"$eprint->{session}->{site}->{server_perl}/user?username=".
			$user->{username}."\">".$user->full_name()."</A>";
	}
	else
	{
		$html .= "INVALID USER";
	}

	if( $eprint->{table} eq $EPrints::Database::table_archive )
	{
		my $date_field = $eprint->{session}->{metainfo}->find_table_field( "eprint","datestamp" );
		$html .= " on ".$eprint->{session}->{render}->format_field(
			$date_field,
			$eprint->{datestamp} );
	}
	$html .= "</TD></TR>\n";

	# Alternative locations
	if( defined $eprint->{altloc} && $eprint->{altloc} ne "" )
	{
		$html .= "<TR><TD VALIGN=TOP><STRONG>Alternative Locations:".
			"</STRONG></TD><TD>";
		my $altloc_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "altloc" );
		$html .= $eprint->{session}->{render}->format_field(
			$altloc_field,
			$eprint->{altloc} );
		$html .= "</TD></TR>\n";
	}

	$html .= "</TABLE></P>\n";

	# If being viewed by a staff member, we want to show any suggestions for
	# additional subject categories
	if( $for_staff )
	{
		my $additional_field = 
			$eprint->{session}->{metainfo}->find_table_field( "eprint", "additional" );
		my $reason_field = $eprint->{session}->{metainfo}->find_table_field( "eprint", "reasons" );

		# Write suggested extra subject category
		if( defined $eprint->{additional} )
		{
			$html .= "<TABLE BORDER=0 CELLPADDING=3>\n";
			$html .= "<TR><TD><STRONG>".$additional_field->display_name().":</STRONG>".
				"</TD><TD>$eprint->{additional}</TD></TR>\n";
			$html .= "<TR><TD><STRONG>".$reason_field->display_name().":</STRONG>".
				"</TD><TD>$eprint->{reasons}</TD></TR>\n";

			$html .= "</TABLE>\n";
		}
	}
			
	# Now show the version and commentary response threads
	if( $has_multiple_versions )
	{
		$html .= "<h3>Available Versions of This Item</h3>\n";
		$html .= $eprint->{session}->{render}->write_version_thread(
			$eprint,
			$succeeds_field );
	}
	
	if( $eprint->in_thread( $commentary_field ) )
	{
		$html .= "<h3>Commentary/Response Threads</h3>\n";
		$html .= $eprint->{session}->{render}->write_version_thread(
			$eprint,
			$commentary_field );
	}

	return( $html );
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

my %CITATION_SPECS =
(
	"bookchapter" => "{authors} [({year}) ]<i>{title}</i>, in [{editors}, Eds. ][<i>{publication}</i>][, chapter {chapter}][, pages {pages}]. [{publisher}.]",
	"confpaper"   => "{authors} [({year}) ]{title}. In [{editors}, Eds. ][<i>Proceedings {conference}</i>][ <B>{volume}</B>][({number})][, pages {pages}][, {confloc}].",
	"confposter"  => "{authors} [({year}) ]{title}. In [{editors}, Eds. ][<i>Proceedings {conference}</i>][ <B>{volume}</B>][({number})][, pages {pages}][, {confloc}].",
	"techreport"  => "{authors} [({year}) ]{title}. Technical Report[ {reportno}][, {department}][, {institution}].",
	"journale"    => "{authors} [({year}) ]{title}. <i>{publication}</i>[ {volume}][({number})].",
	"journalp"    => "{authors} [({year}) ]{title}. <i>{publication}</i>[ {volume}][({number})][:{pages}].",
	"newsarticle" => "{authors} [({year}) ]{title}. In <i>{publication}</i>[, {volume}][({number})][ pages {pages}][, {publisher}].",
	"other"       => "{authors} [({year}) ]{title}.",
	"preprint"    => "{authors} [({year}) ]{title}.",
	"thesis"      => "{authors} [({year}) ]<i>{title}</i>. {thesistype},[ {department},][ {institution}]."
);

sub eprint_render_citation
{
	my( $self , $eprint, $html ) = @_;
	
	my $citation_spec = $CITATION_SPECS{$eprint->{type}};

	return( EPrints::Citation::render_citation( $eprint->{session},
	                                            $citation_spec,
	                                            $eprint,
	                                            $html ) );
}


######################################################################
#
# $name = user_display_name( $user )
#
#  Return the user's name in a form appropriate for display.
#
######################################################################

sub user_display_name
{
	my( $self , $user ) = @_;

	# If no surname, just return the username
	return( "User $user->{username}" ) if( !defined $user->{name} ||
	                                       $user->{name} eq "" );

	return( EPrints::Name::format_name( $user->{name}, 1 ) );
}


######################################################################
#
# $html = user_render_full( $user, $public )
#
#  Render the full record for $user. If $public, only public fields
#  should be shown.
#
######################################################################

sub user_render_full
{
	my( $self , $user, $public ) = @_;

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
			if( !$public || $field->{visible} )
			{
				$html .= "<TR><TD VALIGN=TOP><STRONG>".$field->display_name().
					"</STRONG></TD><TD>";

				if( defined $user->{$field->{name}} )
				{
					$html .= $user->{session}->{render}->format_field(
						$field,
						$user->{$field->{name}} );
				}

				$html .= "</TD></TR>\n";
			}
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

sub session_init
{
	my( $self , $session, $offline ) = @_;
}


######################################################################
#
# session_close( $session )
#
#  Invoked at the close of each session. Here you should clean up
#  anything you did in session_init().
#
######################################################################

sub session_close
{
	my( $self , $session ) = @_;
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

sub update_submitted_eprint
{
	my( $self , $eprint ) = @_;
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

sub update_archived_eprint
{
	my( $self , $eprint ) = @_;
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

sub oai_list_metadata_formats
{
	my( $self , $eprint ) = @_;
	
	# This returns the list of all metadata formats, suitable if we
	# can export any of those metadata format for any record.
	return( keys %{$eprint->{session}->{site}->{oai_metadata_formats}} );
}


######################################################################
#
# %metadata = oai_get_eprint_metadata( $eprint, $format )
#
#  Return metadata for the given eprint in the given format.
#  The value of each key should be either a scalar value (string)
#  indicating the value for that string, e.g:
#
#   "title" => "Full Title of the Paper"
#
#  or it can be a reference to a list of scalars, indicating multiple
#  values:
#
#   "author" => [ "J. R. Hartley", "J. N. Smith" ]
#
#  it can also be nested:
#
#   "nested" => [
#                  {
#                    "nested_key 1" => "nested value 1",
#                    "nested_key 2" => "nested value 2"
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

sub oai_get_eprint_metadata
{
	my( $self , $eprint, $format ) = @_;

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
		my $subject_list = new EPrints::SubjectList( $eprint->{subjects} );
		my @subjects = $subject_list->get_subjects( $eprint->{session} );
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
				unspec => "01",
				jan => "01",
				feb => "02",
				mar => "03",
				apr => "04",
				may => "05",
				jun => "06",
				jul => "07",
				aug => "08",
				sep => "09",
				oct => "10",
				nov => "11",
				dec => "12" );

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


sub oai_write_eprint_metadata
{
	my( $self , $eprint, $format, $writer ) = @_;

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

sub validate_user_field
{
	my( $self , $field, $value ) = @_;

	my $problem;

	# CHECKS IN HERE

	# Ensure that a URL is valid (i.e. has the initial scheme like http:)
	if( $field->{type} eq "url" && defined $value && $value ne "" )
	{
		$problem = "The URL given for ".$field->display_name()." is invalid.  ".
			"Have you included the initial <STRONG>http://</STRONG>?"
			if( $value !~ /^\w+:/ );
	}

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

sub validate_eprint_field
{
	my( $self , $field, $value );

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
#  If you want to do anything here, you'll probably want to use the
#  EPrints::SubjectList class. Do something like:
#
#   my $list = EPrints::SubjectList->new( $value );
#   my @subject_tags = $list->get_tags();
#
######################################################################

sub validate_subject_field
{
	my( $self , $field, $value ) = @_;

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

sub validate_document
{
	my( $self , $document, $problems ) = @_;

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

sub validate_eprint
{
	my( $self , $eprint, $problems ) = @_;

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

sub validate_eprint_meta
{
	my( $self , $eprint, $problems ) = @_;

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


1;
