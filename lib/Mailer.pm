######################################################################
#
#  EPrints E-Mail module
#
#   Provides e-mail services
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

package EPrints::Mailer;

use EPrintSite::SiteInfo;
use EPrints::Version;

use strict;
##what's with automail in this file? Lose it.

######################################################################
#
# $success = send_mail( $name, $address, $subject, $body )
#  bool                   str   str        str      str
#
#  Send a mail to the given address. Note that the returned $success
#  value indicated whether or not the mail was successfully dispatched,
#  and isn't an indication of whether or not the mail was received.
#
######################################################################

sub send_mail
{
	my( $name, $address, $subject, $body ) = @_;

	open( SENDMAIL, "|$EPrintSite::SiteInfo::sendmail" )
		or return( 0 );

	print SENDMAIL <<"EOF";
X-Loop: $EPrintSite::SiteInfo::automail
From: $EPrintSite::SiteInfo::sitename <$EPrintSite::SiteInfo::admin>
To: $name <$address>
Subject: $EPrintSite::SiteInfo::sitename: $subject

$body

$EPrintSite::SiteInfo::signature
EOF

	close(SENDMAIL) or return( 0 );
	return( 1 );
}


######################################################################
#
# $body = fill_template( $template_filename, $user )
#
#  Reads the template from the given file, and replaces the
#  relevant placeholders with values.
#  The updated body is returned, or undef if an error occurred.
#
######################################################################

sub fill_template
{
	my( $template_filename, $user ) = @_;
	
	my $body = "";

	open( INTROFILE, $template_filename ) or return( undef );
	
	while( <INTROFILE> )
	{
		$body .= EPrints::Mailer::update_template_line( $_, $user );
	}
	
	close( INTROFILE );

	return( $body );
}


######################################################################
#
# $new_line = update_template_line( $template_line, $user )
#
#  Takes a line from a template and fills in the relevant values.
#
#  Values updated are:
#
#   __username__    username of $user
#   __password__    password of $user
#   __sitename__    name of the site
#   __description__ short text description of the site
#   __admin__       admin email address
#   __automail__    email address of automatic mail processing account
#   __perlroot__    URL of perl server
#   __staticroot__  URL of static HTTP server
#   __frontpage__   URL of site front page
#   __usermail__    user's email address
#   __subjectroot__ where on the server the "browse by subject" views are
#   __version__     EPrints software version
#
######################################################################

sub update_template_line
{
	my( $template_line, $user ) = @_;
	
	my $new_line = $template_line;

	if( defined $user )
	{
		$new_line =~ s/__username__/$user->{username}/g;
		$new_line =~ s/__password__/$user->{passwd}/g;
		$new_line =~ s/__usermail__/$user->{email}/g;
	}
	
	$new_line =~ s/__sitename__/$EPrintSite::SiteInfo::sitename/g;
	$new_line =~ s/__description__/$EPrintSite::SiteInfo::description/g;
	$new_line =~ s/__admin__/$EPrintSite::SiteInfo::admin/g;
	$new_line =~ s/__automail__/$EPrintSite::SiteInfo::automail/g;
	$new_line =~ s/__perlroot__/$EPrintSite::SiteInfo::server_perl/g;
	$new_line =~ s/__staticroot__/$EPrintSite::SiteInfo::server_static/g;
	$new_line =~ s/__frontpage__/$EPrintSite::SiteInfo::frontpage/g;
	$new_line =~
		s/__subjectroot__/$EPrintSite::SiteInfo::server_subject_view_stem/g;
	$new_line =~ s/__version__/$EPrints::Version::eprints_software_version/g;
	
	return( $new_line );
}



######################################################################
#
# $success = prepare_send_mail( $name, $address, $subject,
#                               $templatefile, $user )
#
#  Prepare and send a mail to the given $name and $address, filling
#  out $templatefile with appropriate values.
#
######################################################################

sub prepare_send_mail
{
	my( $class, $name, $address, $subject, $templatefile, $user ) = @_;
	
	my $body = EPrints::Mailer::fill_template(
		$templatefile,
		$user );

	return( 0 ) unless( defined $body );

	return( EPrints::Mailer::send_mail(
		$name,
		$address,
		$subject,
		$body ) );
}


1;
