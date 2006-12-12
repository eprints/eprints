######################################################################
#
# validate_document( $document, $session, $for_archive ) 
#
######################################################################
# $document 
# - Document object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a document. validate_document_meta will be called auto-
# matically, so you don't need to duplicate any checks.
#
######################################################################


$c->{validate_document} = sub
{
	my( $document, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	# "other" documents must have a description set
	if( $document->get_value( "format" ) eq "other" &&
	   !EPrints::Utils::is_set( $document->get_value( "formatdesc" ) ) )
	{
		my $fieldname = $session->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $session->html_phrase( 
					"validate:need_description" ,
					type=>$document->render_description(),
					fieldname=>$fieldname );
	}

	# security can't be "public" if date embargo set
	if( $document->get_value( "security" ) eq "public" &&
		EPrints::Utils::is_set( $document->get_value( "date_embargo" ) ) )
	{
		my $fieldname = $session->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $session->html_phrase( 
					"validate:embargo_check_security" ,
					fieldname=>$fieldname );
	}

	# embargo expiry date must be in the future
	if( EPrints::Utils::is_set( $document->get_value( "date_embargo" ) ) )
	{
		my $value = $document->get_value( "date_embargo" );
		my ($thisyear, $thismonth, $thisday) = EPrints::Time::get_date_array();
		my ($year, $month, $day) = split( '-', $value );
		if( $year < $thisyear || ( $year == $thisyear && $month < $thismonth ) ||
			( $year == $thisyear && $month == $thismonth && $day <= $thisday ) )
		{
			my $fieldname = $session->make_element( "span", class=>"ep_problem_field:documents" );
			push @problems,
				$session->html_phrase( "validate:embargo_invalid_date",
				fieldname=>$fieldname );
		}
	}


	return( @problems );
};
