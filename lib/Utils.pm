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
use strict;
use Filesys::DiskSpace;
use Unicode::String qw(utf8 latin1 utf16);
use EPrints::DOM;
use File::Path;
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
		print STDERR <<END;
---------------------------------------------------------------------------
df appears to be unavailable on your server. To enable it, you should
run 'h2ph * */*' in your /usr/include directory. See the EPrints manual for
more information.
---------------------------------------------------------------------------
END
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

	my $utf8body 	= EPrints::Utils::tree_to_utf8( $body , $MAILWIDTH );
	my $utf8sig	= EPrints::Utils::tree_to_utf8( $sig , $MAILWIDTH );
	my $utf8all	= $utf8body.$utf8sig;
	my $type	= get_encoding($utf8all);
	my $content_type_q = "text/plain";
	if ($type eq "iso-latin-1")
	{
		$content_type_q = "text/plain; charset=iso-8859-1"; 
		$utf8all = $utf8all->latin1; 
	}
	#precedence bulk to avoid automail replies?  cjg
	print SENDMAIL <<END;
From: $arcname_q <$adminemail>
To: $name_q <$address>
Subject: $arcname_q: $subject_q
Content-Type: $content_type_q
Content-Transfer-Encoding: 8bit

END
	print SENDMAIL $utf8all;
	close(SENDMAIL) or return( 0 );
	return( 1 );
}

######################################################################
#
# $encoding = get_encoding($mystring)
# 
# Returns:
# "7-bit" if 7-bit clean
# "utf-8" if utf-8 encoded
# "iso-latin-1" if latin-1 encoded
# "unknown" if of unknown origin (shouldn't really happen)
#
######################################################################

sub get_encoding
{
	my( $string ) = @_;

	return "7-bit" if (length($string) == 0);

	my $svnbit = 1;
	my $latin1 = 1;
	my $utf8   = 0;

	foreach($string->unpack())
	{
		$svnbit &= !($_ > 0x79);	
		$latin1 &= !($_ > 0xFF);
		if ($_ > 0xFF)
		{
			$utf8 = 1;	
			last;
		} 
	}
	return "7-bit" if $svnbit;
	return "utf-8" if $utf8;
	return "iso-latin-1" if $latin1;
	return "unknown";
}

# Encode a utf8 string for a MIME header.
sub mime_encode_q
{
	my( $string ) = @_;
	
	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $string );	

	my $encoding = get_encoding($stringobj);

	return $stringobj
		if $encoding eq "7-bit";
	return "=?utf-8?Q?".encode_str($stringobj)."?=" 
		if $encoding eq "utf-8";
	return "=?iso-latin-1?Q?".encode_str($stringobj->latin1)."?=" 
		if $encoding eq "iso-latin-1";
	return $stringobj;	# Not sure what to do, so just return string.
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

# widths smaller than about 3 may totally break, but that's
# a stupid thing to do, anyway.
sub tree_to_utf8
{
        my( $node, $width, $pre ) = @_;

        if( defined $width )
        {
                # If we are supposed to be doing an 80 character wide display
                # then only do 79, so the last char does not force a line break.                $width = $width - 1;
        }

        my $name = $node->getNodeName;
        if( $name eq "#text" || $name eq "#cdata-section")
        {
                my $text = utf8( $node->getNodeValue );
                $text =~ s/[\s\r\n\t]+/ /g unless( $pre );
                return $text;
        }

        my $string = utf8("");
        foreach( $node->getChildNodes )
        {
                $string .= tree_to_utf8( $_, $width, ( $pre || $name eq "pre" )
);
        }

        if( $name eq "fallback" )
        {
                $string = "*".$string."*";
        }

        # <hr /> only makes sense if we are generating a known width.
        if( $name eq "hr" && defined $width )
        {
                $string = latin1("\n"."-"x$width."\n");
        }

        # Handle wrapping block elements if a width was set.
        if( $name eq "p" && defined $width)
        {
                my @chars = $string->unpack;
                my @donechars = ();
                my $i;
                while( scalar @chars > 0 )
                {
                        # remove whitespace at the start of a line
                        if( $chars[0] == 32 )
                        {
                                splice( @chars, 0, 1 );
                                next;
                        }

                        # no whitespace at start, so look for first line break
                        $i=0;
                        while( $i<$width && defined $chars[$i] && $chars[$i] !=
10 ) { ++$i; }
                        if( defined $chars[$i] && $chars[$i] == 10 )
                        {
                                push @donechars, splice( @chars, 0, $i+1 );
                                next;
                        }

                        # no line breaks, so if remaining text is smaller
                        # than the width then just add it to the end and
                        # we're done.
                        if( scalar @chars < $width )
                        {
                                push @donechars,@chars;
                                last;
                        }

                        # no line break, more than $width chars.
                        # so look for the last whitespace within $width
                        $i=$width-1;
                        while( $i>=0 && $chars[$i] != 32 ) { --$i; }
                        if( defined $chars[$i] && $chars[$i] == 32 )
                        {
                                # up to BUT NOT INCLUDING the whitespace
                                my @line = splice( @chars, 0, $i );
# This code makes the output "flush" by inserting extra spaces where
# there is currently one. Is that what we want? cjg
#my $j=0;
#while( scalar @line < $width )
#{
#       if( $line[$j] == 32 )
#       {
#               splice(@line,$j,0,-1);
#               ++$j;
#       }
#       ++$j;
#       $j=0 if( $j >= scalar @line );
#}
#foreach(@line) { $_ = 32 if $_ == -1; }
                                push @donechars, @line;

                                # just consume the whitespace
                                splice( @chars, 0, 1);
                                # and a CR...
                                push @donechars,10;
                                next;
                        }

                        # No CR's, no whitespace, just split on width then.
                        push @donechars,splice(@chars,0,$width);

                        # Not the end of the block, so add a \n
                        push @donechars,10;
                }
                $string->pack( @donechars );
        }
        if( $name eq "p" )
        {
                $string = "\n".$string."\n";
        }
        if( $name eq "br" )
        {
                $string = "\n";
        }
        return $string;
}

sub mkdir
{
	my( $full_path ) = @_;
	my @created = eval
        {
                my @created = mkpath( $full_path, 0, 0775 );
        };
        return ( scalar @created > 0 )
}

1;
