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
From: $EPrintSite::SiteInfo::sitename<$EPrintSite::SiteInfo::admin>
To: $name <$address>
Subject: $EPrintSite::SiteInfo::sitename: $subject

$body
EOF

	close(SENDMAIL) or return( 0 );
	return( 1 );
}

1;
