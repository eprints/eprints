######################################################################
#
# EPrints::DataObj::Subject
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


=pod

=head1 NAME

B<EPrints::DataObj::Subject> - Class and methods relating to the subejcts tree.

=head1 DESCRIPTION

This class represents a single node in the subejcts tree. It also
contains a number of methods for handling the entire tree.

EPrints::DataObj::Subject is a subclass of EPrints::DataObj

=over 4

=cut

package EPrints::DataObj::Subject;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

# Root subject specifier
$EPrints::DataObj::Subject::root_subject = "ROOT";

######################################################################
=pod

=item $thing = EPrints::DataObj::Subject->get_system_field_info

Return an array describing the system metadata of the Subject dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"subjectid", type=>"text", required=>1, text_index=>0, can_clone=>1, },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"name", type=>"multilang", required=>1,	multiple=>1,
			fields=>[ 
				{
            				'sub_name' => 'name',
            				'type' => 'text',
				},
			]
		},

		# should be a itemid?
		{ name=>"parents", type=>"text", required=>1, text_index=>0, 
			multiple=>1 },

		{ name=>"ancestors", type=>"text", required=>0, text_index=>0,
			multiple=>1, export_as_xml=>0 },

		{ name=>"depositable", type=>"boolean", required=>1,
			input_style=>"radio" },
	);
}


######################################################################
=pod

=item $subject = EPrints::DataObj::Subject->new( $session, $subjectid )

Create a new subject object given the id of the subject. The values
for the subject are loaded from the database.

=cut
######################################################################

sub new
{
	my( $class, $session, $subjectid ) = @_;

	if( $session->{subjects_cached} )
	{
		return $session->{subject_cache}->{$subjectid};
	}

	if( $subjectid eq $EPrints::DataObj::Subject::root_subject )
	{
		my $data = {
			subjectid => $EPrints::DataObj::Subject::root_subject,
			name => [],
			parents => [],
			ancestors => [ $EPrints::DataObj::Subject::root_subject ],
			depositable => "FALSE" 
		};
		my $name;
		foreach my $langid ( @{$session->get_repository->get_conf( "languages" )} )
		{
 			my $top_level_name = EPrints::XML::to_string( 
				$session->get_repository->get_language( $langid )->phrase( 
							"lib/subject:top_level", 
							{}, 
							$session ) );

			push @{$data->{name}}, { 
				lang => $langid,
				name => $top_level_name };
		}

		return EPrints::DataObj::Subject->new_from_data( $session, $data );
	}

	return $session->get_database->get_single( 
			$session->get_repository->get_dataset( "subject" ), 
			$subjectid );

}



######################################################################
=pod

=item $subject = EPrints::DataObj::Subject->new_from_data( $session, $data )

Construct a new subject object from a hash reference containing
the relevant fields. Generally this method is only used to construct
new Subjects coming out of the database.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "subject" ) );
}




######################################################################
=pod

=item $success = $subject->commit( [$force] )

Commit this subject to the database, but only if any fields have 
changed since we loaded it.

If $force is set then always commit, even if there appear to be no
changes.

=cut
######################################################################

sub commit 
{
	my( $self, $force ) = @_;

	my @ancestors = $self->_get_ancestors();
	$self->set_value( "ancestors", \@ancestors );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	if( $self->{non_volatile_change} )
	{
		$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	
	}

	my $rv = $self->SUPER::commit( $force );

	# Need to update all children in case ancesors have changed.
	# This is pretty slow esp. For a top level subject, but subject
	# changes will be rare and only done by admin, so mnya.
	my $child;
	foreach $child ( $self->get_children() )
	{
		$rv = $rv && $child->commit();
	}
	return $rv;
}


######################################################################
=pod

=item $success = $subject->remove

Remove this subject from the database.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	if( scalar $self->get_children() != 0 )
	{
		return( 0 );
	}

	#cjg Should we unlink all eprints linked to this subject from
	# this subject?

	return $self->{session}->get_database->remove(
		$self->{dataset},
		$self->{data}->{subjectid} );
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::Subject->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "subject";
}


######################################################################
=pod

=item EPrints::DataObj::Subject::remove_all( $session )

Static function.

Remove all subjects from the database. Use with care!

=cut
######################################################################

sub remove_all
{
	my( $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "subject" );
	my @subjects = $session->get_database->get_all( $ds );
	foreach( @subjects )
	{
		my $id = $_->get_value( "subjectid" );
		$session->get_database->remove( $ds, $id );
	}
	return;
}

	
######################################################################
# =pod
# 
# =item $subject = EPrints::DataObj::Subject::create( $session, $id, $name, $parents, $depositable )
# 
# Creates a new subject in the database. $id is the ID of the subject,
# $name is a multilang data structure with the name of the subject in
# one or more languages. eg. { en=>"Trousers", en-us=>"Pants}. $parents
# is a reference to an array containing the ID's of one or more other
# subjects (don't make loops!). If $depositable is true then eprints may
# belong to this subject.
# 
# =cut
######################################################################

sub create
{
	my( $session, $id, $name, $parents, $depositable ) = @_;

	my $actual_parents = $parents;
	$actual_parents = [ $EPrints::DataObj::Subject::root_subject ] if( !defined $parents );

	my $data = 
		{ "subjectid"=>$id,
		  "name"=>$name,
		  "parents"=>$actual_parents,
		  "ancestors"=>[],
		  "depositable"=>($depositable ? "TRUE" : "FALSE" ) };

	return EPrints::User->create_from_data( 
		$session, 
		$data,
		$session->get_repository->get_dataset( "subject" ) );
}

######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj::Subject->create_from_data( $session, $data, $dataset )
# 
# Returns undef if a bad (or no) subjectid is specified.
# 
# Otherwise calls the parent method in EPrints::DataObj.
# 
# =cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;
                           
	my $id = $data->{subjectid};                                                                                       
	unless( valid_id( $id ) )
	{
		EPrints::abort( <<END );
Error. Can't create new subject. 
The value '$id' is not a valid subject identifier.
Subject id's may not contain whitespace.
END
	}

	my $subject = $class->SUPER::create_from_data( $session, $data, $dataset );

	return unless( defined $subject );
	
	# regenerate ancestors field
	$subject->commit;

	return $subject;
}

######################################################################
# 
# $defaults = EPrints::DataObj::Subject->get_defaults( $session, $data )
#
# Return default values for this object based on the starting data.
# 
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	$data->{"rev_number"} = 1;

	return $data;
}

######################################################################
# 
# @subject_ids = $subject->_get_ancestors
#
# Get the ancestors of a given subject.
#
######################################################################

sub _get_ancestors
{
	my( $self ) = @_;

	my %ancestors;
	$ancestors{$self->{data}->{subjectid}} = 1;

	foreach my $parent ( $self->get_parents() )
	{
		foreach( $parent->_get_ancestors() )
		{
			$ancestors{$_} = 1;
		}
	}

	return keys %ancestors;
}


######################################################################
=pod

=item $child_subject = $subject->create_child( $id, $name, $depositable )

Similar to EPrints::DataObj::Subject::create, but this creates the new subject
as a child of the current subject.

=cut
######################################################################

sub create_child
{
	my( $self, $id, $name, $depositable ) = @_;

	return $self->{dataset}->create_object( $self->{session}, 	
		{ "subjectid"=>$id,
		  "name"=>$name,
		  "parents"=>[$self->{subjectid}],
		  "ancestors"=>[],
		  "depositable"=>($depositable ? "TRUE" : "FALSE" ) } );
}


######################################################################
=pod

=item @children = $subject->get_children

Return a list of EPrints::DataObj::Subject objects which are direct children
of the current subject.

=cut
######################################################################

sub get_children
{
	my( $self ) = @_;

	if( $self->{session}->{subjects_cached} )
	{
		my $subjectid = $self->get_value( "subjectid" );
		return @{$self->{session}->{subject_child_map}->{$subjectid}};
	}

	my $searchexp = EPrints::Search->new(
		session=>$self->{session},
		dataset=>$self->{dataset},
		custom_order=>"name/name_name" );
	# nb. name_name is a hack for 3.0.0 repositories which can't sort
	# on compound fields.

	$searchexp->add_field(
		$self->{dataset}->get_field( "parents" ),
		$self->get_value( "subjectid" ) );

	my $searchid = $searchexp->perform_search();
	my @children = $searchexp->get_records();
	$searchexp->dispose();

	return( @children );
}




######################################################################
=pod

=item @parents = $subject->get_parents

Return a list of EPrints::DataObj::Subject objects which are direct parents
of the current subject.

=cut
######################################################################

sub get_parents
{
	my( $self ) = @_;

	my @parents = ();
	foreach( @{$self->{data}->{parents}} )
	{
		push @parents, new EPrints::DataObj::Subject( $self->{session}, $_ );
	}
	return( @parents );
}


######################################################################
=pod

=item $boolean = $subject->can_post( [$user] )

Determines whether the given user can post in this subject.

Currently there is no way to configure subjects for certain users,
so this just returns the true or false depending on the "depositable"
flag.

=cut
######################################################################

sub can_post
{
	my( $self, $user ) = @_;

	# Depends on the subject	
	return( $self->{data}->{depositable} eq "TRUE" ? 1 : 0 );
}



######################################################################
=pod

=item $xhtml = $subject->render_with_path( $session, $topsubjid )

Return the name of this subject including it's path from $topsubjid.

$topsubjid must be an ancestor of this subject.

eg. 

Library of Congress > B Somthing > BC Somthing more Detailed

=cut
######################################################################

sub render_with_path
{
	my( $self, $session, $topsubjid ) = @_;

	my @paths = $self->get_paths( $session, $topsubjid );

	my $v = $session->make_doc_fragment();

	my $first = 1;
	foreach( @paths )
	{
		if( $first )
		{
			$first = 0;	
		}	
		else
		{
			$v->appendChild( $session->html_phrase( 
				"lib/metafield:join_subject" ) );
			# nb. using one from metafield!
		}
		my $first = 1;
		foreach( @{$_} )
		{
			if( !$first )
			{
				$v->appendChild( $session->html_phrase( 
					"lib/metafield:join_subject_parts" ) );
			}
			$first = 0;
			$v->appendChild( $_->render_description() );
		}
	}
	return $v;
}


######################################################################
=pod

=item @paths = $subject->get_paths( $session, $topsubjid )

This function returns all the paths from this subject back up to the
specified top subject.

@paths is an array of array references. Each of the inner arrays
is a list of subject id's describing a path down the tree from
$topsubjid to $session.

=cut
######################################################################

sub get_paths
{
	my( $self, $session, $topsubjid ) = @_;

	if( $self->get_value( "subjectid" ) eq $topsubjid )
	{
		# empty list, for the top level we care about
		return ([]);
	}
	if( $self->get_value( "subjectid" ) eq $EPrints::DataObj::Subject::root_subject )
	{
		return ([]);
	}
	my( @paths ) = ();
	foreach( @{$self->{data}->{parents}} )
	{
		my $subj = new EPrints::DataObj::Subject( $session, $_ );
		push @paths, $subj->get_paths( $session, $topsubjid );
	}
	foreach( @paths )
	{
		push @{$_}, $self;
	}
	return @paths;
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


######################################################################
=pod

=item $subject_pairs = $subject->get_subjects ( [$postable_only], [$show_top_level], [$nes_tids], [$no_nest_label] )

Return a reference to an array. Each item in the array is a two 
element list. 

The first element in the list is an indenifier string. 

The second element is a utf-8 string describing the subject (in the 
current language), including all the items above it in the tree, but
only as high as this subject.

The subjects which are returned are this item and all its children, 
and childrens children etc. The order is it returns 
this subject, then the first child of this subject, then children of 
that (recursively), then the second child of this subject etc.

If $postable_only is true then filter the results to only contain 
subjects which have the "depositable" flag set to true.

If $show_top_level is not true then the pair representing the current
subject is not included at the start of the list.

If $nest_ids is true then each then the ids retured are nested so
that the ids of the children of this subject are prefixed with this 
subjects id and a colon, and their children are prefixed by their 
nested id and a colon. eg. L:LC:LC003 rather than just "LC003"

if $no_nest_label is true then the subject label only contains the
name of the subject, not the higher level ones.

A default result from this method would look something like this:

  [
    [ "D", "History" ],
    [ "D1", "History: History (General)" ],
    [ "D111", "History: History (General): Medieval History" ]
 ]

=cut
######################################################################

sub get_subjects 
{
	my( $self, $postableonly, $showtoplevel, $nestids, $nonestlabel ) = @_; 

#cjg optimisation to not bother getting labels?
	$postableonly = 0 unless defined $postableonly;
	$showtoplevel = 1 unless defined $showtoplevel;
	$nestids = 0 unless defined $nestids;
	$nonestlabel = 0 unless defined $nonestlabel;
	my( $subjectmap, $rmap ) = EPrints::DataObj::Subject::get_all( $self->{session} );
	return $self->_get_subjects2( $postableonly, !$showtoplevel, $nestids, $subjectmap, $rmap, "", !$nonestlabel );
}

######################################################################
# 
# $subjects = $subject->_get_subjects2( $postableonly, $hidenode, $nestids, $subjectmap, $rmap, $prefix )
#
# Recursive function used by get_subjects.
#
######################################################################

sub _get_subjects2
{
	my( $self, $postableonly, $hidenode, $nestids, $subjectmap, $rmap, $prefix, $cascadelabel ) = @_; 

	my $depositable = $self->get_value( "depositable" );
	my $postable = (defined $depositable && $depositable eq "TRUE" ? 1 : 0 );
	my $id = $self->get_value( "subjectid" );

	my $desc = $self->render_description;
	my $label = EPrints::Utils::tree_to_utf8( $desc );
	EPrints::XML::dispose( $desc );

	my $subpairs = [];
	if( (!$postableonly || $postable) && (!$hidenode) )
	{
		if( $prefix ne "" ) { $prefix .= ":"; }
		$prefix.=$id;
		push @{$subpairs},[ ($nestids?$prefix:$id), $label ];
	}
	$prefix = "" if( $hidenode );
	foreach my $kid ( @{$rmap->{$id}} )# cjg sort on labels?
	{
		my $kidmap = $kid->_get_subjects2( 
				$postableonly, 0, $nestids, $subjectmap, $rmap, $prefix, $cascadelabel );
		if( !$cascadelabel )
		{
			push @{$subpairs}, @{$kidmap};
			next;
		}
		foreach my $pair ( @{$kidmap} )
		{
			my $label = ($hidenode?"":$label.": ").$pair->[1];
			push @{$subpairs}, [ $pair->[0], $label ];
		}
	}

	return $subpairs;
}

######################################################################
=pod

=item $label = EPrints::DataObj::Subject::subject_label( $session, $subject_id )

Return the full label of a subject, including parents. Returns
undef if the subject id is invalid.

The returned string is encoded in utf8.

=cut
######################################################################

sub subject_label
{
	my( $session, $subject_tag ) = @_;
	
	my $label = "";
	my $tag = $subject_tag;

	while( $tag ne $EPrints::DataObj::Subject::root_subject )
	{
		my $ds = $session->get_repository->get_dataset();
		my $data = $session->{database}->get_single( $ds, $tag );
		
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
			#cjg lang ": "
			$label = $data->{name} . ": " . $label;
		}
	}
	
	return( $label );
}


# cjg CACHE this per, er, session?
# commiting a subject should erase the cache

######################################################################
=pod

=item ( $subject_map, $reverse_map ) = EPrints::DataObj::Subject::get_all( $session )

Get all the subjects for the current archvive of $session.

$subject_map is a reference to a hash. The keys of the hash are
the id's of the subjects. The values of the hash are the 
EPrint::Subject object relating to that id.

$reverse_map is a reference to a hash. Each key is the id of a
subject. Each value is a reference to an array. The array contains
a EPrints::DataObj::Subject objects, one for each child of the subject 
with the id. The array is sorted by the labels for the subjects,
in the current language.

=cut
######################################################################

sub get_all
{
	my( $session ) = @_;
	
	if( $session->{subjects_cached} )
	{
		return ( $session->{subject_cache}, $session->{subject_child_map} );
	}

	# Retrieve all of the subjects
	my @subjects = $session->get_database->get_all( 
		$session->get_repository->get_dataset( "subject" ) );

	return( undef ) if( scalar @subjects == 0 );

	my( %subjectmap );
	my( %rmap );
	my $subject;
	foreach $subject (@subjects)
	{
		$subjectmap{$subject->get_value("subjectid")} = $subject;
		# iffy non oo bit here.
		# guess it's ok within the same class... (maybe)
		# works fine, just a bit naughty
		foreach( @{$subject->{data}->{parents}} )
		{
			$rmap{$_} = [] if( !defined $rmap{$_} );
			push @{$rmap{$_}}, $subject;
		}
	}
	my $namefield = $session->get_repository->get_dataset(
		"subject" )->get_field( "name" );
	foreach( keys %rmap )
	{
		@{$rmap{$_}} = sort {   
			$a->local_name cmp $b->local_name
			} @{$rmap{$_}};
	}
	
	return( \%subjectmap, \%rmap );
}

sub local_name
{
	my( $self ) = @_;

	my $lang_hash = {};
	my $value = $self->get_value( "name" );
	foreach ( @{$value} )
	{
		$lang_hash->{$_->{lang}||""} = $_->{name};
	}
	my $namefield = $self->{dataset}->get_field( "name" );

	my $r = $namefield->most_local( $self->{session}, $lang_hash );
	return "" unless defined $r;
	return $r;
}
	





######################################################################
#
# @eprints  = $subject->posted_eprints( $dataset )
#
# Deprecated. This method is no longer used by eprints, and may be 
# removed in a later release.
# 
# Return all the eprints which are in this subject (or below it in
# the tree, its children etc.) It searches all fields of type subject.
# 
# $dataset is the dataset to return eprints from.
# 
######################################################################

sub posted_eprints
{
	my( $self, $dataset ) = @_;

	my $searchexp = new EPrints::Search(
		session => $self->{session},
		dataset => $dataset,
		satisfy_all => 0 );

	my $n = 0;
	my $field;
	foreach $field ( $dataset->get_fields() )
	{
		next unless( $field->is_type( "subject" ) );
		$n += 1;
		$searchexp->add_field(
			$field,
			$self->get_value( "subjectid" ) );
	}

	if( $n == 0 )
	{
		# no actual subject fields
		return();
	}

	my $searchid = $searchexp->perform_search;
	my @data = $searchexp->get_records;
	$searchexp->dispose();

	return @data;
}

######################################################################
=pod

=item $count = $subject->count_eprints( $dataset )

Return the number of eprints in the dataset which are in this subject
or one of its decendants. Search all fields of type subject.

=cut
######################################################################

sub count_eprints
{
	my( $self, $dataset ) = @_;

	# Create a search expression
	my $searchexp = new EPrints::Search(
		satisfy_all => 0, 
		session => $self->{session},
		dataset => $dataset );

	my $n = 0;
	my $field;
	foreach $field ( $dataset->get_fields() )
	{
		next unless( $field->is_type( "subject" ) );
		$n += 1;
		$searchexp->add_field(
			$field,
			$self->get_value( "subjectid" ) );
	}

	if( $n == 0 )
	{
		# no actual subject fields
		return( 0 );
	}

	my $searchid = $searchexp->perform_search;
	my $count = $searchexp->count;
	$searchexp->dispose();

	return $count;

}

######################################################################
=pod

=item $boolean = EPrints::DataObj::Subject::valid_id( $id )

Return true if the string is an acceptable identifier for a subject.

This does not check all possible illegal values, yet.

=cut
######################################################################

sub valid_id
{
	my( $id ) = @_;

	return 0 if( $id =~ m/\s/ ); # no whitespace

	return 1;
}


# Subjects don't have a URL.
#
# sub get_url
# {
# }

# Subjects don't have a type.
#
# sub get_type
# {
# }

sub render_description
{
	my( $self ) = @_;

	return $self->render_value( "name" );
}


#deprecated

######################################################################
=pod

=item $subj->render()

undocumented

=cut
######################################################################

sub render
{
	EPrints::abort( "subjects can't be rendered. Use render_description instead." ); 
}

1;

######################################################################
=pod

=back

=cut

