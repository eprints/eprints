# HEADERS cjg

print "EPRINTS: ".$ENV{EPRINTS_PATH}."\n";

# This module loads and sets information for eprints not
# specific to any archive.

package EPrints::Config;

use EPrints::DOM;

BEGIN {
	if( !defined $ENV{EPRINTS_PATH} )
	{
		if( $ENV{MOD_PERL} )
		{
			EPrints::Config::abort( <<END );
EPRINTS_PATH Environment variable not set.
Try adding something like this to the apache conf:
PerlSetEnv EPRINTS_PATH /opt/eprints
END
		}
		else
		{
			EPrints::Config::abort( <<END );
EPRINTS_PATH Environment variable not set.
cjg need advice!
END
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
		die;
	}


}

my $eprints_path = $ENV{EPRINTS_PATH};

$EPrints::Config::base_path = $eprints_path;
$EPrints::Config::cgi_path = $eprints_path."/cgi";
$EPrints::Config::cfg_path = $eprints_path."/cfg";
$EPrints::Config::phr_path = $eprints_path."/sys";

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
	my $val = "";
	foreach( $lang_tag->getChildNodes ) { $val.=$_->toString; }
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
	print STDERR "($file)($1)\n";
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
			"hostname", 
			"urlpath", 
			"configfile", 
			"port", 
			"archivepath" )
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
	unless( $ainfo->{archivepath}=~m#^/# )
	{
		$ainfo->{archivepath}= $eprints_path."/".$ainfo->{archivepath};
	}
	unless( $ainfo->{configfile}=~m#^/# )
	{
		$ainfo->{configfile}= $ainfo->{archivepath}."/".$ainfo->{configfile};
	}
	$ARCHIVEMAP{$ainfo->{hostname}.":".$ainfo->{port}.$ainfo->{urlpath}} = $id;
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

use Data::Dumper;
print STDERR Dumper( \%ARCHIVEMAP );

###############################################

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

sub load_archive_config_file
{
	my( $id ) = @_;

	$info = $ARCHIVES{$id};
	return unless( defined $info );
	
	eval{ require $info->{configfile} };	

	if( $@ )
	{
		$@=~s# at /.*##;
		EPrints::Config::abort( "Failed to load config module for $id\nFile: $info->{configfile}\nError: $@" );
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
	

1;
