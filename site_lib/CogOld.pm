######################################################################
#
#  Handles old CogPrints IDs.
#
######################################################################

package EPrintSite::CogOld;

use EPrints::Database;
use EPrints::Log;
use EPrints::EPrint;
use EPrints::Session;

use EPrintSite::SiteInfo;

use strict;

$EPrintSite::CogOld::idmap_filename = "/opt/eprints/old-ids.map";
%EPrintSite::CogOld::idmap = ();


######################################################################
#
# $eprint = find_eprint( $session, $old_id )
#
#  Attempts to retrieve the eprint with the given ID from old CogPrints.
#
######################################################################

sub find_eprint
{
	my( $session, $old_id ) = @_;
	
	if( scalar keys %EPrintSite::CogOld::idmap == 0 )
	{
		# Read in old IDs
		my $ok = open IDMAP, $EPrintSite::CogOld::idmap_filename;
		unless( $ok )
		{
			EPrints::Log::log_entry( "CogOld",
			                         "Failed to open list of old CogPrints IDs" );
			return( undef );
		}
		
		while( <IDMAP> )
		{
			chomp();
			my( $old_cog_id, $new_id ) = split /:/, $_;
			$EPrintSite::CogOld::idmap{$old_cog_id} = $new_id;
		}

		close IDMAP;
	}	

	# Find new ID
	if( defined $old_id && defined $EPrintSite::CogOld::idmap{$old_id} )
	{
		# Return the eprint object
		return( new EPrints::EPrint(
			$session,
			$EPrints::Database::table_archive,
			$EPrintSite::CogOld::idmap{$old_id} ) );
	}
	else
	{
		return( undef );
	}
}

1;
