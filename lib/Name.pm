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

	if( $familylast )
	{
		return "$$name{given} $$name{family}";
	}
print STDERR "!sigh!\n" if (!defined $$name{given}); #cjg!!!
		
	return "$$name{family}, $$name{given}";
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
	foreach( @{$lista} ) { $texta.=":$_->{family},$_->{given}"; } 
	foreach( @{$listb} ) { $textb.=":$_->{family},$_->{given}"; } 
	return( $texta cmp $textb );
}

1;
