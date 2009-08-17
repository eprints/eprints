######################################################################
# $field 
# - MetaField object
# $value
# - metadata value (see docs)
# $handle 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a particular field of metadata, currently used on users
# and eprints.
#
# This description should make sense on its own (i.e. should include 
# the name of the field.)
#
# The "required" field is checked elsewhere, no need to check that
# here.
#
######################################################################

$c->{validate_field} = sub
{
	my( $field, $value, $handle, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	# Loop over actual individual values to check URLs, names and emails

	if( $field->is_type( "url", "name", "email" ) && EPrints::Utils::is_set( $value ) )
	{
		$value = [$value] unless( $field->get_property( "multiple" ) );
		foreach( @{$value} )
		{
			my $v = $_;

			my $fieldname = $handle->make_element( "span", class=>"ep_problem_field:".$field->get_name );
			$fieldname->appendChild( $field->render_name( $handle ) );
			# Check a URL for correctness
			if( $field->is_type( "url" ) && $v !~ /^\w+:/ )
			{
				push @problems,
					$handle->html_phrase( "validate:missing_http",
						fieldname=>$fieldname );
			}

			# Check a name has a family part
			if( $field->is_type( "name" ) && !EPrints::Utils::is_set( $v->{family} ) )
			{
				push @problems,
					$handle->html_phrase( "validate:missing_family",
						fieldname=>$fieldname );
			}

			# Check a name has a given part
			if( $field->is_type( "name" ) && !EPrints::Utils::is_set( $v->{given} ) )
			{
				push @problems,
					$handle->html_phrase( "validate:missing_given",
						fieldname=>$fieldname );
			}

			# Check an email looks "ok". Just checks it has only one "@" and no
			# spaces.
			if( $field->is_type( "email" ) && $v !~ /^[^ \@]+\@[^ \@]+$/ )
			{
				push @problems,
					$handle->html_phrase( "validate:bad_email",
						fieldname=>$fieldname );
			}
		}
	}


	return( @problems );
};



