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

## WP1: BAD
sub fetch
{
	my( $site , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $site->get_conf( "default_language" );
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

## WP1: BAD
sub new
{
	my( $class , $langid , $site ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{id} = $langid;

	$self->{sitedata} =
		read_phrases( $site->get_conf( "phrases_path" )."/".$self->{id} );

	$self->{data} =
		read_phrases( $EPrints::Site::General::lang_path."/".$self->{id} );
	
	if( $site->get_conf("default_language") ne $self->{id})
	{
		$self->{fallback} = EPrints::Language::fetch( 
					$site,  
					$site->get_conf("default_language") );
	}

	return( $self );
}


## WP1: BAD
sub phrase
{
	my( $self, $phraseid, $inserts, $session ) = @_;

	my( $response , $fb ) = $self->_phrase_aux( $phraseid , $_ );

	if( !defined $response )
	{
		$response = $session->make_text(  
				"[\"$phraseid\" not defined]" );
	}
	$inserts = {} if( !defined $inserts );

	my $result;
	if( $fb )
	{
		$result = $session->make_element( "fallback" );
	}
	else
	{
		$result = $session->make_doc_fragment;
	}
	$session->take_ownership( $response );
	$result->appendChild( $response );

	my $pin;
	foreach $pin ( $result->getElementsByTagName( "pin", 1 ) )
	{
		my $ref = $pin->getAttribute( "ref" );
		print STDERR "^*^ $ref\n";
		my $repl;
		if( $inserts->{$ref} )
		{
			$repl = $inserts->{$ref};
		}
		else
		{
			$repl = $session->make_text( "[ref missing: $ref]" );
		}
		print STDERR "= ".$repl->toString()."\n";

		# All children remain untouched, only the PIN is
		# changed.
		for my $kid ($pin->getChildNodes)
		{
			$pin->removeChild( $kid );
			$repl->appendChild( $kid );
		}
		$pin->getParentNode->replaceChild( $repl, $pin );	
		$pin->dispose();
	}

	return $result;
}


## WP1: BAD
sub _phrase_aux
{
	my( $self, $phraseid ) = @_;

	my $res = undef;

	$res = $self->{sitedata}->{$phraseid};
	return $res->cloneNode( 1 ) if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_sitedata->{$phraseid};
		return ( $res->cloneNode( 1 ) , 1 ) if ( defined $res );
	}

	$res = $self->{data}->{$phraseid};
	return $res->cloneNode( 1 ) if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_data->{$phraseid};
		return ( $res->cloneNode( 1 ) , 1 ) if ( defined $res );
	}

	return undef;
}

## WP1: BAD
sub _get_data
{
	my( $self ) = @_;
	return $self->{data};
}
## WP1: BAD
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

## WP1: BAD
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
			my $kid;
			foreach $kid ( $element->getChildNodes )
			{
				$element->removeChild( $kid );
				$val->appendChild( $kid ); 
			}
			$data->{$key} = $val;
		}
	}
	$doc->dispose();
	return $data;
}

## WP1: BAD
sub get_id
{
	my( $self ) = @_;
	return $self->{id};
}

1;
