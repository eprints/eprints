######################################################################
#
#  Routines for handling names
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

package EPrints::Name;


use strict;


######################################################################
#
# $html = format_name( $namespec, $familylast )
#
#  Takes a name (a reference to a hash containing keys
#  "family" and "given" and returns it rendered 
#  for screen display.
#
######################################################################

## WP1: BAD
sub format_name
{
	my( $name, $familylast ) = @_;

	my $firstbit;
	if( defined $name->{honourific} && $name->{honourific} ne "" )
	{
		$firstbit = $name->{honourific}." ".$name->{given};
	}
	else
	{
		$firstbit = $name->{given};
	}
	
	my $secondbit;
	if( defined $name->{lineage} && $name->{lineage} ne "" )
	{
		$secondbit = $name->{family}." ".$name->{lineage};
	}
	else
	{
		$secondbit = $name->{family};
	}
	
	if( $familylast )
	{
		return $firstbit." ".$secondbit;
	}
	
	return $secondbit.", ".$firstbit;
}

######################################################################
#
# ( $cmp ) = cmp_names( $lista , $listb )
#
#  This method compares (alphabetically) two arrays of names. Passed
#  by reference.
#
######################################################################

## WP1: BAD
sub cmp_names
{
	my( $lista , $listb ) = @_;	

	my( $texta , $textb ) = ( "" , "" );
	foreach( @{$lista} ) { $texta.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	foreach( @{$listb} ) { $textb.=":$_->{family},$_->{given},$_->{honourific},$_->{lineage}"; } 
	return( $texta cmp $textb );
}

1;
