######################################################################
#
#  Site Information
#
#   Constants and information about the local EPrints site
#   *PATHS SHOULD NOT END WITH SLASHES, LEAVE THEM OUT*
#
######################################################################
#
#  01/10/99 - Created by Robert Tansley
#  $Id$
#
######################################################################

package EPrintSite::SiteInfo;

use EPrints::Document;

use strict;


######################################################################
#
#  General site information
#
######################################################################

# Name for the site
$EPrintSite::SiteInfo::sitename = "CogPrints";

# E-mail address for automatically processed mail
$EPrintSite::SiteInfo::automail = "auto\@eprints.org";

# E-mail address for human-read administration mail
$EPrintSite::SiteInfo::admin = "rob\@soton.ac.uk";

# Root of EPrint installation on the machine
$EPrintSite::SiteInfo::local_root = "/opt/eprints";

# Host the machine is running on
$EPrintSite::SiteInfo::host = "dibble.ecs.soton.ac.uk";

# Stem for local ID codes
$EPrintSite::SiteInfo::eprint_id_stem = "cog";

# If 1, users can request the removal of their submissions from the archive
$EPrintSite::SiteInfo::allow_user_removal_request = 1;


######################################################################
#
#  Site information that shouldn't need changing
#
######################################################################

# Server of static HTML + images
$EPrintSite::SiteInfo::server_static = "http://$EPrintSite::SiteInfo::host";

# Mod_perl script server
$EPrintSite::SiteInfo::server_perl = "$EPrintSite::SiteInfo::host/perl";

# Site "home page" address
$EPrintSite::SiteInfo::frontpage = "$EPrintSite::SiteInfo::server_static/";

# Local directory holding HTML files read by the web server
$EPrintSite::SiteInfo::local_html_root = "$EPrintSite::SiteInfo::local_root/html";

# Local directory with the content of static web pages (to be given site border)
$EPrintSite::SiteInfo::static_html_root = "$EPrintSite::SiteInfo::local_root/static";

# Local directory containing the uploaded document file hierarchy
$EPrintSite::SiteInfo::local_document_root = "$EPrintSite::SiteInfo::local_html_root/documents";

# Corresponding URL of document file hierarchy
$EPrintSite::SiteInfo::server_document_root = "$EPrintSite::SiteInfo::server_static/documents";

# Local stem for HTML files generated for "browse by subject"
$EPrintSite::SiteInfo::local_subject_view_stem = "$EPrintSite::SiteInfo::local_html_root/view-";

# Corresponding URL stem for "browse by subject" HTML files
$EPrintSite::SiteInfo::server_subject_view_stem = "$EPrintSite::SiteInfo::server_static/view-";

# Local path of perl scripts
$EPrintSite::SiteInfo::local_perl_root = "$EPrintSite::SiteInfo::local_root/cgi";

# Paths of configuration files
$EPrintSite::SiteInfo::user_meta_config = "$EPrintSite::SiteInfo::local_root/cfg/metadata.user";
$EPrintSite::SiteInfo::template_author_intro = "$EPrintSite::SiteInfo::local_root/cfg/template.author-intro";
$EPrintSite::SiteInfo::template_reader_intro = "$EPrintSite::SiteInfo::local_root/cfg/template.reader-intro";
$EPrintSite::SiteInfo::template_fail_reply = "$EPrintSite::SiteInfo::local_root/cfg/template.fail-reply";
$EPrintSite::SiteInfo::template_fail_user = "$EPrintSite::SiteInfo::local_root/cfg/template.fail-user";
$EPrintSite::SiteInfo::template_change_email = "$EPrintSite::SiteInfo::local_root/cfg/template.change-email";
$EPrintSite::SiteInfo::site_eprint_fields = "$EPrintSite::SiteInfo::local_root/cfg/metadata.eprint-fields";
$EPrintSite::SiteInfo::site_eprint_types = "$EPrintSite::SiteInfo::local_root/cfg/metadata.eprint-types";
$EPrintSite::SiteInfo::subject_config = "$EPrintSite::SiteInfo::local_root/cfg/subjects";



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
@EPrintSite::SiteInfo::simple_search_fields =
(
	"title/abstract/keywords",
	"authors",
	"publication",
	"year"
);

# Fields for an advanced user search
@EPrintSite::SiteInfo::advanced_search_fields =
(
	"title",
	"authors",
	"abstract",
	"keywords",
	"subjects",
	"type",
	"conference",
	"department",
	"editors",
	"institution",
	"ispublished",
	"refereed",
	"publication",
	"year"
);

# Fields used for specifying a subscription
@EPrintSite::SiteInfo::subscription_fields =
(
	"subjects",
	"refereed",
	"ispublished"
);

# Ways of ordering search results
%EPrintSite::SiteInfo::eprint_order_methods =
(
	"by year (most recent first)" => "year DESC, authors, title",
	"by year (oldest first)"      => "year ASC, authors, title",
	"by author's name"            => "authors, year DESC, title",
	"by title"                    => "title, authors, year DESC"
);

# The default way of ordering a search result
#   (must be key to %eprint_order_methods)
$EPrintSite::SiteInfo::eprint_default_order = "by author's name";

# How to order the articles in a "browse by subject" view.
$EPrintSite::SiteInfo::subject_view_order = "authors, year DESC, title";

# Fields for a staff user search.
@EPrintSite::SiteInfo::user_search_fields =
(
	"name",
	"dept/org",
	"address/country",
	"groups",
	"email"
);

# Ways to order the results of a staff user search.
%EPrintSite::SiteInfo::user_order_methods =
(
	"by surname"                          => "name",
	"by joining date (most recent first)" => "joined DESC, name",
	"by joining date (oldest first)"      => "joined ASC, name",
	"by group"                            => "group, name "
);

# Default order for a staff user search (must be key to user_order_methods)
$EPrintSite::SiteInfo::default_user_order = "by surname";	

# How to display articles in "version of" and "commentary" threads.
#  See lib/Citation.pm for information on how to specify this.
%EPrintSite::SiteInfo::thread_citation_specs =
(
	"succeeds"   => "{title} ({datestamp})",
	"commentary" => "{authors}. {title}. ({datestamp})"
);


######################################################################
#
#  Site Look and Feel
#
######################################################################

# Foreground and background colours for every page
$EPrintSite::SiteInfo::html_fgcolor = "black";
$EPrintSite::SiteInfo::html_bgcolor = "white";

# This is the HTML put at the top of every page. It will be put in the <BODY>,
#  so shouldn't include a <BODY> tag.
$EPrintSite::SiteInfo::html_banner = "
<table border=0 cellpadding=0 cellspacing=0>
  <tr>
    <td align=\"center\" valign=\"top\" bgcolor=\"#dddddd\" fgcolor=\"white\">
      <a href=\"$EPrintSite::SiteInfo::frontpage\"><img border=0 src=$EPrintSite::SiteInfo::server_static/images/logo_small.gif ALT=\"$EPrintSite::SiteInfo::sitename\"></a>
    </td>
    <td width=\"100\%\" colspan=2 align=center valign=\"middle\" bgcolor=\"white\" fgcolor=\"black\">
      <H1>TITLE_PLACEHOLDER</H1>
    </td>
  </tr>

  <tr>
    <td align=\"center\" valign=\"top\" bgcolor=\"#dddddd\">
      <table border=0 cellpadding=0 cellspacing=0>
        <tr>
          <td align=center valign=top bgcolor=#dddddd>
		      <BR>
            <A HREF=\"$EPrintSite::SiteInfo::frontpage\">Home</A>\&nbsp;<BR><BR>
            <A HREF=\"$EPrintSite::SiteInfo::server_static/information.html\">About</A>\&nbsp;<BR><BR>
            <A HREF=\"$EPrintSite::SiteInfo::server_subject_view_stem"."ROOT.html\">Browse</A>\&nbsp;<BR><BR>
            <A HREF=\"$EPrintSite::SiteInfo::server_perl/search\">Search</A>\&nbsp;<BR><BR>
            <A HREF=\"$EPrintSite::SiteInfo::server_static/register.html\">Registrations</A>\&nbsp;<BR><BR>
            <A HREF=\"$EPrintSite::SiteInfo::server_perl/reader/subscribe\">Subscriptions</A>\&nbsp;<BR><BR>
            <A HREF=\"$EPrintSite::SiteInfo::server_perl/author/home\">Author\&nbsp;Area</A>\&nbsp;<BR><BR>
            <A HREF=\"$EPrintSite::SiteInfo::server_static/help\">Help</A>
          </td>
        </tr>
      </table>
    </td>

    <td valign=top>
      \&nbsp;\&nbsp;\&nbsp;\&nbsp;
    </td>

    <td valign=top width=\"100%\">
<BR><BR>\n";

# This is the HTML put at the bottom of every page. Obviously, it should close
#  up any tags left open in html_banner.
$EPrintSite::SiteInfo::html_tail = "<BR>
<HR>

<a href=\"http://www.ukoln.ac.uk/services/elib/\"><img src=\"$EPrintSite::SiteInfo::server_static/images/logo_elib.gif\" alt=\"Elib logo\" border=0 hspace=5 vspace=5 align=\"left\"></a>
<p>The <strong>CogPrints</strong> project is funded by the <a href=\"http://www.jisc.ac.uk/\">Joint Information Systems Committee (JISC)</a> of the Higher Education Funding Councils, as part of its <a href=\"http://www.ukoln.ac.uk/services/elib/\">Electronic Libraries (eLib) Programme</a>.<br clear=\"left\"></p>

<HR>
<address>
Contact site administrator at: <a href=\"mailto:$EPrintSite::SiteInfo::admin\">$EPrintSite::SiteInfo::admin</a>
</address>

    </td>
  </tr>
</table>
";

#  E-mail signature, appended to every email sent by the software
$EPrintSite::SiteInfo::signature =
"--
 $EPrintSite::SiteInfo::sitename EPrint Archive
 $EPrintSite::SiteInfo::frontpage
 $EPrintSite::SiteInfo::admin\n";

#  Default text to send a user when "bouncing" a submission back to their
#  workspace. It should leave some space for staff to give a reason.
$EPrintSite::SiteInfo::default_bounce_reason =
"Unfortunately your submission:\n\n".
"  _SUBMISSION_TITLE_\n\n".
"could not be accepted into $EPrintSite::SiteInfo::sitename as-is.\n\n\n\n".
"The submission has been returned to your workspace. If you\n".
"visit your author area you will be able to edit your\n".
"submission, fix the problem and re-submit.\n";

#  Default text to send a user when rejecting a submission outright.
$EPrintSite::SiteInfo::default_delete_reason =
"Unfortunately your submission:\n\n".
"  _SUBMISSION_TITLE_\n\n".
"could not be accepted into $EPrintSite::SiteInfo::sitename.\n\n\n\n".
"The submission has been deleted.\n";


######################################################################
#
#  Document file upload information
#
######################################################################

# Supported document storage formats, given as an array and a hash value,
#  so that some order of preference can be imposed.
@EPrintSite::SiteInfo::supported_formats =
(
	"HTML",
	"PDF",
	"PS",
	"ASCII"
);

%EPrintSite::SiteInfo::supported_format_names = 
(
	"HTML"                     => "HTML",
	"PDF"                      => "Adobe PDF",
	"PS"                       => "Postscript",
	"ASCII"                    => "Plain ASCII Text"
);

# AT LEAST one of the following formats will be required. Include
# $EPrints::Document::other as well as those in your list if you want to
# allow any format. Leave this list empty if you don't want to require that
# full text is deposited.
@EPrintSite::SiteInfo::required_formats =
(
	"HTML",
	"PDF",
	"PS",
	"ASCII"
);

#  If 1, will allow non-listed formats to be uploaded.
$EPrintSite::SiteInfo::allow_arbitrary_formats = 1;

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$EPrintSite::SiteInfo::diskspace_error_threshold = 20480;

# If ever the amount of free space drops below this threshold, the
# archive administrator is sent a warning email. In kilobytes.
$EPrintSite::SiteInfo::diskspace_warn_threshold = 102400;

# A list of compressed/archive formats that are accepted
@EPrintSite::SiteInfo::supported_archive_formats =
(
	"ZIP",
	"TARGZ"
);

# Command lines to execute to extract files from each type of archive.
# Note that archive extraction programs should not ever do any prompting,
# and should be SILENT whatever the error.  _DIR_ will be replaced with the 
# destination dir, and _ARC_ with the full pathname of the .zip. (Each
# occurence will be replaced if more than one of each.) Make NO assumptions
# about which dir the command will be run in. Exit code is assumed to be zero
# if everything went OK, non-zero in the case of any error.
%EPrintSite::SiteInfo::archive_extraction_commands =
(
	"ZIP"   => "/usr/bin/unzip 1>/dev/null 2>\&1 -qq -o -d _DIR_ _ARC_",
	"TARGZ" => "gunzip -c < _ARC_ 2>/dev/null | /bin/tar xf - -C _DIR_ >/dev/null 2>\&1"
);

# Displayable names for the compressed/archive formats.
%EPrintSite::SiteInfo::archive_names =
(
	"ZIP"   => "ZIP Archive [.zip]",
	"TARGZ" => "Compressed TAR archive [.tar.Z, .tar.gz]"
);

# The extensions to give the temporary uploaded file for each format.
%EPrintSite::SiteInfo::archive_extensions =
(
	"ZIP"   => ".zip",
	"TARGZ" => ".tar.gz"
);

#  Command to run to grab URLs. Should:
#  - Produce no output
#  - only follow relative links to same or subdirectory
#  - chop of the number of top directories _CUTDIRS_, so a load of pointlessly
#    deep directories aren't created
#  - start grabbing at _URL_
#
$EPrintSite::SiteInfo::wget_command =
	"wget -r -L -q -m -nH -np --execute=\"robots=off\" --cut-dirs=_CUTDIRS_ _URL_";


######################################################################
#
#  Miscellaneous
#
######################################################################

# Command for sending mail
$EPrintSite::SiteInfo::sendmail = "/usr/lib/sendmail -oi -t -odb";

# Database information: Since we hold the password here unencrypted, this
# file should have suitable strict read permissions
$EPrintSite::SiteInfo::database = "eprints";
$EPrintSite::SiteInfo::username = "eprints";
$EPrintSite::SiteInfo::password = "eprints";


######################################################################
#
#  Open Archives interoperability
#
######################################################################

# Site specific **UNIQUE** archive identifier.
# See http://www.openarchives.org/sfc/sfc_archives.htm for existing identifiers.
$EPrintSite::SiteInfo::archive_identifier = "cogprints";
# Domain the software is running in
$EPrintSite::SiteInfo::domain = $EPrintSite::SiteInfo::host;
# Port the perl server is running on
$EPrintSite::SiteInfo::server_perl_port = "80";
# Standard time zone
$EPrintSite::SiteInfo::standard_time_zone = "GMT";
# Daylight savings time zone
$EPrintSite::SiteInfo::daylight_savings_time_zone = "BST";


1; # For use/require success
