######################################################################
#
#  Site Specific Routines
#
#   Routines for handling operations that will vary from site to site
#
######################################################################
#
#  06/01/00 - Created by Robert Tansley
#  $Id$
#
######################################################################

package EPrintSite::SiteRoutines;

use EPrints::Citation;
use EPrints::EPrint;
use EPrints::User;
use EPrints::Session;
use EPrints::Subject;
use EPrints::SubjectList;
use EPrints::Name;

use strict;
use diagnostics;


# Specs for rendering citations.

%EPrints::SiteRoutines::citation_specs =
(
	"bookchapter" => "{authors} [({year}) ]<i>{title}</i>[, in <i>{publication}</i>][ ,chapter {chapter}][, pages {pages}]. [{publisher}.]",
	"confpaper"   => "{authors} [({year}) ]{title}. In [{editors}, Eds. ] [<i>Proceedings {conference}.</i>][ <B>{volume}</B>][({number})][, pages {pages}][, {confloc}].",
	"confposter"  => "{authors} [({year}) ]{title}. In [{editors}, Eds. ] [<i>Proceedings {conference}.</i>][ <B>{volume}</B>][({number})][, pages {pages}][, {confloc}].",
	"techreport"  => "{authors} [({year}) ]{title}. Technical Report[ {reportno}][, {department}][, {institution}].",
	"journale"    => "{authors} [({year}) ]{title}. <i>{publication}</i>[ {volume}][({number})].",
	"journalp"    => "{authors} [({year}) ]{title}. <i>{publication}</i>[ {volume}][({number})][:{pages}].",
	"newsarticle" => "{authors} [({year}) ]{title}. In <i>{publication}</i>[, {volume}][({number})][ pages {pages}][, {publisher}].",
	"other"       => "{authors} [({year}) ]{title}.",
	"preprint"    => "{authors} [({year}) ]{title}.",
	"thesis"      => "{authors} [({year}) ]<i>{title}</i>. {thesistype},[ {department},][ {institution}]."
);

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
	my( $class, $eprint ) = @_;
	
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
# $title = eprint_render_full( $eprint )
#
#  Return HTML for rendering an EPrint
#
######################################################################

sub eprint_render_full
{
	my( $class, $eprint ) = @_;

	# Start with a citation
	my $html = "<P>";
	$html .= $eprint->{session}->{render}->render_eprint_citation(
		$eprint,
		1,
		0 );
	$html .= "</P>\n";

	# Then the abstract
	$html .= "<H2>Abstract</H2>\n";
	$html .= "<P>$eprint->{abstract}</P>\n";
	
	$html .= "<P><TABLE BORDER=0 CELLPADDING=3>\n";
	
	# Keywords
	if( defined $eprint->{keywords} && $eprint->{keywords} ne "" )
	{
		$html .= "<TD VALIGN=TOP><STRONG>Keywords:</STRONG></TD><TD>".
			$eprint->{keywords}."</TD></TR>\n";
	}

	# Comments:
	if( defined $eprint->{comments} && $eprint->{comments} ne "" )
	{
		$html .= "<TD VALIGN=TOP><STRONG>Comments:</STRONG></TD><TD>".
			$eprint->{comments}."</TD></TR>\n";
	}

	# Subjects...
	$html .= "<TD VALIGN=TOP><STRONG>Subjects:</STRONG></TD><TD>";

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
	$html .= "<TD VALIGN=TOP><STRONG>Submitted by:</STRONG></TD><TD>";
	my $user = new EPrints::User( $eprint->{session}, $eprint->{username} );
	if( defined $user )
	{
		$html .= "<A HREF=\"$EPrints::SiteInfo::server_perl/cgi/user?username=".
			$user->{username}."\">".$user->full_name()."</A>";
	}
	else
	{
		$html .= "INVALID USER";
	}

	my $date_field = EPrints::MetaInfo->find_eprint_field( "datestamp" );
	$html .= " on ".$eprint->{session}->{render}->format_field(
		$date_field,
		$eprint->{datestamp} );
	$html .= "</TD></TR>\n";

	# Alternative locations
	if( defined $eprint->{altloc} && $eprint->{altloc} ne "" )
	{
		$html .= "</TD></TR>\n<TD VALIGN=TOP><STRONG>Alternative Locations:".
			"</STRONG></TD><TD>";
		my $altloc_field = EPrints::MetaInfo->find_eprint_field( "altloc" );
		$html .= $eprint->{session}->{render}->format_field(
			$altloc_field,
			$eprint->{altloc} );
		$html .= "</TD></TR>\n";
	}

	$html .= "</TABLE></P>\n";

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

sub eprint_render_citation
{
	my( $class, $eprint, $html ) = @_;
	
	my $citation_spec = $EPrints::SiteRoutines::citation_specs{$eprint->{type}};

	return( EPrints::Citation->render_citation( $eprint->{session},
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
	my( $class, $user ) = @_;

	# If no surname, just return the username
	return( "User $user->{username}" ) if( !defined $user->{name} ||
	                                       $user->{name} eq "" );

	return( EPrints::Name->format_name( $user->{name}, 1 ) );
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
	my( $class, $user, $public ) = @_;

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
		my @user_fields = EPrints::MetaInfo->get_user_fields();
		my $email_field = EPrints::MetaInfo->find_field( \@user_fields, "email" );
		my $url_field = EPrints::MetaInfo->find_field( \@user_fields, "url" );

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
		my @fields = EPrints::MetaInfo->get_user_fields();
		my $field;

		foreach $field (@fields)
		{
			if( !$public || $field->{visible} )
			{
				$html .= "<TR><TD VALIGN=TOP><STRONG>$field->{displayname}".
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

sub update_submitted_eprint
{
	my( $class, $eprint ) = @_;
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
	my( $class, $eprint ) = @_;
}

1;
