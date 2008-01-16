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

B<EPrints::Language> - A Single Language supported by a repository.

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
#     If $self is the primary language in its repository then this is
#     undef, otherwise it is a reference to the primary language
#     object.
#
#  $self->{repository_data}
#  $self->{data}
#     A reference to a hash. Keys are ids for phrases, values are
#     DOM fragments containing the phases.
#     repository_data contains repository specific phrases, data contains
#     generic eprints phrases. 
#
#  $self->{xmldoc}
#     A XML document to hold all the stray DOM elements.
#
######################################################################

package EPrints::Language;

use strict;

######################################################################
=pod

=item $language = EPrints::Language->new( $langid, $repository, [$fallback] )

Create a new language object representing the phases eprints will
use in a given language, loading them from the phrase config XML files.

$langid is the ISO language ID of the language, $repository is the 
repository to which this language object belongs. $fallback is either
undef or a reference to the main language object for the repository.

=cut
######################################################################

sub new
{
	my( $class , $langid , $repository , $fallback ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{xmldoc} = EPrints::XML::make_document();

	$self->{id} = $langid;
	
	$self->{fallback} = $fallback;

	$self->{repository_data} = $self->_read_phrases_dir(
		$repository,
		$repository->get_conf( "config_path" ).
			"/lang/".$self->{id}."/phrases" );

	if( !defined $self->{repository_data} )
	{
		return( undef );
	}

	$self->{data} = $self->_read_phrases_dir(
		$repository,
		$repository->get_conf( "lib_path" ).
			"/lang/".$self->{id}."/phrases" );

	if( !defined $self->{data} )
	{
		return( undef );
	}
	
	return( $self );
}

sub _read_phrases_dir
{
	my( $self, $repository, $dir ) = @_;

	my $dh;
	opendir( $dh, $dir ) || EPrints::abort( "Failed to read: $dir: $!" );
	my @phrase_files = ();
	while( my $fn = readdir( $dh ) )
	{
		next if $fn =~ m/^\./;
		next unless $fn =~ m/\.xml$/;
		push @phrase_files,$fn;
	}
	close $dh;

	my %phrases = ();
	foreach my $fn ( sort @phrase_files )
	{
		my $new = $self->_read_phrases( $dir."/".$fn, $repository );

		foreach( keys %{$new} ) { $phrases{$_} = $new->{$_}; }
	}
	return \%phrases;
}
	


######################################################################
=pod

=item $xhtml = $language->phrase( $phraseid, $inserts, $session )

Return an XHTML DOM structure for the phrase with the given phraseid.

The phraseid is looked for in the following order, if it's not in
one phrase file the system checks the next.

=over 4

=item This languages repository specific phrases.

=item The fallback languages repository specific phrases (if there is a fallback).

=item This languages general phrases.

=item The fallback languages general phrases (if there is a fallback).

=item Failing that it returns an XHTML DOM encoded error.

=back

If the phrase contains "pin" elements then $inserts must be a reference
to a hash. Each "pin" has a "name" attribute. For each pin there must be
a key in $inserts of the "name". The value is a XHTML DOM object which
will replace the "pin" when returing this phrase.

=cut
######################################################################

sub phrase
{
	my( $self, $phraseid, $inserts, $session ) = @_;

	# not using fb 
	my( $phrase , $fb ) = $self->_get_phrase( $phraseid, $session );

	if( !defined $phrase )
	{
		$session->get_repository->log( 
			'Undefined phrase: "'.$phraseid.'" ('.$self->{id}.')' );
		return $session->make_text( '["'.$phraseid.'" not defined]' );
	}

	$inserts = {} if( !defined $inserts );
#print STDERR "---\nN:$phrase\nNO:".$phrase->getOwnerDocument."\n";
	my $used = {};
	my $result = EPrints::XML::EPC::process_child_nodes( 
		$phrase, 
		in => "Phrase: '$phraseid'",
		session => $session, 
		pindata=>{ 
			inserts => $inserts,
			used => $used,
			phraseid => $phraseid,
		} );
	foreach( keys %{$inserts} )
	{
		if( !$used->{$_} )
		{
			# Should log this, but somtimes it's supposed to happen!
			# $session->get_repository->log( "Unused parameter \"$_\" passed to phrase \"$phraseid\"" );
			EPrints::XML::dispose( $inserts->{$_} );
		}
	}
	return $result;
}


######################################################################
# 
# ( $phrasexml, $is_fallback ) = $language->_get_phrase( $phraseid, $session )
#
# Return the phrase for the given id or undef if no phrase is defined,
# and reload the phrase from disk if needed.
#
######################################################################

sub _get_phrase
{
	my( $self, $phraseid, $session ) = @_;

	my( $phraseinfo, $srchash, $is_fallback ) = $self->_get_phraseinfo_in_memory( $phraseid, $session );

	if( !defined $phraseinfo )
	{
		return undef;
	}

	if( !defined $session->{config_file_mtime_checked}->{$phraseinfo->{file}} )
	{
		my @filestat = stat( $phraseinfo->{file} );
		my $mtime = $filestat[9];
		if( $mtime ne $phraseinfo->{mtime} )
		{
			my $new = $self->_read_phrases( $phraseinfo->{file}, $session->get_repository );
			foreach( keys %{$new} ) { $srchash->{$_} = $new->{$_}; }
			$phraseinfo = $srchash->{$phraseid};
		}
		$session->{config_file_mtime_checked}->{$phraseinfo->{file}} = 1;
	}

	return $phraseinfo->{xml};
}

######################################################################
# 
# ( $phraseinfo, $srchash, $is_fallback ) = $language->_get_phraseinfo_in_memory( $phraseid, $session )
#
# Return the phrase details for the given id or undef if no phrase is 
# defined. Details include the xml, source file and last modification
# time.
# $srchash is the hash where the phrase came from, and is_fallback is
# true if it's not the users language of preference.
#
######################################################################

sub _get_phraseinfo_in_memory
{
	my( $self, $phraseid ) = @_;

	my $res = undef;
	my $src = undef;

	# repository specific, correct language
	$src = $self->{repository_data};
	return( $src->{$phraseid}, $src , 0 ) if( defined $src->{$phraseid} );

	# repository specific, fallback language
	if( defined $self->{fallback} )
	{
		$src = $self->{fallback}->_get_repositorydata;
		return( $src->{$phraseid}, $src , 1 ) if( defined $src->{$phraseid} );
	}

	# system phrases, correct language
	$src = $self->{data};
	return( $src->{$phraseid}, $src , 0 ) if( defined $src->{$phraseid} );

	# system phrases, fallback language
	if( defined $self->{fallback} )
	{
		$src = $self->{fallback}->_get_data;
		return( $src->{$phraseid}, $src , 1 ) if( defined $src->{$phraseid} );
	}

	# no phrase found at all.
	return undef;
}

######################################################################
=pod

=item $boolean = $language->has_phrase( $phraseid, $session )

Return 1 if the phraseid is defined for this language. Return 0 if
it is only available as a fallback or unavailable.

=cut
######################################################################

sub has_phrase
{
	my( $self, $phraseid, $session ) = @_;

	my( $phrase , $fb ) = $self->_get_phrase( $phraseid, $session );

	return( defined $phrase && !$fb );
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
# $foo = $language->_get_repositorydata
#
# undocumented
#
######################################################################

sub _get_repositorydata
{
	my( $self ) = @_;
	return $self->{repository_data};
}


######################################################################
# 
#  $phrases = $language->_read_phrases( $file, $repository )
# 
# Return a reference to a hash of DOM objects describing the phrases
# from the XML phrase file $file.
# 
######################################################################

sub _read_phrases
{
	my( $self, $file, $repository ) = @_;

	my $doc=$repository->parse_xml( $file );	
	if( !defined $doc )
	{
		print STDERR "Error loading $file\n";
		return;
	}
	my @filestat = stat( $file );
	my $mtime = $filestat[9];
	my $phrases = ($doc->getElementsByTagName( "phrases" ))[0];

	if( !defined $phrases ) 
	{
		print STDERR "Error parsing $file\nCan't find top level element.";
		EPrints::XML::dispose( $doc );
		return;
	}
	my $data = {};

	my $element;
	my $warned = 1; # set to zero if we want to warn about name="" vs id=""
	my $near;
	foreach $element ( $phrases->getChildNodes )
	{
		my $name = $element->nodeName;
		if( $name eq "phrase" or $name eq "epp:phrase" )
		{
			my $key = $element->getAttribute( "id" );
			if( !defined $key || $key eq "")
			{
				$key = $element->getAttribute( "name" );
				if(  !$key || $key eq "" || !$warned )
				{
					my $warning = "Warning: in $file";
					if( defined $near ) 
					{
						$warning.=", near '$near'";
					}
					$warning.= " found phrase without 'id' attribute.";
					if( !$key || $key eq "")
					{
						$repository->log( $warning );
						next;
					}
					$repository->log( 
"$warning The phrase did have a 'name' attribute so this probably means it's an EPrints v2 phrase file." );
					$warned = 1;
				}
			}
			$near = $key;
			$data->{$key} = { xml=>$element, file=>$file, mtime=>$mtime };
		}
	}

	# Keep the document in scope...	
	$self->{docs}->{$file} = $doc;

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

