######################################################################
#
# EPrints Metadata Validation Module
#
#  This module is responsible for validating user input. 
#
######################################################################
#
# 22/10/99 - Created by Robert Tansley
#
######################################################################

package EPrintSite::Validate;

use strict;


######################################################################
#
# $problem = validate_user_field( $field, $value )
#   str                         MetaField  str
#
#  Validate a particular field of a user's metadata. Should return
#  undef if the field is OK, otherwise should return a textual
#  description of the problem. This description should make sense on
#  its own (i.e. should include the name of the field.)
#
#  The "required" field is checked elsewhere, no need to check that
#  here.
#
######################################################################

sub validate_user_field
{
	my( $class, $field, $value );

	my $problem;

	# CHECKS IN HERE

	return( (!defined $problem || $problem eq "" ) ? undef : $problem );
}


######################################################################
#
# $problem = validate_eprint_field( $field, $value )
#   str                         MetaField  str
#
#  Validate a particular field of an eprint's metadata. Should return
#  undef if the field is OK, otherwise should return a textual
#  description of the problem. This description should make sense on
#  its own (i.e. should include the name of the field.)
#
#  The "required" field is checked elsewhere, no need to check that
#  here.
#
######################################################################

sub validate_eprint_field
{
	my( $class, $field, $value );

	my $problem;

	# CHECKS IN HERE

	return( (!defined $problem || $problem eq "" ) ? undef : $problem );
}


######################################################################
#
# $problem = validate_subject_field( $field, $value )
#   str                            MetaField  str
#
#  Validate the subjects field of an eprint's metadata. Should return
#  undef if the field is OK, otherwise should return a textual
#  description of the problem. This description should make sense on
#  its own (i.e. should include the name of the field.)
#
#  The "required" field is checked elsewhere, no need to check that
#  here.
#
#  If you want to do anything here, you'll probably want to use the
#  EPrints::SubjectList class. Do something like:
#
#   my $list = EPrints::SubjectList->new( $value );
#   my @subject_tags = $list->get_tags();
#
######################################################################

sub validate_subject_field
{
	my( $class, $field, $value );

	my $problem;

	# CHECKS IN HERE


	return( (!defined $problem || $problem eq "" ) ? undef : $problem );
}


######################################################################
#
# validate_document( $document, $problems )
#                                array_ref
#
#  Validate the given document. $document is an EPrints::Document
#  object. $problems is a reference to an array in which any identified
#  problems with the document can be put.
#
#  Any number of problems can be put in the array but it's probably
#  best to keep the number down so the user's heart doesn't sink!
#
#  If no problems are identified and everything's fine then just
#  leave $problems alone.
#
######################################################################

sub validate_document
{
	my( $class, $document, $problems ) = @_;

	# CHECKS IN HERE
}


######################################################################
#
# validate_eprint( $eprint, $problems )
#                           array_ref
#
#  Validate a whole EPrint record. $eprint is an EPrints::EPrint object.
#  
#  Any number of problems can be put in the array but it's probably
#  best to keep the number down so the user's heart doesn't sink!
#
#  If no problems are identified and everything's fine then just
#  leave $problems alone.
#
######################################################################

sub validate_eprint
{
	my( $class, $eprint, $problems ) = @_;

	# CHECKS IN HERE
}


######################################################################
#
# validate_eprint_meta( $eprint, $problems )
#                                 array_ref
#
#  Validate the site-specific EPrints metadata. $eprint is an
#  EPrints::EPrint object.
#  
#  Any number of problems can be put in the array but it's probably
#  best to keep the number down so the user's heart doesn't sink!
#
#  If no problems are identified and everything's fine then just
#  leave $problems alone.
#
######################################################################

sub validate_eprint_meta
{
	my( $class, $eprint, $problems ) = @_;

	# CHECKS IN HERE

	# We check that if a journal article is published, then it has the volume
	# number and page numbers.
	if( $eprint->{type} eq "journalp" )
	{
		push @$problems, "You haven't specified any page numbers"
			unless( defined $eprint->{pages} && $eprint->{pages} ne "" );
	}
	
	if( $eprint->{type} eq "journalp" || $eprint->{type} eq "journale" )
	{	
		push @$problems, "You haven't specified the volume number"
			unless( defined $eprint->{volume} && $eprint->{volume} ne "" );
	}
}


1;
