######################################################################
#
# EPrints Language class module
#
#  This module represents a language, and provides methods for 
#  retrieving phrases in that language (from a config file)
#
#  All errors in the Language file are in english, otherwise we could
#  get into a loop!
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


package EPrints::Language;

use EPrints::Site::General;

use XML::DOM;
use strict;

# Cache for language objects NOT attached to a config.
my %LANG_CACHE = ();

######################################################################
#
# $language = fetch( $site , $langid )
#
# Return a language from the cache. If it isn't in the cache
# attempt to load and return it.
# Returns undef if it cannot be loaded.
# Uses default language if langid is undef. [STATIC]
# $site might not be defined if this is the log language and
# therefore not of any specific site.
#
######################################################################

sub fetch
{
	my( $site , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $site->getConf( "default_language" );
	}

	my $lang = EPrints::Language->new( $langid , $site );

	return $lang;

}


######################################################################
#
# $language = new( $langid, $site )
#
# Create a new language object representing the language to use, 
# loading it from a config file.
#
# $site is optional. If it exists then the language object
# will query the site specific override files.
#
######################################################################

sub new
{
	my( $class , $langid , $site ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{id} = $langid;

	$self->{sitedata} =
		read_phrases( $site->getConf( "phrases_path" )."/".$self->{id} );

	$self->{data} =
		read_phrases( $EPrints::Site::General::lang_path."/".$self->{id} );
	
	if( $site->getConf("default_language") ne $self->{id})
	{
		$self->{fallback} = EPrints::Language::fetch( 
					$site,  
					$site->getConf("default_language") );
	}

	return( $self );
}


sub file_phrase
{
	my( $self, $file, $phraseid, $inserts, $session ) = @_;

	my( $response , $fb ) = $self->_file_phrase( $file , $phraseid , $_ );

	if( !defined $response )
	{
		$response = $session->makeText(  
				"[\"$file:$phraseid\" not defined]" );
	}
	$inserts = {} if( !defined $inserts );

	my $result;
	if( $fb )
	{
		$result = $session->make_element( "fallback" );
	}
	else
	{
		$result = $session->makeDocFragment;
	}
	$session->takeOwnership( $response );
	$result->appendChild( $response );

	foreach( $result->getElementsByTagName( "pin", 1 ) )
	{
		my $ref = $_->getAttribute( "ref" );
		print STDERR "^*^ $ref\n";
		my $repl;
		if( $inserts->{$ref} )
		{
			$repl = $inserts->{$ref};
		}
		else
		{
			$repl = $session->makeText( "[ref missing: $ref]" );
		}

		# All children remain untouched, only the PIN is
		# changed.
		for my $kid ($_->getChildNodes)
		{
			$_->removeChild( $kid );
			$repl->appendChild( $kid );
		}
		$_->getParentNode->replaceChild( $repl, $_ );	
	}

	return $result;
}


sub _file_phrase
{
	my( $self, $file, $phraseid ) = @_;

	my $res = undef;

	$res = $self->{sitedata}->{MAIN}->{$phraseid};
	return $res->cloneNode( 1 ) if ( defined $res );
	$res = $self->{sitedata}->{$file}->{$phraseid};
	return $res->cloneNode( 1 ) if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_sitedata->{MAIN}->{$phraseid};
		return ( $res->cloneNode( 1 ) , 1 ) if ( defined $res );
		$res = $self->{fallback}->_get_sitedata->{$file}->{$phraseid};
		return ( $res->cloneNode( 1 ) , 1 ) if ( defined $res );
	}

	$res = $self->{data}->{MAIN}->{$phraseid};
	return $res->cloneNode( 1 ) if ( defined $res );
	$res = $self->{data}->{$file}->{$phraseid};
	return $res->cloneNode( 1 ) if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_data->{MAIN}->{$phraseid};
		return ( $res->cloneNode( 1 ) , 1 ) if ( defined $res );
		$res = $self->{fallback}->_get_data->{$file}->{$phraseid};
		return ( $res->cloneNode( 1 ) , 1 ) if ( defined $res );
	}


	return undef;
}

sub _get_data
{
	my( $self ) = @_;
	return $self->{data};
}
sub _get_sitedata
{
	my( $self ) = @_;
	return $self->{sitedata};
}
######################################################################
#
# read_phrases( $file )
#
#  read in the phrases.
#
######################################################################

sub read_phrases
{
	my( $file ) = @_;
	

	my $parser = new XML::DOM::Parser;
	my $doc = eval {
		$parser->parsefile( $file );
	};
	if( $@ )
	{
		my $err = $@;
		$err =~ s# at /.*##;
		die "Error parsing $file\n$err";
	}
	my $phrases;
	foreach( $doc->getChildNodes )
	{
		$phrases = $_ if( $_->getNodeName eq "phrases" );
	}
	if( !defined $phrases ) 
	{
		die "Error parsing $file\nCan't find top level element.";
	}
	my $data;

	my $element;
	foreach $element ( $phrases->getChildNodes )
	{
		my $name = $element->getNodeName;
		if( $name eq "phrase" )
		{
			my $key = $element->getAttribute( "ref" );
			my $val = $doc->createDocumentFragment;
			foreach( $element->getChildNodes )
			{
				$element->removeChild( $_ );
				$val->appendChild( $_ ); 
			}
			$data->{MAIN}->{$key} = $val;
		}
		if( $name eq "file" )
		{
			my $fname = $element->getAttribute( "name" );
			my $subelement;
			foreach $subelement ( $element->getChildNodes )
			{
				unless( $subelement->getNodeName eq "phrase" )
				{
					next;
				}
				my $key = $subelement->getAttribute( "ref" );
				my $val = $doc->createDocumentFragment;
				foreach( $subelement->getChildNodes )
				{
					$subelement->removeChild( $_ );
					$val->appendChild( $_ ); 
				}
				$data->{$fname}->{$key} = $val;
			}
		}
	}

	return $data;
}

sub getID
{
	my( $self ) = @_;
	return $self->{id};
}

1;
