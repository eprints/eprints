######################################################################
#
#  Site Data Validation Configuration
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################
#
#  Validation routines. EPrints does some validation itself, such as
#  checking for required fields, but you can add custom requirements
#  here.
#
#  All the validation routines should return a list of XHTML DOM 
#  objects, one per problem. An empty list means no problems.
#
#  $for_archive is a boolean flag (1 or 0) it is set to 0 when the
#  item is being validated as a submission and to 1 when the item is
#  being validated for submission to the actual archive. This allows
#  a stricter validation for editors than for submitters. A useful 
#  example would be that a deposit may have one of several format of
#  documents but the editor must ensure that it has a PDF before it
#  can be submitted into the main archive. If it doesn't have a PDF
#  file, then the editor will have to generate one.
#
#---------------------------------------------------------------------

######################################################################
#
# validate_field( $field, $value, $session, $for_archive ) 
#
######################################################################
# $field 
# - MetaField object
# $value
# - metadata value (see docs)
# $session 
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

sub validate_field
{
	my( $field, $value, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	# Ensure that a URL is valid (i.e. has the initial scheme like http:)
	if( $field->is_type( "url" ) && defined $value && $value ne "" )
	{
		$value = [$value] unless( $field->get_property( "multiple" ) );
		foreach( @{$value} )
		{
			if( $_ !~ /^\w+:/ )
			{
				push @problems,
					$session->html_phrase( "validate:missing_http",
					fieldname=>$session->make_text( $field->display_name( $session ) ) );
			}
		}
	}

	return( @problems );
}

######################################################################
#
# validate_eprint_meta( $eprint, $session, $for_archive ) 
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
# Validate just the metadata of an eprint. The validate_field method
# will have been called on each field first so only complex problems
# such as interdependancies need to be checked here.
#
######################################################################

sub validate_eprint_meta
{
	my( $eprint, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE
	
	#[ cjg NOT DONE
	# We check that if a journal article is published, then it 
	# has the volume number and page numbers.
	#if( $eprint->{type} eq "journalp" && $eprint->{ispublished} eq "pub" )
	#{
		#push @$problems, "You haven't specified any page numbers"
			#unless( defined $eprint->{pages} && $eprint->{pages} ne "" );
	#}
	#
	#if( ( $eprint->{type} eq "journalp" || $eprint->{type} eq "journale" )
		#&& $eprint->{ispublished} eq "pub" )
	#{	
		#push @$problems, "You haven't specified the volume number"
			#unless( defined $eprint->{volume} && $eprint->{volume} ne "" );
	#}

	return @problems;
}

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

	# CHECKS IN HERE

	return( @problems );
}


######################################################################
#
# validate_document_meta( $document, $session, $for_archive ) 
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
# Validate a documents metadata.
#
######################################################################


sub validate_document_meta
{
	my( $document, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	# "other" documents must have a description set
	if( $document->get_value( "format" ) eq "other" &&
	   !EPrints::Utils::is_set( $document->get_value( "formatdesc" ) ) )
	{
		push @problems, $session->html_phrase( 
					"validate:need_description" ,
					type=>$document->render_description() );
	}

	return( @problems );
}

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


sub validate_document
{
	my( $document, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
}

######################################################################
#
# validate_user( $user, $session, $for_archive ) 
#
######################################################################
# $user 
# - User object
# $session 
# - Session object (the current session)
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

sub validate_user
{
	my( $user, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
}

1;
