######################################################################
#
# Subject class.
#
#  Handles the subject hierarchy.
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

package EPrints::Subject;

use EPrints::Database;
use EPrints::Log;
use EPrints::SearchExpression;

use strict;


# Root subject specifier
$EPrints::Subject::root_subject = "ROOT";

# Root subject name
$EPrints::Subject::root_subject_name = "(Top Level)";

sub get_system_field_info
{
	my( $class , $site ) = @_;

	return ( 
	{
		name=>"subjectid",
		type=>"text",
		required=>1,
		editable=>0,
		visable=>0
	},
	{
		name=>"name",
		type=>"text",
		required=>1,
		editable=>0,
		visable=>0
	},
	{
		name=>"parent",
		type=>"text",
		required=>0,
		editable=>0,
		visable=>0
	},
	{
		name=>"depositable",
		type=>"boolean",
		required=>1,
		editable=>0,
		visable=>0
	} );
}

######################################################################
#
# $subject = new( $session, $id, $row )
#
#  Create a new subject object. Can either pass in fields from the
#  database (which must be the same fields in the same order as given
#  in @EPrints::Subject::system_meta_fields, including subjectid),
#  or just the $id, in which case the database will be searched.
#
#  If both $id and $row are undefined, then the subject becomes the
#  implicit, invisible root subject, whose children are the top-level
#  subjects.
#
######################################################################

sub new
{
	my( $class, $session, $id, $known ) = @_;

	my $self;
	
	if( defined $known )
	{
		$self = $known;
	}
	elsif( !defined $id || $id eq $EPrints::Subject::root_subject )
	{
		# Create a root subject object
		$self->{subjectid} = $EPrints::Subject::root_subject;
		$self->{depositable} = "FALSE";
		$self->{name} = $EPrints::Subject::root_subject_name;
	}
	else
	{
		# Got ID, need to read stuff in from database
		return $session->{database}->get_single( "subject" , $id );

	}

	if (! defined $self->{parent} ) {
		$self->{parent} = $EPrints::Subject::root_subject;
	}
	$self->{session} = $session;
	bless $self, $class;
	return( $self );
}
	


######################################################################
#
# $subject = create_subject( $session, $id, $name, $parent, $depositable )
#
#  Creates the given subject in the database. $id is the ID of the subject,
#  $name is a suitably meaningful name in English, and $depositable is
#  a boolean specifying whether or not users can deposit articles in this
#  subject. $parent is the parent subject, which should be undef if the
#  subject is a top level subject.
#
######################################################################

sub create_subject
{
	my( $class, $session, $id, $name, $parent, $depositable ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;

	my $actual_parent = $parent;
	$actual_parent = $EPrints::Subject::root_subject
		if( !defined $parent || $parent eq "" );

	my $newsub = 
		{ "subjectid"=>$id,
		  "name"=>$name,
		  "parent"=>$actual_parent,
		  "depositable"=>($depositable ? "TRUE" : "FALSE" ) };

# cjg add_record call
	return( undef ) unless( $session->{database}->add_record( "subject", $newsub ) );

	return( new EPrints::Subject( $session, undef, $newsub ) );
}


######################################################################
#
# $subject = create_child( $id, $name, $depositable )
#
#  Create a child subject.
#
######################################################################

sub create_child
{
	my( $self, $id, $name, $depositable ) = @_;
	
	return( EPrints::Subject->create_subject( $self->{session},
	                                          $id,
	                                          $name,
	                                          $self->{subjectid},
	                                          $depositable ) );
}


######################################################################
#
# @children = children()
#
#  Retrieves the subject's children, if any. Children of the root
#  subject are the top-level subjects.
#
#  The children are ordered by name.
#
######################################################################

sub children
{
	my( $self ) = @_;
	
	my @fields = $self->{session}->{metainfo}->get_fields( "subject" );

	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		"subject" );

	$searchexp->add_field(
		$self->{session}->{metainfo}->find_table_field(
			"subject",
			"parent" ),
		"ALL:EQ:$self->{subjectid}" );

#cjg set order (it's in the site config)

	my $searchid = $searchexp->perform_search();
	my @rows = $searchexp->get_records();

	#EPrints::Log::debug( "Subject", "Children: $#{$rows}" );

	my @children;
	my $r;

	foreach $r (@rows)
	{
		my $child = new EPrints::Subject( $self->{session}, undef, $r );

		# Sort out the full label for displaying in listboxes etc.
		if( defined $self->{label} )
		{
			$child->{label} = $self->{label} . ": " . $child->{name};
		}
		else
		{
			$child->{label} = $child->{name};
		}

		#EPrints::Log::debug( "Subject", "Child: $child->{subjectid}" );
		push @children, $child;
	}
	return( @children );
}


######################################################################
#
# $subject = parent()
#
#  Returns the subject's parent. If this is called on the root subject,
#  undef is returned. If this is called on a top-level subject, the
#  root subject is returned (i.e. $subject->{subjectid} is
#  $EPrints::Subject::root_subject.)
#
######################################################################

sub parent
{
	my( $self ) = @_;
	
	return( undef ) if( $self->{subjectid} eq $EPrints::Subject::root_subject );
	
	return( new EPrints::Subject( $self->{session}, $self->{parent} ) );
}


######################################################################
#
# $boolean = can_post( $user )
#
#  Determines whether the given user can post in this subject.
#  At the moment, no user-specific stuff - each subject is just
#  a yes or no.
#
######################################################################

sub can_post
{
	my( $self, $user ) = @_;

	# Depends on the subject	
	return( $self->{depositable} eq "TRUE" ? 1 : 0 );
}


######################################################################
#
# $success = create_subject_table( $session )
#
#  Reads in the subject info from a config file and writes it to the
#  database. [STATIC]
#
######################################################################

sub create_subject_table
{
	my( $session ) = @_;
	
	# Read stuff in from the subject config file
	open SUBJECTS, $session->{site}->{subject_config} or return( 0 );

	my $success = 1;
	
	while( <SUBJECTS> )
	{
#		print "Line: $_\n";
		chomp();
		next if /^\s*#/;
		my @vals = split /:/;
		
		#EPrints::Log::debug( "Subject", "ID: $vals[0]  Name: $vals[1]  Parent: $vals[2]  Depositable: $vals[3]" );
		$success = $success &&
			( defined EPrints::Subject->create_subject( $session,
			                                            $vals[0],
			                                            $vals[1],
			                                            $vals[2],
			                                            $vals[3] ) );
	}
	
	return( $success );
}


######################################################################
#
# ( $tags, $labels ) = get_postable( $session, $user )
#
#  Returns a list of the subjects that can be posted to by $user. They
#  are returned in a tuple, the first element being a reference to an
#  array of tags (for the ordering) and the second being a reference
#  to the hash mapping tags to full names. [STATIC]
#
######################################################################

sub get_postable
{
	my( $session, $user ) = @_;

	# Get all of the subjects
	my( $subjects, $subjectmap ) = EPrints::Subject::get_all( $session );

	# For the results
	my @tags;
	my %labels;

	# Maps full label (with "path", e.g. "Psychology: Behavioural") for
	# easy sorting
	my %labelmap;
	
	# Go through all of the subjects
	foreach (@$subjects)
	{
		# If the user can post to it...
		if( !defined $user || $_->can_post( $user ) )
		{
			# Lob it in the list!
			my $lab = EPrints::Subject::subject_label_cache(
				$session,
				$_->{subjectid},
				$subjectmap );

			$labels{$_->{subjectid}} = $lab;
			$labelmap{$lab} = $_;
		}
	}
	
	# Put subjects in alphabetical order to labelmap
	foreach (sort keys %labelmap)
	{
		push @tags, $labelmap{$_}->{subjectid};
	}

	return( ( \@tags, \%labels ) );
}


######################################################################
#
# ($tags, $labels ) = all_subject_labels( $session )
#
#  Returns tags and labels for _all_ subjects, in a manner similar to
#  get_postable().
#
######################################################################

sub all_subject_labels
{
	my( $session ) = @_;
	
	return( EPrints::Subject::get_postable( $session, undef ) );
}

######################################################################
#
# $name = subject_name( $session, $subject_tag )
#
#  Return just the subjects name. Returns
#  undef if the subject tag is invalid. [STATIC]
#
######################################################################

sub subject_name
{
	my( $session, $subject_tag ) = @_;

	my $data = $session->{database}->get_single( "subject" , $subject_tag );

	# If we can't find it, the tag must be invalid.
	if( !defined $data )
	{
		return( undef );
	}

	# return the name
	return $data->{name};
}

######################################################################
#
# $label = subject_label( $session, $subject_tag )
#
#  Return the full label of a subject, including parents. Returns
#  undef if the subject tag is invalid. [STATIC]
#
######################################################################

sub subject_label
{
	my( $session, $subject_tag ) = @_;
	
	my $label = "";
	my $tag = $subject_tag;

	while( $tag ne $EPrints::Subject::root_subject )
	{
		my $data = $session->{database}->get_single( "subject", $tag );
		
		# If we can't find it, the tag must be invalid.
		if( !defined $data )
		{
			return( undef );
		}

		$tag = $data->{parent};

		if( $label eq "" )
		{
			$label = $data->{name};
		}
		else
		{
			$label = $data->{name} . ": " . $label;
		}
	}
	
	return( $label );
}


######################################################################
#
# $label = subject_label_cache( $session, $subject_tag, $subject_cache )
#
#  Return the full label of a subject, including parents. Returns
#  undef if the subject tag is invalid. This one works when you have
#  the subjects cached in a hash that maps subject ID - Subject. 
#  [STATIC]
#
######################################################################

sub subject_label_cache
{
	my( $session, $subject_tag, $subject_cache ) = @_;
	
	my $label = "";
	my $tag = $subject_tag;

	while( $tag ne $EPrints::Subject::root_subject )
	{
		my $s = $subject_cache->{$tag};

		# If we can't find it, the tag must be invalid.
		if( !defined $s )
		{
			return( undef );
		}

		$tag = $s->{parent};

		if( $label eq "" )
		{
			$label = $s->{name};
		}
		else
		{
			$label = $s->{name} . ": " . $label;
		}
	}
	
	return( $label );
}


######################################################################
#
# ($subjects, $subjectmap) = get_all( $session )
#
#  Return all of the subjects in the system. $subject is a reference
#  to an array with all the Subject objects in, and $subjectmap is a
#  hash ref that maps subject IDs to subject objects.
#
######################################################################

sub get_all
{
	my( $session ) = @_;
	
	my @fields = $session->{metainfo}->get_fields( "subject" );
	
	# Retrieve all of the subjects
	my @rows = $session->{database}->get_all( "subject" );

	return( undef ) if( scalar @rows == 0 );

	my( @subjects, %subjectmap );

		
	foreach (@rows)
	{
		push @subjects, $_;

		$subjectmap{$_->{subjectid}} = $_;

#		my $p = "get_all:";
#		foreach (@$r)
#		{
#			$p .= " $_";
#		}
#		EPrints::Log::debug( "Subject", $p );
	}
	
	return( \@subjects, \%subjectmap );
}	


######################################################################
#
# @eprints = posted_eprints( $table )
#
#  Retrieve the EPrints in this subject fields from $table. If $table
#  is unspecified, the main archive table is assumed.
#
######################################################################

sub posted_eprints
{
	my( $self, $table ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		$table );

	$searchexp->add_field(
		$self->{session}->{metainfo}->find_table_field( "archive", "subject" ),
		"ALL:EQ:$self->{subjectid}" );

	my $searchid = $searchexp->perform_search();
	my @data = $searchexp->get_records();

	return @data;
}


######################################################################
#
# $num = count_eprints( $table )
#
#  Simpler version of above function. Counts the EPrints in this
#  subject fields from $table. If $table is unspecified, the main
#  archive table is assumed.
#
######################################################################

sub count_eprints
{
	my( $self, $table ) = @_;

	# Create a search expression
	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		$table );

	$searchexp->add_field(
		$self->{session}->{metainfo}->find_table_field( "archive", "subject" ),
		"ALL:EQ:$self->{subjectid}" );

	my $searchid = $searchexp->perform_search();
	my $count = $searchexp->count();

	return $count;

}





1;
