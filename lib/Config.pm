######################################################################
#
# EPrints::Config
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

B<EPrints::Config> - software configuration handler

=head1 DESCRIPTION

This module handles loading the main configuration for an instance
of the eprints software - such as the list of language id's and 
the top level configurations for archives - the XML files in /archives/

=over 4

=cut

######################################################################

#cjg SHOULD BE a way to configure an archive NOT to load the
# module except on demand (for buggy / testing ones )

package EPrints::Config;
use EPrints::Utils;
use EPrints::SystemSettings;
use Unicode::String qw(utf8 latin1);

use Data::Dumper;
use XML::DOM;
use Cwd;


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
######################################################################
=pod

=item EPrints::Config::abort( $msg )

Print an error message and exit. If running under mod_perl then
print the error as a webpage and exit.

This subroutine is loaded before other modules so that it may be
used to report errors when initialising modules.

=cut
######################################################################

	sub abort
	{
		my( $errmsg ) = @_;

		my $r;
		if( $ENV{MOD_PERL} )
		{
 			$r = Apache->request();
		}
		if( defined $r )
		{
			# If we are running under MOD_PERL
			# AND this is actually a request, not startup,
			# then we should print an explanation to the
			# user in addition to logging to STDERR.

			$r->content_type( 'text/html' );
			$r->send_http_header;
			print <<END;
<html>
  <head>
    <title>EPrints System Error</title>
  </head>
  <body>
    <h1>EPrints System Error</h1>
    <p><tt>$errmsg</tt></p>
  </body>
</html>
END
		}

		
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
			"adminemail", "securehost", "securepath" )
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
	$ARCHIVEMAP{$ainfo->{host}.$ainfo->{urlpath}} = $id;
	if( EPrints::Utils::is_set( $ainfo->{securehost} ) )
	{
		$ARCHIVEMAP{$ainfo->{securehost}.$ainfo->{securepath}} = $id;
	}
	$ainfo->{aliases} = [];
	foreach $tag ( $conf_tag->getElementsByTagName( "alias" ) )
	{
		my $alias = {};
		my $val = "";
		foreach( $tag->getChildNodes ) { $val.=$_->toString; }
		$alias->{name} = $val; 
		$alias->{redirect} = ( $tag->getAttribute( "redirect" ) eq "yes" );
		push @{$ainfo->{aliases}},$alias;
		$ARCHIVEMAP{$alias->{name}.$ainfo->{urlpath}} = $id;
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



######################################################################
=pod

=item $archive = EPrints::Config::get_archive_config( $id )

Returns a hash of the basic configuration for the archive with the
given id. This hash will include the properties from SystemSettings. 

=cut
######################################################################

sub get_archive_config
{
	my( $id ) = @_;

	return $ARCHIVES{$id};
}


######################################################################
=pod

=item @languages = EPrints::Config::get_languages

Return a list of all known languages ids (from languages.xml).

=cut
######################################################################

sub get_languages
{
	return @LANGLIST;
}


######################################################################
=pod

=item @languages = EPrints::Config::get_supported_languages

Return a list of ids of all supported languages. 

EPrints does not yet formally support languages other then "en". You
have to configure others yourself. This will be fixed in a later 
version.

=cut
######################################################################

sub get_supported_languages
{
	return @SUPPORTEDLANGLIST;
}


######################################################################
=pod

=item $archiveid = EPrints::Config::get_id_from_host_and_path( $hostpath )

Return the archiveid (if any) of the archive which belongs on the 
virutal host specified by $hostpath. eg. "www.fishprints.com/perl/search"

=cut
######################################################################

sub get_id_from_host_and_path
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


######################################################################
=pod

=item @ids = EPrints::Config::get_archive_ids( get_archive_ids )

Return a list of ids of all archives belonging to this instance of
the eprints software.

=cut
######################################################################

sub get_archive_ids
{
	return keys %ARCHIVES;
}


######################################################################
=pod

=item EPrints::Config::parse_xml( $file, [%config] )

Return a DOM document describing Parse the XML file specified by $file 
with the optional additional config to XML::DOM::Parser specified 
in %config. 

In the event of an error in the XML file, report to STDERR and
return undef.

=cut
######################################################################

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


######################################################################
=pod

=item $arc_conf = EPrints::Config::load_archive_config_module( $id )

Load the full configuration for the specified archive unless the 
it has already been loaded.

Return a reference to a hash containing the full archive configuration. 

=cut
######################################################################

sub load_archive_config_module
{
	my( $id ) = @_;

	$info = $ARCHIVES{$id};
	return unless( defined $info );

	my $prev_dir = cwd;
	
	eval { 
		chdir $info->{archiveroot};
		require $info->{configmodule};
	};

	chdir $prev_dir;

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


######################################################################
=pod

=item $title = EPrints::Config::lang_title( $id )

Return the title of a given language as a UTF-8 encoded string. 

For example: "en" would return "English".

=cut
######################################################################

sub lang_title
{
	my( $id ) = @_;

	return $LANGNAMES{$id};
}


######################################################################
=pod

=item $value = EPrints::Config::get( $confitem )

Return the value of a given eprints configuration item. These
values are obtained from SystemSettings plus a few extras for
paths.

=cut
######################################################################

sub get
{
	my( $confitem ) = @_;

	return $SYSTEMCONF{$confitem};
}

1;

######################################################################
=pod

=back

=cut

