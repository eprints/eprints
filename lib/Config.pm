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
use EPrints::Utils;
use EPrints::SystemSettings;
use Unicode::String qw(utf8 latin1);

use Data::Dumper;
use XML::DOM;


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
# cjg Should these be hardwired? Probably they should.
$SYSTEMCONF{cgi_path} = $SYSTEMCONF{base_path}."/cgi";
$SYSTEMCONF{cfg_path} = $SYSTEMCONF{base_path}."/cfg";
$SYSTEMCONF{arc_path} = $SYSTEMCONF{base_path}."/archives";
$SYSTEMCONF{phr_path} = $SYSTEMCONF{base_path}."/cfg";
$SYSTEMCONF{sys_path} = $SYSTEMCONF{base_path}."/cfg";
$SYSTEMCONF{bin_path} = $SYSTEMCONF{base_path}."/bin";

###############################################

my @LANGLIST;
my @SUPPORTEDLANGLIST;
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
	my $supported = ($lang_tag->getAttribute( "supported" ) eq "yes" );
	my $val = EPrints::Utils::tree_to_utf8( $lang_tag );
	push @LANGLIST,$id;
	if( $supported )
	{
		push @SUPPORTEDLANGLIST,$id;
	}
	$LANGNAMES{$id} = $val;
}
$lang_doc->dispose();

###############################################

my %ARCHIVES;
my %ARCHIVEMAP;
opendir( CFG, $SYSTEMCONF{arc_path} );
while( $file = readdir( CFG ) )
{
	next unless( $file=~m/^(.*)\.xml$/ );
	my $fpath = $SYSTEMCONF{arc_path}."/".$file;
	my $id = $1;
	my $conf_doc = parse_xml( $fpath );
	if( !defined $conf_doc )
	{
		print STDERR "Error parsing file: $fpath\n";
		next;
	}
	my $conf_tag = ($conf_doc->getElementsByTagName( "archive" ))[0];
	if( !defined $conf_tag )
	{
		print STDERR "In file: $fpath there is no <archive> tag.\n";
		$conf_doc->dispose();
		next;
	}
	if( $id ne $conf_tag->getAttribute( "id" ) )
	{
		print STDERR "In file: $fpath id is not $id\n";
		$conf_doc->dispose();
		next;
	}
	my $ainfo = {};
	foreach( keys %SYSTEMCONF ) { $ainfo->{$_} = $SYSTEMCONF{$_}; }
	my $tagname;
	foreach $tagname ( 
			"host", "urlpath", "configmodule", "port", 
			"archiveroot", "dbname", "dbhost", "dbport",
			"dbsock", "dbuser", "dbpass", "defaultlanguage",
			"adminemail" )
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
		push @{$ainfo->{aliases}},$alias;
		$ARCHIVEMAP{$alias->{name}.":".$ainfo->{port}.$ainfo->{urlpath}} = $id;
	}
	$ainfo->{languages} = [];
	foreach $tag ( $conf_tag->getElementsByTagName( "language" ) )
	{
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=$_->toString; }
		push @{$ainfo->{languages}},$val;
	}
	foreach $tag ( $conf_tag->getElementsByTagName( "archivename" ) )
	{
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=$_->toString; }
		my $langid = $tag->getAttribute( "language" );
		$ainfo->{archivename}->{$langid} = $val;
	}
	$ARCHIVES{$id} = $ainfo;
	$conf_doc->dispose();
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

sub get_supported_languages
{
	return @SUPPORTEDLANGLIST;
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

	my $parser = XML::DOM::Parser->new( %c );

	unless( open( XML, $file ) )
	{
		print STDERR "Error opening XML file: $file\n";
		return;
	}
	my $doc = eval { $parser->parse( *XML ); };
	close XML;
	if( $@ )
	{
		my $err = $@;
		$err =~ s# at /.*##;
		print STDERR "Error parsing XML $file ($err)";
		return;
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
		print STDERR "Failed to load config module for $id\nFile: $info->{configmodule}\nError: $@";
		return;
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

sub get
{
	my( $id ) = @_;

	return $SYSTEMCONF{$id};
}

1;
