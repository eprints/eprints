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
use EPrints::DOM;
use EPrints::Document;

use File::Path;
use Filesys::DiskSpace;
use strict;

#cjg doc validation lets through docs with no type (??)

# Number of digits in generated ID codes
$EPrints::EPrint::id_code_digits = 8;

$EPrints::EPrint::static_page = "index.html";

## WP1: BAD
sub get_system_field_info
{
	my( $class ) = @_;

	return ( 
	{ name=>"eprintid", type=>"int", required=>1 },

	# UserID is not required, as some bulk importers
	# may not provide this info. maybe bulk importers should
	# set a userid of -1 or something.

	{ name=>"userid", type=>"int", required=>0 },

	{ name=>"dir", type=>"text", required=>0 },

	{ name=>"datestamp", type=>"date", required=>0 },

	{ name=>"type", type=>"datatype", datasetid=>"eprint", required=>1, 
		displaylines=>"ALL" },

	{ name=>"succeeds", type=>"text", required=>0 },

	{ name=>"commentary", type=>"text", required=>0 },

	{ name=>"replacedby", type=>"text", required=>0 }

	);
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
	my( $class, $session, $dataset, $id ) = @_;

	if( defined $dataset )
	{
		return $session->get_db()->get_single( $dataset , $id );
	}

	## Work out in which table the EPrint resides.
	## and return the eprint.
	foreach( "archive" , "inbox" , "buffer" )
	{
		my $ds = $session->get_archive()->get_dataset( $_ );
		my $self = $session->get_db()->get_single( $ds, $id );
		if ( defined $self ) 
		{
			$self->{dataset} = $ds;
			return $self;
		}
	}
	return undef;
}

sub new_from_data
{
	my( $class, $session, $dataset, $known ) = @_;

	my $self = {};
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
# $eprint = create( $session, $dataset, $userid, $data )
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
	my( $session, $dataset, $userid, $data ) = @_;

	my $setdefaults = 0;
	if( !defined $data )
	{
		$data = {};
		$setdefaults = 1;
	}

	my $new_id = _create_id( $session );
	my $dir = _create_directory( $session, $new_id );
#print STDERR "($new_id)($dir)\n";

	if( !defined $dir )
	{
		return( undef );
	}

	$data->{eprintid} = $new_id;
	$data->{userid} = $userid;
	$data->{dir} = $dir;

	if( $setdefaults )
	{	
		$session->get_archive()->call(
			"set_eprint_defaults",
			$data,
			$session );
	}

	my $success = $session->get_db()->add_record( $dataset, $data );

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
	
	return $session->get_db()->counter_next( "eprintid" );

}


#####################################################################
#
# $directory = _create_directory( $eprintid )
#
#  Create a directory on the local filesystem for the new document
#  with the given ID. undef is returned if it couldn't be created
#  for some reason.
#
######################################################################

## WP1: BAD
sub _create_directory
{
	my( $session, $eprintid ) = @_;
	
	# Get available directories
	my $docpath = $session->get_archive()->get_conf( "documents_path" );
#print STDERR "DOCPATH: $docpath\n";
	unless( opendir DOCSTORE, $docpath )
	{
		$session->get_archive()->log( "Failed to open docpath: ".$docpath );
		return undef;
	}
	# The grep here just removes the "." and ".." directories
	my @avail = grep !/^\.\.?$/, readdir DOCSTORE;
	closedir DOCSTORE;

	# Check amount of space free on each device. We'll use the first one we find
	# (alphabetically) that has enough space on it.
	my $storedir;
	my $best_free_space = 0;
	my $device;	
	foreach $device (sort @avail)
	{
#cjg use the lib!
		my $free_space = 1000000000;
#cjg OH GOD			(df $session->get_archive()->get_conf( "documents_path" )."/$device" )[3];
#print STDERR "(".$session->get_archive()->get_conf( "documents_path" )."/$device)($free_space)\n";
		$best_free_space = $free_space if( $free_space > $best_free_space );

		unless( defined $storedir )
		{
			if( $free_space >= $session->get_archive()->get_conf("diskspace_error_threshold") )
			{
				# Enough space on this drive.
				$storedir = $device;
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
			"lib/eprint:diskout" );
#print STDERR "oraok\n";
#cjg LOG WHY!
		return( undef );
	}

	# Warn the administrator if we're low on space
	if( $best_free_space < $session->get_archive()->get_conf("diskspace_warn_threshold") )
	{
# cjg - not done this bit yet...
#
#		$session->mail_administrator(
#			EPrints::Language::logphrase( "lib/eprint:disklow_sub" ),
#			EPrints::Language::logphrase( "lib/eprint:disklow" ) );
	}

	# Work out the directory path. It's worked out using the ID of the 
	# EPrint.
	my $idpath = eprintid_to_path( $eprintid );

	if( !defined $idpath )
	{
		$session->get_archive()->log( "Failed to turn eprintid: \"$eprintid\" into a path." );
		return( undef ) ;
	}

	my $dir = $storedir."/".$idpath;

	# Full path including doc store root
	my $full_path = $session->get_archive()->get_conf("documents_path")."/".$dir;
	
	if (!EPrints::Utils::mkdir( $full_path ))
	{
		$session->get_archive()->log( "Failed to create directory ".$full_path.": $@");
                return( undef );
	}
	else
	{
		# Return the path relative to the document store root
		return( $dir );
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
	my( $self, $dest_dataset, $copy_documents ) = @_;

	# Create the new EPrint record
	my $new_eprint = EPrints::EPrint::create(
		$self->{session},
		$dest_dataset,
		$self->get_value( "userid" ),
		$self->{data} );
	
	unless( defined $new_eprint )
	{
		return undef;
	}

	$new_eprint->datestamp();

	# We assume the new eprint will be a later version of this one,
	# so we'll fill in the succeeds field, provided this one is
	# already in the main archive.
	if( $self->{dataset}->id() eq  "archive"  )
	{
		$new_eprint->set_value( "succeeds" , 
			$self->get_value( "eprintid" ) );
	}

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


######################################################################
#
# $success = _transfer( $dataset )
#
#  Move the EPrint to the given table
#
######################################################################

sub _transfer
{
	my( $self, $dataset ) = @_;

	# Keep the old table
	my $old_dataset = $self->{dataset};

	# Copy to the new table
	$self->{dataset} = $dataset;

	# Create an entry in the new table

	my $success = $self->{session}->get_db()->add_record(
		$dataset,
		{ "eprintid"=>$self->get_value( "eprintid" ) } );

	# Datestamp every time we move between tables.
	$self->datestamp();

	# Write self to new table
	$success =  $success && $self->commit();

	# If OK, remove the old copy
	$success = $success && $self->{session}->get_db()->remove(
		$old_dataset,
		$self->get_value( "eprintid" ) );

	# Need to clean up stuff if we move this record out of the
	# archive.
	if( $old_dataset->id() eq "archive" )
	{
		$self->_move_from_archive();
	}
	
	return( $success );
}


# remove EPrint - should really only be called on eprints
# in the buffer or inbox.
sub remove
{
	my( $self ) = @_;

	my $doc;
	foreach $doc ( $self->get_all_documents() )
	{
		$doc->remove();
	}

	my $success = $self->{session}->get_db()->remove(
		$self->{dataset},
		$self->get_value( "eprintid" ) );

	return $success;
}



######################################################################
#
# $title = short_title()
#
#  Return a short title for the EPrint. Delegates to the site-specific
#  routine.
#
######################################################################

sub render_short_title
{
	my( $self ) = @_;

	return( $self->{session}->get_archive()->call( "eprint_render_short_title", $self ) );
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

	$self->{session}->get_archive()->call( "set_eprint_automatic_fields", $self );

	my $success = $self->{session}->get_db()->update(
		$self->{dataset},
		$self->{data} );

	if( !$success )
	{
		my $db_error = $self->{session}->get_db()->error();
		$self->{session}->get_archive()->log( "Error committing EPrint ".$self->get_value( "eprintid" ).": $db_error" );
	}

	return( $success );
}



######################################################################
######################################################################

sub validate_type
{
	my( $self, $for_archive ) = @_;
	
	my @problems;

	# Make sure we have a value for the type, and that it's one of the
	# configured EPrint types
	if( !defined $self->get_value( "type" ) )
	{
		push @problems, 
			$self->{session}->html_phrase( "lib/eprint:no_type" );
	} 
	elsif( ! $self->{dataset}->is_valid_type( $self->get_value( "type" ) ) )
	{
		push @problems, $self->{session}->html_phrase( 
					"lib/eprint:invalid_type" );
	}

	my $field = $self->{dataset}->get_field( "type" );

	push @problems, $self->{session}->get_archive()->call(
				"validate_field",
				$field,
				$self->get_value( $field->get_name() ),
				$self->{session},
				$for_archive );

	return( \@problems );
}


######################################################################
#
# $problems = validate_linking()
#  array_ref
#
######################################################################

sub validate_linking
{
	my( $self, $for_archive ) = @_;

	my @problems;
	
	my $field_id;
	foreach $field_id ( "succeeds", "commentary" )
	{
		my $field = $self->{dataset}->get_field( $field_id );
	
		push @problems, $self->{session}->get_archive()->call(
					"validate_field",
					$field,
					$self->get_value( $field->get_name() ),
					$self->{session},
					$for_archive );

		next unless( defined $self->get_value( $field_id ) );

		my $archive_ds = $self->{session}->get_archive()->get_dataset( "archive" );

		my $test_eprint = new EPrints::EPrint( $self->{session}, 
		                                       $archive_ds,
		                                       $self->get_value( $field_id ) );

		if( !defined( $test_eprint ) )
		{
			push @problems, $self->{session}->html_phrase(
				"lib/eprint:invalid_id",	
				field => $self->{session}->make_text(
					$field->display_name( $self->{session} ) ) );
			next;
		}

		if( $field_id eq "succeeds" )
		{
			# Ensure that the user is authorised to post to this
			if( $test_eprint->get_value("userid") ne $self->get_value("userid") )
			{
 				# Not the same user. 

#Must be certified to do this. cjg: Should this be staff only or something???
#				my $user = new EPrints::User( $self->{session},
#				                              $self->{userid} );
#				if( !defined $user && $user->{

				push @problems, $self->{session}->html_phrase( "lib/eprint:cant_succ" );
			}
		}
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
	my( $self, $for_archive ) = @_;
	
	my @all_problems;
	my @req_fields = $self->{dataset}->get_required_type_fields( $self->get_value("type") );
	my @all_fields = $self->{dataset}->get_fields();

	# For all required fields...
	my $field;
	foreach $field (@req_fields)
	{
		# Check that the field is filled 
		next if ( defined $self->get_value( $field->get_name() ) );

		my $problem = $self->{session}->html_phrase( 
			"lib/eprint:not_done_field" ,
			fieldname=> $self->{session}->make_text( 
			   $field->display_name( $self->{session} ) ) );

		push @all_problems,$problem;
	}

	# Give the site validation module a go
	foreach $field (@all_fields)
	{
		push @all_problems, $self->{session}->get_archive()->call(
			"validate_field",
			$field,
			$self->get_value( $field->{name} ),
			$self->{session},
			$for_archive );
	}

	# Site validation routine for eprint metadata as a whole:
	push @all_problems, $self->{session}->get_archive()->call(
		"validate_eprint_meta",
		$self, 
		$self->{session},
		$for_archive );

	return( \@all_problems );
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
	my( $self, $for_archive ) = @_;
	my @problems;
	
        my @req_formats = @{$self->{session}->get_archive()->get_conf( "required_formats" )};
	my @docs = $self->get_all_documents();

	my $ok = 0;
	$ok = 1 if( scalar @req_formats == 0 );

	my $doc;
	foreach $doc ( @docs )
        {
		my $docformat = $doc->get_value( "format" );
		foreach( @req_formats )
		{
                	$ok = 1 if( $docformat eq $_ );
		}
        }

	if( !$ok )
	{
		my $doc_ds = $self->{session}->get_archive()->get_dataset( "document" );
		my $prob = $self->{session}->make_doc_fragment();
		$prob->appendChild( $self->{session}->html_phrase( "lib/eprint:need_a_format" ) );
		my $ul = $self->{session}->make_element( "ul" );
		$prob->appendChild( $ul );
		
		foreach( @req_formats )
		{
			my $li = $self->{session}->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $doc_ds->render_type_name( $self->{session}, $_ ) );
		}
			
		push @problems, $prob;

	}

	foreach $doc (@docs)
	{
		my $probs = $doc->validate( $for_archive );
		foreach (@$probs)
		{
			my $prob = $self->{session}->make_doc_fragment();
			$prob->appendChild( $doc->render_desc() );
			$prob->appendChild( $self->{session}->make_text( ": " ) );
			$prob->appendChild( $_ );
		}
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
	my( $self , $for_archive ) = @_;
	
	my @problems;

	# Firstly, all the previous checks, just to be certain... it's possible
	# that some problems remain, but the user is submitting direct from
	# the author home.	
	my $probs = $self->validate_type( $for_archive );
	push @problems, @$probs;

	$probs = $self->validate_linking( $for_archive );
	push @problems, @$probs;

	$probs = $self->validate_meta( $for_archive );
	push @problems, @$probs;

	$probs = $self->validate_documents( $for_archive );
	push @problems, @$probs;

	# Now give the site specific stuff one last chance to have a gander.
	push @problems, $self->{session}->get_archive()->call( 
			"validate_eprint", 
			$self,
			$self->{session},
			$for_archive );

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

	# Check each one
	my $doc;
	foreach $doc ( $self->get_all_documents() )
	{
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
# @documents = get_all_documents()
#
#  Return all documents associated with the EPrint.
#
######################################################################

## WP1: BAD
sub get_all_documents
{
	my( $self ) = @_;

	my $doc_ds = $self->{session}->get_archive()->get_dataset( "document" );

	my $searchexp = EPrints::SearchExpression->new(
		session=>$self->{session},
		dataset=>$doc_ds );

	$searchexp->add_field(
		$doc_ds->get_field( "eprintid" ),
		"PHR:EQ:".$self->get_value( "eprintid" ) );

	my $searchid = $searchexp->perform_search();
	my @documents = $searchexp->get_records();
	$searchexp->dispose();

	return( @documents );
}

######################################################################
#
# prune()
#
#  Remove fields not allowed for this records type and prune document 
#  entries.
#
######################################################################

#loseit? cjg
sub prune
{
	my( $self ) = @_;

	$self->prune_documents();

	# This part chops out fields which don't belong to 
	# this type. But that's not really what we want.
	# as some may have been hidden on purpose (eg. subjects)
	# or a composite field. 

	# Commenting out this code means that if you edit an
	# eprint, then change it's type to a type which can't
	# have field "foo" then field "foo" may remain set.
	# This probably won't matter much.

	#  my @fields = $self->{dataset}->get_type_fields();
	#  my @all_fields = $self->{dataset}->get_fields();
	#
	#  my $f;
	#  foreach $f (@all_fields)
	#  {
	#	unless( grep( /^$f$/, @fields ) )
	#	{
	#		$self->set_value( $f->{name}, undef );
	#	}
	#  }

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

	$self->set_value( "datestamp" , EPrints::MetaField::get_datestamp( time ) );
}


######################################################################
#
# $success = archive()
#
#  This transfers the EPrint to the main archive table - i.e. it
#  actually _archives_ it.
#
######################################################################

sub move_to_deletion
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "deletion" );
	
	my $last_in_thread = $self->last_in_thread( $ds->get_field( "succeeds" ) );
	my $replacement_id = $last_in_thread->get_value( "eprintid" );

	if( $replacement_id == $self->get_value( "eprintid" ) )
	{
		# This IS the last in the thread, so we should redirect
		# enquirers to the one this replaced, if any.
		$replacement_id = $self->get_value( "succeeds" );
	}

	$self->set_value( "replacedby" , $replacement_id );

	my $success = $self->_transfer( $ds );

	if( $success )
	{
		$self->generate_static();
	}
	
	return $success;
}

sub move_to_inbox
{
	my( $self ) = @_;

	# if we is currently in archive... cjg? eh???

	my $ds = $self->{session}->get_archive()->get_dataset( "inbox" );
	
	my $success = $self->_transfer( $ds );
	
	return $success;
}

sub move_to_buffer
{
	my( $self ) = @_;
	
	my $ds = $self->{session}->get_archive()->get_dataset( "buffer" );

	my $success = $self->_transfer( $ds );
	
	if( $success )
	{
		$self->{session}->get_archive()->call( "update_submitted_eprint", $self );
		$self->commit();
	}
	
	return( $success );
}

sub remove_static()
{
	my( $self ) = @_;
	#cjg tsk needs to actually clean up symlinks abstracts etc.
}	

sub _move_from_archive
{
	my( $self ) = @_;

	$self->remove_static();

	# Generate static pages for everything in threads, if 
	# appropriate
	my @to_update = $self->get_all_related();
		
	# Do the actual updates
	foreach (@to_update)
	{
		$_->generate_static();
	}
}

sub move_to_archive
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "archive" );
	my $success = $self->_transfer( $ds );
	
	if( $success )
	{
		$self->{session}->get_archive()->call( "update_archived_eprint", $self );
		$self->commit();
		$self->generate_static();

		# Generate static pages for everything in threads, if 
		# appropriate
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
	
	return( $self->{session}->get_archive()->get_conf( "documents_path" )."/".$self->get_value( "dir" ) );
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

	return( sprintf( 
			"%s/%0".$EPrints::EPrint::id_code_digits."d/", 
			$self->{session}->get_archive()->get_conf( "documents_url" ), 
			$self->{data}->{eprintid} ) );
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

	my $eprintid = $self->get_value( "eprintid" );

	my $ds_id = $self->{dataset}->id();
	if( $ds_id ne "deletion" && $ds_id ne "archive" )
	{
		$self->{session}->get_archive()->log( 
			"Attempt to generate static files for record ".
			$eprintid." in dataset $ds_id (may only generate ".
			"static for deletion and archive" );
	}

	# We is going to temporarily change the language of our session to
	# render the abstracts in each language.
	my $real_langid = $self->{session}->get_langid();

	my $langid;
	foreach $langid ( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		$self->{session}->change_lang( $langid );
		my $full_path = $self->{session}->get_archive()->get_conf( "htdocs_path" )."/$langid/archive/".eprintid_to_path( $eprintid );

		my @created = eval
		{
			my @created = mkpath( $full_path, 0, 0775 );
			return( @created );
		};

		$self->{session}->new_page();
		my( $page, $title ) = $self->render();

		$self->{session}->build_page( $title, $page ); #cjg title?
		$self->{session}->page_to_file( $full_path .
			  "/" . $EPrints::EPrint::static_page );

		next if( $ds_id ne "archive" );
		# Only live archive records have actual documents 
		# available.

		my @docs = $self->get_all_documents();
		my $doc;
		foreach $doc ( @docs )
		{
			if( $doc->get_value( "security" ) eq "public" ) 
			{
				$doc->create_symlink( $self, $full_path );
			}
		}
	}
	$self->{session}->change_lang( $real_langid );
}


sub render
{
        my( $self ) = @_;

        my( $dom, $title );
	my $ds_id = $self->{dataset}->id();
	if( $ds_id eq "deletion" )
	{
		$title = $self->{session}->phrase( "lib/eprint:eprint_gone_title" );
		$dom = $self->{session}->make_doc_fragment();
		$dom->appendChild( $self->{session}->html_phrase( "lib/eprint:eprint_gone" ) );
		my $replacement = new EPrints::EPrint(
			$self->{session},
			$self->{session}->get_archive()->get_dataset( "archive" ),
			$self->get_value( "replacedby" ) );
		if( defined $replacement )
		{
			my $cite = $replacement->render_citation_link();
			$dom->appendChild( $self->{session}->html_phrase( "lib/eprint:later_version", citation=>$cite ) );
		}
	}
	else
	{
		($dom, $title ) = $self->{session}->get_archive()->call( "eprint_render", $self, $self->{session}, 0 );
	}
	
        return( $dom, $title );
}

# This should include all the info, not just that presented to the public.
sub render_full
{
        my( $self ) = @_;

        my( $dom, $title ) = $self->{session}->get_archive()->call( "eprint_render", $self, $self->{session}, 1 );

        return( $dom );
}



################################################################################


sub render_citation_link
{
	my( $self , $cstyle , $staff ) = @_;
	my $url;
	if( defined $staff && $staff )
	{
		$url = $self->{session}->get_archive()->get_conf( "perl_url" ).
			"/users/staff/edit_eprint?eprintid=".$self->get_value( "eprintid" );
	}
	else
	{
		$url = $self->static_page_url();
	}

	my $a = $self->{session}->make_element( "a", href=>$url );
	$a->appendChild( $self->render_citation( $cstyle ) );

	return $a;
}

sub render_citation
{
	my( $self , $cstyle) = @_;
	
	if( !defined $cstyle )
	{
		$cstyle = $self->{session}->get_citation_spec(
					$self->{dataset},
					$self->get_value( "type" ) );
	}

	EPrints::Utils::render_citation( $self , $cstyle );
}

## WP1: BAD
sub get_value
{
	my( $self , $fieldname ) = @_;
	
	my $r = $self->{data}->{$fieldname};

	$r = undef unless( EPrints::Utils::is_set( $r ) );

	return $r;
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

sub get_data
{
	my( $self ) = @_;
	
	return $self->{data};
}

sub get_dataset
{
	my( $self ) = @_;
	
	return $self->{dataset};
}

sub get_user
{
	my( $self ) = @_;

	my $user = EPrints::User->new( $self->{session}, $self->get_value( "userid" ) );

	return $user;
}

sub eprintid_to_path
{
	my( $eprintid ) = @_;

	return unless( $eprintid =~ m/^\d+$/ );

	my( $a, $b, $c, $d );
	$d = $eprintid % 100;
	$eprintid = int( $eprintid / 100 );
	$c = $eprintid % 100;
	$eprintid = int( $eprintid / 100 );
	$b = $eprintid % 100;
	$eprintid = int( $eprintid / 100 );
	$a = $eprintid % 100;
	
	return sprintf( "%02d/%02d/%02d/%02d", $a, $b, $c, $d );
}

######################################################################
#
# Thread related code
#
######################################################################


######################################################################
#
# @eprints = get_all_related()
#
#  Gets the eprints that are related in some way to this in a succession
#  or commentary thread. The returned list does NOT include this EPrint.
#

sub get_all_related
{
	my( $self ) = @_;

	my $succeeds_field = $self->{dataset}->get_field( "succeeds" );
	my $commentary_field = $self->{dataset}->get_field( "commentary" );

	my @related = ();

	if( $self->in_thread( $succeeds_field ) )
	{
		push @related, $self->all_in_thread( $succeeds_field );
	}
	
	if( $self->in_thread( $commentary_field ) )
	{
		push @related, $self->all_in_thread( $commentary_field );
	}
	
	# Remove duplicates, just in case
	my %related_uniq;
	my $eprint;	
	my $ownid = $self->get_value( "eprintid" );
	foreach $eprint (@related)
	{
		# We don't want to re-update ourself
		next if( $ownid eq $eprint->get_value( "eprintid" ) );
		
		$related_uniq{$eprint->get_value("eprintid")} = $eprint;
	}

	return( values %related_uniq );
}



######################################################################
#
# $is_first = in_thread( $field )
#
#  Returns non-zero if this paper is part of a thread
#

sub in_thread
{
	my( $self, $field ) = @_;
	
	if( defined $self->get_value( $field->get_name() ) )
	{
		return( 1 );
	}

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

sub first_in_thread
{
	my( $self, $field ) = @_;
	
	my $first = $self;
	my $ds = $self->{session}->get_archive()->get_dataset( "archive" );
	
	while( defined $first->get_value( $field->get_name() ) )
	{
		my $prev = EPrints::EPrint->new( 
				$self->{session},
				$ds,
				$first->get_value( $field->get_name() ) );

		return( $first ) unless( defined $prev );
		$first = $prev;
	}
		       
	return( $first );
}


#
# @eprints = later_in_thread( $field )
#
#  Returns a list of the later items in the thread
#

sub later_in_thread
{
	my( $self, $field ) = @_;

	my $searchexp = EPrints::SearchExpression->new(
		session => $self->{session},
		dataset => $self->{session}->get_archive()->get_dataset( "archive" ) );
#cjg		[ "datestamp DESC" ] ) ); sort by date!

	$searchexp->add_field( 
		$field, 
		"PHR:EQ:".$self->get_value( "eprintid" ) );

	my $searchid = $searchexp->perform_search();
	my @eprints = $searchexp->get_records();
	$searchexp->dispose();

	return @eprints;

}


#
# @eprints = all_in_thread( $field )
#
#  Returns all of the EPrints in the given thread
#

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

#
# remove_from_threads()
#
#  Extracts the eprint from any threads it's in. i.e., if any other
#  paper is a later version of or commentary on this paper, the link
#  from that paper to this will be removed.
#

sub remove_from_threads
{
	my( $self ) = @_;

	if( $self->{dataset}->id() ne "archive" )
	{
		return;
	}

	# Remove thread info in this eprint
	$self->set_value( "succeeds", undef );
	$self->set_value( "commentary", undef );
	$self->commit();

	my @related = $self->get_all_related();
	my $eprint;
	# Remove all references to this eprint
	my $this_id = $self->get_value( "eprintid" );

	foreach $eprint ( @related )
	{
		# Update the objects if they refer to us (the objects were 
		# retrieved before we unlinked ourself)
		my $changed = 0;
		if( $eprint->get_value( "succeeds" ) eq $this_id )
		{
			$self->set_value( "succeeds", undef );
			$changed = 1;
		}
		if( $eprint->get_value( "commentary" ) eq $this_id )
		{
			$self->set_value( "commentary", undef );
			$changed = 1;
		}
		if( $changed )
		{
			$eprint->commit();
		}
	}

	# Update static pages for each eprint
	foreach $eprint (@related)
	{
		next if( $eprint->get_value( "eprintid" ) eq $this_id );
		$eprint->generate_static(); 
	}
}

sub render_value
{
	my( $self, $fieldname, $showall ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );	
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall );
}

sub get_id
{
	my( $self ) = @_;

	return $self->{data}->{eprintid};
}

sub render_version_thread
{
	my( $self, $field ) = @_;

	my $html;

	my $first_version = $self->first_in_thread( $field );

	my $ul = $self->{session}->make_element( "ul" );
	
	$ul->appendChild( $first_version->_render_version_thread_aux( $field, $self ) );
	
	return( $ul );
}

sub _render_version_thread_aux
{
	my( $self, $field, $eprint_shown ) = @_;
	
	my $li = $self->{session}->make_element( "li" );

	my $cstyle = $self->{session}->get_citation_spec(
					$self->{dataset},
					"thread_".$field->get_name() );

	if( $self->get_value( "eprintid" ) != $eprint_shown->get_value( "eprintid" ) )
	{
		$li->appendChild( $self->render_citation_link( $cstyle ) );
	}
	else
	{
		$li->appendChild( $self->render_citation( $cstyle ) );
		$li->appendChild( $self->{session}->make_text( " " ) );
		$li->appendChild( $self->{session}->html_phrase( "lib/eprint:curr_disp" ) );
	}

	my @later = $self->later_in_thread( $field );

	# Are there any later versions in the thread?
	if( scalar @later > 0 )
	{
		# if there are, start a new list
		my $ul = $self->{session}->make_element( "ul" );
		my $version;
		foreach $version (@later)
		{
			$ul->appendChild( $version->_render_version_thread_aux(
				$field, $eprint_shown ) );
		}
		$li->appendChild( $ul );
	}
	
	return( $li );
}




1; # For use/require success
	
1;
