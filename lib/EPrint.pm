######################################################################
#
# EPrints EPrint class
#
#  Class representing an actual EPrint
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

package EPrints::EPrint;

use EPrints::Database;
use EPrints::MetaInfo;
use EPrintSite::SiteRoutines;

use File::Path;
use Filesys::DiskSpace;
use strict;

# Number of digits in generated ID codes
$EPrints::EPrint::id_code_digits = 8;



# Additional fields in this class:
#
#   table   - the table the EPrint appears in

#
# System field help
#
%EPrints::EPrint::help =
(
	"additional" => "If you'd like to suggest another subject or subjects for ".
		"your submission (and the archive) that are not in the above list, ".
		"then enter them here. Please specify them fully, in a manner similar ".
		"to those displayed in the above list.",
	"reasons" => "Here you can offer justification for your suggested new ".
		"subject(s).",
	"commentary" => "If your paper is a commentary on another document (or ".
		"author's response to a commentary) in the archive, please enter its ".
		"ID in this box.",
	"succeeds" => "If this document is a revised version of another document ".
		"in the archive, please enter its ID code in this box.",
	"subjects" => "Please select at least one main subject category, and ".
		"optionally up to two other subject categories you think are ".
		"appropriate for your submisson, in the list below. In some browsers ".
		"you may have to hold CTRL or SHIFT to select more than one subject.",
);

	

$EPrints::EPrint::static_page = "index.html";

sub get_system_field_info
{
	my( $class , $site ) = @_;

	return ( 
	{
		name=>"eprintid",
		type=>"text",
		required=>1,
		editable=>0,
		visable=>1
	},
	{
		name=>"username",
		type=>"text",
		required=>1,
		editable=>0,
		visable=>1
	},
	{
		name=>"dir",
		type=>"text",
		required=>0,
		editable=>0,
		visable=>0
	},
	{
		name=>"datestamp",
		type=>"date",
		required=>0,
		editable=>0,
		visable=>1
	},
	                                         # Subject categories. Tagged as
	                                         # "not visible" since it's a special
	                                         # case.
	{
		name=>"subjects",
		type=>"subject",
		required=>0,
		editable=>0,
		visable=>0,
		multiple=>1
	},
	{
		name=>"additional",
		type=>"text",
		required=>0,
		editable=>0,
		visable=>0
	},
	{
		name=>"reasons",
		type=>"longtext",
		required=>0,
		editable=>0,
		visable=>0,
		displaylines=>6
	},
	{
		name=>"type",
		type=>"eprinttype",
		required=>1,
		editable=>0,
		visable=>0
	},
	{
		name=>"succeeds",
		type=>"text",
		required=>0,
		editable=>0,
		visable=>0
	},
	{
		name=>"commentary",
		type=>"text",
		required=>0,
		editable=>0,
		visable=>0
	} );
}

######################################################################
#
# $eprint = new( $session, $table, $id, $known )
#
#  Create an EPrint object corresponding to the given EPrint. If
#  $table is passed in undefined, each table will be searched.
#  To improve performance, if the fields of the EPrint are already
#  known, for example as part of a largish search, then they can be
#  passed in here (as $known, a reference to an array of rows as
#  returned by DBI->selectrow_array[ref].) This avoids the
#  need for a database access. In this case, $table MUST also be
#  passed in, and $known must contain ALL fields, including the system
#  ones.
#
######################################################################

sub new
{
	my( $class, $session, $tableid, $id, $known ) = @_;

	my $self;

	if ( !defined $known )	
	{
		if( defined $tableid )
		{
			return $session->{database}->get_single( $tableid , $id );
		}

		## Work out in which table the EPrint resides.
		## and return the eprint.
		foreach( "archive" , "inbox" , "buffer" )
		{
			$self = $session->{database}->get_single( $_, $id );
			if ( defined $self ) 
			{
				return $self;
			}
		}
		return undef;
	}

	if( defined $known )
	{
		## Rows are already known
		$self = $known;
	} else {
		$self = {};
	}
	$self->{tableid} = $tableid;
	$self->{session} = $session;

	bless $self, $class;

	return( $self );
}
	

######################################################################
#
# $eprint = create( $session, $tableid, $username, $data )
#
#  Create a new EPrint entry in the given table, from the given user.
#
#  If data is defined, then this is used as the base for the
#  new record.
#
######################################################################

sub create
{
	my( $session, $tableid, $username, $data ) = @_;

	my $new_eprint = ( defined $data ? $data : {} );

	my $new_id = _create_id( $session );
	my $dir = _create_directory( $session, $new_id );
print STDERR "($new_id)($dir)\n";
	return( undef ) if( !defined $dir );

	$new_eprint->{eprintid} = $new_id;
	$new_eprint->{username} = $username;
	$new_eprint->{dir} = $dir;
	
# cjg add_record call
	my $success = $session->{database}->add_record(
		$tableid,
		$new_eprint );

	if( $success )
	{
		return( EPrints::EPrint->new( $session, $tableid, $new_id ) );
	}
	else
	{
		return( undef );
	}
}


######################################################################
#
# $new_id = _create_id( $session )
#
#  Create a new EPrint ID code.
#
######################################################################

sub _create_id
{
	my( $session ) = @_;
	
	my $new_id = $session->{database}->counter_next( "eprintid" );

	while( length $new_id < $EPrints::EPrint::id_code_digits )
	{
		$new_id = "0".$new_id;
	}

	return( $session->{site}->{eprint_id_stem} . $new_id );
}


######################################################################
#
# $directory = _create_directory( $eprint_id )
#
#  Create a directory on the local filesystem for the new document
#  with the given ID. undef is returned if it couldn't be created
#  for some reason.
#
######################################################################

sub _create_directory
{
	my( $session, $eprint_id ) = @_;
	
	# Get available directories
	opendir DOCSTORE, $session->{site}->{local_document_root}
		or return( undef );
	# The grep here just removes the "." and ".." directories
	my @avail = grep !/^\.\.?$/, readdir DOCSTORE;
	closedir DOCSTORE;
	
	# Check amount of space free on each device. We'll use the first one we find
	# (alphabetically) that has enough space on it.
	my $storedir;
	my $best_free_space = 0;
	
	foreach (sort @avail)
	{
		my $free_space = 
			(df "$session->{site}->{local_document_root}/$_" )[3];
		$best_free_space = $free_space if( $free_space > $best_free_space );

		unless( defined $storedir )
		{
			if( $free_space >= $session->{site}->{diskspace_error_threshold} )
			{
				# Enough space on this drive.
				$storedir = $_;
			}
		}
	}

	# Check that we do have a place for the new directory
	if( !defined $storedir )
	{

# cjg Need to sort out these warnings - logphrase don't work
# no more.

		# Argh! Running low on disk space overall.
		$session->mail_administrator(
			EPrints::Language::logphrase( "S:diskout_sub" ),
			EPrints::Language::logphrase( "M:diskout" ) );
		return( undef );
	}

	# Warn the administrator if we're low on space
	if( $best_free_space < $session->{site}->{diskspace_warn_threshold} )
	{
# cjg - not done this bit yet...
#
#		$session->mail_administrator(
#			EPrints::Language::logphrase( "S:disklow_sub" ),
#			EPrints::Language::logphrase( "M:disklow" ) );
	}

	# For now, just choose first
	return( undef ) if( !defined $avail[0] );
	
	# Work out the directory path. It's worked out using the ID of the EPrint.
	# It takes the numerical suffix of the ID, and divides it into four
	# components, which become the directory path for the EPrint.
	# e.g. "stem001020304" is given the path "001/02/03/04"

	return( undef ) unless( $eprint_id =~
		/$session->{site}->{eprint_id_stem}(\d+)(\d\d)(\d\d)(\d\d)/ );

	my $dir = $storedir . "/" . $1 . "/" . $2 . "/" . $3 . "/" . $4;
	
	# Full path including doc store root
	my $full_path = "$session->{site}->{local_document_root}/$dir";

	# Ensure the path is there. Dir. is made group writable.
print "($full_path)\n";
	my @created = eval
	{
		my @created = mkpath( $full_path, 0, 0775 );
		return( @created );
	};

#	foreach (@created)
#	{
#		EPrints::Log::debug( "EPrint", "Created directory $_" );
#	}

	# Error if we couldn't even create one
	if( $#created == -1 )
	{
		EPrints::Log::log_entry( 
			"L:mkdir_err" ,
				{ path=>$full_path , errmsg=>$@ } );
		return( undef );
	}

	# Return the path relative to the document store root
	return( $dir );
}





######################################################################
#
# $success = remove()
#
#  Attempts to remove this EPrint from the database.
#
######################################################################

sub remove
{
	my( $self ) = @_;

	my $success = 1;
	
	# Create a deletion record if we're removing the record from the main
	# archive
	if( $self->{tableid} eq "archive" )
	{
		$success = $success && EPrints::Deletion::add_deletion_record( $self );
	}

	# Remove the associated documents
	my @docs = $self->get_all_documents();
	
	foreach (@docs)
	{
		$success = $success && $_->remove();
		if( !$success )
		{
			EPrints::Log::log_entry( 
					"L:doc_rm_err",
					{ docid=>$_->{docid},
					errmsg=>$! } );
		}
	}

	# Now remove the directory
	my $num_deleted = rmtree( $self->local_path() );
	
	if( $num_deleted <= 0 )
	{
		EPrints::Log::log_entry(
				"L:file_rm_err", 
				{ eprintid=>$self->{eprint},
				path=>$self->local_path(),
				errmsg=>$! } );
		$success = 0;
	}

	# Remove from any threads
	$self->remove_from_threads();

	# Remove our entry from the DB
	$success = $success && $self->{session}->{database}->remove(
		$self->{tableid},
		"eprintid",
		$self->{eprintid} );
	
	return( $success );
}


######################################################################
#
# remove_from_threads()
#
#  Extracts the eprint from any threads it's in. i.e., if any other
#  paper is a later version of or commentary on this paper, the link
#  from that paper to this will be removed.
#
######################################################################

sub remove_from_threads
{
	my( $self ) = @_;
	
	if( $self->{tableid} eq  "archive" )
	{
		# Remove thread info in this eprint
		$self->{succeeds} = undef;
		$self->{commentary} = undef;
		$self->commit();

		my @related = $self->get_all_related();

		# Remove all references to this eprint
		foreach (@related)
		{
			# Update the objects if they refer to us (the objects were retrieved
			# before we unlinked ourself)
			$_->{succeeds} = undef if( $_->{succeeds} eq $self->{eprintid} );
			$_->{commentary} = undef if( $_->{commentary} eq $self->{eprintid} );

			$_->commit();
		}

		# Update static pages for each eprint
		foreach (@related)
		{
			$_->generate_static() unless( $_->{eprintid} eq $self->{eprintid} );
		}
	}
}


######################################################################
#
# $new_eprint = clone( $dest_table, $copy_documents )
#
#  Writes a clone of this EPrint to the given table, with a new ID.
#  The new EPrint is returned, or undef in the case of an error.
#  If $copy_documents is defined and non-zero, the documents will be
#  copied as well.
#
######################################################################

sub clone
{
	my( $self, $dest_tableid, $copy_documents ) = @_;
	
	# Create the new EPrint record
	my $new_eprint = EPrints::EPrint::create(
		$self->{session},
		$dest_tableid,
		$self->{username} );
	
	if( defined $new_eprint )
	{
		my $field;

		# Copy all the data across, except the ID and the datestamp
		foreach $field ($self->{session}->{metainfo}->get_table_fields( "eprint", $self->{type} ))
		{
			my $field_name = $field->{name};

			if( $field_name ne "eprintid" &&
			    $field_name ne "datestamp" &&
			    $field_name ne "dir" )
			{
				$new_eprint->{$field_name} = $self->{$field_name};
			}
		}

		# We assume the new eprint will be a later version of this one,
		# so we'll fill in the succeeds field, provided this one is
		# already in the main archive.
		$new_eprint->{succeeds} = $self->{eprintid}
			if( $self->{tableid} eq  "archive"  );

		# Attempt to copy the documents, if appropriate
		my $ok = 1;

		if( $copy_documents )
		{
			my @docs = $self->get_all_documents();

			foreach (@docs)
			{
				$ok = 0 if( !defined $_->clone( $new_eprint ) );
			}
		}

		# Now write the new EPrint to the database
		if( $ok && $new_eprint->commit() )
		{
			return( $new_eprint )
		}
		else
		{
			# Attempt to remove half-copied version
			$new_eprint->remove();
			return( undef );
		}
	}
	else
	{
		return( undef );
	}
}


######################################################################
#
# $success = transfer( $tableid )
#
#  Move the EPrint to the given table
#
######################################################################

sub transfer
{
	my( $self, $tableid ) = @_;

	# Keep the old table
	my $old_tableid = $self->{tableid};

	# Copy to the new table
	$self->{tableid} = $tableid;

	# Create an entry in the new table
# cjg add_record call
	my $success = $self->{session}->{database}->add_record(
		$tableid,
		{ "eprintid"=>$self->{eprintid} } );

	# Write self to new table
	$success =  $success && $self->commit();

	# If OK, remove the old copy
	$success = $success && $self->{session}->{database}->remove(
		$old_tableid,
		"eprintid",
		$self->{eprintid} );
	
	return( $success );
}


######################################################################
#
# $title = short_title()
#
#  Return a short title for the EPrint. Delegates to the site-specific
#  routine.
#
######################################################################

sub short_title
{
	my( $self ) = @_;

	return( EPrintSite::SiteRoutines::eprint_short_title( $self ) );
}



######################################################################
#
# $success = commit()
#
#  Commit any changes that might have been made to the database
#
######################################################################

sub commit
{
	my( $self ) = @_;
	my $success = $self->{session}->{database}->update(
		$self->{tableid},
		$self );

	if( !$success )
	{
		my $db_error = $self->{session}->{database}->error();
		EPrints::Log::log_entry(
				"error_commit",
				{ eprintid=>$self->{eprintid},
				errmsg=>$db_error } );
	}

	return( $success );
}



######################################################################
#
# $problems = validate_type
# array_ref
#
#  Make sure that the type field is OK.
#
######################################################################

sub validate_type
{
	my( $self ) = @_;
	
	my @problems;

	# Make sure we have a value for the type, and that it's one of the
	# configured EPrint types
	if( !defined $self->{type} || $self->{type} eq "" )
	{
		push @problems, $self->{session}->{lang}->phrase( "H:no_type" );
	}
	elsif( !defined $self->{session}->{metainfo}->get_table_type_name( "eprintid", $self->{type} ) )
	{
		push @problems, $self->{session}->{lang}->phrase( "H:invalid_type" );
	}
	
	return( \@problems );
}



######################################################################
#
# @problems = validate_meta()
#  array_ref
#
#  Validate the metadata in this EPrint, returning a hash of any
#  problems found (fieldname->problem).
#
######################################################################

sub validate_meta
{
	my( $self ) = @_;
	
	my @all_problems;
	my @all_fields = $self->{session}->{metainfo}->get_table_fields( "eprint", $self->{type} );
	my $field;
	
	foreach $field (@all_fields)
	{
		my $problem;
		
		# Check that the field is filled in if it is required
		if( $field->{required} && ( !defined $self->{$field->{name}} ||
		                        	 $self->{$field->{name}} eq "" ) )
		{
			$problem = $self->{session}->{lang}->phrase( 
				"H:not_done_field" ,
				{ fieldname=>$field->displayname( $self->{session} ) } );
		}
		else
		{
			# Give the site validation module a go
			$problem = EPrintSite::Validate::validate_eprint_field(
				$field,
				$self->{$field->{name}} );
		}

		if( $field->{type} eq "username")
		{
			my @usernames;
			@usernames = split( ":", $self->{$field->{name}} );
			my @invalid;
			foreach ( @usernames )
			{
				next if( $_ eq "" );
				my $user = new EPrints::User( $self->{session} , $_ );
				if ( !defined $user ) 
				{
					push @invalid, $_;
				}
			}
			if ( scalar @invalid > 0 )
			{
				$problem = $self->{session}->{lang}->phrase(
						"H:invalid_users",
				            	{ usernames=>join(", ",@invalid) } );
			}
		}


		
		if( defined $problem && $problem ne "" )
		{
			push @all_problems, $problem;
		}
	}

	# Site validation routine for eprint metadata as a whole:
	EPrintSite::Validate::validate_eprint_meta( $self, \@all_problems );

	return( \@all_problems );
}
	

######################################################################
#
# $problems = validate_subject()
#  array_ref
#
#  Validate the subject(s) entered
#
######################################################################

sub validate_subject
{
	my( $self ) = @_;
	
	my @all_problems;
	my @all_fields = $self->{session}->{metainfo}->get_table_fields( "eprint", $self->{type} );
	my $field;

	foreach $field (@all_fields)
	{
		my $problem;
	
		if( $field->{type} eq "subject")
		{
			# Make sure at least one subject is selected
			if( !defined $self->{$field->{name}} ||
			    $self->{$field->{name}} eq ":" )
			{
				$problem = $self->{session}->{lang}->phrase(
						"H:least_one_sub" );
			}
		}
		else
		{
			# Give the validation module a go
			$problem = EPrintSite::Validate::validate_subject_field(
				$field,
				$self->{$field->{name}} );
		}

		if( defined $problem && $problem ne "" )
		{
			push @all_problems, $problem;
		}
	}

	return( \@all_problems );
}
		
	


######################################################################
#
# $problems = validate_linking()
#  array_ref
#
######################################################################

sub validate_linking
{
	my( $self ) = @_;

	my @problems;
	
	my $succeeds_field = $self->{session}->{metainfo}->find_table_field( "eprint", "succeeds" );
	my $commentary_field = $self->{session}->{metainfo}->find_table_field( "eprint", "commentary" );

	if( defined $self->{succeeds} && $self->{succeeds} ne "" )
	{
		my $test_eprint = new EPrints::EPrint( $self->{session}, 
		                                       "archive",
		                                       $self->{succeeds} );
		unless( defined( $test_eprint ) )
		{
			push @problems, $self->{session}->{lang}->phrase(
				"H:invalid_succ",	
				{ field=>$succeeds_field->displayname( $self->{session} ) } );
		}

		if( defined $test_eprint )
		{
			# Ensure that the user is authorised to post to this
			if( $test_eprint->{username} ne $self->{username} )
			{

 				# Not the same user. 

#Must be certified to do this. cjg: Should this be staff only or something???
#				my $user = new EPrints::User( $self->{session},
#				                              $self->{username} );
#				if( !defined $user && $user->{

				push @problems, $self->{session}->{lang}->phrase(
					"H:cant_succ" );
			}
		}
	}
	
	if( defined $self->{commentary} && $self->{commentary} ne "" )
	{
		my $test_eprint = new EPrints::EPrint( $self->{session}, 
		                                       "archive",
		                                       $self->{commentary} );
		
		unless( defined( $test_eprint ) ) { 
			push @problems, $self->{session}->{lang}->phrase(
				"H:invalid_id",
				{ field=>$commentary_field->displayname( $self->{session} ) } );
		}

	}
	
	return( \@problems );
}


######################################################################
#
# $document = get_document( $format )
#
#  Gets an associated document with the given format.
#
######################################################################

sub get_document
{
	my( $self, $format ) = @_;
	
	my @fields = $self->{session}->{metainfo}->get_fields( "documents" );

	# Grab relevant rows from the database.
	my $rows = $self->{session}->{database}->retrieve_fields(
		"document",
		\@fields,
		[ "eprintid LIKE \"$self->{eprintid}\"", "format LIKE \"$format\"" ] );

	if( $#{$rows} == -1 )
	{
		# Haven't got one
		return( undef );
	}
	else
	{
		# Return the first
		my $document = EPrints::Document->new( $self->{session},
		                                       undef,
		                                       $rows->[0] );
		return( $document );
	}
}


######################################################################
#
# @documents = get_all_documents()
#
#  Return all documents associated with the EPrint.
#
######################################################################

sub get_all_documents
{
	my( $self ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		"document" );

	$searchexp->add_field(
		$self->{session}->{metainfo}->find_table_field( 
			"document",
			"eprintid" ),
		"ALL:EQ:$self->{eprintid}" );

	my $searchid = $searchexp->perform_search();
	my @documents = $searchexp->get_records();

	return( @documents );
}


######################################################################
#
# @formats = get_formats()
#
#  Get the document file formats that are available for this EPrint
#
######################################################################

sub get_formats
{
	my( $self ) = @_;
	
	# Grab relevant rows from the database.
	my $rows = $self->{session}->{database}->retrieve(
		"document",
		[ "format" ],
		[ "eprintid LIKE \"$self->{eprintid}\"" ] );
	
	my @formats;

	foreach (@$rows)
	{
		push @formats, $_->[0];
	}

	return( @formats );
}


######################################################################
#
# $problems = validate_documents()
#  array_ref
#
#  Ensure this EPrint has appropriate uploaded files.
#
######################################################################

sub validate_documents
{
	my( $self ) = @_;
	my @problems;
	
	# Ensure we have at least one required format
	my @formats = $self->get_formats();
	my $f;
	my $ok = 0;

	foreach $f (@formats)
	{
		$ok = 1 if( EPrints::Document::required_format(
				$self->{session},
				$f ) );
	
	}

	if( !$ok )
	{
		my $prob = $self->{session}->{lang}->phrase( "H:need_a_format" );
		$prob .= "<UL>\n";
		foreach (@{$self->{session}->{required_formats}})
		{
			$prob .= "<LI>".EPrints::Document::format_name( 
						$self->{session},
					 	$_ )."</LI>\n";
		}
		$prob .= "</UL>\n";

		push @problems, $prob;

	}

	return( \@problems );
}


######################################################################
#
# $problems = validate_full()
#  array_ref
#
#  Validate the whole shebang.
#
######################################################################

sub validate_full
{
	my( $self ) = @_;
	
	my @problems;

	# Firstly, all the previous checks, just to be certain... it's possible
	# that some problems remain, but the user is submitting direct from
	# the author home.	
	my $probs = $self->validate_type();
	push @problems, @$probs;

	$probs = $self->validate_meta();
	push @problems, @$probs;

	$probs = $self->validate_subject();
	push @problems, @$probs;

	$probs = $self->validate_linking();
	push @problems, @$probs;

	$probs = $self->validate_documents();
	push @problems, @$probs;

	my @docs = $self->get_all_documents();
	my $doc;
	foreach $doc (@docs)
	{
		$probs = $doc->validate();
		foreach (@$probs)
		{
			push @problems,
				EPrints::Document::format_name( 
					$self->{session}, 
					$doc->{format} ).
				": ".$_;
		}
	}

	# Now give the site specific stuff one last chance to have a gander.
	EPrintSite::Validate::validate_eprint( $self, \@problems );

	return( \@problems );
}


######################################################################
#
# prune_documents()
#
#  Remove documents which don't have any attached files.
#
######################################################################

sub prune_documents
{
	my( $self ) = @_;
	
	# Get the documents from the database
	my @fields = $self->{session}->{metainfo}->get_fields( "documents" );

	my $rows = $self->{session}->{database}->retrieve_fields(
		"document",
		\@fields,
		[ "eprintid LIKE \"$self->{eprintid}\"" ] );

	# Check each one
	foreach (@$rows)
	{
		my $doc = EPrints::Document->new( $self->{session}, $_->[0], $_ );
		my %files = $doc->files();
		if( scalar keys %files == 0 )
		{
			# Has no associated files, prune
			$doc->remove();
		}
	}
}


######################################################################
#
# prune()
#
#  Remove pointless fields and document entries
#
######################################################################

sub prune
{
	my( $self ) = @_;
	
#EPrints::Log::debug( "EPrint", "prune: EPrint ID: $self->{eprintid}" );

	$self->prune_documents();
	
	my @fields = $self->{session}->{metainfo}->get_table_fields( "eprint", $self->{type} );
	my @all_fields = $self->{session}->{metainfo}->get_fields( "archive" );
	my $f;

	foreach $f (@all_fields)
	{
		if( !defined $self->{session}->{metainfo}->find_field( \@fields, $f->{name} ) )
		{
			$self->{$f->{name}} = undef;
		}
	}

#EPrints::Log::debug( "EPrint", "prune: end EPrint ID: $self->{eprintid}" );
}


######################################################################
#
# $success = submit()
#
#  Attempt to transfer the EPrint to the submissions buffer.
#
######################################################################

sub submit
{
	my( $self ) = @_;
	
	my $success = $self->transfer( "buffer" );
	
	if( $success )
	{
		EPrintSite::SiteRoutines::update_submitted_eprint( $self );
		$self->datestamp();
		$self->commit();
	}
	
	return( $success );
}


######################################################################
#
# datestamp()
#
#  Set the datestamp field to today's date (GMT).
#
######################################################################

sub datestamp
{
	my( $self ) = @_;

	$self->{datestamp} = EPrints::MetaField::get_datestamp( time );
}


######################################################################
#
# $success = archive()
#
#  This transfers the EPrint to the main archive table - i.e. it
#  actually _archives_ it.
#
######################################################################

sub archive
{
	my( $self ) = @_;

	# Remove pointless fields
	undef $self->{additional};
	undef $self->{reasons};
	
	my $success = $self->transfer( "archive" );
	
	if( $success )
	{
		EPrintSite::SiteRoutines::update_archived_eprint( $self );
		$self->commit();
		$self->generate_static();

		# Generate static pages for everything in threads, if appropriate
		my $succeeds_field = $self->{session}->{metainfo}->find_table_field( "eprint", "succeeds" );
		my $commentary_field =
			$self->{session}->{metainfo}->find_table_field( "eprint", "commentary" );

		my @to_update = $self->get_all_related();
		
		# Do the actual updates
		foreach (@to_update)
		{
			$_->generate_static();
		}
	}
	
	return( $success );
}



######################################################################
#
# $path = local_path
#
#  Gives the full path of the EPrint directory on the local filesystem.
#  No trailing slash.
#
######################################################################

sub local_path
{
	my( $self ) = @_;
	
	return( "$self->{session}->{site}->{local_document_root}/$self->{dir}" );
}


######################################################################
#
# $stem = url_stem()
#
#  Returns the URL to this EPrint's directory. Note, this INCLUDES the
#  trailing slash, unlike the local_path() method.
#
######################################################################

sub url_stem
{
	my( $self ) = @_;
	
	return( $self->{site}->{session}->{server_document_root}."/".$self->{dir}."/" );
}


######################################################################
#
# my $path = static_page_local()
#
#  Give the path on the local file system of the static HTML abstract
#  page.
#
######################################################################

sub static_page_local
{
	my( $self ) = @_;
	
	return( $self->local_path . "/" . $EPrints::EPrint::static_page );
}


######################################################################
#
# my $url = static_page_url()
#
#  Give the full URL of the static HTML abstract
#
######################################################################

sub static_page_url
{
	my( $self ) = @_;
	
	return( $self->url_stem . $EPrints::EPrint::static_page );
}


######################################################################
#
# $success = generate_static()
#
#  Generate the static version of the abstract page.
#
######################################################################

sub generate_static
{
	my( $self ) = @_;
	
	my $offline_renderer = new EPrints::HTMLRender( $self->{session}, 1 , new CGI( {} ));
	
	my $ok = open OUT, ">".$self->static_page_local();

	unless( $ok )
	{
		EPrints::Log::log_entry(
			"EPrint",
			$self->{session}->{lang}->phrase(
				"L:error_gen_st",
				{ path=>$self->static_page_local(),
				eprintid=>$self->{eprintid},
				errmsg=>$! } ) );
		return( 0 );
	}

	print OUT $offline_renderer->start_html( $self->short_title() );
	
	print OUT $offline_renderer->render_eprint_full( $self );
	
	print OUT $offline_renderer->end_html();
	
	close( OUT );
	
	return( 1 );
}


######################################################################
#
# @eprints = get_all_related()
#
#  Gets the eprints that are related in some way to this in a succession
#  or commentary thread. The returned list does NOT include this EPrint.
#
######################################################################

sub get_all_related
{
	my( $self ) = @_;
	
	my $succeeds_field = $self->{session}->{metainfo}->find_table_field( "eprint", "succeeds" );
	my $commentary_field = $self->{session}->{metainfo}->find_table_field( "eprint", "commentary" );

	my @related = $self->all_in_thread( $succeeds_field )
		if( $self->in_thread( $succeeds_field ) );
	push @related, $self->all_in_thread( $commentary_field )
		if( $self->in_thread( $commentary_field ) );
		
	# Remove duplicates, just in case
	my %related_uniq;
		
	foreach (@related)
	{
		# We also don't want to re-update ourself
		$related_uniq{$_->{eprintid}} = $_
			unless( $_->{eprintid} eq $self->{eprintid} );
	}

	return( values %related_uniq );
}


######################################################################
#
# $is_first = in_thread( $field )
#
#  Returns non-zero if this paper is part of a thread
#
######################################################################

sub in_thread
{
	my( $self, $field ) = @_;
	
	return( 1 )
		if( defined $self->{$field->{name}} && $self->{$field->{name}} ne "" );

	my @later = $self->later_in_thread( $field );

	return( 1 ) if( scalar @later > 0 );
	
	return( 0 );
}


######################################################################
#
# $eprint = first_in_thread( $field )
#
#  Returns the first (earliest) version or first paper in the thread
#  of commentaries of this paper in the archive.
#
######################################################################

sub first_in_thread
{
	my( $self, $field ) = @_;
	
#EPrints::Log::debug( "EPrint", "first_in_thread( $self->{eprintid}, $field->{name} )" );

	my $first = $self;
	
	while( defined $first->{$field->{name}} && $first->{$field->{name}} ne "" )
	{
		my $prev = new EPrints::EPrint( $self->{session},
		                                "archive",
		                                $first->{$field->{name}} );

		return( $first ) unless( defined $prev );
		$first = $prev;
	}
		       
	return( $first );
}


######################################################################
#
# @eprints = later_in_thread( $field )
#
#  Returns a list of the later items in the thread
#
######################################################################

sub later_in_thread
{
	my( $self, $field ) = @_;
#cjg	
	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		"archive" );

	$searchexp->add_field( $field, "ALL:EQ:$self->{eprintid}" );

#cjg		[ "datestamp DESC" ] ) );

	my $searchid = $searchexp->perform_search();
	my @eprints = $searchexp->get_records();

	return @eprints;

}


######################################################################
#
# @eprints = all_in_thread( $field )
#
#  Returns all of the EPrints in the given thread
#
######################################################################

sub all_in_thread
{
	my( $self, $field ) = @_;

	my @eprints;
	
	my $first = $self->first_in_thread( $field );
	
	$self->_collect_thread( $field, $first, \@eprints );

	return( @eprints );
}


sub _collect_thread
{
	my( $self, $field, $current, $eprints ) = @_;
	
	push @$eprints, $current;
	
	my @later = $current->later_in_thread( $field );
	foreach (@later)
	{
		$self->_collect_thread( $field, $_, $eprints );
	}
}


######################################################################
#
# $eprint = last_in_thread( $field )
#
#  Return the eprint that is the most recent deposit in the given
#  thread.  This eprint is returned if it is the latest.
#
######################################################################

sub last_in_thread
{
	my( $self, $field ) = @_;
	
	my $latest = $self;
	my @later = ( $self );

	while( scalar @later > 0 )
	{
		$latest = $later[0];
		@later = $latest->later_in_thread( $field );
	}

	return( $latest );
}

1;
