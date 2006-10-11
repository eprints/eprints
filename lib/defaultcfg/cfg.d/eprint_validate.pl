

######################################################################
#
# validate_eprint( $eprint, $session, $for_archive ) 
#
######################################################################
# $field 
# - EPrint object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate the whole eprint, this is the last part of a full 
# validation so you don't need to duplicate tests in 
# validate_eprint_meta, validate_field or validate_document.
#
######################################################################

sub validate_eprint
{
	my( $eprint, $session, $for_archive ) = @_;

	my @problems = ();

	# If we don't have creators (eg. for a book) then we 
	# must have editor(s). To disable that rule, remove the 
	# following block.	
	if( !$eprint->is_set( "creators" ) && 
		!$eprint->is_set( "editors" ) )
	{
		my $fieldname = $session->make_element( "span", class=>"ep_problem_field:creators_list" );
		push @problems, $session->html_phrase( 
				"validate:need_creators_or_editors",
				fieldname=>$fieldname );
	}


	# by default we insist that each item has a sub date OR 
	# and issue date. To disable that rule, remove the 
	# following block.	
	if( !$eprint->is_set( "date_sub" ) 
		&& !$eprint->is_set( "date_issue" ) )
	{
		my $fieldname = $session->make_element( "span", class=>"ep_problem_field:date_issue" );
		push @problems, $session->html_phrase( 
					"validate:need_sub_or_issue",
					fieldname=>$fieldname );
	}

	return( @problems );
}
