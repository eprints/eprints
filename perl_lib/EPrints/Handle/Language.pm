######################################################################
#
# EPrints::Handle::Render
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Handle::Render> - Render methods for EPrins::Handle

=head1 DESCRIPTION

This module provides additional methods to EPrints::Handle and is not
an object in it's own right.

=over 4

=cut

use strict;

package EPrints::Handle;


######################################################################
=pod

=item $langid = EPrints::Handle::get_language( $repository, $request )

Given an repository object and a Apache (mod_perl) request object, this
method decides what language the session should be.

First it looks at the HTTP cookie "eprints_lang", failing that it
looks at the prefered language of the request from the HTTP header,
failing that it looks at the default language for the repository.

The language ID it returns is the highest on the list that the given
eprint repository actually supports.

=cut
######################################################################

sub get_language
{
	my( $repository, $request ) = @_; #$r should not really be passed???

	my @prefs;

	# IMPORTANT! This function must not consume
	# The post request, if any.

	my $cookie = EPrints::Apache::AnApache::cookie( 
		$request,
		"eprints_lang" );
	push @prefs, $cookie if defined $cookie;

	# then look at the accept language header
	my $accept_language = EPrints::Apache::AnApache::header_in( 
				$request,
				"Accept-Language" );

	if( defined $accept_language )
	{
		# Middle choice is exact browser setting
		foreach my $browser_lang ( split( /, */, $accept_language ) )
		{
			$browser_lang =~ s/;.*$//;
			push @prefs, $browser_lang;
		}
	
		# Next choice is general browser setting (so fr-ca matches
		#	'fr' rather than default to 'en')
		foreach my $browser_lang ( split( /, */, $accept_language ) )
		{
			$browser_lang =~ s/-.*$//;
			push @prefs, $browser_lang;
		}
	}
		
	# last choice is always...	
	push @prefs, $repository->get_conf( "defaultlanguage" );

	# So, which one to use....
	my $arc_langs = $repository->get_conf( "languages" );	
	foreach my $pref_lang ( @prefs )
	{
		foreach my $langid ( @{$arc_langs} )
		{
			if( $pref_lang eq $langid )
			{
				# it's a real language id, go with it!
				return $pref_lang;
			}
		}
	}

	print STDERR <<END;
Something odd happend in the language selection code... 
Did you make a default language which is not in the list of languages?
END
	return undef;
}

######################################################################
=pod

=item $handle->change_lang( $newlangid )

Change the current language of the session. $newlangid should be a
valid country code for the current repository.

An invalid code will cause eprints to terminate with an error.

=cut
######################################################################

sub change_lang
{
	my( $self, $newlangid ) = @_;

	if( !defined $newlangid )
	{
		$newlangid = $self->{repository}->get_conf( "defaultlanguage" );
	}
	$self->{lang} = $self->{repository}->get_language( $newlangid );

	if( !defined $self->{lang} )
	{
		die "Unknown language: $newlangid, can't go on!";
		# cjg (maybe should try english first...?)
	}
}


######################################################################
=pod

=item $xhtml_phrase = $handle->html_phrase( $phraseid, %inserts )

Return an XHTML DOM object describing a phrase from the phrase files.

$phraseid is the id of the phrase to return. If the same ID appears
in both the repository-specific phrases file and the system phrases file
then the repository-specific one is used.

If the phrase contains <ep:pin> elements, then each one should have
an entry in %inserts where the key is the "ref" of the pin and the
value is an XHTML DOM object describing what the pin should be 
replaced with.

=cut
######################################################################

sub html_phrase
{
	my( $self, $phraseid , %inserts ) = @_;
	# $phraseid [ASCII] 
	# %inserts [HASH: ASCII->DOM]
	#
	# returns [DOM]	
        
	$self->{used_phrases}->{$phraseid} = 1;

	my $r = $self->{lang}->phrase( $phraseid , \%inserts , $self );
	#my $s = $self->make_element( "span", title=>$phraseid );
	#$s->appendChild( $r );
	#return $s;

	return $r;
}


######################################################################
=pod

=item $utf8_text = $handle->phrase( $phraseid, %inserts )

Performs the same function as html_phrase, but returns plain text.

All HTML elements will be removed, <br> and <p> will be converted 
into breaks in the text. <img> tags will be replaced with their 
"alt" values.

=cut
######################################################################

sub phrase
{
	my( $self, $phraseid, %inserts ) = @_;

	$self->{used_phrases}->{$phraseid} = 1;
	foreach( keys %inserts )
	{
		$inserts{$_} = $self->make_text( $inserts{$_} );
	}
        my $r = $self->{lang}->phrase( $phraseid, \%inserts , $self);
	my $string =  EPrints::Utils::tree_to_utf8( $r, 40 );
	EPrints::XML::dispose( $r );
	return $string;
}

######################################################################
=pod

=item $language = $handle->get_lang

Return the EPrints::Language object for this sessions current 
language.

=cut
######################################################################

sub get_lang
{
	my( $self ) = @_;

	return $self->{lang};
}


######################################################################
=pod

=item $langid = $handle->get_langid

Return the ID code of the current language of this session.

=cut
######################################################################

sub get_langid
{
	my( $self ) = @_;

	return $self->{lang}->get_id();
}



#cjg: should be a util? or even a property of repository?

######################################################################
=pod

=item $value = EPrints::Handle::best_language( $repository, $lang, %values )

$repository is the current repository. $lang is the prefered language.

%values contains keys which are language ids, and values which is
text or phrases in those languages, all translations of the same 
thing.

This function returns one of the values from %values based on the 
following logic:

If possible, return the value for $lang.

Otherwise, if possible return the value for the default language of
this repository.

Otherwise, if possible return the value for "en" (English).

Otherwise just return any one value.

This means that the view sees the best possible phrase. 

=cut
######################################################################

sub best_language
{
	my( $repository, $lang, %values ) = @_;

	# no options?
	return undef if( scalar keys %values == 0 );

	# The language of the current session is best
	return $values{$lang} if( defined $lang && defined $values{$lang} );

	# The default language of the repository is second best	
	my $defaultlangid = $repository->get_conf( "defaultlanguage" );
	return $values{$defaultlangid} if( defined $values{$defaultlangid} );

	# Bit of personal bias: We'll try English before we just
	# pick the first of the heap.
	return $values{en} if( defined $values{en} );

	# Anything is better than nothing.
	my $akey = (keys %values)[0];
	return $values{$akey};
}




######################################################################
=pod

=item $viewname = $handle->get_view_name( $dataset, $viewid )

Return a UTF8 encoded string containing the human readable name
of the /view/ section with the ID $viewid.

=cut
######################################################################

sub get_view_name
{
	my( $self, $dataset, $viewid ) = @_;

        return $self->phrase( 
		"viewname_".$dataset->confid()."_".$viewid );
}


1;
