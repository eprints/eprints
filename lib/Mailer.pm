######################################################################
#
#  EPrints E-Mail module
#
#   Provides e-mail services
#
######################################################################
#
#  09/11/99 - Created by Robert Tansley
#  $Id$
#
######################################################################

package EPrints::Mailer;

use EPrintSite::SiteInfo;

use strict;

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
	my( $class, $name, $address, $subject, $body ) = @_;

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
# $body = prepare_mail( $template_filename, $user )
#
#  Reads the mail template from the given file, and replaces the
#  relevant placeholders with values. Placeholders are:
#
#   __username__    username of $user
#   __password__    password of $user
#   __sitename__    name of the site
#   __admin__       admin email address
#   __automail__    email address of automatic mail processing account
#   __perlroot__    URL of perl server
#   __staticroot__  URL of static HTTP server
#   __frontpage__   URL of site front page
#   __usermail__    user's email address
#
#  The updated body is returned, or undef if an error occurred.
#
######################################################################

sub prepare_mail
{
	my( $class, $template_filename, $user ) = @_;
	
	my $body = "";

	open( INTROFILE, $template_filename ) or return( undef );
	
	while( <INTROFILE> )
	{
		s/__username__/$user->{username}/g;
		s/__password__/$user->{passwd}/g;
		s/__usermail__/$user->{email}/g;
		s/__sitename__/$EPrintSite::SiteInfo::sitename/g;
		s/__admin__/$EPrintSite::SiteInfo::admin/g;
		s/__automail__/$EPrintSite::SiteInfo::automail/g;
		s/__perlroot__/$EPrintSite::SiteInfo::server_perl/g;
		s/__staticroot__/$EPrintSite::SiteInfo::server_static/g;
		s/__frontpage__/$EPrintSite::SiteInfo::frontpage/g;

		$body .= $_;
	}
	
	close( INTROFILE );

	return( $body );
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
	
	my $body = EPrints::Mailer->prepare_mail(
		$templatefile,
		$user );

	return( 0 ) unless( defined $body );

	return( EPrints::Mailer->send_mail(
		$name,
		$address,
		$subject,
		$body ) );
}


1;
