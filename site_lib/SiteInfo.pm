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


#
# General site information
#

$EPrintSite::SiteInfo::sitename = "CogPrints";
$EPrintSite::SiteInfo::automail = "auto\@eprints.org";
$EPrintSite::SiteInfo::admin = "rob\@soton.ac.uk";
$EPrintSite::SiteInfo::local_root = "/opt/eprints";

$EPrintSite::SiteInfo::server_static = "http://dibble.ecs.soton.ac.uk";
$EPrintSite::SiteInfo::server_perl = "http://dibble.ecs.soton.ac.uk/cgi";
$EPrintSite::SiteInfo::frontpage = "http://dibble.ecs.soton.ac.uk";

$EPrintSite::SiteInfo::local_html_root = "$EPrintSite::SiteInfo::local_root/html";
$EPrintSite::SiteInfo::static_html_root = "$EPrintSite::SiteInfo::local_root/static";
$EPrintSite::SiteInfo::local_document_root = "$EPrintSite::SiteInfo::local_html_root/documents";
$EPrintSite::SiteInfo::server_document_root = "$EPrintSite::SiteInfo::server_static/documents";

$EPrintSite::SiteInfo::local_subject_view_stem = "$EPrintSite::SiteInfo::local_html_root/view-";
$EPrintSite::SiteInfo::server_subject_view_stem = "$EPrintSite::SiteInfo::server_static/view-";

$EPrintSite::SiteInfo::eprint_id_stem = "cog";

# If 1, users can remove their own submissions from the archive.
$EPrintSite::SiteInfo::allow_user_removal_request = 1;



# Fields that can be searched in simple, advanced and staff user searches
@EPrintSite::SiteInfo::simple_search_fields =
(
	"title/abstract/keywords",
	"authors",
	"publication",
	"year"
);

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

@EPrintSite::SiteInfo::subscription_fields =
(
	"subjects",
	"refereed",
	"ispublished"
);

%EPrintSite::SiteInfo::eprint_order_methods =
(
	"by year (most recent first)" => "year DESC, authors, title",
	"by year (oldest first)"      => "year ASC, authors, title",
	"by author's name"            => "authors, year DESC, title",
	"by title"                    => "title, authors, year DESC"
);

$EPrintSite::SiteInfo::eprint_default_order = "by author's name";

$EPrintSite::SiteInfo::subject_view_order = "authors, year DESC, title";

@EPrintSite::SiteInfo::user_search_fields =
(
	"name",
	"dept/org",
	"address/country",
	"groups",
	"email"
);

%EPrintSite::SiteInfo::user_order_methods =
(
	"by surname"                          => "name",
	"by joining date (most recent first)" => "joined DESC, name",
	"by joining date (oldest first)"      => "joined ASC, name",
	"by group"                            => "group, name "
);

$EPrintSite::SiteInfo::default_user_order = "by surname";	

%EPrintSite::SiteInfo::thread_citation_specs =
(
	"succeeds"   => "{title} ({datestamp})",
	"commentary" => "{authors}. {title}. ({datestamp})"
);



#
# Hopefully, these won't need changing in most instances
#

$EPrintSite::SiteInfo::user_meta_config = "$EPrintSite::SiteInfo::local_root/cfg/metadata.user";
$EPrintSite::SiteInfo::template_author_intro = "$EPrintSite::SiteInfo::local_root/cfg/template.author-intro";
$EPrintSite::SiteInfo::template_reader_intro = "$EPrintSite::SiteInfo::local_root/cfg/template.reader-intro";
$EPrintSite::SiteInfo::template_fail_reply = "$EPrintSite::SiteInfo::local_root/cfg/template.fail-reply";
$EPrintSite::SiteInfo::template_fail_user = "$EPrintSite::SiteInfo::local_root/cfg/template.fail-user";
$EPrintSite::SiteInfo::template_change_email = "$EPrintSite::SiteInfo::local_root/cfg/template.change-email";
$EPrintSite::SiteInfo::site_eprint_fields = "$EPrintSite::SiteInfo::local_root/cfg/metadata.eprint-fields";
$EPrintSite::SiteInfo::site_eprint_types = "$EPrintSite::SiteInfo::local_root/cfg/metadata.eprint-types";
$EPrintSite::SiteInfo::subject_config = "$EPrintSite::SiteInfo::local_root/cfg/subjects";


# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$EPrintSite::SiteInfo::diskspace_error_threshold = 20480;

# If ever the amount of free space drops below this threshold, the
# archive administrator is sent a warning email.
$EPrintSite::SiteInfo::diskspace_warn_threshold = 102400;

$EPrintSite::SiteInfo::log_path = "$EPrintSite::SiteInfo::local_root/logs";

$EPrintSite::SiteInfo::sendmail = "/usr/lib/sendmail -oi -t -odb";


@EPrintSite::SiteInfo::supported_archive_formats =
(
	"ZIP",
	"TARGZ"
);

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

%EPrintSite::SiteInfo::archive_names =
(
	"ZIP"   => "ZIP Archive [.zip]",
	"TARGZ" => "Compressed TAR archive [.tar.Z, .tar.gz]"
);

%EPrintSite::SiteInfo::archive_extensions =
(
	"ZIP"   => ".zip",
	"TARGZ" => ".tar.gz"
);

#
# Will we allow storage of formats not explicitly supported? (0/1)
#
$EPrintSite::SiteInfo::allow_arbitrary_formats = 1;

#
# Supported document storage formats
#
#  Given as an array and a hash value, so that some order of preference
#  can be imposed. Note that the hash includes an expansion for the "other"
#  type
#
@EPrintSite::SiteInfo::supported_formats =
(
	"HTML",
	"PDF",
	"PS",
	"ASCII"
);

%EPrintSite::SiteInfo::supported_format_names = 
(
	"HTML"                     => "Hypertext Markup Language (HTML)",
	"PDF"                      => "Adobe Portable Document Format",
	"PS"                       => "Adobe Postscript",
	"ASCII"                    => "Plain ASCII Text"
);

#
# AT LEAST one of the following formats will be required. Include
# $EPrints::Document::other as well as those in your list if you want to
# allow any format. Leave this list empty if you don't want to require that
# full text is deposited.
#
@EPrintSite::SiteInfo::required_formats =
(
	"HTML",
	"PDF",
	"PS",
	"ASCII"
);
	
#
#  Command to run to grab URLs. Should:
#
#  - Produce no output
#  - only follow relative links to same or subdirectory
#  - chop of the number of top directories _CUTDIRS_, so a load of pointlessly
#    deep directories aren't created
#  - start grabbing at _URL_
#
$EPrintSite::SiteInfo::wget_command =
	"wget -r -L -q -m -nH -np --execute=\"robots=off\" --cut-dirs=_CUTDIRS_ _URL_";


#
# Database information
#

$EPrintSite::SiteInfo::database = "eprints";
$EPrintSite::SiteInfo::username = "eprints";
$EPrintSite::SiteInfo::password = "eprints";


#
# Standard problem stubs
#

$EPrintSite::SiteInfo::default_bounce_reason =
"Unfortunately your submission:\n\n".
"  _SUBMISSION_TITLE_\n\n".
"could not be accepted into $EPrintSite::SiteInfo::sitename as-is.\n\n\n\n".
"The submission has been returned to your workspace. If you\n".
"visit your author area you will be able to edit your\n".
"submission, fix the problem and re-submit.\n";

$EPrintSite::SiteInfo::default_delete_reason =
"Unfortunately your submission:\n\n".
"  _SUBMISSION_TITLE_\n\n".
"could not be accepted into $EPrintSite::SiteInfo::sitename.\n\n\n\n".
"The submission has been deleted.\n";

#
#  HTML look and feel
#
$EPrintSite::SiteInfo::html_fgcolor = "black";
$EPrintSite::SiteInfo::html_bgcolor = "white";

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
    <td align=\"center\" valign=\"top\" bgcolor=\"#dddddd\" fgcolor=\"white\">
      <table border=0 cellpadding=0 cellspacing=0>
        <tr>
          <td align=center valign=top bgcolor=#dddddd fgcolor=white>
		      <BR>
            <A HREF=\"$EPrintSite::SiteInfo::frontpage\">Home</A>\&nbsp;<BR><BR>
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


#<TABLE WIDTH=\"100\%\" CELLPADDING=0 CELLSPACING=0 BORDER=0>
#   <TR>
#      <TD WIDTH=\"100\%\" ALIGN=\"CENTER\" VALIGN=\"MIDDLE\">
#         <H1>TITLE_PLACEHOLDER</H1>
#      </TD>
#      <TD ROWSPAN=2>
#         <A HREF=\"$EPrintSite::SiteInfo::frontpage\"><IMG SRC=$EPrintSite::SiteInfo::server_static/images/logo_small.jpg ALT=$EPrintSite::SiteInfo::sitename BORDER=0></A>
#      </TD>
#   </TR>
#   <TR>
#      <TD VALIGN=BOTTOM>
#         <TABLE BORDER=0 WIDTH=\"100\%\">
#            <TR>
#               <TD>&nbsp;<A HREF=\"$EPrintSite::SiteInfo::frontpage\">Home</A>&nbsp;</TD>
#               <TD>&nbsp;<A HREF=\"$EPrintSite::SiteInfo::frontpage/cgi/author/home\">Author&nbsp;Area</A>&nbsp;</TD>
#               <TD WIDTH=\"100\%\">&nbsp;</TD>
#            </TR>
#         </TABLE>
#      </TD>
#   </TR>
#</TABLE>\n";

$EPrintSite::SiteInfo::html_tail = "<BR>
<HR>

<a href=\"http://www.ukoln.ac.uk/services/elib/\"><img src=\"$EPrintSite::SiteInfo::server_static/images/logo_elib.gif\" alt=\"Elib logo\" border=0 hspace=5 vspace=5 align=\"left\"></a>
<p>The <strong>CogPrints</strong> project is funded by the <a href=\"http://www.jisc.ac.uk/\">Joint Information Systems Committee (JISC)</a> of the Higher Education Funding Councils, as part of its <a href=\"http://www.ukoln.ac.uk/services/elib/\">Electronic Libraries (eLib) Programme</a>.<br clear=\"left\"></p>

<HR>
<address>
Contact site administrator at: <a href=\"mailto:rob\@soton.ac.uk\">rob\@soton.ac.uk</a>
</address>

    </td>
  </tr>
</table>
";


#
#  E-mail signature
#

$EPrintSite::SiteInfo::signature =
"--
 $EPrintSite::SiteInfo::sitename EPrint Archive
 $EPrintSite::SiteInfo::frontpage
 $EPrintSite::SiteInfo::admin\n";


#
#  For Open Archives software
#

# Domain the software is running in
$EPrintSite::SiteInfo::domain = "dibble.ecs.soton.ac.uk";
# Port the perl server is running on
$EPrintSite::SiteInfo::server_perl_port = "80";
# Standard time zone
$EPrintSite::SiteInfo::standard_time_zone = "GMT";
# Daylight savings time zone
$EPrintSite::SiteInfo::daylight_savings_time_zone = "BST";


1; # For use/require success
