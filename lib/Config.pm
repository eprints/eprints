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
# HEADERS cjg

#cjg SHOULD BE a way to configure an archive NOT to load the
# module except on demand (for buggy / testing ones )


# This module loads and sets information for eprints not
# specific to any archive.

package EPrints::Config;

use EPrints::SystemSettings;
use EPrints::DOM;
use Unicode::String qw(utf8 latin1);

BEGIN {
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
		die;
	}
}

my $eprints_path = $EPrints::SystemSettings::base_path;
$EPrints::Config::base_path = $eprints_path;
$EPrints::Config::cgi_path = $eprints_path."/cgi";
$EPrints::Config::cfg_path = $eprints_path."/cfg";
$EPrints::Config::phr_path = $eprints_path."/sys";
$EPrints::Config::sys_path = $eprints_path."/sys";
$EPrints::Config::bin_path = $eprints_path."/bin";

###############################################

my @LANGLIST;
my %LANGNAMES;
my $file = $EPrints::Config::cfg_path."/languages.xml";
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
opendir( CFG, $EPrints::Config::cfg_path );
while( $file = readdir( CFG ) )
{
	next unless( $file=~m/^conf-(.*)\.xml/ );
	my $fpath = $EPrints::Config::cfg_path."/".$file;
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
		$ainfo->{archiveroot}= $eprints_path."/".$ainfo->{archiveroot};
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
print "FUNCTION: $function\n";
	my $config = &{$function}( $info );

	return $config;
}

sub lang_title
{
	my( $id ) = @_;

	return $LANGNAMES{$id};
}
	
sub tree_to_utf8
{
	my( $node ) = @_;

	my $name = $node->getNodeName;
	if( $name eq "#text" || $name eq "#cdata-section")
	{
		return utf8($node->getNodeValue);
	}

	my $string = utf8("");
	foreach( $node->getChildNodes )
	{
		$string .= tree_to_utf8( $_ );
	}

	if( $name eq "fallback" )
	{
		$string = latin1("*").$string.latin1("*");
	}

	return $string;
}

1;
