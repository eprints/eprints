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

use strict;

sub send_mail
{
	my( $archive, $langid, $name, $address, $subject, $body, $sig ) = @_;
	#   Archive   string   utf8   utf8      utf8      DOM    DOM

	unless( open( SENDMAIL, "|".$archive->invocation( "sendmail" ) ) )
	{
		$archive->log( "Failed to invoke sendmail: ".
			$archive->invocation( "sendmail" ) );
		return( 0 );
	}

	# Addresses should be 7bit clean, but I'm not checking yet.
	# god only knows what 8bit data does in an email address.

	#cjg should be in the top of the file.
	my $MAILWIDTH = 80;

	my $arcname_q = mime_encode_q( EPrints::Session::best_language( 
		$archive,
		$langid,
		%{$archive->get_conf( "archivename" )} ) );

	my $name_q = mime_encode_q( $name );
	my $subject_q = mime_encode_q( $subject );
	my $adminemail = $archive->get_conf( "adminemail" );

	#precedence bulk to avoid automail replies?  cjg
	print SENDMAIL <<END;
From: $arcname_q <$adminemail>
To: $name_q <$address>
Subject: $arcname_q: $subject_q
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: 8bit

END
	print SENDMAIL EPrints::Config::tree_to_utf8( $body , $MAILWIDTH );
	if( defined $sig )
	{
		print SENDMAIL EPrints::Config::tree_to_utf8( $sig , $MAILWIDTH );
	}

	close(SENDMAIL) or return( 0 );
	return( 1 );
}

# Encode a utf8 string for a MIME header.
sub mime_encode_q {
	my( $string ) = @_;

	return "" if( length($string) == 0);
	my $encoded = "";
	my $i;
	for $i (0..length($string)-1)
	{
		my $o = ord(substr($string,$i,1));
		# less than space, higher or equal than 'DEL' or _ or ?
		if( $o < 0x20 || $o > 0x7E || $o == 0x5F || $o == 0x3F )
		{
			$encoded.=sprintf( "=%02X", $o );
		}
		else
		{
			$encoded.=chr($o);
		}
	}
	return "=?utf-8?Q?".$encoded."?=";
}



1;
