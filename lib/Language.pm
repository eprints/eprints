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

use EPrintSite;

use strict;

# Cache for language objects NOT attached to a config.
%EPrints::Language::lang_cache = ();

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

	if( defined $site )
	{
		if( !defined $site->{lang_cache} )
		{
			$site->{lang_cache} = {};
		}
		if( !defined $langid )
		{
			$langid = $site->{default_language};
		}
		if ( defined $site->{lang_cache}->{ $langid } )
		{
			return $site->{lang_cache}->{ $langid };
		}
	}
	else
	{
		if ( defined $EPrints::Language::lang_cache{ $langid } )
		{
			return $EPrints::Language::lang_cache{ $langid };
		}
	}

	my $lang = EPrints::Language->new( $langid , $site );

	if ( !defined $lang )
	{
		return undef;
	}
	if( defined $site )
	{
		$site->{lang_cache}->{ $langid } = $lang;
	}
	else
	{
		$EPrints::Language::languages{ $langid } = $lang;
	}
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
	$self->{data} = {};
	$self->read_phrases();

	return( $self );
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
	my( $self , $phraseid , $inserts ) = @_;

	my @callinfo = caller();
	$callinfo[1] =~ m#[^/]+$#;
	return $self->file_phase( $& , $phraseid , $inserts );
}


sub file_phase
{
	my( $self , $file , $phraseid , $inserts ) = @_;

	if( !defined $inserts )
	{
		$inserts = {};
	}
	
	my $response = $self->{data}->{$file}->{$phraseid};
	if( defined $response )
	{
		$response =~ s/\$\(([a-z_]+)\)/$inserts->{$1}/ieg;
		return $response;
	}
	return "[- \"$file:$phraseid\" not defined for lang (".join(")(",$self->{id},values %{$inserts}).")-]";
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

	my $file = $EPrintSite::languages{$self->{id}};

	unless( open LANG_FILE, $file )
	{
		# can't translate yet...
		print STDERR "Can't open eprint language file: $file: $!";
		return;
	}

	while( <LANG_FILE> )
	{
		chomp();
		next if /^\s*#/;
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
		elsif( /^\s*([A-Z]:[A-Za-z0-9_]+)\s*=\s*(.*)$/ )
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
