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

use EPrints::Archives::General;

use strict;

# Cache for language objects NOT attached to a config.




######################################################################
#
# $language = new( $langid, $archive )
#
# Create a new language object representing the language to use, 
# loading it from a config file.
#
# $archive is optional. If it exists then the language object
# will query the site specific override files.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class , $langid , $archive , $fallback ) = @_;

	my $self = {};
	bless $self, $class;

print STDERR "------LOADINGLANG:$langid-------\n";

	$self->{id} = $langid;
	
	$self->{fallback} = $fallback;

	$self->{archivedata} =
		read_phrases( $archive->get_conf( "config_path" )."/phrases-".$self->{id}.".xml", $archive );

	$self->{data} =
		read_phrases( $EPrints::Archives::General::lang_path."/".$self->{id}.".xml", $archive );
	
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

if( $session == undef ) {
	EPrints::Session::bomb();
} 
	my $result;
	if( $fb )
	{
		$result = $session->make_element( "fallback" );
	}
	else
	{
		$result = $session->make_doc_fragment();
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

	$res = $self->{archivedata}->{$phraseid};
	return $res->cloneNode( 1 ) if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_archivedata->{$phraseid};
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
sub _get_archivedata
{
	my( $self ) = @_;
	return $self->{archivedata};
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
	my( $file, $archive ) = @_;

	my $doc=$archive->parse_xml( $file );	

	my $phrases = ($doc->getElementsByTagName( "phrases" ))[0];

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
