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

## WP1: BAD
sub send_mail
{
	my( $session, $name, $address, $subject, $body ) = @_;

	open( SENDMAIL, "|$session->get_archive()->{sendmail}" )
		or return( 0 );

	print SENDMAIL <<"EOF";
From: $session->get_archive()->get_conf( "sitename" ) <$session->get_archive()->{admin}>
To: $name <$address>
Subject: $session->get_archive()->( "sitename" ): $subject

$body

$session->get_archive()->{signature}
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

## WP1: BAD
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
# $new_line = update_template_line( $session, $template_line, $user )
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
#   __perlroot__    URL of perl server
#   __staticroot__  URL of static HTTP server
#   __frontpage__   URL of site front page
#   __usermail__    user's email address
#   __subjectroot__ where on the server the "browse by subject" views are
#   __version__     EPrints software version
#
######################################################################

## WP1: BAD
sub update_template_line
{
	my( $session, $template_line, $user ) = @_;
	
	my $new_line = $template_line;

	if( defined $user )
	{
		$new_line =~ s/__username__/$user->{username}/g;
		$new_line =~ s/__password__/$user->{passwd}/g;
		$new_line =~ s/__usermail__/$user->{email}/g;
	}
	
	$new_line =~ s/__sitename__/$session->get_archive()->get_conf( "sitename" )/g;
	$new_line =~ s/__description__/$session->get_archive()->get_conf( "description" )n/g;
	$new_line =~ s/__admin__/$session->get_archive()->get_conf( "admin" )/g;
	$new_line =~ s/__perlroot__/$session->get_archive()->get_conf( "server_perl" )/g;
	$new_line =~ s/__staticroot__/$session->get_archive()->get_conf( "server_static" )/g;
	$new_line =~ s/__frontpage__/$session->get_archive()->get_conf( "frontpage" )/g;
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

## WP1: BAD
sub prepare_send_mail
{
	my( $session, $name, $address, $subject, $templatefile, $user ) = @_;
	
	my $body = EPrints::Mailer::fill_template(
		$templatefile,
		$user );

	return( 0 ) unless( defined $body );

	return( EPrints::Mailer::send_mail(
		$session,
		$name,
		$address,
		$subject,
		$body ) );
}


1;
