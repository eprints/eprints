######################################################################
#
# Subject List class.
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
# 12/01/2000 - Created by Robert Tansley
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
	my( $class, $string_representation ) = @_;
	
	my $self = {};
	bless $self, $class;

	my @subjects = ();
	$self->{subjects} = \@subjects;
	
#EPrints::Log->debug( "SubjectList", "Creating subject list from ".(defined $string_representation ? $string_representation : "undef" ));

	if( defined $string_representation )
	{
		# Parse string rep
		my @tags = split /:/, $string_representation;
		my $tag;

		foreach $tag (@tags)
		{
			# Ignore empty, since list starts and ends with : giving an empty
			# tag at the start and end
			if( $tag ne "" )
			{
				push @subjects, $tag;
#EPrints::Log->debug( "SubjectList", "Added tag $tag" );
			}
		}
	}
	
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
		
		EPrints::Log->log_entry( "SubjectList", "List contains invalid tag $_" )
			unless( defined $sub );
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
