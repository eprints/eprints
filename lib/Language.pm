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
		if ( defined $LANG_CACHE{ $langid } )
		{
			return $LANG_CACHE{ $langid };
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
		$EPrints::Language::LANG_CACHE{ $langid } = $lang;
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

	$self->{sitedata} =
		read_phrases( $site->{phrases_path}."/".$self->{id} );

	$self->{data} =
		read_phrases( $EPrints::Site::General::lang_path."/".$self->{id} );
	
	if( $site->{default_language} ne $self->{id})
	{
		$self->{fallback} = EPrints::Language::fetch( 
					$site,  
					$site->{default_language} );
	}

	$self->{tryorder} = [];
	push @{$self->{tryorder}}, $self->{sitedata};
	if( defined $self->{fallback} )
	{
		push @{$self->{tryorder}}, $self->{fallback}->{sitedata};
	}
	push @{$self->{tryorder}}, $self->{data};
	if( defined $self->{fallback} )
	{
		push @{$self->{tryorder}}, $self->{fallback}->{data};
	}

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

	my $response = undef;
	foreach( @{$self->{tryorder}} )
	{
		$response = $_->{MAIN}->{$phraseid};
		last if( defined $response );
		$response = $_->{$file}->{$phraseid};
		last if( defined $response );
	}

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
	my( $file ) = @_;
	
	unless( open(LANG, $file) )
	{
		# can't translate yet...
		print STDERR "Can't open eprint language file: $file: $!\n";
		return {};
	}
	
	my $data = {};	

	print STDERR "opened eprint language file: $file\n";

	my $CURRENTFILE = 'MAIN';
	while( <LANG> )
	{
		chomp;
		next if /^\s*#/;
		next if /^\s*$/;
		
		if( /FILE\s*=\s*([^\s]+)/ )
		{
			$CURRENTFILE=$1;
			if( !defined $data->{$CURRENTFILE} )
			{
				$data->{$CURRENTFILE} = {};
			}
		}
		elsif( /^\s*([A-Z]:[A-Za-z0-9_]+)\s*=\s*(.*)$/ )
		{
			my ( $key , $val ) = ( $1 , $2 );
			# convert \n to actual CR's
			$val =~ s/\\n/\n/g;
			$data->{$CURRENTFILE}->{$key}=$val;
		}
		else
		{
			print STDERR "ERROR in language file: $file near:\n$_\n";
		}
	}
print STDERR "Loaded: $file\n";

	close( LANG );

	return $data;
}

1;
