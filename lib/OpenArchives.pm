######################################################################
#
#  EPrints OpenArchives Support Module
#
#   Methods for open archives support in EPrints.
#
######################################################################
#
# $Id$
#
######################################################################

package EPrints::OpenArchives;

use EPrints::EPrint;
use EPrints::Session;

use EPrintSite::SiteRoutines;

$EPrints::OpenArchives::id_separator = ":";

######################################################################
#
# %tags = disseminate( $fullID )
#
#  Return OAMS tags corresponding to the given fullID. If the fullID
#  can't be resolved to an existing EPrint, and empty hash is returned.
#
######################################################################

sub disseminate
{
	my( $class, $fullID ) = @_;
	
	my( $arc_id, $record_id ) = split /$EPrints::OpenArchives::id_separator/,
	                            $fullID;

	# Return an error unless we have values for both archive ID and record ID,
	# and the archive identifier received matches our archive identifier.
	return( () ) unless( defined $arc_id && defined $record_id &&
		$arc_id eq $EPrintSite::SiteInfo::archive_identifier );
	
	# Create a new non-script session
	my $session = new EPrints::Session( 1 );
	
	# Try and get the EPrint
	my $eprint = new EPrints::EPrint( $session,
	                                  $EPrints::Database::table_archive,
	                                  $record_id );

	# Get the tags (get_oams_tags returns empty hash if $eprint is undefined)
	my %tags = EPrints::OpenArchives->get_oams_tags( $eprint );
	
	$session->terminate();
	
	return( %tags );
}






######################################################################
#
# %tags = get_oams_tags( $eprint )
#
#  Get OAMS tags for the given eprint.
#
######################################################################

sub get_oams_tags
{
	my( $class, $eprint) = @_;

	# If the EPrint doesn't exist, we will return the empty hash
	return( () ) unless( defined $eprint );
	
	my %tags = ();

	# Fill out the system tags

	# Date of accession (submission) - fortunately uses the same format
	$tags{accession} = $eprint->{datestamp};

	# Display ID (URL)
	$tags{displayID} = [ $eprint->static_page_url() ];

	# FullID
	$tags{fullID} = $fullID;

	# Other tags are site-specific. Delegate to site routine.
	EPrintSite::SiteRoutines->eprint_get_oams( $eprint, \%tags );

	return( %tags );
}



1;
