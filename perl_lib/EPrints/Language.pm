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

	my( $phrase , $fb ) = $self->_phrase_aux( $phraseid );

	my $response;
	if( !defined $phrase )
	{
		$response = $session->make_doc_fragment;
		$response->appendChild( 
			 $session->make_text(  
				'["'.$phraseid.'" not defined]' ) );
		$session->get_repository->log( 
			'Undefined phrase: "'.$phraseid.'" ('.$self->{id}.')' );
if( $phraseid eq "document_fieldopt_main_Error.pm" ){ EPrints::abort("wheee");}
	}
	else
	{
		$inserts = {} if( !defined $inserts );
#print STDERR "---\nN:$phrase\nNO:".$phrase->getOwnerDocument."\n";
		my $used = {};
		$response = _insert_pins( $phrase, $session, $inserts, $used, $phraseid );
		foreach( keys %{$inserts} )
		{
			if( !$used->{$_} )
			{
				# Should log this, but somtimes it's supposed to happen!
				# $session->get_repository->log( "Unused parameter \"$_\" passed to phrase \"$phraseid\"" );
				EPrints::XML::dispose( $inserts->{$_} );
			}
		}
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

	$result->appendChild( $response );
	return $result;
}

sub _insert_pins
{
	my( $node, $session, $inserts, $used, $phraseid ) = @_;

	my $retnode;

	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^ep://;
		if( $name eq "pin" )
		{
			my $name = $node->getAttribute( "name" );
			my $repl;
			if( defined $inserts->{$name} )
			{
				if( $used->{$name} )
				{
					$retnode = EPrints::XML::clone_node( 
						$inserts->{$name}, 1 );
				}
				else
				{
					$retnode = $inserts->{$name};
					$used->{$name} = 1;
				}
				# special case if the pin is a docfragment containing only 
				# one element. Sometimes this is used to pass <a> elements which
				# are going to be spanning something in the phrase.
				# in this case we set retnode to that only element.
				if( EPrints::XML::is_dom( $retnode, "DocumentFragment" ) )
				{ 
					my @retkids = $retnode->getChildNodes;
					if( scalar @retkids == 1 && EPrints::XML::is_dom( $retkids[0], "Element" ))
					{
						$retnode = $retkids[0];
					}
			
				}
				
			}
			else
			{
				$retnode = $session->make_text( 
						"[name missing: $name]" );
				$session->get_repository->log(
"missing parameter \"$name\" when making phrase \"$phraseid\"" );
			}
		

		}

		if( $name eq "phrase" )
		{
			$retnode = $session->make_doc_fragment;
		}
	}

	# If the retnode was not "pin" or "phrase" element...
	if( !defined $retnode )
	{
		$retnode = $session->clone_for_me( $node, 0 );
	}

	if( EPrints::XML::is_dom( $retnode, "Text" ) )
	{
		# can't insert kids on a text node!
		# 
		# This can happen if we have a <pin> which spans
		# a range but is not set. Then the whole range
		# becomes a "not found" text node.
		return $retnode;
	}

	foreach my $kid ( $node->getChildNodes() )
	{
		$retnode->appendChild(
			_insert_pins( $kid, $session, $inserts, $used, $phraseid ) );
	}

	return $retnode;
}


######################################################################
# 
# $foo = $language->_phrase_aux( $phraseid, $session )
#
# Return the phrase for the given id or undef if no phrase is defined.
#
######################################################################

sub _phrase_aux
{
	my( $self, $phraseid ) = @_;

	my $res = undef;

	$res = $self->{repository_data}->{$phraseid};
	return( $res , 0 ) if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_repositorydata->{$phraseid};
		return ( $res , 1 ) if ( defined $res );
	}

	$res = $self->{data}->{$phraseid};
	return ( $res , 0 ) if ( defined $res );
	if( defined $self->{fallback} )
	{
		$res = $self->{fallback}->_get_data->{$phraseid};
		return ( $res , 1 ) if ( defined $res );
	}

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

	my( $phrase , $fb ) = $self->_phrase_aux( $phraseid );

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
		my $name = $element->getNodeName;
		if( $name eq "phrase" || $name eq "ep:phrase" )
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
			$data->{$key} = $element;
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

