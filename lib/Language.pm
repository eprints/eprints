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

B<EPrints::Language> - undocumented

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
#  __LICENSE__
#
######################################################################


package EPrints::Language;

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


######################################################################
=pod

=item $thing = EPrints::Language->new( $langid, $archive, $fallback )

undocumented

=cut
######################################################################

sub new
{
	my( $class , $langid , $archive , $fallback ) = @_;

	my $self = {};
	bless $self, $class;

#print STDERR "------LOADINGLANG:$langid-------\n";

	$self->{id} = $langid;
	
	$self->{fallback} = $fallback;

	$self->{archivedata} =
		read_phrases( $archive->get_conf( "config_path" )."/phrases-".$self->{id}.".xml", $archive );
	
	if( !defined  $self->{archivedata} )
	{
		return( undef );
	}

	$self->{data} =
		read_phrases( EPrints::Config::get( "phr_path" )."/system-phrases-".$self->{id}.".xml", $archive );
	if( !defined  $self->{data} )
	{
		return( undef );
	}
	
	return( $self );
}



######################################################################
=pod

=item $foo = $thing->phrase( $phraseid, $inserts, $session )

undocumented

=cut
######################################################################

sub phrase
{
	my( $self, $phraseid, $inserts, $session ) = @_;

	my( $response , $fb ) = $self->_phrase_aux( $phraseid , $_ );

	if( !defined $response )
	{
		$response = $session->make_text(  
				"[\"$phraseid\" not defined]" );
		$session->get_archive()->log( "Undefined phrase: \"$phraseid\" (".$self->{id}.")" );
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
		#print STDERR "^*^ $ref\n";
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
# $foo = $thing->_phrase_aux( $phraseid )
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
# $foo = $thing->_get_data
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
# $foo = $thing->_get_archivedata
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

=item EPrints::Language::read_phrases( $file, $archive )

undocumented

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

=item $foo = $thing->get_id

undocumented

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;
	return $self->{id};
}


######################################################################
=pod

=item $foo = $thing->DESTROY

undocumented

=cut
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}

1;

######################################################################
=pod

=back

=cut

