######################################################################
#
# EPrints EPrint class
#
#  Class representing an actual EPrint
#
######################################################################
#
#  17/11/99 - Created by Robert Tansley
#  $Id$
#
######################################################################

package EPrints::EPrint;

use EPrints::Database;
use EPrints::MetaInfo;
use EPrintSite::SiteRoutines;

use File::Path;
use strict;

# Number of digits in generated ID codes
my $digits = 8;

#
# System fields, common to all EPrint types
#
@EPrints::EPrint::system_meta_fields =
(
	"eprintid:text::EPrint ID:1:0:1",        # The EPrint ID
	"username:text::Submitted by:1:0:1:1",   # User ID of submitter
	"dir:text::Local Directory:0:0:0",       # Directory it's in
	"datestamp:date::Submission Date:0:0:1", # The submission date stamp
	"subjects:subjects:1:Subject Categories:0:0:0",
	                                         # Subject categories. Tagged as
	                                         # "not visible" since it's a special
	                                         # case.
	"additional:text::Suggested Additional Subject Heading:0:0:0",
	                                         # Suggested extra subject...
	"reasons:multitext:6:Reason for Additional Heading:0:0:0",
	                                         # Chance for user to explain why
	"type:eprinttype::EPrint Type:1:0:0",    # EPrint types, special case again
	"succeeds:text::Later Version Of:0:0:0", # Later version of....
	"commentary:text::Commentary On:0:0:0"   # Commentary on/response to...
);

# Additional fields in this class:
#
#   table   - the table the EPrint appears in

#
# System field help
#
%EPrints::EPrint::help =
(
	"additional" => "If you'd like to suggest another subject or subjects for ".
		"your submission, then enter it here. Please specify it fully, in a ".
		"manner similar to those displayed in the above list.",
	"reasons" => "Here you can offer justification for your suggested added ".
		"subject(s).",
	"commentary" => "If your paper is a commentary on (or a response to) ".
		"another document in the archive, please enter its ID in this box.",
	"succeeds" => "If this document is a revised version of another document ".
		"in the archive, please enter its ID code in this box."
);

$EPrints::EPrint::static_page = "index.html";



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
	my( $class, $session, $table, $id, $known ) = @_;

	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;
	
	my @row;

	if( defined $known )
	{
		# Rows are already known
		@row = @$known;
		$self->{table} = $table;
	}
	else
	{
		if( !defined $table )
		{
			# Work out in which table the EPrint resides.

			# Try the archive table first
			# Get the relevant row...
			@row = $self->{session}->{database}->retrieve_single(
				$EPrints::Database::table_archive,
				"eprintid",
				$id );

			# Next try buffer
			if( $#row >= 0 )
			{
				$self->{table} = $EPrints::Database::table_archive;
			}
			else
			{
				@row = $self->{session}->{database}->retrieve_single(
					$EPrints::Database::table_buffer,
					"eprintid",
					$id );
			}

			# Finally, inbox
			if( $#row >= 0 )
			{
				$self->{table} = $EPrints::Database::table_buffer;
			}
			else
			{
				@row = $self->{session}->{database}->retrieve_single(
					$EPrints::Database::table_inbox,
					"eprintid",
					$id );
			}

			$table = $EPrints::Database::table_inbox if( $#row >= 0 );
		}
		else
		{
			$self->{table} = $table;

			@row = $self->{session}->{database}->retrieve_single(
				$table,
				"eprintid",
				$id );
		}		


		if( $#row == -1 )
		{
			# We still don't have any data, so the EPrint obviously doesn't exist.
			return( undef );
		}		
	}

	# Read in the EPrint data from the rows.
	my @fields = EPrints::MetaInfo->get_all_eprint_fieldnames();
	my $i=0;

	foreach $_ (@fields)
	{
		$self->{$_} = $row[$i];
		$i++;
	}

	return( $self );
}
	

######################################################################
#
# $eprint = create( $session, $table, $userid )
#
#  Create a new EPrint entry in the given table, from the given user.
#
######################################################################

sub create
{
	my( $class, $session, $table, $userid ) = @_;

	my $new_id = _create_id();

	my $dir = _create_directory( $new_id );

	return( undef ) if( !defined $dir );
	
	my $success = $session->{database}->add_record(
		$table,
		[ [ "eprintid", $new_id ],
		  [ "username", $userid ],
		  [ "dir", $dir ] ] );

	if( $success )
	{
		return( EPrints::EPrint->new( $session, $table, $new_id ) );
	}
	else
	{
		return( undef );
	}
}
	

######################################################################
#
# $new_id = _create_id()
#
#  Create a new EPrint ID code. CAUTION: Not robust if two eprints
#  are created asynchronously. Only a problem on a high-traffic site.
#
######################################################################

sub _create_id
{
	my $count = 0;
	my $new_id;

	my $r = open( COUNTER, "$EPrintSite::SiteInfo::eprint_id_counter" );

	if( $r )
	{
		$count = <COUNTER>;
		chop $count;
		close( COUNTER );
	}
	
	$new_id = $count;

	while( length $new_id < $digits )
	{
		$new_id = "0".$new_id;
	}

	# Write count to file
	$count += 1;

#EPrints::Log->debug( "EPrint", "Writing new count $count" );

	open( COUNTER, ">$EPrintSite::SiteInfo::eprint_id_counter" ) or
		EPrints::Log->log_entry( "EPrint", "Error opening counter: $!" );
	print COUNTER "$count\n";
	close( COUNTER );
	
	return( $EPrintSite::SiteInfo::eprint_id_stem . $new_id );
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
	my( $eprint_id ) = @_;
	
	# Get available directories
	opendir DOCSTORE, $EPrintSite::SiteInfo::local_document_root
		or return( undef );
	my @avail = grep !/^\.\.?$/, readdir DOCSTORE;
	closedir DOCSTORE;
	
	# PLACEHOLDER!! Needs to check amount of space free on each device
	# and make an intelligent choice

	# For now, just choose first
	return( undef ) if( !defined $avail[0] );
	my $storedir = $avail[0];
	
	# Work out the directory path. It's worked out using the ID of the EPrint.
	# It takes the numerical suffix of the ID, and divides it into four
	# components, which become the directory path for the EPrint.
	# e.g. "stem001020304" is given the path "001/02/03/04"

	return( undef ) unless( $eprint_id =~
		/$EPrintSite::SiteInfo::eprint_id_stem(\d+)(\d\d)(\d\d)(\d\d)/ );

	my $dir = $storedir . "/" . $1 . "/" . $2 . "/" . $3 . "/" . $4;
	
	# Full path including doc store root
	my $full_path = $EPrintSite::SiteInfo::local_document_root . "/" . $dir;

	# Ensure the path is there. Dir. is made group writable.
	my @created = eval
	{
		my @created = mkpath( $full_path, 0, 0775 );
		return( @created );
	};

#	foreach (@created)
#	{
#		EPrints::Log->debug( "EPrint", "Created directory $_" );
#	}

	# Error if we couldn't even create one
	if( $#created == -1 )
	{
		EPrints::Log->log_entry( "EPrint",
		                         "Failed to create directory $full_path: $@" );
		return( undef );
	}

	# Return the path relative to the document store root
	return( $dir );
}



######################################################################
#
# @eprints = retrieve_eprints( $session, $table, $conditions, $order )
#                                               array_ref   array_ref
#
#  Retrieves EPrints from the given database table, returning full
#  EPrint objects. [STATIC method.]
#
######################################################################

sub retrieve_eprints
{
	my( $class, $session, $table, $conditions, $order ) = @_;
	
	my @fields = EPrints::MetaInfo->get_all_eprint_fields();

	my $rows = $session->{database}->retrieve_fields( $table,
                                                     \@fields,
                                                     $conditions,
                                                     $order );

EPrints::Log->debug( "EPrint", "Making ".scalar @$rows." EPrint objects" );

	my $r;
	my @eprints;

	foreach $r (@$rows)
	{
		push @eprints, EPrints::EPrint->new( $session,
		                                     $table,
		                                     $r->[0],
		                                     $r );
	}
	
	return( @eprints );		                                        
}


######################################################################
#
# my $num = count_eprints( $session, $table, $conditions )
#                                            array_ref
#
#  Simpler version of retrieve_eprints() that just counts the number
#  of EPrints satisfying the conditions.[STATIC method.]
#
######################################################################

sub count_eprints
{
	my( $class, $session, $table, $conditions ) = @_;
	
	my $field = EPrints::MetaInfo->find_eprint_field( "eprintid");

	my $rows = $session->{database}->retrieve_fields( $table,
                                                     [ $field ],
                                                     $conditions );

	return( $#{$rows} + 1 );		                                        
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
	
	# First remove the associated documents
	my @docs = $self->get_all_documents();
	
	foreach (@docs)
	{
		$success = $success && $_->remove();
		EPrints::Log->log_entry( "EPrint", "Error removing doc $_->{docid}: $!" )
			if( !$success );
	}

	# Now remove the directory
	my $num_deleted = rmtree( $self->local_path() );
	
	if( $num_deleted <= 0 )
	{
		EPrints::Log->log_entry(
			"EPrint",
			"Error removing files for $self->{eprint}, path ".$self->local_path().
				": $!" );
		$success = 0;
	}

	$success = $success && $self->{session}->{database}->remove(
		$self->{table},
		"eprintid",
		$self->{eprintid} );
	
	return( $success );
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
	my( $self, $dest_table, $copy_documents ) = @_;
	
	# Create the new EPrint record
	my $new_eprint = EPrints::EPrint->create(
		$self->{session},
		$dest_table,
		$self->{username} );
	
	if( defined $new_eprint )
	{
		my $field;

		# Copy all the data across, except the ID and the datestamp
		foreach $field (EPrints::MetaInfo->get_eprint_fields( $self->{type} ))
		{
			my $field_name = $field->{name};

			if( $field_name ne "eprintid" &&
			    $field_name ne "datestamp" &&
			    $field_name ne "dir" )
			{
				$new_eprint->{$field_name} = $self->{$field_name};
			}
		}

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
# $success = transfer( $table )
#
#  Move the EPrint to the given table
#
######################################################################

sub transfer
{
	my( $self, $table ) = @_;

	# Keep the old table
	my $old_table = $self->{table};

	# Copy to the new table
	$self->{table} = $table;

	# Create an entry in the new table
	my $success = $self->{session}->{database}->add_record(
		$table,
		[ [ "eprintid", $self->{eprintid} ] ] );

	# Write self to new table
	$success =  $success && $self->commit();

	# If OK, remove the old copy
	$success = $success && $self->{session}->{database}->remove(
		$old_table,
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

	return( EPrintSite::SiteRoutines->eprint_short_title( $self ) );
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

	# Put data into columns
	my @all_fields = EPrints::MetaInfo->get_all_eprint_fields();
	my @data;
	my $key_field = shift @all_fields;
	my $key_value = $self->{$key_field->{name}};

	foreach (@all_fields)
	{
		push @data, [ $_->{name}, $self->{$_->{name}} ];
	}

	my $success = $self->{session}->{database}->update(
		$self->{table},
		$key_field->{name},
		$key_value,
		\@data );

	if( !$success )
	{
		my $db_error = $self->{session}->{database}->error();
		EPrints::Log->log_entry(
			"EPrint",
			"Error committing EPrint $self->{eprintid}: $db_error" );
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
		push @problems, "You haven't selected a type for this EPrint.";
	}
	elsif( !defined EPrints::MetaInfo->get_eprint_type_name( $self->{type} ) )
	{
		push @problems, "This EPrint doesn't seem to have a valid type.";
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
	my @all_fields = EPrints::MetaInfo->get_eprint_fields( $self->{type} );
	my $field;
	
	foreach $field (@all_fields)
	{
		my $problem;
		
		# Check that the field is filled in if it is required
		if( $field->{required} && ( !defined $self->{$field->{name}} ||
		                        	 $self->{$field->{name}} eq "" ) )
		{
			$problem = 
				"You haven't filled out the required $field->{displayname} field.";
		}
		else
		{
			# Give the site validation module a go
			$problem = EPrintSite::Validate->validate_eprint_field(
				$field,
				$self->{$field->{name}} );
		}
		
		if( defined $problem && $problem ne "" )
		{
			push @all_problems, $problem;
		}
	}

	# Site validation routine for eprint metadata as a whole:
	EPrintSite::Validate->validate_eprint_meta( $self, \@all_problems );

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
	my @all_fields = EPrints::MetaInfo->get_eprint_fields( $self->{type} );
	my $field;

	foreach $field (@all_fields)
	{
		my $problem;
	
		if( $field->{type} eq "subjects")
		{
			# Make sure at least one subject is selected
			if( !defined $self->{$field->{name}} ||
			    $self->{$field->{name}} eq ":" )
			{
				$problem = "You need to select at least one subject!";
			}
		}
		else
		{
			# Give the validation module a go
			$problem = EPrintSite::Validate->validate_subject_field(
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
	
	my $succeeds_field = EPrints::MetaInfo->find_eprint_field( "succeeds" );
	my $commentary_field = EPrints::MetaInfo->find_eprint_field( "commentary" );

	if( defined $self->{succeeds} && $self->{succeeds} ne "" )
	{
		my $test_eprint = new EPrints::EPrint( $self->{session}, 
		                                       $EPrints::Database::table_archive,
		                                       $self->{succeeds} );
		push @problems,
			"EPrint ID in $succeeds_field->{displayname} field is invalid"
				unless( defined( $test_eprint ) );
	}
	
	if( defined $self->{commentary} && $self->{commentary} ne "" )
	{
		my $test_eprint = new EPrints::EPrint( $self->{session}, 
		                                       $EPrints::Database::table_archive,
		                                       $self->{commentary} );
		push @problems,
			"EPrint ID in $commentary_field->{displayname} field is invalid"
				unless( defined( $test_eprint ) );

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
	
	my @fields = EPrints::MetaInfo->get_document_fields();

	# Grab relevant rows from the database.
	my $rows = $self->{session}->{database}->retrieve_fields(
		$EPrints::Database::table_document,
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

	my @documents;	
	my @fields = EPrints::MetaInfo->get_document_fields();

	# Grab relevant rows from the database.
	my $rows = $self->{session}->{database}->retrieve_fields(
		$EPrints::Database::table_document,
		\@fields,
		[ "eprintid LIKE \"$self->{eprintid}\"" ] );

	foreach( @$rows )
	{
		my $document = EPrints::Document->new( $self->{session},
		                                       undef,
		                                       $_ );
		push @documents, $document if( defined $document );
	}

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
		$EPrints::Database::table_document,
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
		foreach (@EPrintSite::SiteInfo::required_formats)
		{
			$ok = 1 if( $f eq $_ );
		}
	}

	if( !$ok )
	{
		my $prob = 
			"You need to upload at least one of the following formats:\n<UL>\n";
		foreach (@EPrintSite::SiteInfo::required_formats)
		{
			$prob .=
				"<LI>$EPrintSite::SiteInfo::supported_format_names{$_}</LI>\n";
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
				$EPrintSite::SiteInfo::supported_format_names{$doc->{format}}.
				": ".$_;
		}
	}

	# Now give the site specific stuff one last chance to have a gander.
	EPrintSite::Validate->validate_eprint( $self, \@problems );

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
	my @fields = EPrints::MetaInfo->get_document_fields();

	my $rows = $self->{session}->{database}->retrieve_fields(
		$EPrints::Database::table_document,
		\@fields,
		[ "eprintid LIKE \"$self->{eprintid}\"" ] );

	# Check each one
	foreach (@$rows)
	{
		my $doc = EPrints::Document->new( $self->{session}, $_->[0], $_ );
		my %files = $doc->files();
		if( scalar (%files) == 0 )
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
	
EPrints::Log->debug( "EPrint", "prune: EPrint ID: $self->{eprintid}" );

	$self->prune_documents();
	
	my @fields = EPrints::MetaInfo->get_eprint_fields( $self->{type} );
	my @all_fields = EPrints::MetaInfo->get_all_eprint_fields();
	my $f;

	foreach $f (@all_fields)
	{
		if( !defined EPrints::MetaInfo->find_field( \@fields, $f->{name} ) )
		{
			$self->{$f->{name}} = undef;
		}
	}

EPrints::Log->debug( "EPrint", "prune: end EPrint ID: $self->{eprintid}" );
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
	
	my $success = $self->transfer( $EPrints::Database::table_buffer );
	
	if( $success )
	{
		EPrintSite::SiteRoutines->update_submitted_eprint( $self );
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

	$self->{datestamp} = EPrints::MetaField->get_datestamp( time );
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
	
	my $success = $self->transfer( $EPrints::Database::table_archive );
	
	if( $success )
	{
		EPrintSite::SiteRoutines->update_archived_eprint( $self );
		$self->commit();
		$self->generate_static();
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
	
	return( $EPrintSite::SiteInfo::local_document_root."/".$self->{dir} );
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
	
	return( $EPrintSite::SiteInfo::server_document_root."/".$self->{dir}."/" );
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
	
	my $offline_renderer = new EPrints::HTMLRender( $self->{session}, 1 );
	
	my $ok = open OUT, ">".$self->static_page_local();

	unless( $ok )
	{
		EPrints::Log->log_entry(
			"EPrint",
			"Error generating static page for $self->{eprintid}: $!" );
		return( 0 );
	}

	print OUT $offline_renderer->start_html( $self->short_title() );
	
	print OUT $offline_renderer->render_eprint_full( $self );
	
	print OUT $offline_renderer->end_html();
	
	close( OUT );
	
	return( 1 );
}

1;
