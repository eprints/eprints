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

use strict;

%EPrints::Language::languages = ();

######################################################################
#
# $language = fetch( $langid )
#
# Return a language from the cache. If it isn't in the cache
# attempt to load and return it.
# Returns undef if it cannot be loaded.
# Uses default language if langid is undef. [STATIC]
#
######################################################################

sub fetch
{
	my( $langid ) = @_;

	if ( !defined $langid )
	{
		$langid = $EPrintSite::SiteInfo::default_language;
	}

	if ( defined $EPrints::Language::languages{ $langid } )
	{
		return $EPrints::Language::languages{ $langid };
	}

	my $lang = EPrints::Language->new( $langid );

	if ( !defined $lang )
	{
		return undef;
	}

	$EPrints::Language::languages{ $langid } = $lang;

	return $lang;

}


######################################################################
#
# $language = new( )
#
# Create a new language object representing the language to use, 
# loading it from a config file.
#
######################################################################

sub new
{
	my( $class , $langid ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{id} = $langid;
	$self->{data} = {};
	$self->read_phrases();

	return( $self );
}

######################################################################
#
# $phrase = logphrase( $phraseid, @inserts )
#
# Return the phrase represented by phraseid in the language 
# of the log. [STATIC]
#
######################################################################

sub logphrase
{
	my( $phraseid, @inserts ) = @_;
	my $lang = EPrints::Language::fetch( 
		$EPrintSite::SiteInfo::log_language );
	if ( !defined $lang ) 
	{
		return "Can't fetch log language: ".
		       $EPrintSite::SiteInfo::log_language;
	}
	return $lang->phrase( $phraseid, @inserts );
}

######################################################################
#
# $phrase = phrase( $phraseid, @inserts )
#
# Return the phrase represented by phraseid in the language 
# of this object.
# Inserts the @inserts into $(1), $(2) etc...
#
######################################################################

sub phrase 
{
	my( $self , $phraseid , @inserts ) = @_;
	my @callinfo;
	@callinfo = caller();
	$callinfo[1] =~ m#[^/]+$#;
	my $file = $&;
	
	my $response = $self->{data}->{$file}->{$phraseid};
	if (defined $response)
	{
		my $i;
		for($i=0; $i<scalar @inserts; ++$i)
		{
			my $p = $i+1;
			$response =~ s/\$\($p\)/$inserts[$i]/g;
		}
		return $response;
	}
	return "[-$file:$phraseid not defined for lang ".$self->{id}."-]";
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
	my( $self ) = @_;
	
	my @inbuffer;

	my $file = $EPrintSite::SiteInfo::languages{$self->{id}};

	unless( open LANG_FILE, $file )
	{
		EPrints::Log::log_entry( "Language",
		                         "Can't open eprint language file: $file: $!" );
		return;
	}

	while( <LANG_FILE> )
	{
		chomp();
		push @inbuffer, $_;

		if( /<\/file>/i )
		{
			$self->make_file_phrases( @inbuffer );
			@inbuffer = ();
		}
	}

	close( LANG_FILE );
}


######################################################################
#
#  make_file_phrases( @lines )
#
#  Read and store all phrases in given config file lines. 
#
######################################################################

sub make_file_phrases
{
	my( $self, @lines ) = @_;

	my $filename;

	foreach (@lines)
	{
		# Get the filename out of <file filename>
		if( /<file\s+([^>\s]+)>/ )
		{
			$filename = $1;
			$self->{data}->{$filename} = {};
		}
		elsif( /<\/file>/i )
		{
			# End of the class
			return;
		}
		# Get the phrase out of a line "id = phrase";
		elsif( /^\s*([a-z0-9_]+)\s*=\s*(.*)$/i )
		{
			my ( $key , $val ) = ( $1 , $2 );
			# convert \n to actual CR's
			$val =~ s/\\n/\n/g;
			$self->{data}->{$filename}->{$key}=$val;
		}
		# Can ignore everything else
	}
}

1;
