######################################################################
#
# COMMENTME
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

#cjg SHOULD BE a way to configure an archive NOT to load the
# module except on demand (for buggy / testing ones )


# This module loads and sets information for eprints not
# specific to any archive.

package EPrints::Config;

use EPrints::SystemSettings;
use EPrints::DOM;
use Unicode::String qw(utf8 latin1);

use Data::Dumper;


BEGIN {
	# Paranoia: This may annoy people, or help them... cjg

	unless( $ENV{MOD_PERL} ) # mod_perl will probably be running as root for the main httpd.
	{
		if( (getpwuid($>))[0] ne $EPrints::SystemSettings::conf->{user})
		{
			abort( "We appear to be running as user: ".(getpwuid($>))[0]."\n"."We expect to be running as user: ".$EPrints::SystemSettings::conf->{user} );
		}
	}

	# abort($err) Defined here so modules can abort even at startup

	sub abort
	{
		my( $errmsg ) = @_;
		
		print STDERR <<END;
	
------------------------------------------------------------------
---------------- EPrints System Error ----------------------------
------------------------------------------------------------------
$errmsg
------------------------------------------------------------------
END
		$@="";
		exit;
	}
}

my %SYSTEMCONF;
foreach( keys %{$EPrints::SystemSettings::conf} )
{
	$SYSTEMCONF{$_} = $EPrints::SystemSettings::conf->{$_};
}
$SYSTEMCONF{cgi_path} = $SYSTEMCONF{base_path}."/cgi";
$SYSTEMCONF{cfg_path} = $SYSTEMCONF{base_path}."/cfg";
$SYSTEMCONF{phr_path} = $SYSTEMCONF{base_path}."/sys";
$SYSTEMCONF{sys_path} = $SYSTEMCONF{base_path}."/sys";
$SYSTEMCONF{bin_path} = $SYSTEMCONF{base_path}."/bin";

###############################################

my @LANGLIST;
my %LANGNAMES;
my $file = $SYSTEMCONF{cfg_path}."/languages.xml";
my $lang_doc = parse_xml( $file );
my $top_tag = ($lang_doc->getElementsByTagName( "languages" ))[0];
if( !defined $top_tag )
{
	EPrints::Config::abort( "Missing <languages> tag in $file" );
}
my $land_tag;
foreach $lang_tag ( $top_tag->getElementsByTagName( "lang" ) )
{
	my $id = $lang_tag->getAttribute( "id" );
	my $val = tree_to_utf8( $lang_tag );
	push @LANGLIST,$id;
	$LANGNAMES{$id} = $val;
}
$lang_doc->dispose();

###############################################

my %ARCHIVES;
my %ARCHIVEMAP;
opendir( CFG, $SYSTEMCONF{cfg_path} );
while( $file = readdir( CFG ) )
{
	next unless( $file=~m/^conf-(.*)\.xml/ );
	my $fpath = $SYSTEMCONF{cfg_path}."/".$file;
	my $id = $1;
	my $conf_doc = parse_xml( $fpath );
	my $conf_tag = ($conf_doc->getElementsByTagName( "archive" ))[0];
	if( !defined $conf_tag )
	{
		EPrints::Config::abort( "In file: $fpath there is no <archive> tag." );
	}
	if( $id ne $conf_tag->getAttribute( "id" ) )
	{
		EPrints::Config::abort( "In file: $fpath id is not $id" );
	}
	my $ainfo = {};
	foreach( keys %SYSTEMCONF ) { $ainfo->{$_} = $SYSTEMCONF{$_}; }
	my $tagname;
	foreach $tagname ( 
			"host", "urlpath", "configmodule", "port", "archiveroot",
	 		"dbname","dbhost","dbport","dbsock","dbuser","dbpass" )
	{
		my $tag = ($conf_tag->getElementsByTagName( $tagname ))[0];
		if( !defined $tag )
		{
			EPrints::Config::abort( "In file: $fpath the $tagname tag is missing." );
		}
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=$_->toString; }
		$ainfo->{$tagname} = $val;
	}
	unless( $ainfo->{archiveroot}=~m#^/# )
	{
		$ainfo->{archiveroot}= $SYSTEMCONF{base_path}."/".$ainfo->{archiveroot};
	}
	unless( $ainfo->{configmodule}=~m#^/# )
	{
		$ainfo->{configmodule}= $ainfo->{archiveroot}."/".$ainfo->{configmodule};
	}
	$ARCHIVEMAP{$ainfo->{host}.":".$ainfo->{port}.$ainfo->{urlpath}} = $id;
	$ainfo->{aliases} = [];
	foreach $tag ( $conf_tag->getElementsByTagName( "alias" ) )
	{
		my $alias = {};
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=$_->toString; }
		$alias->{name} = $val; 
		$alias->{redirect} = ( $tag->getAttribute( "redirect" ) eq "yes" );
		$ARCHIVEMAP{$alias->{name}.":".$ainfo->{port}.$ainfo->{urlpath}} = $id;
		push @{$ainfo->{aliases}},$alias;
	}
	$ARCHIVES{$id} = $ainfo;
}
closedir( CFG );

###############################################

sub get_archive_config
{
	my( $id ) = @_;

	return $ARCHIVES{$id};
}

sub get_languages
{
	return @LANGLIST;
}

sub get_id_from_host_port_path
{
	my( $hostpath ) = @_;

	foreach( keys %ARCHIVEMAP )
	{
		if( substr($hostpath,0,length($_)) eq $_ )
		{
			return $ARCHIVEMAP{$_};
		}
	}

	return undef;
}

sub get_archive_ids
{
	return keys %ARCHIVES;
}

sub parse_xml
{
	my( $file, %config ) = @_;

	my( %c ) = (
		ParseParamEnt => 1,
		ErrorContext => 2,
		NoLWP => 1 );

	foreach( keys %config ) { $c{$_}=$config{$_}; }

	my $parser = EPrints::DOM::Parser->new( %c );

	unless( open( XML, $file ) )
	{
		EPrints::Config::abort( "Error opening XML file: $file" );
	}
	my $doc = eval { $parser->parse( *XML ); };
	close XML;
	if( $@ )
	{
		my $err = $@;
		$err =~ s# at /.*##;
		EPrints::Config::abort( "Error parsing XML $file ($err)" );
	}

	return $doc;
}

sub load_archive_config_module
{
	my( $id ) = @_;

	$info = $ARCHIVES{$id};
	return unless( defined $info );
	
	eval{ require $info->{configmodule} };	

	if( $@ )
	{
		$@=~s#\nCompilation failed in require.*##;
		EPrints::Config::abort( "Failed to load config module for $id\nFile: $info->{configmodule}\nError: $@" );
	}

	my $function = "EPrints::Config::".$id."::get_conf";
	my $config = &{$function}( $info );
	return $config;
}

sub lang_title
{
	my( $id ) = @_;

	return $LANGNAMES{$id};
}

# widths smaller than about 3 may totally break, but that's
# a stupid thing to do, anyway.	
sub tree_to_utf8
{
	my( $node, $width ) = @_;

	if( defined $width )
	{
		# If we are supposed to be doing an 80 character wide display
		# then only do 79, so the last char does not force a line break.
		$width = $width - 1; 
	}

	my $name = $node->getNodeName;
	if( $name eq "#text" || $name eq "#cdata-section")
	{
		my $text = utf8( $node->getNodeValue );
		$text =~ s/[\s\r\n\t]+/ /g;
		return $text;
	}

	my $string = utf8("");
	foreach( $node->getChildNodes )
	{
		$string .= tree_to_utf8( $_, $width );
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
			while( $i<$width && defined $chars[$i] && $chars[$i] != 10 ) { ++$i; }
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
#	if( $line[$j] == 32 )
#	{
#		splice(@line,$j,0,-1);
#		++$j;
#	}
#	++$j;
#	$j=0 if( $j >= scalar @line );
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

sub get
{
	my( $id ) = @_;

	return $SYSTEMCONF{$id};
}

1;
