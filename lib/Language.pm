######################################################################
#
# EPrints::Language
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

B<EPrints::Language> - A Single Language supported by an Archive.

=head1 DESCRIPTION

The language class handles loading the "phrase" files for a single
language. See the mail documentation for a full explanation of the
format of phrase files.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{id}
#     The ISO id of this language.
#
#  $self->{fallback}
#     If $self is the primary language in its archive then this is
#     undef, otherwise it is a reference to the primary language
#     object.
#
#  $self->{archivedata}
#  $self->{data}
#     A reference to a hash. Keys are ids for phrases, values are
#     DOM fragments containing the phases.
#     archivedata contains archive specific phrases, data contains
#     generic eprints phrases. 
#
######################################################################

package EPrints::Language;

use strict;

######################################################################
=pod

=item $language = EPrints::Language->new( $langid, $archive, [$fallback] )

Create a new language object representing the phases eprints will
use in a given language, loading them from the phrase config XML files.

$langid is the ISO language ID of the language, $archive is the 
archive to which this language object belongs. $fallback is either
undef or a reference to the main language object for the archive.

=cut
######################################################################

sub new
{
	my( $class , $langid , $archive , $fallback ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{id} = $langid;
	
	$self->{fallback} = $fallback;

	$self->{archivedata} = read_phrases( 
		$archive->get_conf( "config_path" ).
			"/phrases-".$self->{id}.".xml", 
		$archive );
	
	if( !defined  $self->{archivedata} )
	{
		return( undef );
	}

	$self->{data} = read_phrases( 
		EPrints::Config::get( "phr_path" ).
			"/system-phrases-".$self->{id}.".xml", 
		$archive );

	if( !defined  $self->{data} )
	{
		return( undef );
	}
	
	return( $self );
}



######################################################################
=pod

=item $xhtml = $language->phrase( $phraseid, $inserts, $session )

Return an XHTML DOM structure for the phrase with the given phraseid.

The phraseid is looked for in the following order, if it's not in
one phrase file the system checks the next.

=over 4

=item This languages archive specific phrases.

=item The fallback languages archives specific phrases (if there is a fallback).

=item This languages general phrases.

=item The fallback languages general phrases (if there is a fallback).

=item Failing that it returns an XHTML DOM encoded error.

=back

If the phrase contains "pin" elements then $inserts must be a reference
to a hash. Each "pin" has a "ref" attribute. For each pin there must be
a key in $inserts of the "ref". The value is a XHTML DOM object which
will replace the "pin" when returing this phrase.

=cut
######################################################################

sub phrase
{
	my( $self, $phraseid, $inserts, $session ) = @_;

	my( $response , $fb ) = $self->_phrase_aux( $phraseid , $_ );

	if( !defined $response )
	{
		$response = $session->make_text(  
			'["'.$phraseid.'" not defined]' );
		$session->get_archive()->log( 
			'Undefined phrase: "'.$phraseid.'" ('.$self->{id}.')' );
	}
	$inserts = {} if( !defined $inserts );

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
		my $repl;
		if( defined $inserts->{$ref} )
		{
			$repl = $inserts->{$ref};
		}
		else
		{
			$repl = $session->make_text( "[ref missing: $ref]" );
		}

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


######################################################################
# 
# $foo = $language->_phrase_aux( $phraseid )
#
# undocumented
#
######################################################################

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

######################################################################
# 
# $foo = $language->_get_data
#
# undocumented
#
######################################################################

sub _get_data
{
	my( $self ) = @_;
	return $self->{data};
}

######################################################################
# 
# $foo = $language->_get_archivedata
#
# undocumented
#
######################################################################

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


######################################################################
=pod

=item $phrases = EPrints::Language::read_phrases( $file, $archive )

Return a reference to a hash of DOM objects describing the phrases
from the XML phrase file $file.

=cut
######################################################################

sub read_phrases
{
	my( $file, $archive ) = @_;

	my $doc=$archive->parse_xml( $file );	
	if( !defined $doc )
	{
		return;
	}

	my $phrases = ($doc->getElementsByTagName( "phrases" ))[0];

	if( !defined $phrases ) 
	{
		print STDERR "Error parsing $file\nCan't find top level element.";
		$doc->dispose();
		return;
	}
	my $data = {};

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


######################################################################
=pod

=item $langid = $language->get_id

Return the ISO language ID of this language object.

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;
	return $self->{id};
}



1;

######################################################################
=pod

=back

=cut

