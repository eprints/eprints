######################################################################
#
#  Routines for handling names
#
######################################################################
#
#  1/3/2000 - Created by Robert Tansley
#  $Id$
#
######################################################################

package EPrints::Name;

use EPrints::Log;

use strict;


######################################################################
#
# $html = format_name( $namespec, $surnamelast )
#
#  Takes the raw names value $namespec and returns it in a form suitable
#  for screen display.
#
######################################################################

sub format_name
{
	my( $class, $namespec, $surnamelast ) = @_;

	my $html = "";
	my $i;

	# Get the names out of the list
	my @names = EPrints::Name->extract( $namespec );
	
	for( $i=0; $i<=$#names; $i++ )
	{
		my( $surname, $firstnames ) = @{$names[$i]};
		
		if( $i==$#names && $#names > 0 )
		{
			# If it's the last name and there's >1 name, add " and "
			$html .= " and ";
		}
		elsif( $i > 0 )
		{
			$html .= ", ";
		}
		
		if( $surnamelast )
		{
			$html .= "$firstnames $surname";
		}
		else
		{
			$html .= "$surname, $firstnames";
		}
	}

	return( $html );
}




######################################################################
#
# @namelist = $extract( $names )
#
#  Gets the names out of a name list. Returns an array of array refs.
#  Each array has two elements, the first being the SURNAME, the
#  second being the FIRST NAMES.
#
#  i.e. @nameslist = ( [ "surname1", "firstnames1" ],
#                      ["surname2", "firstnames2" ], ... )
#
######################################################################

sub extract
{
	my( $class, $names ) = @_;
	
#EPrints::Log->debug( "Name", "in: $names" );

	my( @nameslist, $i );
	
	my @namesplit = split /:/, $names;

#EPrints::Log->debug( "Name", "Split into $#namesplit (+1)" );

	
	for( $i = 1; $i<=$#namesplit; $i++ )
	{
		my( $surname, $firstnames ) = split /,/, $namesplit[$i];

#EPrints::Log->debug( "Name", "added: $surname, $firstnames" );

		push @nameslist, [ $surname, $firstnames ]
			if( defined $surname && $surname ne "" );
	}
	
	return( @nameslist );
}


######################################################################
#
# $newvalue = add_name( $oldvalue, $surname, $firstname )
#
#  Adds the given name to the list of names in $oldvalue.
#
######################################################################

sub add_name
{
	my( $class, $oldvalue, $surname, $firstname ) = @_;
	
	my $new_value = ( defined $oldvalue ? $oldvalue : ":" );

	$new_value .= "$surname,$firstname:";
	
	return( $new_value );
}


1;
