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

use File::Path;
use Filesys::DiskSpace;
use strict;
use XML::DOM;

# Number of digits in generated ID codes
$EPrints::EPrint::id_code_digits = 8;



$EPrints::EPrint::static_page = "index.html";

## WP1: BAD
sub get_system_field_info
{
	my( $class ) = @_;

	return ( 
	{
		name=>"eprintid",
		type=>"text",
		required=>1,
		editable=>0
	},
	{
		name=>"username",
		type=>"text",
		required=>1,
		editable=>0
	},
	{
		name=>"dir",
		type=>"text",
		required=>0,
		editable=>0
	},
	{
		name=>"datestamp",
		type=>"date",
		required=>0,
		editable=>0
	},
                          # Subject categories. Tagged as
                          # "not editable" since it's a special
                          # case.
	{
		name=>"subjects",
		type=>"subject",
		required=>0,
		editable=>0,
		multiple=>1
	},
	{
		name=>"additional",
		type=>"text",
		required=>0,
		editable=>0
	},
	{
		name=>"reasons",
		type=>"longtext",
		required=>0,
		editable=>0,
		displaylines=>6
	},
	{
		name=>"type",
		type=>"datatype",
		datasetid=>"eprint",
		required=>1,
		editable=>0
	},
	{
		name=>"succeeds",
		type=>"text",
		required=>0,
		editable=>0
	},
	{
		name=>"commentary",
		type=>"text",
		required=>0,
		editable=>0
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

## WP1: BAD
sub new
{
	my( $class, $session, $dataset, $id, $known ) = @_;

	my $self;

	if ( !defined $known )	
	{
		if( defined $dataset )
		{
			return $session->get_db()->get_single( $dataset , $id );
		}

		## Work out in which table the EPrint resides.
		## and return the eprint.
		foreach( "archive" , "inbox" , "buffer" )
		{
			my $ds = $session->get_site()->get_data_set( $_ );
			$self = $session->get_db()->get_single( $ds, $id );
			if ( defined $self ) 
			{
				$self->{dataset} = $ds;
				return $self;
			}
		}
		return undef;
	}

	$self = {};
	if( defined $known )
	{
		$self->{data} = $known;
	}
	$self->{dataset} = $dataset;
	$self->{session} = $session;

	bless $self, $class;

	return( $self );
}
	

######################################################################
#
# $eprint = create( $session, $dataset, $username, $data )
#
#  Create a new EPrint entry in the given table, from the given user.
#
#  If data is defined, then this is used as the base for the
#  new record.
#
######################################################################

## WP1: BAD
sub create
{
	my( $session, $dataset, $username, $data ) = @_;

	if( !defined $data )
	{
		$data = {};
	}

	my $new_id = _create_id( $session );
	my $dir = _create_directory( $session, $new_id );
print STDERR "($new_id)($dir)\n";
	if( !defined $dir )
	{
		$session->get_site()->log( "Failed to make dir." );
		return( undef );
	}

	$data->{eprintid} = $new_id;
	$data->{username} = $username;
	$data->{dir} = $dir;
	
# cjg add_record call
	my $success = $session->get_db()->add_record(
		$dataset,
		$data );

	if( $success )
	{
		return( EPrints::EPrint->new( $session, $dataset, $new_id ) );
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

## WP1: BAD
sub _create_id
{
	my( $session ) = @_;
	
	my $new_id = $session->get_db()->counter_next( "eprintid" );

	while( length $new_id < $EPrints::EPrint::id_code_digits )
	{
		$new_id = "0".$new_id;
	}

	return( $session->get_site()->get_conf( "eprint_id_stem" ) . $new_id );
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

## WP1: BAD
sub _create_directory
{
	my( $session, $eprint_id ) = @_;
	
	# Get available directories
print STDERR $session->get_site()->get_conf( "local_document_root" )."\n";
	opendir DOCSTORE, $session->get_site()->get_conf( "local_document_root" )
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
			(df $session->get_site()->get_conf( "local_document_root" )."/$_" )[3];
print STDERR "(".$session->get_site()->get_conf( "local_document_root" )."/$_)($free_space)\n";
		$best_free_space = $free_space if( $free_space > $best_free_space );

		unless( defined $storedir )
		{
			if( $free_space >= $session->get_site()->get_conf("diskspace_error_threshold") )
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
			"lib/eprint:diskout_sub" ,
			"lib/eprint:diskout"  );
print STDERR "oraok\n";
		return( undef );
	}

	# Warn the administrator if we're low on space
	if( $best_free_space < $session->get_site()->get_conf("diskspace_warn_threshold") )
	{
# cjg - not done this bit yet...
#
#		$session->mail_administrator(
#			EPrints::Language::logphrase( "lib/eprint:disklow_sub" ),
#			EPrints::Language::logphrase( "lib/eprint:disklow" ) );
	}

	# For now, just choose first
print STDERR "ook\n";
	return( undef ) if( !defined $avail[0] );
	
print STDERR "oak\n";
	# Work out the directory path. It's worked out using the ID of the EPrint.
	# It takes the numerical suffix of the ID, and divides it into four
	# components, which become the directory path for the EPrint.
	# e.g. "stem001020304" is given the path "001/02/03/04"

	my $sitestem = $session->get_site()->get_conf( "eprint_id_stem" );

	return( undef ) unless( $eprint_id =~
		/$sitestem(\d+)(\d\d)(\d\d)(\d\d)/ );

print STDERR "soak\n";
	my $dir = $storedir . "/" . $1 . "/" . $2 . "/" . $3 . "/" . $4;
	
	# Full path including doc store root
	my $full_path = $session->get_site()->get_conf("local_document_root")."/$dir";

	# Ensure the path is there. Dir. is made group writable.
print "($full_path)\n";
	my @created = eval
	{
		my @created = mkpath( $full_path, 0, 0775 );
		return( @created );
	};

#	foreach (@created)
#	{
#	}

	# Error if we couldn't even create one
	if( $#created == -1 )
	{
		$session->get_site()->log( "Failed to create directory ".$full_path.": $@"); 
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

## WP1: BAD
sub remove
{
	my( $self ) = @_;

	my $success = 1;
	
	# Create a deletion record if we're removing the record from the main
	# archive
	if( $self->{dataset} eq "archive" )
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
			$self->{session}->get_site()->log( "Error removing doc ".$_->{docid}.": $!" );
		}
	}

	# Now remove the directory
	my $num_deleted = rmtree( $self->local_path() );
	
	if( $num_deleted <= 0 )
	{
		$self->{session}->get_site()->log( "Error removing files for ".$self->{eprint}.", path ".$self->local_path().": $!" );
		$success = 0;
	}

	# Remove from any threads
	$self->remove_from_threads();

	# Remove our entry from the DB
	$success = $success && $self->{session}->{database}->remove(
		$self->{dataset},
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

## WP1: BAD
sub remove_from_threads
{
	my( $self ) = @_;
	
	if( $self->{dataset} eq  "archive" )
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

## WP1: BAD
sub clone
{
	my( $self, $dest_dataset, $copy_documents ) = @_;
die "clone NOT DONE"; #cjg	
	# Create the new EPrint record
	my $new_eprint = EPrints::EPrint::create(
		$self->{session},
		$dest_dataset,
		$self->{username} );
	
	if( defined $new_eprint )
	{
		my $field;

		# Copy all the data across, except the ID and the datestamp
		foreach $field ($self->{session}->{metainfo}->get_fields( "eprint", $self->{type} ))
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
			if( $self->{dataset} eq  "archive"  );

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
# $success = transfer( $dataset )
#
#  Move the EPrint to the given table
#
######################################################################

## WP1: BAD
sub transfer
{
	my( $self, $dataset ) = @_;

	# Keep the old table
	my $old_dataset = $self->{dataset};

	# Copy to the new table
	$self->{dataset} = $dataset;

	# Create an entry in the new table
# cjg add_record call
	my $success = $self->{session}->{database}->add_record(
		$dataset,
		{ "eprintid"=>$self->{eprintid} } );

	# Write self to new table
	$success =  $success && $self->commit();

	# If OK, remove the old copy
	$success = $success && $self->{session}->{database}->remove(
		$old_dataset,
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

## WP1: BAD
sub short_title
{
	my( $self ) = @_;

	return( $self->{session}->{site}->eprint_short_title( $self ) );
}



######################################################################
#
# $success = commit()
#
#  Commit any changes that might have been made to the database
#
######################################################################

## WP1: BAD
sub commit
{
	my( $self ) = @_;
	my $success = $self->{session}->{database}->update(
		$self->{dataset},
		$self->{data} );

	if( !$success )
	{
		my $db_error = $self->{session}->{database}->error();
		$self->{session}->get_site()->log( "Error committing EPrint ".$self->{eprintid}.": $db_error" );
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

## WP1: BAD
sub validate_type
{
	my( $self ) = @_;
	
	my @problems;

	# Make sure we have a value for the type, and that it's one of the
	# configured EPrint types
	if( !defined $self->{type} || $self->{type} eq "" )
	{
		push @problems, $self->{session}->phrase( "lib/eprint:no_type" );
	}
	elsif( !defined $self->{session}->{metainfo}->get_type_name( $self->{session} , "eprintid", $self->{type} ) )
	{
		push @problems, $self->{session}->phrase( "lib/eprint:invalid_type" );
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

## WP1: BAD
sub validate_meta
{
	my( $self ) = @_;
	
	my @all_problems;
	my @all_fields = $self->{session}->{metainfo}->get_fields( "eprint", $self->{type} );
	my $field;
	
	foreach $field (@all_fields)
	{
		my $problem;
		
		# Check that the field is filled in if it is required
		if( $field->{required} && ( !defined $self->{$field->{name}} ||
		                        	 $self->{$field->{name}} eq "" ) )
		{
			$problem = $self->{session}->phrase( 
				"lib/eprint:not_done_field" ,
				fieldname=>$field->displayname( $self->{session} ) );
		}
		else
		{
			# Give the site validation module a go
			$problem = $self->{session}->{site}->validate_eprint_field(
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
				$problem = $self->{session}->phrase(
						"lib/eprint:invalid_users",
				            	usernames=>join(", ",@invalid) );
			}
		}


		
		if( defined $problem && $problem ne "" )
		{
			push @all_problems, $problem;
		}
	}

	# Site validation routine for eprint metadata as a whole:
	$self->{session}->{site}->validate_eprint_meta( $self, \@all_problems );

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

## WP1: BAD
sub validate_subject
{
	my( $self ) = @_;
	
	my @all_problems;
	my @all_fields = $self->{session}->{metainfo}->get_fields( "eprint", $self->{type} );
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
				$problem = $self->{session}->phrase(
						"lib/eprint:least_one_sub" );
			}
		}
		else
		{
			# Give the validation module a go
			$problem = $self->{session}->{site}->validate_subject_field(
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

## WP1: BAD
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
			push @problems, $self->{session}->phrase(
				"lib/eprint:invalid_succ",	
				field=>$succeeds_field->displayname( $self->{session} ) );
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

				push @problems, $self->{session}->phrase(
					"lib/eprint:cant_succ" );
			}
		}
	}
	
	if( defined $self->{commentary} && $self->{commentary} ne "" )
	{
		my $test_eprint = new EPrints::EPrint( $self->{session}, 
		                                       "archive",
		                                       $self->{commentary} );
		
		unless( defined( $test_eprint ) ) { 
			push @problems, $self->{session}->phrase(
				"lib/eprint:invalid_id",
				field=>$commentary_field->displayname( $self->{session} ) );
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

## WP1: BAD
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

## WP1: BAD
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
		"PHR:EQ:$self->{eprintid}" );

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

## WP1: BAD
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

## WP1: BAD
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
		my $prob = $self->{session}->phrase( "lib/eprint:need_a_format" );
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

## WP1: BAD
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
	$self->{session}->{site}->validate_eprint( $self, \@problems );

	return( \@problems );
}


######################################################################
#
# prune_documents()
#
#  Remove documents which don't have any attached files.
#
######################################################################

## WP1: BAD
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

## WP1: BAD
sub prune
{
	my( $self ) = @_;
	

	$self->prune_documents();
	
	my @fields = $self->{session}->{metainfo}->get_fields( "eprint", $self->{type} );
	my @all_fields = $self->{session}->{metainfo}->get_fields( "archive" );
	my $f;

	foreach $f (@all_fields)
	{
		if( !defined $self->{session}->{metainfo}->find_table_field( \@fields, $f->{name} ) )
		{
			$self->{$f->{name}} = undef;
		}
	}

}


######################################################################
#
# $success = submit()
#
#  Attempt to transfer the EPrint to the submissions buffer.
#
######################################################################

## WP1: BAD
sub submit
{
	my( $self ) = @_;
	
	my $success = $self->transfer( "buffer" );
	
	if( $success )
	{
		$self->{session}->{site}->update_submitted_eprint( $self );
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

## WP1: BAD
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

## WP1: BAD
sub archive
{
	my( $self ) = @_;

	# Remove pointless fields
	undef $self->{additional};
	undef $self->{reasons};
	
	my $success = $self->transfer( "archive" );
	
	if( $success )
	{
		$self->{session}->{site}->update_archived_eprint( $self );
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

## WP1: BAD
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

## WP1: BAD
sub url_stem
{
	my( $self ) = @_;
	
	return( $self->{session}->get_site()->get_conf( "server_document_root" ).
		"/".$self->{data}->{eprintid}."/" );
}


######################################################################
#
# my $url = static_page_url()
#
#  Give the full URL of the static HTML abstract
#
######################################################################

## WP1: BAD
sub static_page_url
{
	my( $self ) = @_;
	
	return( $self->url_stem );
}


######################################################################
#
# $success = generate_static()
#
#  Generate the static version of the abstract page.
#
######################################################################

## WP1: BAD
sub generate_static
{
	my( $self ) = @_;

	print "ID: ".$self->get_value( "eprintid" )."\n";

	my $eprint_id = $self->get_value( "eprintid" );

	# Work out the directory path. It's worked out using the ID of the EPrint.
	# It takes the numerical suffix of the ID, and divides it into four
	# components, which become the directory path for the EPrint.
	# e.g. "stem001020304" is given the path "001/02/03/04"

	my $sitestem = $self->{session}->get_site()->get_conf( "eprint_id_stem" );

	return( undef ) unless( $eprint_id =~
		/$sitestem(\d+)(\d\d)(\d\d)(\d\d)/ );
	
	my $langid;
	foreach $langid ( keys %EPrints::Site::General::languages )
	{
		print "LANG: $langid\n";	


		my $full_path = 
			$self->{session}->get_site()->get_conf( "local_html_root" ).
			"/$langid/archive/$1/$2/$3/$3";

		my @created = eval
		{
			my @created = mkpath( $full_path, 0, 0775 );
			return( @created );
		};
		print "yo:".join(",",@created)."\n";

		$self->{session}->new_page( $langid );
		my $page = $self->to_html_page;
		$self->{session}->build_page( "TITLE?????", $page ); #cjg title?
		$self->{session}->page_to_file( $full_path .
			  "/" . $EPrints::EPrint::static_page );
		# SYMLINK's to DOCS...
	}



	
	return;	
}


## WP1: BAD
sub to_html_page
{
        my( $self ) = @_;

        my $dom = $self->{session}->get_site()->call( "eprint_render_full", $self, 0 );

        return( $dom );
}

## WP1: BAD
sub to_html_staff_page
{
        my( $self ) = @_;

        my $dom = $self->{session}->get_site()->call( "eprint_render_full", $self, 1 );

        return( $dom );
}


######################################################################
#
# @eprints = get_all_related()
#
#  Gets the eprints that are related in some way to this in a succession
#  or commentary thread. The returned list does NOT include this EPrint.
#
######################################################################

## WP1: BAD
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

## WP1: BAD
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

## WP1: BAD
sub first_in_thread
{
	my( $self, $field ) = @_;
	

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

## WP1: BAD
sub later_in_thread
{
	my( $self, $field ) = @_;
#cjg	
	my $searchexp = new EPrints::SearchExpression(
		$self->{session},
		"archive" );

	$searchexp->add_field( $field, "PHR:EQ:$self->{eprintid}" );

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

## WP1: BAD
sub all_in_thread
{
	my( $self, $field ) = @_;

	my @eprints;
	
	my $first = $self->first_in_thread( $field );
	
	$self->_collect_thread( $field, $first, \@eprints );

	return( @eprints );
}


## WP1: BAD
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

## WP1: BAD
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

## WP1: BAD
sub to_html_link
{
	my( $self , $cstyle ) = @_;
	my $a = $self->{session}->make_element( "A",
			href => $self->static_page_url() );
	$a->appendChild( $self->to_html( $cstyle ) );

	return $a;
}

## WP1: BAD
sub to_html
{
	my( $self , $cstyle) = @_;
	
	if( !defined $cstyle )
	{
		$cstyle = $self->{session}->get_site()->call( "get_eprint_citation_style", $self );
	}

	my $ifnode;
	foreach $ifnode ( $cstyle->getElementsByTagName( "IF" , 1 ) )
	{
		my $fieldname = $ifnode->getAttribute( "name" );
		my $val = $self->get_value( "$fieldname" );
		if( defined $val )
		{       
			my $sn; 
			foreach $sn ( $ifnode->getChildNodes )
			{       
				$ifnode->getParentNode->insertBefore( 
								$sn, 
								$ifnode );
			}       
		}
		$ifnode->getParentNode->removeChild( $ifnode );
		$ifnode->dispose();
	}

	my $fieldnode;
	foreach $fieldnode ( $cstyle->getElementsByTagName( "FIELD" , 1 ) ) 
	{
		my $fieldname = $fieldnode->getAttribute( "name" );
		my $el = $self->{dataset}->get_field( $fieldname )->render_value( 
			$self->{session},
			$self->get_value( $fieldname ) );
		$fieldnode->getParentNode()->replaceChild( $el, $fieldnode );
		$fieldnode->dispose();
	}

	return $cstyle;
}                                                   


## WP1: BAD
sub get_value
{
	my( $self , $fieldname ) = @_;

	if( $self->{data}->{$fieldname} eq "")
	{
		return undef;
	}

	return $self->{data}->{$fieldname};
}

## WP1: BAD
sub set_value
{
	my( $self , $fieldname, $value ) = @_;

	$self->{data}->{$fieldname} = $value;
}

## WP1: BAD
sub get_session
{
	my( $self ) = @_;

	return $self->{session};
}

## WP1: BAD
sub get_data
{
	my( $self ) = @_;
	
	return $self->{data};
}
1;
