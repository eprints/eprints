######################################################################
#
#  EPrints Utility module
#
#   Provides various useful functions
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

package EPrints::Utils;
use Filesys::DiskSpace;
use strict;
use Unicode::String qw(utf8 latin1 utf16);

print "Utility module loaded...\n";

my $DF_AVAILABLE;

BEGIN {

	sub detect_df 
	{
	
		my $dir = "/";
		my ($fmt, $res);
	
		# try with statvfs..
		eval 
		{  
			{
				package main;
				require "sys/syscall.ph";
			}
			$fmt = "\0" x 512;
			$res = syscall (&main::SYS_statvfs, $dir, $fmt) ;
			$res == 0;
		}
		# try with statfs..
		|| eval 
		{ 
			{
				package main;
				require "sys/syscall.ph";
			}	
			$fmt = "\0" x 512;
			$res = syscall (&main::SYS_statfs, $dir, $fmt);
			$res == 0;
		}
	}
	$DF_AVAILABLE = detect_df();
	if (!$DF_AVAILABLE)
	{
		warn("df appears to be unavailable on your server. To enable it, you should run 'h2ph * */*' in your /usr/include directory. See the manual for more information.");
	}
}


######################################################################
# $dirspace = df_dir( $dir );
#
#  Returns the amount of free space in directory $dir, or undef
#  if df could not be used.
# 
######################################################################

sub df_dir
{
	my( $dir ) = @_;
	return df $dir if ($DF_AVAILABLE);
	warn("df appears to be unavailable on your server. To enable it, you should run 'h2ph * */*' in your /usr/include directory. See the manual for
more information.");	
}


######################################################################
#
# $html = format_name( $namespec, $familylast )
#
#  Takes a name (a reference to a hash containing keys
#  "family" and "given" and returns it rendered 
#  for screen display.
#
######################################################################

## WP1: BAD
sub format_name
{
	my( $name, $familylast ) = @_;

	my $firstbit;
	if( defined $name->{honourific} && $name->{honourific} ne "" )
	{
		$firstbit = $name->{honourific}." ".$name->{given};
	}
	else
	{
		$firstbit = $name->{given};
	}
	
	my $secondbit;
	if( defined $name->{lineage} && $name->{lineage} ne "" )
	{
		$secondbit = $name->{family}." ".$name->{lineage};
	}
	else
	{
		$secondbit = $name->{family};
	}
	
	if( $familylast )
	{
		return $firstbit." ".$secondbit;
	}
	
	return $secondbit.", ".$firstbit;
}

######################################################################
#
# ( $cmp ) = cmp_names( $lista , $listb )
#
#  This method compares (alphabetically) two arrays of names. Passed
#  by reference.
#
######################################################################

## WP1: BAD
sub cmp_names
{
	my( $lista , $listb ) = @_;	

	my( $texta , $textb ) = ( "" , "" );
	foreach( @{$lista} ) { $texta.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	foreach( @{$listb} ) { $textb.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	return( $texta cmp $textb );
}


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
sub mime_encode_q
{
	my( $string ) = @_;

	return "" if (length($string) == 0);

	my $svnbit = 1;
	my $latin1 = 1;
	my $utf8   = 0;
	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $string );	

	foreach($stringobj->unpack())
	{
		$svnbit &= !($_ > 0x79);	
		$latin1 &= !($_ > 0xFF);
		if ($_ > 0xFF)
		{
			$utf8 = 1;	
			last;
		} 
	}
	return $stringobj if $svnbit;
	return "=?utf-8?Q?".encode_str($stringobj)."?=" if $utf8;
	return "=?iso-latin-1?Q?".encode_str($stringobj->latin1)."?=" if $latin1;
}

sub encode_str
{
	my( $string ) = @_;
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
	return $encoded;
}

# ALL cjg get_value should use this.
sub is_set
{
	my( $r ) = @_;

	return 0 if( !defined $r );
		
	if( ref($r) eq "" )
	{
		return ($r ne "");
	}
	if( ref($r) eq "ARRAY" )
	{
		foreach( @$r )
		{
			return( 1 );
		}
		return( 0 );
	}
	if( ref($r) eq "HASH" )
	{
		foreach( keys %$r )
		{
			return( 1 );
		}
		return( 0 );
	}
	# Hmm not a scalar, or a hash or array ref.
	# Lets assume it's set. (it is probably a blessed thing)
	return( 1 );
}

1;
