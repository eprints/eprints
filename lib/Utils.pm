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
use File::Path;
use XML::DOM;

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



sub format_date
{	
	my( $session, $datevalue ) = @_;

	if( !defined $datevalue )
	{
		return $session->phrase( "lib/utils:date_unspecified" );
	}

	my @elements = split /\-/, $datevalue;

	if( $elements[0]==0 )
	{
		return $session->phrase( "lib/utils:date_unspecified" );
	}

	if( $#elements != 2 || $elements[1] < 1 || $elements[1] > 12 )
	{
		return $session->phrase( "lib/utils:date_invalid" );
	}

	return $elements[2]." ".EPrints::Utils::get_month_label( $session, $elements[1] )." ".$elements[0];
}

sub get_month_label
{
	my( $session, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_%02d", $monthid );

	return $session->phrase( $code );
}


sub render_name
{
	my( $session, $name, $familylast ) = @_;

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
		return $session->make_text( $firstbit." ".$secondbit );
	}
	
	return $session->make_text( $secondbit.", ".$firstbit );
}

######################################################################
#
# ( $cmp ) = cmp_names( $val_a , $val_b )
#
#  This method compares (alphabetically) two arrays of names. Passed
#  by reference.
#
######################################################################


sub cmp_namelists
{
	my( $a , $b , $fieldname ) = @_;

	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	return _cmp_names_aux( $val_a, $val_b );
}

sub cmp_names
{
	my( $a , $b , $fieldname ) = @_;

	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	return _cmp_names_aux( [$val_a] , [$val_b] );
}

sub _cmp_names_aux
{
	my( $val_a, $val_b ) = @_;

	my( $texta , $textb ) = ( "" , "" );
	if( defined $val_a )
	{ 
		foreach( @{$a} ) { $texta.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	}
	if( defined $val_b )
	{ 
		foreach( @{$b} ) { $textb.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	}

	return( $texta cmp $textb );
}


sub cmp_ints
{
	my( $a , $b , $fieldname ) = @_;
	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	$val_a = 0 if( !defined $val_a );
	$val_b= 0 if( !defined $val_b);
	return $val_a <=> $val_b
}

sub cmp_strings
{
	my( $a , $b , $fieldname ) = @_;
	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	$val_a = "" if( !defined $val_a );
	$val_b= "" if( !defined $val_b);
	return $val_a cmp $val_b
}

sub cmp_dates
{
	my( $a , $b , $fieldname ) = @_;
	return cmp_strings( $a, $b, $fieldname );
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
			return( 1 ) if( is_set( $_ ) );
		}
		return( 0 );
	}
	if( ref($r) eq "HASH" )
	{
		foreach( keys %$r )
		{
			return( 1 ) if( is_set( $r->{$_} ) );
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

	if( substr(ref($node) , 0, 8 ) ne "XML::DOM" )
	{
		print STDERR "Oops. tree_to_utf8 got as a node: $node\n";
	}

        if( defined $width )
        {
                # If we are supposed to be doing an 80 character wide display
                # then only do 78, so the last char does not force a line break.                
		$width = $width - 2;
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
        if( $name eq "img" )
        {
		my $alt = $node->getAttribute( "alt" );
		$string = $alt if( defined $alt );
        }
        return $string;
}

sub mkdir
{
	my( $full_path ) = @_;
	my @created = eval
        {
                return mkpath( $full_path, 0, 0775 );
        };
        return ( scalar @created > 0 )
}

# cjg - Potential bug if: <ifset a><ifset b></></> and ifset a is disposed
# then ifset: b is processed it will crash.

sub render_citation
{
	my( $obj, $cstyle, $url ) = @_;

	# This should belong to the base class of EPrint User Subject and
	# Subscription, if we were better OO people...

	# cjg BUG in nested <ifset>'s ?

	my $nodes = { keep=>[], lose=>[] };
	my $node;

	foreach $node ( $cstyle->getElementsByTagName( "ifset" , 1 ) )
	{
		my $fieldname = $node->getAttribute( "name" );
		my $val = $obj->get_value( $fieldname );
		push @{$nodes->{EPrints::Utils::is_set( $val )?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "ifnotset" , 1 ) )
	{
		my $fieldname = $node->getAttribute( "name" );
		my $val = $obj->get_value( $fieldname );
		push @{$nodes->{!EPrints::Utils::is_set( $val )?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "iflink" , 1 ) )
	{
		push @{$nodes->{defined $url?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "ifnotlink" , 1 ) )
	{
		push @{$nodes->{!defined $url?"keep":"lose"}}, $node;
	}
	foreach $node ( $cstyle->getElementsByTagName( "a" , 1 ) )
	{
		if( !defined $url )
		{
			push @{$nodes->{keep}}, $node;
			next;
		}
		$node->setAttribute( "href", $url );
	}
	foreach $node ( @{$nodes->{keep}} )
	{
		my $sn; 
		foreach $sn ( $node->getChildNodes )
		{       
			$node->getParentNode->insertBefore( $sn, $node );
		}
		$node->getParentNode->removeChild( $node );
		$node->dispose();
	}
	foreach $node ( @{$nodes->{lose}} )
	{
		$node->getParentNode->removeChild( $node );
		$node->dispose();
	}

	_expand_references( $obj, $cstyle );

	return $cstyle;
}      

sub _expand_references
{
	my( $obj, $node ) = @_;

	foreach( $node->getChildNodes )
	{                
		if( $_->getNodeType == ENTITY_REFERENCE_NODE )
		{
			my $fname = $_->getNodeName;
			my $field = $obj->get_dataset()->get_field( $fname );
			my $fieldvalue = $field->render_value( 
						$obj->get_session(),
						$obj->get_value( $fname ),
						0,
 						1 );
			$node->replaceChild( $fieldvalue, $_ );
			$_->dispose();
		}
		else
		{
			_expand_references( $obj, $_ );
		}
	}
}

# cjg Eh? What's this doing here?
sub render_value
{
	my( $self, $fieldname, $showall ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );	
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall );
}

sub field_from_config_string
{
	my( $dataset, $fieldname ) = @_;

	my $useid = ( $fieldname=~s/\.id$// );
	# use id side of a field if the fieldname
	# ends in .id (and strip the .id)
	my $field = $dataset->get_field( $fieldname );
	if( !defined $field )
	{
		EPrints::Config::abort( "Can't make field from config_string: $fieldname" );
	}
	if( $field->get_property( "hasid" ) )
	{
		if( $useid )
		{
			$field = $field->get_id_field();
		}
		else
		{
			$field = $field->get_main_field();
		
		}
	}
	
	return $field;
}


sub get_input
{
	my( $regexp, $prompt, $default ) = @_;

	$prompt = "" if( !defined $prompt);
	for(;;)
	{
		print $prompt;
		if( defined $default )
		{
			print " [$default] ";
		}
		print "? ";
		my $in = <STDIN>;
		chomp $in;
		if( $in eq "" && defined $default )
		{
			return $default;
		}
		if( $in=~m/^$regexp$/ )
		{
			return $in;
		}
		else
		{
			print "Bad Input, try again.\n";
		}
	}
}


1;
