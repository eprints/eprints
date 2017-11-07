######################################################################
#
# EPrints::Email
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Email> - Email Utility functions for EPrints.

=head1 DESCRIPTION

This package handles sending emails.

=over 4

=cut

package EPrints::Email;

use MIME::Lite;
use LWP::MediaTypes qw( guess_media_type );
use Encode; # required for MIME-Header support

use strict;


######################################################################
=pod

=item EPrints::Email::send_mail( %properties )

Sends an email. 

Required properties:

session - the current session

langid - the id of the language to send the email in.

to_email, to_name - who to send it to

subject - the subject of the message (UTF-8 encoded string)

message - the body of the message as a DOM tree

optional properties:

from_email, from_name - who is sending the email (defaults to the archive admin)

sig - the signature file as a DOM tree

replyto_email, replyto_name

attach - ref to an array of filenames (with full paths) to attach to the message 

to_list - ref to an array of additional email addresses to send the email to
(note that to_email must be provided)

cc_list - ref to an array of email addresses to CC the email to (note that
to_email must be provided)

Returns true if mail sending (appears to have) succeeded. False otherwise.

Uses the config. option "send_email" to send the mail, or if that's
not defined sends the email via STMP.

names and the subject should be encoded as utf-8


=cut
######################################################################

sub send_mail
{
	my( %p ) = @_;

	my $repository = $p{session}->get_repository;

	if( defined $p{message} )
	{
		my $msg = $p{message};

		# First get the body
		my $body = $p{session}->html_phrase( 
			"mail_body",
			content => $p{session}->clone_for_me($msg,1) );
		# Then add the HTML around it
		my $html = $p{session}->html_phrase(
			"mail_wrapper",
			body => $body );

		$p{message} = $html;
	}

	if( !defined $p{from_email} ) 
	{
		$p{from_name} = $p{session}->phrase( "archive_name" );
		$p{from_email} = $repository->get_conf( "adminemail" );
	}
	
	# If a name contains a comma we must quote it, because comma is the
	# separator for multiple addressees
	foreach my $name (qw( from_name to_name replyto_name ))
	{
		if( defined $p{$name} and $p{$name} =~ /,/ )
		{
			$p{$name} = "\"".$p{$name}."\"";
		}
	}

	my $result;
	if( $repository->can_call( 'send_email' ) )
	{
		$result = $repository->call( 'send_email', %p );
	}
	else
	{
		$result = send_mail_via_sendmail( %p );
	}

	if( !$result )
	{
		$p{session}->get_repository->log( "Failed to send mail.\nTo: $p{to_email} <$p{to_name}>\nSubject: $p{subject}\n" );
	}

	return $result;
}


######################################################################
#=pod
#
#=item EPrints::Email::send_mail_via_smtp( %properties )
#
#Send an email via STMP. Should not be called directly, but rather by
#EPrints::Email::send_mail.
#
#=cut
######################################################################

sub send_mail_via_smtp
{
	my( %p ) = @_;

	eval 'use Net::SMTP';

	my $repository = $p{session}->get_repository;

	my $smtphost = $repository->get_conf( 'smtp_server' );

	if( !defined $smtphost )
	{
		$repository->log( "No STMP host has been defined. To fix this, find the full\naddress of your SMTP server (eg. smtp.example.com) and add it\nas the value of smtp_server in\nperl_lib/EPrints/SystemSettings.pm" );
		return( 0 );
	}

	my $smtp = Net::SMTP->new( $smtphost );
	if( !defined $smtp )
	{
		$repository->log( "Failed to create SMTP connection to $smtphost" );
		return( 0 );
	}

	
	if( !$smtp->mail( $p{from_email} ) )
	{
		$repository->log( "SMTP refused MAIL FROM: $p{from_email}: ".$smtp->code." ".$smtp->message );
		$smtp->quit;
		return 0;
	}
	if( !$smtp->recipient( $p{to_email} ) )
	{
		$repository->log( "SMTP refused RCPT TO: $p{to_email}: ".$smtp->code." ".$smtp->message );
		$smtp->quit;
		return 0;
	}

	if( EPrints::Utils::is_set( $p{to_list} ) )
	{
		my @goodrecips = $smtp->recipient( @{ $p{to_list} }, { Notify => ['NEVER'], SkipBad => 1 } );
		$p{to_list} = \@goodrecips;
	}
	if( EPrints::Utils::is_set( $p{cc_list} ) )
	{
		my @goodrecips = $smtp->recipient( @{ $p{cc_list} }, { Notify => ['NEVER'], SkipBad => 1 } );
		$p{cc_list} = \@goodrecips;
	}

	my $message = build_email( %p );
	my $data = $message->as_string;
	# Send the message as bytes, to avoid Net::Cmd wide-character warnings
	utf8::encode($data);
	$smtp->data();
	$smtp->datasend( $data );
	$smtp->dataend();
	$smtp->quit;

	return 1;
}

######################################################################
# =pod
# 
# =item EPrints::Email::send_mail_via_sendmail( %params )
# 
# Also should not be called directly. The config. option "send_email"
# can be set to \&EPrints::Email::send_mail_via_sendmail to use the
# sendmail command to send emails rather than send to a SMTP server.
# 
# =cut
######################################################################

sub send_mail_via_sendmail
{
	my( %p )  = @_;

	my $repository = $p{session}->get_repository;

	if( open(my $fh, "|-", $p{session}->invocation( "sendmail" )) )
	{
		binmode($fh, ":utf8");
		print $fh build_email( %p )->as_string;
		close($fh);
	}
	else
	{
		$p{session}->log( $p{session}->invocation( "sendmail" ).": $!" );
	}

	return 1;
}

# $mime_message = EPrints::Email::build_email( %params ) 
#
# Takes the same parameters as send_mail. This creates a MIME::Lite email
# object with both a text and an HTML part.

sub build_email
{
	my( %p ) = @_;

	my $MAILWIDTH = 80;

	my $repository = $p{session}->get_repository;

	# removes the @ and everything after (confuses SMTP otherwise)
        $p{to_name} =~ s/@[^@]*$//g;

	my $mimemsg = MIME::Lite->new(
		From       => encode_mime_header( "$p{from_name}" )." <$p{from_email}>",
		To         => encode_mime_header( "$p{to_name}" )." <$p{to_email}>",
		Subject    => encode_mime_header( $p{subject} ),
		Type       => "multipart/alternative",
		Precedence => "bulk",
	);

	if( defined $p{replyto_email} )
	{
		$mimemsg->attr( "Reply-to" => encode_mime_header( "$p{replyto_name}" )." <$p{replyto_email}>" );
	}
	$mimemsg->replace( "X-Mailer" => "EPrints http://eprints.org/" );

	if( EPrints::Utils::is_set( $p{to_list} ) )
	{
		$mimemsg->replace( "To", encode_mime_header( "$p{to_name}" )." <$p{to_email}>, " . join( ", ", @{ $p{to_list} } ) );
	}
	if( EPrints::Utils::is_set( $p{cc_list} ) )
	{
		$mimemsg->replace( "Cc", join( ", ", @{ $p{cc_list} } ) );
	}

	# If there are file attachments, change to a "mixed" type
	# and attach the body Text and HTML to an "alternative" subpart
	my $mixedmsg;
	if( $p{attach} )
	{
		$mixedmsg = $mimemsg;
		$mixedmsg->attr( "Content-Type" => "multipart/mixed" );
		$mimemsg = MIME::Lite->new(
			Type => "multipart/alternative",
		);
		$mixedmsg->attach( $mimemsg );
	}

	my $xml_mail = $p{message};
	EPrints::XML::tidy( $xml_mail );
	my $data = EPrints::Utils::tree_to_utf8( $xml_mail , $MAILWIDTH, 0, 0, 0 );

	my $text = MIME::Lite->new( 
		Type  => "TEXT",
		Data  => $data
	);
	$text->attr("Content-type.charset" => "UTF-8");
	$text->attr("Content-disposition" => "");
	$mimemsg->attach( $text );

	$data = EPrints::XML::to_string( $xml_mail, undef, 1 );

	my $html = MIME::Lite->new( 
		Type  => "text/html",
		Data  => $data,
	);
	$html->attr("Content-type.charset" => "UTF-8");
	$html->attr("Content-disposition" => "");
	$mimemsg->attach( $html );

	if( !$p{attach} )
	{
		# not a multipart message
		return $mimemsg;
	}

	foreach my $file ( @{ $p{attach} } )
	{
		my $part = MIME::Lite->new(
			Type => guess_media_type( $file ),
			Path => $file,
		);
		$mixedmsg->attach( $part );
	}

	return $mixedmsg;
}

sub encode_mime_header
{
	Encode::encode("MIME-Header", $_[0] );
}



1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

