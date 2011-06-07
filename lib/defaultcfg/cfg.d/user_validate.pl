######################################################################
#
# validate_user( $user, $repository, $for_archive ) 
#
######################################################################
# $user 
# - User object
# $repository 
# - Repository object (the current repository)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a user, although all the fields will already have been
# checked with validate_field so only complex problems need to be
# tested.
#
######################################################################

$c->{validate_user} = sub
{
	my( $user, $repository, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
};

1;
