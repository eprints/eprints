######################################################################
#
#  Site Specific Routines
#
#   Routines for handling operations that will vary from site to site
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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

use EPrintSite::SiteInfo;

use strict;


# Specs for rendering citations.

%EPrints::SiteRoutines::citation_specs =
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

sub eprint_render_full
{
	my( $eprint, $for_staff ) = @_;

	my $html = "";

	my $succeeds_field = EPrints::MetaInfo::find_eprint_field( "succeeds" );
	my $commentary_field = EPrints::MetaInfo::find_eprint_field( "commentary" );
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
		my $description = 
			$EPrintSite::SiteInfo::supported_format_names{$_->{format}};
		$description = $_->{formatdesc}
			if( $_->{format} eq $EPrints::Document::other );

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
		$html .= "<A HREF=\"$EPrintSite::SiteInfo::server_perl/user?username=".
			$user->{username}."\">".$user->full_name()."</A>";
	}
	else
	{
		$html .= "INVALID USER";
	}

	if( $eprint->{table} eq $EPrints::Database::table_archive )
	{
		my $date_field = EPrints::MetaInfo::find_eprint_field( "datestamp" );
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
		my $altloc_field = EPrints::MetaInfo::find_eprint_field( "altloc" );
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
			EPrints::MetaInfo::find_eprint_field( "additional" );
		my $reason_field = EPrints::MetaInfo::find_eprint_field( "reasons" );

		# Write suggested extra subject category
		if( defined $eprint->{additional} )
		{
			$html .= "<TABLE BORDER=0 CELLPADDING=3>\n";
			$html .= "<TR><TD><STRONG>$additional_field->{displayname}:</STRONG>".
				"</TD><TD>$eprint->{additional}</TD></TR>\n";
			$html .= "<TR><TD><STRONG>$reason_field->{displayname}:</STRONG>".
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

sub eprint_render_citation
{
	my( $eprint, $html ) = @_;
	
	my $citation_spec = $EPrints::SiteRoutines::citation_specs{$eprint->{type}};

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
	my( $user ) = @_;

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
		my @user_fields = EPrints::MetaInfo::get_user_fields();
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
		my @fields = EPrints::MetaInfo::get_user_fields();
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
#  %EPrintSite::SiteInfo::oai_metadata_formats.
#
######################################################################

sub oai_list_metadata_formats
{
	my( $eprint ) = @_;
	
	# This returns the list of all metadata formats, suitable if we
	# can export any of those metadata format for any record.
	return( keys %EPrintSite::SiteInfo::oai_metadata_formats );
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
#
#  For Santa-Fe complaint OAMS, the tags are:
#
#  title [M]      =>  "document title"
#  author [M][R}  =>  [ { name => "author's name",
#                     organization = "author's org." },
#                   { name => "author's name",
#                     organization = "author's org." },
#                   .... ]
#  abstract       =>  "document abstract"
#  subject [R]    =>  [ "topic1", "topic2" ]  e.g. subjects, keywords (how this
#                       should be filled out is not specified in OAMS)
#  comment [R]    =>  [ "any extra info" ]
#  discovery      =>  date for discovery, in the format YYYY-MM-DD. This can be
#                     the date of original publication, for example.
#
#  [M] - mandatory tag, must give a value for this
#  [R] - repeatable tag, pass in a reference to an array of values
#
#  If for some reason an error is encountered, or for some other
#  reason the record shouldn't be disseminated, you can empty $tags.
#
######################################################################

sub oai_get_eprint_metadata
{
	my( $eprint, $format ) = @_;

	if( $format eq "oams" )
	{
		my %tags;

		# Title
		$tags{title} = $eprint->{title};

		# Authors
		my @authors = EPrints::Name::extract( $eprint->{authors} );
		$tags{author} = [];

		foreach (@authors)
		{
			my( $surname, $firstnames ) = @$_;
			push @{$tags{author}}, { "name" => "$firstnames $surname",
			                         "organization" => "" };
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

		# Abstract
		$tags{abstract} = $eprint->{abstract};

		# Comment
		$tags{comment} = $eprint->{comment} if( defined $eprint->{comment} );

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

		$tags{discovery} = "$year-$month-01";

		return( %tags );
	}
	elsif( $format eq "dc" )
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
		$tags{type} = EPrints::MetaInfo::get_eprint_type_name(
			$eprint->{type} );
		$tags{identifier} = $eprint->static_page_url();

		return( %tags );
	}
	else
	{
		return( undef );
	}
}




1;
