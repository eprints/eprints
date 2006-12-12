

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

	my $all_public = 1;
	foreach my $doc ( @docs )
	{
		if( $doc->get_value( "security" ) ne "public" ) 
		{ 
			$all_public = 0; 
		}
	}

	if( !$all_public && !$eprint->is_set( "contact_email" ) )
	{
		push @problems, $session->html_phrase( "warnings:no_contact_email" );
	}
		


	return( @problems );
};
