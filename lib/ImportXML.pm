######################################################################
#
# cjg
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

package EPrints::ImportXML;

use EPrints::Log;
use EPrints::MetaInfo;
use XML::Parser;

# function will be called once for each object described by the XML
# file with the session handle and whatever kind of eprint object.

# this module creates an extra property of the parser, calling it
# "eprints". This is used to pass around state information including
# the session handle and the current object.

sub import_file
{
	my( $session , $filename , $function ) = @_;

	my $parser = new XML::Parser(
		Style => "Subs", 
		Handlers => { 
			Start => \&_handle_start, 
			End => \&_handle_end,
			Char => \&_handle_char 
		} );
	$parser->{eprints} = {};
	$parser->{eprints}->{session} = $session;
	$parser->{eprints}->{function} = $function;
	$parser->parsefile( $filename );
}

sub _handle_start
{
	my( $parser , $tag , %params ) = @_;

	if( $tag eq "TABLE" )
	{
		if( defined $parser->{eprints}->{table} )
		{
			$parser->xpcroak( "TABLE inside TABLE" );
		}
		$parser->{eprints}->{table} = $params{name};
		my @fields = EPrints::MetaInfo::get_fields( $params{name} );
		if( !defined @fields )
		{
			$parser->xpcroak( "unknown table: $params{name}" );
		}
		$parser->{eprints}->{fields} = {};
		foreach( @fields )
		{
			$parser->{eprints}->{fields}->{$_->{name}}=$_;
		}
		return;
	}

	if( $tag eq "RECORD" )
	{
		if( defined $parser->{eprints}->{data} )
		{
			$parser->xpcroak( "RECORD inside RECORD" );
		}
		$parser->{eprints}->{data} = {};
		return;
	}	

	if( $tag =~ m/^TEXT|YEAR|SUBJECTS|MULTITEXT|EPRINTTYPE$/)
	{
		if( defined $parser->{eprints}->{currentfield} )
		{
			$parser->xpcroak( "$tag inside other field" );
		}
		$parser->{eprints}->{currentfield} = $params{field};
		$parser->{eprints}->{currentdata} = "";
		return;
	}

	if( $tag eq "NAME" )
	{
		if( defined $parser->{eprints}->{currentfield} )
		{
			$parser->xpcroak( "$tag inside other field" );
		}
		$parser->{eprints}->{currentfield} = $params{field};
		$parser->{eprints}->{currentdata} = {};
		$parser->{eprints}->{currentspecial} = 1;
		return;
	}
	
	if( $tag =~ m/^GIVEN|FAMILY$/ )
	{
		if( !$parser->{eprints}->{currentspecial} )
		{
			$parser->xpcroak( "$tag inside wrong kind of field" );
		}
		$parser->{eprints}->{currentspecialpart} = lc $tag;
		$parser->{eprints}->{currentdata}->{lc $tag} = "";
		return;
	}

	$parser->xpcroak( "Unknown tag: $tag" );
}



sub _handle_end
{
	my ( $parser , $tag ) = @_;

	if ( $tag eq "TABLE" )
	{
		delete $parser->{eprints}->{table};
		delete $parser->{eprints}->{fields};
		return;
	}

	if ( $tag eq "RECORD" )
	{


		my $item = EPrints::Database::make_object(
			$parser->{eprints}->{session},
			$parser->{eprints}->{table},
			$parser->{eprints}->{data} );

		
		&{$parser->{eprints}->{function}}( 
			$parser->{eprints}->{session}, 
			$item );

		delete $parser->{eprints}->{data};
		return;
	}

	if( $tag =~ m/^TEXT|YEAR|SUBJECTS|MULTITEXT|EPRINTTYPE$/
		|| $tag =~ m/^NAME$/ )
	{
		if( $parser->{eprints}->{fields}->
			{$parser->{eprints}->{currentfield}}->{multiple} )
		{
			push @{ $parser->{eprints}->{data}->
				{$parser->{eprints}->{currentfield}} },
				$parser->{eprints}->{currentdata};
		} 
		else
		{
			$parser->{eprints}->{data}->{$parser->{eprints}->{currentfield}}=$parser->{eprints}->{currentdata};
		}
		delete $parser->{eprints}->{currentfield};
		delete $parser->{eprints}->{currentdata};
		delete $parser->{eprints}->{currentspecial};
		delete $parser->{eprints}->{currentspecialpart};
		return;
	}

	if( $tag =~ m/^GIVEN|FAMILY$/ )
	{
		delete $parser->{eprints}->{currentspecialpart};
		return;
	}
	$parser->xpcroak( "Unknown end tag: $tag" );
}

sub _handle_char
{
	my( $parser , $text ) = @_;

	if( !defined $parser->{eprints}->{currentdata} )
	{
		return;
	}

	if( $parser->{eprints}->{currentspecial} )
	{
		if( !defined $parser->{eprints}->{currentspecialpart} )
		{
			return;
		}
		$parser->{eprints}->{currentdata}->
			{$parser->{eprints}->{currentspecialpart}} .= $text;
	}
	else
	{	
		$parser->{eprints}->{currentdata}.= $text;
	}
	
}

1;
