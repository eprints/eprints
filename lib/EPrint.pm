######################################################################
#
# EPrints::EPrint
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

B<EPrints::EPrint> - Class representing an actual EPrint

=head1 DESCRIPTION

This class represents a single eprint record and the metadata 
associated with it. This is associated with one of more 
EPrint::Document objects.

EPrints::EPrint is a subclass of EPrints::DataObj with the following
metadata fields (plus those defined in ArchiveMetadataFieldsConfig:

=over 4

=item eprintid (int)

The unique numerical ID of this eprint. 

=item userid (int)

The id of the user who deposited this eprint (if any). Scripted importing
could cause this not to be set.

=item dir (text)

The directory, relative to the documents directory for this archive, which
this eprints data is stored in. Eg. disk0/00/00/03/34 for record 334.

=item datestamp (date)

The date this record was last modified.

=item type (datatype)

The type of this record, one of the types of the "eprint" dataset.

=item succeeds (text)

The ID of the eprint (if any) which this succeeds.  This field should have
been an int and may be changed in a later upgrade.

=item commentary (text)

The ID of the eprint (if any) which this eprint is a commentary on.  This 
field should have been an int and may be changed in a later upgrade.

=item replacedby (text)

The ID of the eprint (if any) which has replaced this eprint. This is only set
on records in the "deletion" dataset.  This field should have
been an int and may be changed in a later upgrade.

=back

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::EPrint;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use EPrints::Database;
use EPrints::Document;

use File::Path;
use strict;

#cjg doc validation lets through docs with no type (??)

######################################################################
=pod

=item $metadata = EPrints::EPrint->get_system_field_info

Return an array describing the system metadata of the EPrint dataset.

=cut
######################################################################

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
		input_rows=>"ALL" },

	{ name=>"succeeds", type=>"int", required=>0 },

	{ name=>"commentary", type=>"int", required=>0 },

	{ name=>"replacedby", type=>"int", required=>0 }

	);
}


######################################################################
=pod

=item $eprint = EPrints::EPrint->new( $session, $id, [$dataset] )

Return the eprint with the given id, or undef if it does not exist.

Setting dataset saves looking through all the datasets (does not
search "deletion").

=cut
######################################################################

sub new
{
	my( $class, $session, $id, $dataset ) = @_;

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


######################################################################
=pod

=item $eprint = EPrints::EPrint->new_from_data( $session, $data, $dataset )

Construct a new EPrints::EPrint object based on the $data hash 
reference of metadata.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $self = {};
	if( defined $data )
	{
		$self->{data} = $data;
	}
	$self->{dataset} = $dataset;
	$self->{session} = $session;

	bless( $self, $class );

	return( $self );
}
	

######################################################################
=pod

=item $eprint = EPrints::EPrint::create( $session, $dataset, $data )

Create a new EPrint entry in the given dataset.

If data is defined, then this is used as the base for the new record.
Otherwise the archive specific defaults (if any) are used.

The fields "eprintid" and "dir" will be overridden even if they
are set.

=cut
######################################################################

sub create
{
	my( $session, $dataset, $data ) = @_;

	# don't want to mangle the origional data.
	$data = EPrints::Utils::clone( $data );
	
	my $setdefaults = 0;
	if( !defined $data )
	{
		$data = {};
		$setdefaults = 1;
	}

	my $new_id = _create_id( $session );
	my $dir = _create_directory( $session, $new_id );

	if( !defined $dir )
	{
		return( undef );
	}

	$data->{eprintid} = $new_id;
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
		return( EPrints::EPrint->new( $session, $new_id, $dataset ) );
	}
	else
	{
		return( undef );
	}
}


######################################################################
# 
# $eprintid = EPrints::EPrint::_create_id( $session )
#
#  Create a new EPrint ID code. (Unique across all eprint datasets)
#
######################################################################

sub _create_id
{
	my( $session ) = @_;
	
	return $session->get_db()->counter_next( "eprintid" );

}


######################################################################
# 
# $directory =  EPrints::EPrint::_create_directory( $session, $eprintid )
#
#  Create a directory on the local filesystem for the new document
#  with the given ID. undef is returned if it couldn't be created
#  for some reason.
#
#  If "df" is available then check for diskspace and mail a warning 
#  to the admin if the threshold is passed.
#
######################################################################

sub _create_directory
{
	my( $session, $eprintid ) = @_;
	
	# Get available directories
	my @dirs = sort $session->get_archive()->get_store_dirs();
	my $storedir;

	if( $EPrints::SystemSettings::conf->{disable_df} )
	{
		# df not available, use the LAST available directory, 
		# sorting alphabetically.

		$storedir = pop @dirs;
	}
	else
	{
		# Check amount of space free on each device. We'll use the 
		# first one we find (alphabetically) that has enough space on 
		# it.
		my $warnsize = $session->get_archive()->get_conf(
						"diskspace_warn_threshold");
		my $errorsize = $session->get_archive()->get_conf(
						"diskspace_error_threshold");

		my $best_free_space = 0;
		my $dir;	
		foreach $dir (sort @dirs)
		{
			my $free_space = $session->get_archive()->
						get_store_dir_size( $dir );
			if( $free_space > $best_free_space )
			{
				$best_free_space = $free_space;
			}
	
			unless( defined $storedir )
			{
				if( $free_space >= $errorsize )
				{
					# Enough space on this drive.
					$storedir = $dir;
				}
			}
		}

		# Check that we do have a place for the new directory
		if( !defined $storedir )
		{
			# Argh! Running low on disk space overall.
			$session->get_archive()->log(<<END);
*** URGENT ERROR
*** Out of disk space.
*** All available drives have under $errorsize kilobytes remaining.
*** No new eprints may be added until this is rectified.
END
			$session->mail_administrator(
				"lib/eprint:diskout_sub" ,
				"lib/eprint:diskout" );
			return( undef );
		}

		# Warn the administrator if we're low on space
		if( $best_free_space < $warnsize )
		{
			$session->get_archive()->log(<<END);
Running low on diskspace.
All available drives have under $warnsize kilobytes remaining.
END
			$session->mail_administrator(
				"lib/eprint:disklow_sub" ,
				"lib/eprint:disklow" );
		}
	}

	# Work out the directory path. It's worked out using the ID of the 
	# EPrint.
	my $idpath = eprintid_to_path( $eprintid );

	if( !defined $idpath )
	{
		$session->get_archive()->log(<<END);
Failed to turn eprintid: "$eprintid" into a path.
END
		return( undef ) ;
	}

	my $docdir = $storedir."/".$idpath;

	# Full path including doc store root
	my $full_path = $session->get_archive()->get_conf("documents_path").
				"/".$docdir;
	
	if (!EPrints::Utils::mkdir( $full_path ))
	{
		$session->get_archive()->log(<<END);
Failed to create directory $full_path: $@
END
                return( undef );
	}
	else
	{
		# Return the path relative to the document store root
		return( $docdir );
	}
}


######################################################################
=pod

=item $eprint = $eprint->clone( $dest_dataset, $copy_documents )

Create a copy of this EPrint with a new ID in the given dataset.
Return the new eprint, or undef in the case of an error.

If $copy_documents is set and true then the documents (and files)
will be copied in addition to the metadata.

=cut
######################################################################

sub clone
{
	my( $self, $dest_dataset, $copy_documents ) = @_;

	# Create the new EPrint record
	my $new_eprint = EPrints::EPrint::create(
		$self->{session},
		$dest_dataset,
		$self->{data} );
	
	unless( defined $new_eprint )
	{
		return undef;
	}

	$new_eprint->datestamp();

	# We assume the new eprint will be a later version of this one,
	# so we'll fill in the succeeds field, provided this one is
	# already in the main archive.
	if( $self->{dataset}->id() eq  "archive" || 
	    $self->{dataset}->id() eq  "deletion" )
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
# $success = $eprint->_transfer( $dataset )
#
#  Move the EPrint to the given dataset.
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


######################################################################
=pod

=item $success = $eprint->remove

Erase this eprint and any associated records from the database and
filesystem.

This should only be called on eprints in "inbox" or "buffer".

=cut
######################################################################

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
=pod

=item $success = $eprint->commit

Commit any changes that might have been made to the database

=cut
######################################################################

sub commit
{
	my( $self ) = @_;

	$self->{session}->get_archive()->call( 
		"set_eprint_automatic_fields", 
		$self );

	my $success = $self->{session}->get_db()->update(
		$self->{dataset},
		$self->{data} );

	if( !$success )
	{
		my $db_error = $self->{session}->get_db()->error();
		$self->{session}->get_archive()->log( 
			"Error committing EPrint ".
			$self->get_value( "eprintid" ).": ".$db_error );
	}

	return( $success );
}


######################################################################
=pod

=item $problems = $eprint->validate_type( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "type" stage of eprint
submission.

A reference to an empty array indicates no problems.

=cut
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
=pod

=item $problems = $eprint->validate_linking( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "linking" stage of eprint
submission.

A reference to an empty array indicates no problems.

=cut
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

		my $archive_ds = $self->{session}->get_archive()->get_dataset( 
			"archive" );

		my $test_eprint = new EPrints::EPrint( 
			$self->{session}, 
			$self->get_value( $field_id ),
			$archive_ds );

		if( !defined( $test_eprint ) )
		{
			push @problems, $self->{session}->html_phrase(
				"lib/eprint:invalid_id",	
				field => $self->{session}->make_text(
					$field->display_name( $self->{session}) 
				) );
			next;
		}

		unless( $field_id eq "succeeds" )
		{
			next;
		}

		# so it is "succeeds"...
		# Ensure that the user is authorised to post to this
		# either the same user owns both eprints, or the 
		# current user is an editor.

		my $user = $self->{session}->current_user();
		unless( 
			( defined $user && $user->has_priv( "editor" ) ) ||
			( $test_eprint->get_value("userid" ) eq 
				$self->get_value("userid") ) )
		{
 			# Not the same user. 
			push @problems, $self->{session}->html_phrase( 
				"lib/eprint:cant_succ" );
		}
	}

	
	return( \@problems );
}


######################################################################
=pod

=item $problems = $eprint->validate_meta( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "meta" stage of eprint
submission.

A reference to an empty array indicates no problems.

=cut
######################################################################

sub validate_meta
{
	my( $self, $for_archive ) = @_;
	
	my @all_problems;
	my @req_fields = $self->{dataset}->get_required_type_fields( 
		$self->get_value("type") );
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
=pod

=item $problems = $eprint->validate_documents( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the results of the "documents" stage of eprint
submission. That is to say, validate all the documents.

A reference to an empty array indicates no problems.

=cut
######################################################################

sub validate_documents
{
	my( $self, $for_archive ) = @_;
	my @problems;
	
        my @req_formats = @{$self->{session}->get_archive()->get_conf( 
		"required_formats" )};
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
		my $doc_ds = $self->{session}->get_archive()->get_dataset( 
			"document" );
		my $prob = $self->{session}->make_doc_fragment();
		$prob->appendChild( $self->{session}->html_phrase( 
			"lib/eprint:need_a_format" ) );
		my $ul = $self->{session}->make_element( "ul" );
		$prob->appendChild( $ul );
		
		foreach( @req_formats )
		{
			my $li = $self->{session}->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $doc_ds->render_type_name( 
				$self->{session}, $_ ) );
		}
			
		push @problems, $prob;

	}

	foreach $doc (@docs)
	{
		my $probs = $doc->validate( $for_archive );
		foreach (@$probs)
		{
			my $prob = $self->{session}->make_doc_fragment();
			$prob->appendChild( $doc->render_description() );
			$prob->appendChild( 
				$self->{session}->make_text( ": " ) );
			$prob->appendChild( $_ );
		}
	}

	return( \@problems );
}


######################################################################
=pod

=item $foo = $eprint->validate_full( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the entire eprint.

A reference to an empty array indicates no problems.

=cut
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
=pod

=item $eprint->prune_documents

Remove any documents associated with this eprint which don't actually
have any files.

=cut
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
=pod

=item @documents = $eprint->get_all_documents

Return an array of all EPrint::Document objects associated with this
eprint.

=cut
######################################################################

sub get_all_documents
{
	my( $self ) = @_;

	my $doc_ds = $self->{session}->get_archive()->get_dataset( "document" );

	my $searchexp = EPrints::SearchExpression->new(
		session=>$self->{session},
		dataset=>$doc_ds );

	$searchexp->add_field(
		$doc_ds->get_field( "eprintid" ),
		$self->get_value( "eprintid" ) );

	my $searchid = $searchexp->perform_search();
	my @documents = $searchexp->get_records();
	$searchexp->dispose();

	return( @documents );
}


######################################################################
=pod

=item $eprint->datestamp

Set the datestamp field to today's date (GMT).

=cut
######################################################################

sub datestamp
{
	my( $self ) = @_;

	$self->set_value( 
		"datestamp" , 
		EPrints::Utils::get_datestamp( time ) );
}


######################################################################
=pod

=item $success = $eprint->move_to_deletion

Transfer the EPrint into the "deletion" dataset. Should only be
called in eprints in the "archive" dataset.

=cut
######################################################################

sub move_to_deletion
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "deletion" );
	
	my $last_in_thread = $self->last_in_thread( $ds->get_field( 
		"succeeds" ) );
	my $replacement_id = $last_in_thread->get_value( "eprintid" );

	if( $replacement_id == $self->get_value( "eprintid" ) )
	{
		# This IS the last in the thread, so we should redirect
		# enquirers to the one this replaced, if any.
		$replacement_id = $self->get_value( "succeeds" );
	}

	$self->set_value( "replacedby" , $replacement_id );

	my $success = $self->_transfer( $ds );

	return $success;
}


######################################################################
=pod

=item $success = $eprint->move_to_inbox

Transfer the EPrint into the "inbox" dataset. Should only be
called in eprints in the "buffer" dataset.

=cut
######################################################################

sub move_to_inbox
{
	my( $self ) = @_;

	# if we is currently in archive... cjg? eh???

	my $ds = $self->{session}->get_archive()->get_dataset( "inbox" );
	
	my $success = $self->_transfer( $ds );
	
	return $success;
}


######################################################################
=pod

=item $success = $eprint->move_to_buffer

Transfer the EPrint into the "buffer" dataset. Should only be
called in eprints in the "inbox" or "archive" dataset.

=cut
######################################################################

sub move_to_buffer
{
	my( $self ) = @_;
	
	my $ds = $self->{session}->get_archive()->get_dataset( "buffer" );

	my $success = $self->_transfer( $ds );
	
	if( $success )
	{
		$self->{session}->get_archive()->call( 
			"update_submitted_eprint", $self );
		$self->commit();
	}
	
	return( $success );
}


######################################################################
# 
# $eprint->_move_from_archive
#
# Called when an item leaves the main archive. Removes the static 
# pages.
#
######################################################################

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


######################################################################
=pod

=item $success = $eprint->move_to_archive

Move this eprint into the main "archive" dataset. Normally only called
on eprints in "deletion" or "buffer" datasets.

=cut
######################################################################

sub move_to_archive
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "archive" );
	my $success = $self->_transfer( $ds );
	
	if( $success )
	{
		$self->{session}->get_archive()->call( 
			"update_archived_eprint", $self );
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
=pod

=item $path = $eprint->local_path

Return the full path of the EPrint directory on the local filesystem.
No trailing slash.

=cut
######################################################################

sub local_path
{
	my( $self ) = @_;
	
	return( 
		$self->{session}->get_archive()->get_conf( 
			"documents_path" )."/".$self->get_value( "dir" ) );
}


######################################################################
=pod

=item $url = $eprint->url_stem

Return the URL to this EPrint's directory. Note, this INCLUDES the
trailing slash, unlike the local_path() method.

=cut
######################################################################

sub url_stem
{
	my( $self ) = @_;

	return( 
		sprintf( 
			"%s/%08d/", 
			$self->{session}->get_archive()->get_conf( 
							"documents_url" ), 
			$self->{data}->{eprintid} ) );
}


######################################################################
=pod

=item $eprint->generate_static

Generate the static version of the abstract web page. In a multi-language
archive this will generate one version per language.

It only makes sense to call this on eprints in the "archive" and
"deletion" datasets.

=cut
######################################################################

sub generate_static
{
	my( $self ) = @_;

	my $eprintid = $self->get_value( "eprintid" );

	my $ds_id = $self->{dataset}->id();
	if( $ds_id ne "archive" && $ds_id ne "deletion" )
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
	foreach $langid ( 
		@{$self->{session}->get_archive()->get_conf( "languages" )} ) 
	{
		$self->{session}->change_lang( $langid );
		my $full_path = $self->_htmlpath( $langid );

		my @created = eval
		{
			my @created = mkpath( $full_path, 0, 0775 );
			return( @created );
		};

		$self->{session}->new_page();
		my( $page, $title, $links ) = $self->render();

		$self->{session}->build_page( $title, $page, "abstract", $links );
		$self->{session}->page_to_file( $full_path . "/index.html" );

		next if( $ds_id ne "archive" );
		# Only live archive records have actual documents 
		# available.

		my @docs = $self->get_all_documents();
		my $doc;
		foreach $doc ( @docs )
		{
			unless( $doc->is_set( "security" ) )
			{
				$doc->create_symlink( $self, $full_path );
			}
		}
	}
	$self->{session}->change_lang( $real_langid );
}


######################################################################
=pod

=item $eprint->remove_static

Remove the static web page or pages.

=cut
######################################################################

sub remove_static
{
	my( $self ) = @_;

	my $langid;
	foreach $langid 
		( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		rmtree( $self->_htmlpath( $langid ) );
	}
}

######################################################################
# 
# $path = $eprint->_htmlpath( $langid )
#
# return the filesystem path in which the static files for this eprint
# are stored.
#
######################################################################

sub _htmlpath
{
	my( $self, $langid ) = @_;

	return $self->{session}->get_archive()->get_conf( "htdocs_path" ).
		"/".$langid."/archive/".
		eprintid_to_path( $self->get_value( "eprintid" ) );
}


######################################################################
=pod

=item ( $description, $title, $links ) = $eprint->render

Render the eprint. The 3 returned values are references to XHTML DOM
objects. $description is the public viewable description of this eprint
that appears as the body of the abstract page. $title is the title of
the abstract page for this eprint. $links is any elements which should
go in the <head> of this page.

=cut
######################################################################

sub render
{
        my( $self ) = @_;

        my( $dom, $title, $links );
	my $ds_id = $self->{dataset}->id();
	if( $ds_id eq "deletion" )
	{
		$title = $self->{session}->html_phrase( 
			"lib/eprint:eprint_gone_title" );
		$dom = $self->{session}->make_doc_fragment();
		$dom->appendChild( $self->{session}->html_phrase( 
			"lib/eprint:eprint_gone" ) );
		my $replacement = new EPrints::EPrint(
			$self->{session},
			$self->get_value( "replacedby" ),
			$self->{session}->get_archive()->get_dataset( 
				"archive" ) );
		if( defined $replacement )
		{
			my $cite = $replacement->render_citation_link();
			$dom->appendChild( 
				$self->{session}->html_phrase( 
					"lib/eprint:later_version", 
					citation => $cite ) );
		}
	}
	else
	{
		( $dom, $title, $links ) = 
			$self->{session}->get_archive()->call( 
				"eprint_render", 
				$self, $self->{session} );
	}

	if( !defined $links )
	{
		$links = $self->{session}->make_doc_fragment();
	}
	
        return( $dom, $title, $links );
}


######################################################################
=pod

=item $dom = $eprint->render_full

Render as XHTML DOM a full description of this eprint - the one
intended for editors.

=cut
######################################################################

sub render_full
{
        my( $self ) = @_;

        my( $dom, $title ) = $self->{session}->get_archive()->call( 
		"eprint_render_full", 
		$self, 
		$self->{session} );

        return( $dom );
}


######################################################################
=pod

=item $url = $eprint->get_url( [$staff] )

Return the public URL of this eprints abstract page. If $staff is
true then return the URL of the staff view of this eprint.

=cut
######################################################################

sub get_url
{
	my( $self , $staff ) = @_;

	if( defined $staff && $staff )
	{
		return $self->{session}->get_archive()->get_conf( "perl_url" ).
			"/users/staff/edit_eprint?eprintid=".
			$self->get_value( "eprintid" )."&".
			"dataset=".$self->get_dataset()->id();
	}
	
	return( $self->url_stem() );
}


######################################################################
=pod

=item $user = $eprint->get_user

Return the EPrints::User to whom this eprint belongs (if any).

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	my $user = EPrints::User->new( 
		$self->{session}, 
		$self->get_value( "userid" ) );

	return $user;
}


######################################################################
=pod

=item $path = EPrints::EPrint::eprintid_to_path( $eprintid )

Return this eprints id converted into directories. Thousands of 
files in one directory cause problems. For example, the eprint with the 
id 50344 would have the path 00/05/03/44.

=cut
######################################################################

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
=pod

=item @eprints = $eprint->get_all_related

Return the eprints that are related in some way to this in a succession
or commentary thread. The returned list does NOT include this EPrint.

=cut
######################################################################

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
=pod

=item $boolean = $eprint->in_thread( $field )

Return true if this eprint is part of a thread of $field. $field
should be an EPrint::MetaField representing either "commentary" or
"succeeds".

=cut
######################################################################

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
=pod

=item $eprint = $eprint->first_in_thread( $field )

Return the first (earliest) version or first paper in the thread
of commentaries of this paper in the archive.

=cut
######################################################################

sub first_in_thread
{
	my( $self, $field ) = @_;
	
	my $first = $self;
	my $ds = $self->{session}->get_archive()->get_dataset( "archive" );
	
	while( defined $first->get_value( $field->get_name() ) )
	{
		my $prev = EPrints::EPrint->new( 
				$self->{session},
				$first->get_value( $field->get_name() ),
				$ds );

		return( $first ) unless( defined $prev );
		$first = $prev;
	}
		       
	return( $first );
}


######################################################################
=pod

=item @eprints = $eprint->later_in_thread( $field )

Return a list of the later items in the thread.

=cut
######################################################################

sub later_in_thread
{
	my( $self, $field ) = @_;

	my $searchexp = EPrints::SearchExpression->new(
		session => $self->{session},
		dataset => $self->{session}->get_archive()->get_dataset( 
			"archive" ) );
#cjg		[ "datestamp DESC" ] ) ); sort by date!

	$searchexp->add_field( 
		$field, 
		$self->get_value( "eprintid" ) );

	my $searchid = $searchexp->perform_search();
	my @eprints = $searchexp->get_records();
	$searchexp->dispose();

	return @eprints;
}


######################################################################
=pod

=item @eprints = $eprint->all_in_thread( $field )

Return all of the EPrints in the given thread.

=cut
######################################################################

sub all_in_thread
{
	my( $self, $field ) = @_;

	my @eprints;
	
	my $first = $self->first_in_thread( $field );
	
	$self->_collect_thread( $field, $first, \@eprints );

	return( @eprints );
}

######################################################################
# 
# $foo = $eprint->_collect_thread( $field, $current, $eprints )
#
# undocumented
#
######################################################################

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
=pod

=item $eprint = $eprint->last_in_thread( $field )

Return the last item in the specified thread.

=cut
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


######################################################################
=pod

=item $eprint->remove_from_threads

Extract the eprint from any threads it's in. i.e., if any other
paper is a later version of or commentary on this paper, the link
from that paper to this will be removed.

Abstract pages are updated if needed.

=cut
######################################################################

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


######################################################################
=pod

=item $xhtml = $eprint->render_version_thread( $field )

Render XHTML DOM describing the entire thread as nested unordered lists.

=cut
######################################################################

sub render_version_thread
{
	my( $self, $field ) = @_;

	my $html;

	my $first_version = $self->first_in_thread( $field );

	my $ul = $self->{session}->make_element( "ul" );
	
	$ul->appendChild( $first_version->_render_version_thread_aux( $field, $self ) );
	
	return( $ul );
}

######################################################################
# 
# $xhtml = $eprint->_render_version_thread_aux( $field, $eprint_shown )
#
# undocumented
#
######################################################################

sub _render_version_thread_aux
{
	my( $self, $field, $eprint_shown ) = @_;
	
	my $li = $self->{session}->make_element( "li" );

	my $cstyle = "thread_".$field->get_name();

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


######################################################################
=pod

=item $type = $eprint->get_type

Return the type of this eprint.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "type" );
}



1; # For use/require success

	

######################################################################
=pod

=back

=cut

