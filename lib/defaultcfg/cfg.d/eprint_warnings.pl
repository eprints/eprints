

######################################################################
#
# eprint_warnings( $eprint, $session )
#
######################################################################
#
# $eprint 
# - EPrint object
# $session 
# - Session object (the current session)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
#
# Create warnings which will appear on the final deposit page but
# will not actually prevent the item being deposited.
#
# Any span tags with a class of ep_problem_field:fieldname will be
# linked to fieldname in the workflow.
#
######################################################################

$c->{eprint_warnings} = sub
{
	my( $eprint, $session ) = @_;

	my @problems = ();

	my @docs = $eprint->get_all_documents;
	if( @docs == 0 )
	{
		push @problems, $session->html_phrase( "warnings:no_documents" );
	}


	return( @problems );
};
