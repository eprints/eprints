######################################################################
#
#  Subject List class.
#
#  SubjectList objects represent lists of subject categories, and
#  provide some useful methods for manipulating them, displaying 
#  them and storing and searching them in the database.
#
#  Lists are stored externally in the following form:
#
#    :tag1:tag2:...:tagn:
#
#  The colons ':' allow easy specification of a subject searching
#  using an SQL select statement. The starting and ending colons
#  are intentionally included.
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::SubjectList;

use EPrints::Subject;

use strict;

######################################################################
#
# $subject_list = new( $string_representation )
#
#  Create a new subject list, filling in the tags from the string
#  representation from the database. Passing in undef or an empty
#  string will give an empty list.
#
######################################################################

sub new
{
	my( $class, $subjects ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{subjects} = $subjects;
	
	return( $self );
}


######################################################################
#
# @tags = get_tags()
#
#  Returns a list of the tags in this list.
#
######################################################################

sub get_tags
{
	my( $self ) = @_;
	
	return( @{$self->{subjects}} );
}


######################################################################
#
# set_tags( $tags )
#
#  Set the tags in the subject list. $tags is an array reference.
#
######################################################################

sub set_tags
{
	my( $self, $tags ) = @_;
	
	$self->{subjects} = $tags;
}


######################################################################
#
# @subjects = get_subjects( $session )
#
#  Return the subjects in the list.
#
######################################################################

sub get_subjects
{
	my( $self, $session ) = @_;
	
	my @subjects;

	foreach (@{$self->{subjects}})
	{
		my $sub = new EPrints::Subject( $session, $_ );
		
		push @subjects, $sub if( defined $sub );
		
		unless( defined $sub ) 
		{
			EPrints::Log::log_entry( "L:invalid_tag", { tag=>$_ } );
		}
	}
	
	return( @subjects );
}


######################################################################
#
# $string_representation = to_string()
#
#  Return a string representation of the list for storing in the
#  database, optimised for searching and parsing.
#
######################################################################

sub to_string
{
	my( $self ) = @_;
	
	my $t;
	my $string_rep = ":";


	foreach $t (sort @{$self->{subjects}})
	{
		$string_rep .= "$t:";
	}
	
	return( $string_rep );
}


######################################################################
#
# add_tag( $tag )
#
#  Add the given tag to the list
#
######################################################################

sub add_tag
{
	my( $self, $tag ) = @_;
	push @{$self->{subjects}}, $tag;
}

1;
