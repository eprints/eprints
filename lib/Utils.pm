######################################################################
#
# EPrints::Utils
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


=pod

=head1 NAME

B<EPrints::Utils> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
#  EPrints Utility module
#
#   Provides various useful functions
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::Utils;
use strict;
use Filesys::DiskSpace;
use Unicode::String qw(utf8 latin1 utf16);
use File::Path;
use URI;
use Carp;

use EPrints::SystemSettings;
use EPrints::XML;

my $DF_AVAILABLE;

BEGIN {
	$DF_AVAILABLE = 0;

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
	unless( $EPrints::SystemSettings::conf->{disable_df} )
	{
		$DF_AVAILABLE = detect_df();
		if( !$DF_AVAILABLE )
		{
			print STDERR <<END;
---------------------------------------------------------------------------
df ("Disk Free" system call) appears to be unavailable on your server. To 
enable it, you should run 'h2ph * */*' (as root) in your /usr/include 
directory. See the EPrints manual for more information.

If you can't get df working on your system, you can work around it by
adding 
  disable_df => 1
to .../eprints2/perl_lib/EPrints/SystemSettings.pm
but you should read the manual about the implications of doing this.
---------------------------------------------------------------------------
END
			exit;
		}
	}
}


######################################################################
# $dirspace = df_dir( $dir );
#
#  Returns the amount of free space in directory $dir, or undef
#  if df could not be used.
# 
######################################################################


######################################################################
=pod

=item EPrints::Utils::df_dir( $dir )

undocumented

=cut
######################################################################

sub df_dir
{
	my( $dir ) = @_;

	return df $dir if( $DF_AVAILABLE );
	die( "Attempt to call df when df function is not available." );
}




######################################################################
=pod

=item EPrints::Utils::render_date( $session, $datevalue )

undocumented

=cut
######################################################################

sub render_date
{
	my( $session, $datevalue ) = @_;

	if( !defined $datevalue )
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	my @elements = split /\-/, $datevalue;

	if( $elements[0]==0 )
	{
		return $session->html_phrase( "lib/utils:date_unspecified" );
	}

	# 1999
	if( scalar @elements == 1 )
	{
		return $session->make_text( $elements[0] );
	}

	# 1999-02
	if( scalar @elements == 2 )
	{
		return $session->make_text( EPrints::Utils::get_month_label( $session, $elements[1] )." ".$elements[0] );
	}

#	if( $#elements != 2 || $elements[1] < 1 || $elements[1] > 12 )
#	{
#		return $session->html_phrase( "lib/utils:date_invalid" );
#	}

	# 1999-02-02
	return $session->make_text( $elements[2]." ".EPrints::Utils::get_month_label( $session, $elements[1] )." ".$elements[0] );
}


######################################################################
=pod

=item EPrints::Utils::get_month_label( $session, $monthid )

undocumented

=cut
######################################################################

sub get_month_label
{
	my( $session, $monthid ) = @_;

	my $code = sprintf( "lib/utils:month_%02d", $monthid );

	return $session->phrase( $code );
}



######################################################################
=pod

=item $string = EPrints::Utils::make_name_string( $name, [$familylast] )

undocumented

=cut
######################################################################

sub make_name_string
{
	my( $name, $familylast ) = @_;

	my $firstbit = "";
	if( defined $name->{honourific} && $name->{honourific} ne "" )
	{
		$firstbit = $name->{honourific}." ";
	}
	if( defined $name->{given} )
	{
		$firstbit.= $name->{given};
	}
	
	
	my $secondbit = "";
	if( defined $name->{family} )
	{
		$secondbit = $name->{family};
	}
	if( defined $name->{lineage} && $name->{lineage} ne "" )
	{
		$secondbit .= " ".$name->{lineage};
	}

	
	if( defined $familylast && $familylast )
	{
		return $firstbit." ".$secondbit;
	}
	
	return $secondbit.", ".$firstbit;
}

######################################################################
#
# ( $cmp ) = cmp_names( $val_a , $val_b )
#
#  This method compares (alphabetically) two arrays of names. Passed
#  by reference.
#
######################################################################



######################################################################
=pod

=item EPrints::Utils::cmp_namelists( $a, $b, $fieldname )

undocumented

=cut
######################################################################

sub cmp_namelists
{
	my( $a , $b , $fieldname ) = @_;

	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	return _cmp_names_aux( $val_a, $val_b );
}


######################################################################
=pod

=item EPrints::Utils::cmp_names( $a, $b, $fieldname )

undocumented

=cut
######################################################################

sub cmp_names
{
	my( $a , $b , $fieldname ) = @_;

	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	return _cmp_names_aux( [$val_a] , [$val_b] );
}

######################################################################
# 
# EPrints::Utils::_cmp_names_aux( $val_a, $val_b )
#
# undocumented
#
######################################################################

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



######################################################################
=pod

=item EPrints::Utils::cmp_ints( $a, $b, $fieldname )

undocumented

=cut
######################################################################

sub cmp_ints
{
	my( $a , $b , $fieldname ) = @_;
	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	$val_a = 0 if( !defined $val_a );
	$val_b= 0 if( !defined $val_b);
	return $val_a <=> $val_b
}


######################################################################
=pod

=item EPrints::Utils::cmp_strings( $a, $b, $fieldname )

undocumented

=cut
######################################################################

sub cmp_strings
{
	my( $a , $b , $fieldname ) = @_;
	my $val_a = $a->get_value( $fieldname );
	my $val_b = $b->get_value( $fieldname );
	$val_a = "" if( !defined $val_a );
	$val_b= "" if( !defined $val_b);
	return $val_a cmp $val_b
}


######################################################################
=pod

=item EPrints::Utils::cmp_dates( $a, $b, $fieldname )

undocumented

=cut
######################################################################

sub cmp_dates
{
	my( $a , $b , $fieldname ) = @_;
	return cmp_strings( $a, $b, $fieldname );
}

# replyto / replytoname are optional (both or neither), they set
# the reply-to header.

######################################################################
=pod

=item EPrints::Utils::send_mail( $archive, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname )

undocumented

=cut
######################################################################

sub send_mail
{
	my( $archive, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname ) = @_;
	#   Archive   string   utf8   utf8      utf8      DOM    DOM   string    utf8

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
	my $msg = $utf8all;
	if ($type eq "iso-latin-1")
	{
		$content_type_q = 'text/plain; charset="iso-8859-1"'; 
		$msg = $utf8all->latin1; 
	}
	#precedence bulk to avoid automail replies?  cjg
	my $mailheader = "";
	if( defined $replyto )
	{
		my $replytoname_q = mime_encode_q( $replytoname );
		$mailheader.= <<END;
Reply-To: "$replytoname_q" <$replyto>
END
	}
	$mailheader.= <<END;
From: "$arcname_q" <$adminemail>
To: "$name_q" <$address>
Subject: $arcname_q: $subject_q
Precedence: bulk
Content-Type: $content_type_q
Content-Transfer-Encoding: 8bit
END

	print SENDMAIL $mailheader;
	print SENDMAIL "\n";
	print SENDMAIL $msg;
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


######################################################################
=pod

=item EPrints::Utils::get_encoding( $string )

undocumented

=cut
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

######################################################################
=pod

=item EPrints::Utils::mime_encode_q( $string )

undocumented

=cut
######################################################################

sub mime_encode_q
{
	my( $string ) = @_;
	
	my $stringobj = Unicode::String->new();
	$stringobj->utf8( $string );	

	my $encoding = get_encoding($stringobj);

	return $stringobj
		if( $encoding eq "7-bit" );

	return $stringobj
		if( $encoding ne "utf-8" && $encoding ne "iso-latin-1" );

	my @words = split( " ", $stringobj->utf8 );

	foreach( @words )
	{
		my $wordobj = Unicode::String->new();
		$wordobj->utf8( $_ );	
		# don't do words which are 7bit clean
		next if( get_encoding($wordobj) eq "7-bit" );

		my $estr = ( $encoding eq "iso-latin-1" ?
		             $wordobj->latin1 :
			     $wordobj );
		
		$_ = "=?".$encoding."?Q?".encode_str($estr)."?=";
	}

	return join( " ", @words );
}



######################################################################
=pod

=item EPrints::Utils::encode_str( $string )

undocumented

=cut
######################################################################

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

######################################################################
=pod

=item EPrints::Utils::is_set( $r )

undocumented

=cut
######################################################################

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

######################################################################
=pod

=item EPrints::Utils::tree_to_utf8( $node, $width, $pre )

undocumented

=cut
######################################################################

sub tree_to_utf8
{
        my( $node, $width, $pre ) = @_;

	unless( EPrints::XML::is_dom( $node ) )
	{
		print STDERR "Oops. tree_to_utf8 got as a node: $node\n";
	}
	if( EPrints::XML::is_dom( $node, "NodeList" ) )
	{
		# Hmm, a node list, not a node.
        	my $string = utf8("");
        	for( my $i=0 ; $i<$node->getLength ; ++$i )
        	{
                	$string .= tree_to_utf8( 
				$node->index( $i ), 
				$width,
 				$pre );
		}
		return $string;
	}

        if( defined $width )
        {
                # If we are supposed to be doing an 80 character wide display
                # then only do 78, so the last char does not force a line break.                
		$width = $width - 2;
        }

	
	if( EPrints::XML::is_dom( $node, "Text" ) ||
	    EPrints::XML::is_dom( $node, "CDataSection" ) )
        {
        	my $v = $node->getNodeValue();
                $v =~ s/[\s\r\n\t]+/ /g unless( $pre );
                return $v;
        }

        my $name = $node->getNodeName();

        my $string = utf8("");
        foreach( $node->getChildNodes )
        {
                $string .= tree_to_utf8( $_, $width, ( $pre || $name eq "pre" || $name eq "mail" )
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
        if( ( $name eq "p" || $name eq "mail" ) && defined $width)
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


######################################################################
=pod

=item EPrints::Utils::mkdir( $full_path )

undocumented

=cut
######################################################################

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


######################################################################
=pod

=item EPrints::Utils::render_citation( $obj, $cstyle, $url )

undocumented

=cut
######################################################################

sub render_citation
{
	my( $obj, $cstyle, $url ) = @_;

	# This should belong to the base class of EPrint User Subject and
	# Subscription, if we were better OO people...

	my $session = $obj->get_session;

	my $r= _render_citation_aux( $obj, $session, $cstyle, $url );

	return $r;
}

sub _render_citation_aux
{
	my( $obj, $session, $node, $url ) = @_;
	my $rendered;

	if( EPrints::XML::is_dom( $node, "Text" ) ||
	    EPrints::XML::is_dom( $node, "CDataSection" ) )
	{
		my $rendered = $session->make_doc_fragment;
		my $v = $node->getData;
		my $inside = 0;
		foreach( split( '@' , $v ) )
		{
			if( $inside )
			{
				$inside = 0;
				unless( EPrints::Utils::is_set( $_ ) )
				{
					$rendered->appendChild( 
						$session->make_text( '@' ) );
					next;
				}
                                my $field = EPrints::Utils::field_from_config_string( 
					$obj->get_dataset(), 
					$_ );
				$rendered->appendChild( 
					$field->render_value( 
						$obj->get_session(),
						$obj->get_value( $field->get_name ),
						0,
 						1 ) );
				next;
			}

			$rendered->appendChild( 
				$session->make_text( $_ ) );
			$inside = 1;
		}
		return $rendered;
	}

	if( EPrints::XML::is_dom( $node, "EntityReference" ) )
	{
		my $fname = $node->getNodeName;
		my $field = $obj->get_dataset()->get_field( $fname );
		return $field->render_value( 
					$obj->get_session(),
					$obj->get_value( $fname ),
					0,
 					1 );
	}


	my $addkids = $node->hasChildNodes;

	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^ep://;

		if( $name eq "ifset" )
		{
			$rendered = $session->make_doc_fragment;
			$addkids = $obj->is_set( $node->getAttribute( "name" ) );
		}
		elsif( $name eq "ifnotset" )
		{
			$rendered = $session->make_doc_fragment;
			$addkids = !$obj->is_set( $node->getAttribute( "name" ) );
		}
		elsif( $name eq "ifmatch" || $name eq "ifnotmatch" )
		{
			my $dataset = $obj->get_dataset;

			my $fieldname = $node->getAttribute( "name" );
			my $merge = $node->getAttribute( "merge" );
			my $value = $node->getAttribute( "value" );
			my $match = $node->getAttribute( "match" );

			my @multiple_names = split /\//, $fieldname;
			my @multiple_fields;
			
			# Put the MetaFields in a list
			foreach (@multiple_names)
			{
				push @multiple_fields, EPrints::Utils::field_from_config_string( $dataset, $_ );
			}
	
			my $sf = EPrints::SearchField->new( 
				$session, 
				$dataset, 
				\@multiple_fields,
				$value,	
				$match,
				$merge );

			$addkids = $sf->item_matches( $obj );
			if( $name eq "ifnotmatch" )
			{
				$addkids = !$addkids;
			}
		}
		elsif( $name eq "iflink" )
		{
			$rendered = $session->make_doc_fragment;
			$addkids = defined $url;
		}
		elsif( $name eq "ifnotlink" )
		{
			$rendered = $session->make_doc_fragment;
			$addkids = !defined $url;
		}
		elsif( $name eq "linkhere" )
		{
			if( defined $url )
			{
				$rendered = $session->make_element( 
					"a",
					href=>EPrints::Utils::url_escape( 
						$url ) );
			}
			else
			{
				$rendered = $session->make_doc_fragment;
			}
		}
	}

	if( !defined $rendered )
	{
		$rendered = $session->clone_for_me( $node );
	}

	# icky code to spot @title@ in node attributes and replace it.
	my $attrs = $rendered->getAttributes;
	if( $attrs )
	{
		for my $i ( 0..$attrs->getLength-1 )
		{
			my $attr = $attrs->item( $i );
			my $v = $attr->getValue;
			$v =~ s/@([a-z0-9_]+)@/$obj->get_value( $1 )/egi;
			$v =~ s/@@/@/gi;
			$attr->setValue( $v );
		}
	}

	if( $addkids )
	{
		foreach my $child ( $node->getChildNodes )
		{
			$rendered->appendChild(
				_render_citation_aux( 
					$obj,
					$session,
					$child,
					$url ) );			
		}
	}
	return $rendered;
}



######################################################################
=pod

=item EPrints::Utils::field_from_config_string( $dataset, $fieldname )

undocumented

=cut
######################################################################

sub field_from_config_string
{
	my( $dataset, $fieldname ) = @_;

	my %q = ();
	if( $fieldname =~ s/^([^\.]*)\.(.*)$/$1/ )
	{
		foreach( split( /\./, $2 ) )
		{
			$q{$_}=1;
		}
	}

	my $field = $dataset->get_field( $fieldname );
	if( !defined $field )
	{
		EPrints::Config::abort( "Can't make field from config_string: $fieldname" );
	}
	if( $field->get_property( "hasid" ) )
	{
		if( $q{id} )
		{
			$field = $field->get_id_field();
		}
		else
		{
			$field = $field->get_main_field();
		
		}
	}

	foreach( "D", "M", "Y" )
	{
		if( $q{"res=".$_} )
		{
			$field = $field->clone;
			$field->set_property( "max_resolution", $_ );
		}
	}
	
	return $field;
}



######################################################################
=pod

=item EPrints::Utils::get_input( $regexp, $prompt, $default )

undocumented

=cut
######################################################################

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


######################################################################
=pod

=item EPrints::Utils::clone( $data )

undocumented

=cut
######################################################################

sub clone
{
	my( $data ) = @_;

	if( ref($data) eq "" )
	{
		return $data;
	}
	if( ref($data) eq "ARRAY" )
	{
		my $r = [];
		foreach( @{$data} )
		{
			push @{$r}, clone( $_ );
		}
		return $r;
	}
	if( ref($data) eq "HASH" )
	{
		my $r = {};
		foreach( keys %{$data} )
		{
			$r->{$_} = clone( $data->{$_} );
		}
		return $r;
	}


	# dunno
	return $data;			
}


######################################################################
=pod

=item EPrints::Utils::crypt_password( $value, $session )

undocumented

=cut
######################################################################

sub crypt_password
{
	my( $value, $session ) = @_;

	return unless EPrints::Utils::is_set( $value );

	my @saltset = ('a'..'z', 'A'..'Z', '0'..'9', '.', '/');
	my $salt = $saltset[time % 64] . $saltset[(time/64)%64];
	my $cryptpass = crypt($value ,$salt);

	return $cryptpass;
}

# Escape everything AFTER the last /

######################################################################
=pod

=item EPrints::Utils::url_escape( $url )

undocumented

=cut
######################################################################

sub url_escape
{
	my( $url ) = @_;

	my $uri = URI->new( $url );
	return $uri->as_string;
}

# Command Version: Prints the GNU style --version comment for a command
# line script. Then exits.

######################################################################
=pod

=item EPrints::Utils::cmd_version( $progname )

undocumented

=cut
######################################################################

sub cmd_version
{
	my( $progname ) = @_;

	my $version_id = $EPrints::SystemSettings::conf->{version_id};
	my $version = $EPrints::SystemSettings::conf->{version};
	
	print <<END;
$progname (GNU EPrints $version_id)
$version

Copyright (C) 2001-2002 University of Southampton

__LICENSE__
END
	exit;
}

# This code is for debugging memory leaks in objects.
# It is not used by EPrints except when developing. 
#
# 
# my %OBJARRAY = ();
# my %OBJSCORE = ();
# my %OBJPOS = ();
# my %OBJPOSR = ();
# my $c = 0;


######################################################################
=pod

=item EPrints::Utils::destroy( $ref )

undocumented

=cut
######################################################################

sub destroy
{
	my( $ref ) = @_;
#
#	my $class = delete $OBJARRAY{"$ref"};
#	my $n = delete $OBJPOS{"$ref"};
#	delete $OBJPOSR{$n};
#	
#	$OBJSCORE{$class}--;
#	print "Kill: $ref ($class) [$OBJSCORE{$class}]\n";

}

#my %OBJOLDSCORE = ();
#use Data::Dumper;
#sub debug
#{
#	my @k = sort {$b<=>$a} keys %OBJPOSR;
#	for(0..9)
#	{
#		print "=========================================\n";
#		print $OBJPOSR{$k[$_]}."\n";
#	}
#	foreach( keys %OBJSCORE ) { 
#		my $diff = $OBJSCORE{$_}-$OBJOLDSCORE{$_};
#		if( $diff > 0 ) { $diff ="+$diff"; }
#		print "$_ $OBJSCORE{$_}   $diff\n"; 
#		$OBJOLDSCORE{$_} = $OBJSCORE{$_};
#	}
#}
#
#sub bless
#{
#	my( $ref, $class ) = @_;
#
#	CORE::bless $ref, $class;
#
#	$OBJSCORE{$class}++;
#	print "Make: $ref ($class) [$OBJSCORE{$class}]\n";
#	$OBJARRAY{"$ref"}=$class;
#	$OBJPOS{"$ref"} = $c;
#	#my $x = $ref;
#	$OBJPOSR{$c} = "$c - $ref\n";
#	my $i=1;
#	my @info;
#	while( @info = caller($i++) )
#	{
#		$OBJPOSR{$c}.="$info[3] $info[2]\n";
#	}
#
#
#	if( ref( $ref ) =~ /XML::DOM/  )
#	{// to_string
#		#$OBJPOSR{$c}.= $ref->toString."\n";
#	}
#	++$c;
#
#	return $ref;
#}


######################################################################
=pod

=item $xhtml = EPrints::Utils::render_xhtml_field( $session, $field,
$value )

Return an XHTML DOM object of the contents of $value. In the case of
an error parsing the XML in $value return an XHTML DOM object 
describing the problem.

This is intented to be used by the render_single_value metadata 
field option, as an alternative to the default text renderer. 

This allows through any XML element, so could cause problems if
people start using SCRIPT to make pop-up windows. A later version
may allow a limited set of elements only.

=cut
######################################################################

sub render_xhtml_field
{
	my( $session , $field , $value ) = @_;

	if( !defined $value ) { return $session->make_doc_fragment; }
        my( %c ) = (
                ParseParamEnt => 0,
                ErrorContext => 2,
                NoLWP => 1 );

        my $doc = eval { EPrints::XML::parse_xml_string( "<fragment>".$value."</fragment>" ); };
        if( $@ )
        {
                my $err = $@;
                $err =~ s# at /.*##;
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( "Error parsing XML: ".$err ) );
		return $pre;
        }
	my $fragment = $session->make_doc_fragment;
	my $top = ($doc->getElementsByTagName( "fragment" ))[0];
	foreach my $node ( $top->getChildNodes )
	{
		$fragment->appendChild(
			$session->clone_for_me( $node, 1 ) );
	}
	EPrints::XML::dispose( $doc );
		
	return $fragment;
}
	

#
# ( $year, $month, $day ) = get_date( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#


######################################################################
=pod

=item EPrints::Utils::get_date( $time )

undocumented

=cut
######################################################################

sub get_date
{
	my( $time ) = @_;

	my @date = localtime( $time );
	my $day = $date[3];
	my $month = $date[4]+1;
	my $year = $date[5]+1900;
	
	# Ensure number of digits
	while( length $day < 2 )
	{
		$day = "0".$day;
	}

	while( length $month < 2 )
	{
		$month = "0".$month;
	}

	return( $year, $month, $day );
}


######################################################################
#
# $datestamp = get_datestamp( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#
######################################################################



######################################################################
=pod

=item EPrints::Utils::get_datestamp( $time )

undocumented

=cut
######################################################################

sub get_datestamp
{
	my( $time ) = @_;

	my( $year, $month, $day ) = EPrints::Utils::get_date( $time );

	return( $year."-".$month."-".$day );
}

######################################################################
=pod

=item $timestamp = EPrints::Utils::get_timestamp()

Return a string discribing the current local date and time.

=cut
######################################################################

sub get_timestamp
{
	my $stamp = "Error in get_timestamp";
	eval {
		use POSIX qw(strftime);
		$stamp = strftime( "%a %b %e %H:%M:%S %Z %Y", localtime);
	};	
	return $stamp;
}

######################################################################
=pod

=item $timestamp = EPrints::Utils::get_UTC_timestamp()

Return a string discribing the current local date and time. 
In UTC Format. eg:

 1957-03-20T20:30:00Z

This the UTC time, not the localtime.

=cut
######################################################################

sub get_UTC_timestamp
{
	my $stamp = "Error in get_UTC_timestamp";
	eval {
		use POSIX qw(strftime);
		$stamp = strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime);
	};
print STDERR $@;
	return $stamp;
}


######################################################################
=pod

=item $boolean = EPrints::Utils::is_in( $needles, $haystack, $matchall )

undocumented

=cut
######################################################################

sub is_in
{
	my( $needles, $haystack, $matchall ) = @_;
	
	if( $matchall )
	{
		foreach my $n ( @{$needles} )
		{
			my $found = 0;
			foreach my $h ( @{$haystack} )
			{
				$found = 1 if( $n eq $h );
			}
			return 0 unless( $found );
		}
		return 1;
	}

	foreach my $n ( @{$needles} )
	{
		foreach my $h ( @{$haystack} )
		{
			return 1 if( $n eq $h );
		}
	}
	return 0;
}

######################################################################
=pod

=item $esc_string = EPrints::Utils::escape_filename( $string )

Take a value and escape it to be a legal filename to go in the /view/
section of the site.

=cut
######################################################################

sub escape_filename
{
	my( $fileid ) = @_;

	return "NULL" if( $fileid eq "" );

	$fileid =~ s/[\s\/]/_/g; 

        return $fileid;
}

1;

######################################################################
=pod

=back

=cut
