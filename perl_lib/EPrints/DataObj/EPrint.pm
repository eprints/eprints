######################################################################
#
# EPrints::DataObj::EPrint
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

=head1 NAME

B<EPrints::DataObj::EPrint> - Class representing an actual EPrint

=head1 DESCRIPTION

This class represents a single eprint record and the metadata 
associated with it. This is associated with one of more 
EPrint::Document objects.

EPrints::DataObj::EPrint is a subclass of EPrints::DataObj with the following
metadata fields (plus those defined in ArchiveMetadataFieldsConfig):

=head1 SYSTEM METADATA

=over 4

=item eprintid (int)

The unique numerical ID of this eprint. 

=item rev_number (int)

The number of the current revision of this record.

=item userid (itemref)

The id of the user who deposited this eprint (if any). Scripted importing
could cause this not to be set.

=item dir (text)

The directory, relative to the documents directory for this repository, which
this eprints data is stored in. Eg. disk0/00/00/03/34 for record 334.

=item datestamp (time)

The date this record first appeared live in the repository.

=item lastmod (time)

The date this record was last modified.

=item status_changes (time)

The date/time this record was moved between inbox, buffer, archive, etc.

=item type (namedset)

The type of this record, one of the types of the "eprint" dataset.

=item succeeds (itemref)

The ID of the eprint (if any) which this succeeds.  This field should have
been an int and may be changed in a later upgrade.

=item commentary (itemref)

The ID of the eprint (if any) which this eprint is a commentary on.  This 
field should have been an int and may be changed in a later upgrade.

=item replacedby (itemref)

The ID of the eprint (if any) which has replaced this eprint. This is only set
on records in the "deletion" dataset.  This field should have
been an int and may be changed in a later upgrade.

=back

=head1 METHODS

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From EPrints::DataObj
#
######################################################################

package EPrints::DataObj::EPrint;

@ISA = ( 'EPrints::DataObj' );

use strict;

######################################################################
=pod

=item $metadata = EPrints::DataObj::EPrint->get_system_field_info

Return an array describing the system metadata of the EPrint dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return ( 
	{ name=>"eprintid", type=>"int", required=>1, import=>0, can_clone=>0 },

	{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

	{ name=>"documents", type=>"subobject", datasetid=>'document',
		multiple=>1 },

	{ name=>"eprint_status", type=>"set", required=>1,
		options=>[qw/ inbox buffer archive deletion /] },

	# UserID is not required, as some bulk importers
	# may not provide this info. maybe bulk importers should
	# set a userid of -1 or something.

	{ name=>"userid", type=>"itemref", 
		datasetid=>"user", required=>0 },

	{ name=>"importid", type=>"itemref", required=>0, datasetid=>"import" },

	{ name=>"source", type=>"text", required=>0, },

	{ name=>"dir", type=>"text", required=>0, can_clone=>0,
		text_index=>0, import=>0, show_in_fieldlist=>0 },

	{ name=>"datestamp", type=>"time", required=>0, import=>0,
		render_res=>"minute", render_style=>"short", can_clone=>0 },

	{ name=>"lastmod", type=>"time", required=>0, import=>0,
		render_res=>"minute", render_style=>"short", can_clone=>0 },

	{ name=>"status_changed", type=>"time", required=>0, import=>0,
		render_res=>"minute", render_style=>"short", can_clone=>0 },

	{ name=>"type", type=>"namedset", set_name=>"eprint", required=>1, 
		"input_style"=> "long" },

	{ name=>"succeeds", type=>"itemref", required=>0,
		datasetid=>"eprint", can_clone=>0 },

	{ name=>"commentary", type=>"itemref", required=>0,
		datasetid=>"eprint", can_clone=>0, sql_index=>0 },

	{ name=>"replacedby", type=>"itemref", required=>0,
		datasetid=>"eprint", can_clone=>0 },

	# empty string: normal visibility
	# no_search: does not appear on search/view pages. 
	# to hide... well, the dark dataset should appear in 3.1 or 3.2
	{ name=>"metadata_visibility", type=>"set", required=>1,
		options=>[ "show", "no_search" ] },

	{ name=>"contact_email", type=>"email", required=>0, can_clone=>0 },

	{ name=>"fileinfo", type=>"longtext", 
		text_index=>0,
		export_as_xml=>0,
		render_value=>"EPrints::DataObj::EPrint::render_fileinfo" },

	{ name=>"latitude", type=>"float", required=>0 },

	{ name=>"longitude", type=>"float", required=>0 },

	{ name=>"relation", type=>"compound", multiple=>1,
		fields => [
			{
				sub_name => "type",
				type => "namedset",
				set_name => "document_relation",
			},
			{
				sub_name => "uri",
				type => "text",
			},
		],
	},

	{ name=>"item_issues", type=>"compound", multiple=>1,
		fields => [
			{
				sub_name => "id",
				type => "text",
				text_index => 0,
			},
			{
				sub_name => "type",
				type => "text",
				text_index => 0,
			},
			{
				sub_name => "description",
				type => "longtext",
				text_index => 0,
				render_single_value => "EPrints::Extras::render_xhtml_field",
			},
			{
				sub_name => "timestamp",
				type => "time",
			},
			{
				sub_name => "status",
				type => "set",
				text_index => 0,
				options=> [qw/ discovered ignored reported autoresolved resolved /],
			},
			{
				sub_name => "reported_by",
				type => "itemref",
				datasetid => "user",
			},
			{
				sub_name => "resolved_by",
				type => "itemref",
				datasetid => "user",
			},
			{
				sub_name => "comment",
				type => "longtext",
				text_index => 0,
				render_single_value => "EPrints::Extras::render_xhtml_field",
			},
		],
		make_value_orderkey => "EPrints::DataObj::EPrint::order_issues_newest_open_timestamp",
		render_value=>"EPrints::DataObj::EPrint::render_issues",
		volatile => 1,
	},

	{ name=>"item_issues_count", type=>"int",  volatile=>1 },

	);
}




sub render_issues
{
	my( $session, $field, $value ) = @_;

	# Default rendering only shows discovered and reported issues (not resolved or ignored ones)

	my $f = $field->get_property( "fields_cache" );
	my $fmap = {};	
	foreach my $field_conf ( @{$f} )
	{
		my $fieldname = $field_conf->{name};
		my $field = $field->{dataset}->get_field( $fieldname );
		$fmap->{$field_conf->{sub_name}} = $field;
	}

	my $ol = $session->make_element( "ol" );
	foreach my $issue ( @{$value} )
	{
		next if( $issue->{status} ne "reported" && $issue->{status} ne "discovered" ); 
		my $li = $session->make_element( "li" );
		$li->appendChild( EPrints::Extras::render_xhtml_field( $session, $fmap->{description}, $issue->{description} ) );
		$li->appendChild( $session->make_text( " - " ) );
		$li->appendChild( $fmap->{timestamp}->render_single_value( $session, $issue->{timestamp} ) );
		$ol->appendChild( $li );
	}

	return $ol;
}


sub order_issues_newest_open_timestamp
{
	my( $field, $value, $session, $langid, $dataset ) = @_;

	return "" if !defined $value;

	my $v = "";
	foreach my $issue ( sort { $b->{timestamp} cmp $a->{timestamp} } @{$value} )
	{
		next if( $issue->{status} ne "reported" && $issue->{status} ne "discovered" );
		$v.=$issue->{timestamp};
	}

	return $v;	
}

sub render_fileinfo
{
	my( $session, $field, $value, $alllangs, $nolink, $eprint ) = @_;

	my $f = $session->make_doc_fragment;
	foreach my $doc ($eprint->get_all_documents)
	{
		my $a = $session->render_link( $doc->get_url );
		$a->appendChild( $session->make_element( 
			"img", 
			class=>"ep_doc_icon",
			alt=>"file",
			src=>$doc->icon_url,
			border=>0 ));
		$f->appendChild( $a );
	}

	return $f;
};



######################################################################
# =pod
# 
# =item $eprint = EPrints::DataObj::EPrint::create( $session, $dataset, $data )
# 
# Create a new EPrint entry in the given dataset.
# 
# If data is defined, then this is used as the base for the new record.
# Otherwise the repository specific defaults (if any) are used.
# 
# The fields "eprintid" and "dir" will be overridden even if they
# are set.
# 
# If C<$data> is not defined calls L</set_eprint_defaults>.
# 
# =cut
######################################################################

sub create
{
	my( $session, $dataset, $data ) = @_;

	return EPrints::DataObj::EPrint->create_from_data( 
		$session, 
		$data, 
		$dataset );
}

######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
# 
# Create a new object of this type in the database. 
# 
# $dataset is the dataset it will belong to. 
# 
# $data is the data structured as with new_from_data.
# 
# This will create sub objects also.
# 
# =cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $documents = delete $data->{documents};

	my $new_eprint = $class->SUPER::create_from_data( $session, $data, $dataset );
	
	return undef unless defined $new_eprint;

	$session->get_database->counter_minimum( "eprintid", $new_eprint->get_id );
	
	$new_eprint->set_under_construction( 1 );

	return unless defined $new_eprint;

	if( defined $documents )
	{
		my @docs;
		foreach my $docdata_orig ( @{$documents} )
		{
			my %docdata = %{$docdata_orig};
			$docdata{eprintid} = $new_eprint->get_id;
			$docdata{eprint} = $new_eprint;
			my $docds = $session->get_repository->get_dataset( "document" );
			push @docs, EPrints::DataObj::Document->create_from_data( $session,\%docdata,$docds );
		}
		my @finfo = ();
		foreach my $doc ( @docs )
		{
			push @finfo, $doc->icon_url.";".$doc->get_url;
		}
		$new_eprint->set_value( "fileinfo", join( "|", @finfo ) );
	}

	$new_eprint->set_under_construction( 0 );

	$session->get_repository->call( 
		"set_eprint_automatic_fields", 
		$new_eprint );

	$session->get_database->update(
		$dataset,
		$new_eprint->{data} );

	$new_eprint->queue_changes;

	my $user = $session->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;

	my $history_ds = $session->get_repository->get_dataset( "history" );
	$history_ds->create_object( 
		$session,
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$new_eprint->get_id,
			revision=>$new_eprint->get_value( "rev_number" ),
			action=>"create",
			details=>undef,
		}
	);
	$new_eprint->write_revision;

	# No longer needed - generates on demand.
	# $new_eprint->generate_static;

	return $new_eprint;
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::EPrint->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "eprint";
}

######################################################################
=pod

=item $dataset = $eprint->get_gid

Returns the OAI identifier for this eprint.

=cut
######################################################################

sub get_gid
{
	my( $self ) = @_;

	my $session = $self->get_session;

	return EPrints::OpenArchives::to_oai_identifier(
		$session->get_repository->get_conf(
			"oai",
			"v2",
			"archive_id",
		),
		$self->get_id,
	);
}

######################################################################
=pod

=item $dataset = $eprint->get_dataset

Return the dataset to which this object belongs. This will return
one of the virtual datasets: inbox, buffer, archive or deletion.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	my $status = $self->get_value( "eprint_status" );

	EPrints::abort "eprint_status not set" unless defined $status;

	return $self->{session}->get_repository->get_dataset( $status );
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::EPrint->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	if( !defined $data->{eprintid} )
	{ 
		my $new_id = $session->get_database->counter_next( "eprintid" );
		$data->{eprintid} = $new_id;
	}

	my $dir = _create_directory( $session, $data->{eprintid} );

	$data->{dir} = $dir;
	$data->{rev_number} = 1;
	$data->{lastmod} = EPrints::Time::get_iso_timestamp();
	$data->{status_changed} = $data->{lastmod};
	if( $data->{eprint_status} eq "archive" )
	{
		$data->{datestamp} = $data->{lastmod};
	}
	$data->{metadata_visibility} = "show";

	$session->get_repository->call(
		"set_eprint_defaults",
		$data,
		$session );

	return $data;
}


######################################################################
# 
# $directory =  EPrints::DataObj::EPrint::_create_directory( $session, $eprintid )
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
	my @dirs = sort $session->get_repository->get_store_dirs;
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
		my $warnsize = $session->get_repository->get_conf(
						"diskspace_warn_threshold");
		my $errorsize = $session->get_repository->get_conf(
						"diskspace_error_threshold");

		my $best_free_space = 0;
		my $dir;	
		foreach $dir (reverse sort @dirs)
		{
			my $free_space = $session->get_repository->
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
			$session->get_repository->log(<<END);
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
			$session->get_repository->log(<<END);
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
		$session->get_repository->log(<<END);
Failed to turn eprintid: "$eprintid" into a path.
END
		return( undef ) ;
	}

	my $docdir = $storedir."/".$idpath;

	# Full path including doc store root
	my $full_path = $session->get_repository->get_conf("documents_path").
				"/".$docdir;
	
	if (!EPrints::Platform::mkdir( $full_path ))
	{
		$session->get_repository->log(<<END);
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

=item $eprint = $eprint->clone( $dest_dataset, $copy_documents, $link )

Create a copy of this EPrint with a new ID in the given dataset.
Return the new eprint, or undef in the case of an error.

If $copy_documents is set and true then the documents (and files)
will be copied in addition to the metadata.

If $nolink is true then the new eprint is not connected to the
old one.

=cut
######################################################################

sub clone
{
	my( $self, $dest_dataset, $copy_documents, $nolink ) = @_;

	my $data = EPrints::Utils::clone( $self->{data} );
	foreach my $field ( $self->{dataset}->get_fields )
	{
		next if( $field->get_property( "can_clone" ) );
		delete $data->{$field->get_name};
	}

	# Create the new EPrint record
	my $new_eprint = $dest_dataset->create_object(
		$self->{session},
		$data );
	
	unless( defined $new_eprint )
	{
		return undef;
	}

	my $status = $self->get_value( "eprint_status" );
	unless( $nolink )
	{
		# We assume the new eprint will be a later version of this one,
		# so we'll fill in the succeeds field, provided this one is
		# already in the main repository.
#		if( $status eq "archive" || $status eq "deletion" )
#		{
#		}
#		cjg disabled this condtion.

		$new_eprint->set_value( "succeeds" , $self->get_value( "eprintid" ) );
	}

	# Attempt to copy the documents, if appropriate
	my $ok = 1;

	if( $copy_documents )
	{
		my @docs = $self->get_all_documents;

		foreach my $doc (@docs)
		{
			my $new_doc = $doc->clone( $new_eprint );
			unless( $new_doc )
			{	
				$ok = 0;
				next;
			}
			$new_doc->register_parent( $new_eprint );
		}
	}

	# Now write the new EPrint to the database
	unless( $ok && $new_eprint->commit )
	{
		$new_eprint->remove;
		return( undef );
	}


	return( $new_eprint )
}


######################################################################
# 
# $success = $eprint->_transfer( $new_status )
#
#  Change the eprint status.
#
######################################################################

sub _transfer
{
	my( $self, $new_status ) = @_;

	# Keep the old table
	my $old_status = $self->get_value( "eprint_status" );

	# set the status changed time to now.
	$self->set_value( 
		"status_changed" , 
		EPrints::Time::get_iso_timestamp() );
	$self->set_value( 
		"eprint_status" , 
		$new_status );

	# Write self
	$self->commit( 1 );

	# log the change
	my $user = $self->{session}->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;
	my $code = "move_"."$old_status"."_to_"."$new_status";
	my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
	$history_ds->create_object( 
		$self->{session},
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$self->get_id,
			revision=>$self->get_value( "rev_number" ),
			action=>$code,
			details=>undef
		}
	);

	# Need to clean up stuff if we move this record out of the
	# archive.
	if( $old_status eq "archive" )
	{
		$self->_move_from_archive;
	}

	# Trigger any actions which are configured for eprints status
	# changes.
	if( $self->{session}->get_repository->can_call( 'eprint_status_change' ) )
	{
		$self->{session}->get_repository->call( 
			'eprint_status_change', 
			$self, 
			$old_status, 
			$new_status );
	}

	# if this succeeds something then update its metadata visibility
	my $successor = EPrints::EPrint->new( $self->{session}, $self->{data}->{succeeds} );
	$successor->succeed_thread_modified if( defined $successor );

	# update this eprints metadata visibility if needed.
	$self->succeed_thread_modified;
	
	return( 1 );
}

######################################################################
=pod

=item $eprint->log_mail_owner( $mail )

Log that the given mail message was send to the owner of this EPrint.

$mail is the same XHTML DOM that was sent as the email.

=cut
######################################################################

sub log_mail_owner
{
	my( $self, $mail ) = @_;

	my $user = $self->{session}->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;

	my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
	my $details = EPrints::Utils::tree_to_utf8( $mail , 80 );

	$history_ds->create_object( 
		$self->{session},
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$self->get_id,
			revision=>$self->get_value( "rev_number" ),
			action=>"mail_owner",
			details=> $details,
		}
	);
}

######################################################################
=pod

=item $user = $eprint->get_editorial_contact

Return the user identified as the editorial contact for this item.

By default returns undef.

nb. This has nothing to do with the editor defined in the metadata

=cut
######################################################################

sub get_editorial_contact
{
	my( $self ) = @_;

	return undef;
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

	my $user = $self->{session}->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;

	my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
	$history_ds->create_object( 
		$self->{session},
		{
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$self->get_id,
			revision=>$self->get_value( "rev_number" ),
			action=>"destroy",
			details=>undef,
		}
	);

	foreach my $doc ( $self->get_all_documents )
	{
		$doc->remove;
	}

	my $success = $self->{session}->get_database->remove(
		$self->{dataset},
		$self->get_value( "eprintid" ) );

	# remove the webpages assocaited with this record.
	$self->remove_static;

	return $success;
}


######################################################################
=pod

=item $success = $eprint->commit( [$force] );

Commit any changes that might have been made to the database.

If the item has not be changed then this function does nothing unless
$force is true.

Calls L</set_eprint_automatic_fields> just before the C<$eprint> is committed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	if( $self->{changed}->{succeeds} )
	{
		my $old_succ = EPrints::EPrint->new( $self->{session}, $self->{changed}->{succeeds} );
		$old_succ->succeed_thread_modified if( defined $old_succ );

		my $new_succ = EPrints::EPrint->new( $self->{session}, $self->{data}->{succeeds} );
		$new_succ->succeed_thread_modified if( defined $new_succ );
	}

	# recalculate issues number
	my $issues = $self->get_value( "item_issues" ) || [];
	my $c = 0;
	foreach my $issue ( @{$issues} )
	{
		$c+=1 if( $issue->{status} eq "discovered" );
		$c+=1 if( $issue->{status} eq "reported" );
	}
	$self->set_value( "item_issues_count", $c );

	$self->{session}->get_repository->call( 
		"set_eprint_automatic_fields", 
		$self );

	my @docs = $self->get_all_documents();
	my @finfo = ();
	foreach my $doc ( @docs )
	{
		push @finfo, $doc->icon_url.";".$doc->get_url;
	}
	$self->set_value( "fileinfo", join( "|", @finfo ) );

	if( !$self->is_set( "datestamp" ) && $self->get_value( "eprint_status" ) eq "archive" )
	{
		$self->set_value( 
			"datestamp" , 
			EPrints::Time::get_iso_timestamp() );
	}

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	if( $self->{non_volatile_change} )
	{
		my $rev_number = $self->get_value( "rev_number" ) || 0;
		$rev_number += 1;
	
		$self->set_value( "rev_number", $rev_number );

		$self->set_value( 
			"lastmod" , 
			EPrints::Time::get_iso_timestamp() );
	}

	$self->tidy;
	my $success = $self->{session}->get_database->update(
		$self->{dataset},
		$self->{data} );

	if( !$success )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( 
			"Error committing EPrint ".
			$self->get_value( "eprintid" ).": ".$db_error );
		return $success;
	}

	unless( $self->under_construction )
	{
		if( $self->{non_volatile_change} )
		{
			$self->write_revision;
		}
		$self->remove_static;
	}

	$self->queue_changes;
	
	if( $self->{non_volatile_change} )
	{
		my $user = $self->{session}->current_user;
		my $userid = undef;
		$userid = $user->get_id if defined $user;
	
		my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
		$history_ds->create_object( 
			$self->{session},
			{
				userid=>$userid,
				datasetid=>"eprint",
				objectid=>$self->get_id,
				revision=>$self->get_value( "rev_number" ),
				action=>"modify",
				details=>undef
			}
		);
	}

	return( $success );
}

######################################################################
=pod

=item $eprint->write_revision

Write out a snapshot of the XML describing the current state of the
eprint.

=cut
######################################################################

sub write_revision
{
	my( $self ) = @_;

	my $tmpfile = File::Temp->new;
	my $filename = "eprint.xml";

	print $tmpfile '<?xml version="1.0" encoding="utf-8" ?>'."\n";
	print $tmpfile $self->export( "XML" );

	seek($tmpfile,0,0);

	# Bit more complex, because we want to use our revision for controlling
	# the file revision numbers
	my $file = $self->get_stored_files( "revision", $filename );
	unless( $file )
	{
		$file = EPrints::DataObj::File->create_from_data( $self->get_session, {
			_parent => $self,
			bucket => "revision",
			filename => $filename,
		} );
	}
	$file->set_value( "rev_number", $self->get_value( "rev_number" )-1 );
	$file->upload( $tmpfile, "eprint.xml", -s "$tmpfile" );
}


######################################################################
=pod

=item $problems = $eprint->validate( [$for_archive] )

Return a reference to an array of XHTML DOM objects describing
validation problems with the entire eprint.

A reference to an empty array indicates no problems.

Calls L</validate_eprint> for the C<$eprint>.

=cut
######################################################################

sub validate
{
	my( $self , $for_archive ) = @_;

	return [] if $self->skip_validation;
	

	# get the workflow

	my %opts = ( item=> $self, session=>$self->{session} );
	$opts{STAFF_ONLY} = [$for_archive ? "TRUE" : "FALSE","BOOLEAN"];
 	my $workflow = EPrints::Workflow->new( $self->{session}, "default", %opts );

	my @problems = ();

	push @problems, $workflow->validate;

	# Now give the site specific stuff one last chance to have a gander.
	push @problems, $self->{session}->get_repository->call( 
			"validate_eprint", 
			$self,
			$self->{session},
			$for_archive );

	return( \@problems );
}

######################################################################
=pod

=item $warnings = $eprint->get_warnings

Return a reference to an array of XHTML DOM objects describing
warnings about this eprint - that is things that are not quite 
validation errors, but it'd be nice if they were fixed.

Calls L</eprint_warnings> for the C<$eprint>.

=cut
######################################################################

sub get_warnings
{
	my( $self , $for_archive ) = @_;

	# Now give the site specific stuff one last chance to have a gander.
	my @warnings = $self->{session}->get_repository->call( 
			"eprint_warnings", 
			$self,
			$self->{session} );

	return \@warnings;
}


######################################################################
=pod

=item $boolean = $eprint->skip_validation

Returns true if this eprint should pass validation without being
properly validated. This is to allow the use of dodgey data imported
from legacy systems.

=cut
######################################################################

sub skip_validation 
{
	my( $self ) = @_;

	my $repos = $self->{session}->get_repository;
	if( $repos->can_call( 'skip_validation' ) )
	{
		return $repos->call( 'skip_validation', $self );
	}
	else
	{
		return( 0 );
	}
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
	foreach my $doc ( $self->get_all_documents )
	{
		my %files = $doc->files;
		if( scalar keys %files == 0 )
		{
			# Has no associated files, prune
			$doc->remove;
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

	my $docs = $self->get_value( "documents" );

	return @$docs;
}



######################################################################
=pod

=item @formats =  $eprint->required_formats

Return a list of the required formats for this 
eprint. Only one of the required formats is required, not all.

An empty list means no format is required.

=cut
######################################################################

sub required_formats
{
	my( $self ) = @_;

	my $fmts = $self->{session}->get_repository->get_conf( 
				"required_formats" );
	if( ref( $fmts ) ne "ARRAY" )
	{
		# function pointer then...
		$fmts = $self->{session}->get_repository->call(
			'required_formats',
			$self );
	}

	return @{$fmts};
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

	my $ds = $self->{session}->get_repository->get_dataset( "eprint" );
	
	my $last_in_thread = $self->last_in_thread( $ds->get_field( "succeeds" ) );
	my $replacement_id = $last_in_thread->get_value( "eprintid" );

	if( $replacement_id == $self->get_value( "eprintid" ) )
	{
		# This IS the last in the thread, so we should redirect
		# enquirers to the one this replaced, if any.
		$replacement_id = $self->get_value( "succeeds" );
	}

	$self->set_value( "replacedby" , $replacement_id );

	my $success = $self->_transfer( "deletion" );

	if( $success )
	{
		$self->generate_static_all_related;
	}
	
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

	my $success = $self->_transfer( "inbox" );

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
	
	my $success = $self->_transfer( "buffer" );
	
	if( $success )
	{
		# supported but deprecated. use eprint_status_change instead.
		if( $self->{session}->get_repository->can_call( "update_submitted_eprint" ) )
		{
			$self->{session}->get_repository->call( 
				"update_submitted_eprint", $self );
			$self->commit;
		}
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

	$self->generate_static_all_related;
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

	my $success = $self->_transfer( "archive" );
	
	if( $success )
	{
		# supported but deprecated. use eprint_status_change instead.
		if( $self->{session}->get_repository->can_call( "update_archived_eprint" ) )
		{
			$self->{session}->get_repository->try_call( 
				"update_archived_eprint", $self );
			$self->commit;
		}

		$self->generate_static_all_related;
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

	unless( $self->is_set( "dir" ) )
	{
		EPrints::abort( "EPrint ".$self->get_id." has no directory set. This is very dangerous as EPrints has no idea where to write files for this eprint. This may imply a buggy import tool or some other cause of corrupt data." );
	}

	return( 
		$self->{session}->get_repository->get_conf( 
			"documents_path" )."/".$self->get_value( "dir" ) );
}


######################################################################
=pod

=item $url = $eprint->url_stem

Return the URL to this EPrint's directory. Note, this INCLUDES the
trailing slash, unlike the local_path method.

=cut
######################################################################

sub url_stem
{
	my( $self ) = @_;

	my $repository = $self->{session}->get_repository;

	my $url;
	$url = $repository->get_conf( "http_url" );
	$url .= '/';
	$url .= $self->get_value( "eprintid" )+0;
	$url .= '/';

	return $url;
}


######################################################################
=pod

=item $eprint->generate_static

Generate the static version of the abstract web page. In a multi-language
repository this will generate one version per language.

If called on inbox or buffer, remove the abstract page.

=cut
######################################################################

sub generate_static
{
	my( $self ) = @_;

	my $status = $self->get_value( "eprint_status" );

	$self->remove_static;

	# We is going to temporarily change the language of our session to
	# render the abstracts in each language.
	my $real_langid = $self->{session}->get_langid;

	my @langs = @{$self->{session}->get_repository->get_conf( "languages" )};
	foreach my $langid ( @langs )
	{
		$self->{session}->change_lang( $langid );
		my $full_path = $self->_htmlpath( $langid );

		my @created = EPrints::Platform::mkdir( $full_path );

		# only deleted and live records have a web page.
		next if( $status ne "archive" && $status ne "deletion" );

		my( $page, $title, $links ) = $self->render;

		my @plugins = $self->{session}->plugin_list( 
					type=>"Export",
					can_accept=>"dataobj/".$self->{dataset}->confid, 
					is_advertised => 1,
					is_visible=>"all" );
		if( scalar @plugins > 0 ) {
			$links = $self->{session}->make_doc_fragment() if( !defined $links );
			foreach my $plugin_id ( @plugins ) 
			{
				$plugin_id =~ m/^[^:]+::(.*)$/;
				my $id = $1;
				my $plugin = $self->{session}->plugin( $plugin_id );
				my $link = $self->{session}->make_element( 
					"link", 
					rel=>"alternate",
					href=>$plugin->dataobj_export_url( $self ),
					type=>$plugin->param("mimetype"),
					title=>EPrints::XML::to_string( $plugin->render_name ), );
				$links->appendChild( $link );
				$links->appendChild( $self->{session}->make_text( "\n" ) );
			}
		}
		$self->{session}->write_static_page( 
			$full_path . "/index",
			{title=>$title, page=>$page, head=>$links },
			"default" );
	}
	$self->{session}->change_lang( $real_langid );
}

######################################################################
=pod

=item $eprint->generate_static_all_related

Generate the static pages for this eprint plus any it's related to,
by succession or commentary.

=cut
######################################################################

sub generate_static_all_related
{
	my( $self ) = @_;

	$self->generate_static;

	# Generate static pages for everything in threads, if 
	# appropriate
	my @to_update = $self->get_all_related;
	
	# Do the actual updates
	foreach my $related (@to_update)
	{
		$related->generate_static;
	}
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
		( @{$self->{session}->get_repository->get_conf( "languages" )} )
	{
		EPrints::Utils::rmtree( $self->_htmlpath( $langid ) );
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

	return $self->{session}->get_repository->get_conf( "htdocs_path" ).
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

Calls L</eprint_render> to actually render the C<$eprint>, if it isn't deleted.

=cut
######################################################################

sub render_preview
{
	my( $self ) = @_;

	return $self->render( 1 );
}

sub render
{
	my( $self, $preview ) = @_;

	my( $dom, $title, $links );

	my $status = $self->get_value( "eprint_status" );
	if( $status eq "deletion" )
	{
		$title = $self->{session}->html_phrase( 
			"lib/eprint:eprint_gone_title" );
		$dom = $self->{session}->make_doc_fragment;
		$dom->appendChild( $self->{session}->html_phrase( 
			"lib/eprint:eprint_gone" ) );
		my $replacement = new EPrints::DataObj::EPrint(
			$self->{session},
			$self->get_value( "replacedby" ) );
		if( defined $replacement )
		{
			my $cite = $replacement->render_citation_link;
			$dom->appendChild( 
				$self->{session}->html_phrase( 
					"lib/eprint:later_version", 
					citation => $cite ) );
		}
	}
	else
	{
		( $dom, $title, $links ) = 
			$self->{session}->get_repository->call( 
				"eprint_render", 
				$self, $self->{session}, $preview );
		my $content = $self->{session}->make_element( "div", class=>"ep_summary_content" );
		my $content_top = $self->{session}->make_element( "div", class=>"ep_summary_content_top" );
		my $content_left = $self->{session}->make_element( "div", class=>"ep_summary_content_left" );
		my $content_main = $self->{session}->make_element( "div", class=>"ep_summary_content_main" );
		my $content_right = $self->{session}->make_element( "div", class=>"ep_summary_content_right" );
		my $content_bottom = $self->{session}->make_element( "div", class=>"ep_summary_content_bottom" );
		my $content_after = $self->{session}->make_element( "div", class=>"ep_summary_content_after" );
	
		$content_left->appendChild( render_box_list( $self->{session}, $self, "summary_left" ) );
		$content_right->appendChild( render_box_list( $self->{session}, $self, "summary_right" ) );
		$content_bottom->appendChild( render_box_list( $self->{session}, $self, "summary_bottom" ) );
		$content_top->appendChild( render_box_list( $self->{session}, $self, "summary_top" ) );

		$content->appendChild( $content_left );
		$content->appendChild( $content_right );
		$content->appendChild( $content_top );
		$content->appendChild( $content_main );
		$content_main->appendChild( $dom );
		$content->appendChild( $content_bottom );
		$content->appendChild( $content_after );
		$dom = $content;
	}

	if( !defined $links )
	{
		$links = $self->{session}->make_doc_fragment;
	}
	
	return( $dom, $title, $links );
}

sub render_box_list
{
	my( $session, $eprint, $list ) = @_;

	my $processor = bless { session=>$session, eprint=>$eprint, eprintid=>$eprint->get_id }, "EPrints::ScreenProcessor";
	my $some_plugin = $session->plugin( "Screen", processor=>$processor );

	my $imagesurl = $session->get_repository->get_conf( "rel_path" );
	my $chunk = $session->make_doc_fragment;
	foreach my $item ( $some_plugin->list_items( $list ) )
	{
		my $i = $session->get_next_id;
		my $id = "ep_summary_box_$i";
		my $contentid = $id."_content";
		my $colbarid = $id."_colbar";
		my $barid = $id."_bar";

		my $div = $session->make_element( "div", class=>"ep_summary_box", id=>$id );
		$chunk->appendChild( $div );


		# Title
		my $div_title = $session->make_element( "div", class=>"ep_summary_box_title" );
		$div->appendChild( $div_title );

		my $nojstitle = $session->make_element( "div", class=>"ep_no_js" );
		$nojstitle->appendChild( $item->{screen}->render_title );
		$div_title->appendChild( $nojstitle );

		my $collapse_bar = $session->make_element( "div", class=>"ep_js_only", id=>$colbarid );
		my $collapse_link = $session->make_element( "a", class=>"ep_box_collapse_link", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',true,'${id}');EPJS_toggle('${colbarid}',true);EPJS_toggle('${barid}',false);return false", href=>"#" );
		$collapse_link->appendChild( $session->make_element( "img", alt=>"-", src=>"$imagesurl/style/images/minus.png", border=>0 ) );
		$collapse_link->appendChild( $session->make_text( " " ) );
		$collapse_link->appendChild( $item->{screen}->render_title );
		$collapse_bar->appendChild( $collapse_link );
		$div_title->appendChild( $collapse_bar );
		
		my $uncollapse_bar = $session->make_element( "div", class=>"ep_js_only", id=>$barid );
		my $uncollapse_link = $session->make_element( "a", id=>$barid, class=>"ep_box_collapse_link", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${contentid}',false,'${id}');EPJS_toggle('${colbarid}',true);EPJS_toggle('${barid}',false);return false", href=>"#" );
		$uncollapse_link->appendChild( $session->make_element( "img", alt=>"+", src=>"$imagesurl/style/images/plus.png", border=>0 ) );
		$uncollapse_link->appendChild( $session->make_text( " " ) );
		$uncollapse_link->appendChild( $item->{screen}->render_title );
		$uncollapse_bar->appendChild( $uncollapse_link );
		$div_title->appendChild( $uncollapse_bar );
	
		# Body	
		my $div_body = $session->make_element( "div", class=>"ep_summary_box_body", id=>$contentid );
		my $div_body_inner = $session->make_element( "div", id=>$contentid."_inner" );
		$div_body->appendChild( $div_body_inner );
		$div->appendChild( $div_body );
		$div_body_inner->appendChild( $item->{screen}->render );

		if( $item->{screen}->render_collapsed ) 
		{ 
			$collapse_bar->setAttribute( "style", "display: none" ); 
			$uncollapse_bar->setAttribute( "style", "display: block" ); 
			$div_body->setAttribute( "style", "display: none" ); 
		}
		else
		{
			$uncollapse_bar->setAttribute( "style", "display: none" ); 
			$collapse_bar->setAttribute( "style", "display: block" ); 
		}
	}
		
	return $chunk;
}



######################################################################
=pod

=item ( $html ) = $eprint->render_history

Render the history of this eprint as XHTML DOM.

=cut
######################################################################

sub render_history
{
	my( $self ) = @_;

	my $page = $self->{session}->make_doc_fragment;

	my $ds = $self->{session}->get_repository->get_dataset( "history" );
	my $searchexp = EPrints::Search->new(
		session=>$self->{session},
		dataset=>$ds,
		custom_order=>"-timestamp/-historyid" );
	
	$searchexp->add_field(
		$ds->get_field( "objectid" ),
		$self->get_id );
	$searchexp->add_field(
		$ds->get_field( "datasetid" ),
		'eprint' );
	
	my $results = $searchexp->perform_search;
	
	$results->map( sub {
		my( $session, $dataset, $item ) = @_;
	
		$item->set_parent( $self );
		$page->appendChild( $item->render );
	} );

	return $page;
}

######################################################################
=pod

=item $url = $eprint->get_control_url

Return the URL of the control page for this eprint.

=cut
######################################################################

sub get_control_url
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_conf( "http_cgiurl" ).
		"/users/home?screen=EPrint::View&eprintid=".
		$self->get_value( "eprintid" )
}

######################################################################
=pod

=item $url = $eprint->get_url

Return the public URL of this eprints abstract page. 

=cut
######################################################################

sub get_url
{
	my( $self , $staff ) = @_;

	return( $self->url_stem );
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

=item $path = EPrints::DataObj::EPrint::eprintid_to_path( $eprintid )

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
	
	if( defined $self->get_value( $field->get_name ) )
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
of commentaries of this paper in the repository.

=cut
######################################################################

sub first_in_thread
{
	my( $self, $field ) = @_;
	
	my $first = $self;
	my $below = {};	
	while( defined $first->get_value( $field->get_name ) )
	{
		if( $below->{$first->get_id} )
		{
			$self->loop_error( $field, keys %{$below} );
			last;
		}
		$below->{$first->get_id} = 1;
		my $prev = EPrints::DataObj::EPrint->new( 
				$self->{session},
				$first->get_value( $field->get_name ) );

		return( $first ) unless( defined $prev );
		$first = $prev;
	}
			
	return( $first );
}


######################################################################
=pod

=item @eprints = $eprint->later_in_thread( $field )

Return a list of the immediately later items in the thread. 

=cut
######################################################################

sub later_in_thread
{
	my( $self, $field ) = @_;

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $self->{session}->get_repository->get_dataset( 
			"archive" ) );
#cjg		[ "datestamp DESC" ] ) ); sort by date!

	$searchexp->add_field( 
		$field, 
		$self->get_value( "eprintid" ) );

	my $searchid = $searchexp->perform_search;
	my @eprints = $searchexp->get_records;
	$searchexp->dispose;

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

	my $above = {};
	my $set = {};
	
	my $first = $self->first_in_thread( $field );
	
	$self->_collect_thread( $field, $first, $set, $above );

	return( values %{$set} );
}

######################################################################
# 
# $eprint->_collect_thread( $field, $current, $eprints, $set, $above )
#
# $above is a hash which contains all the ids eprints above the current
# one as keys.
# $set contains all the eprints found.
#
######################################################################

sub _collect_thread
{
	my( $self, $field, $current, $set, $above ) = @_;

	if( defined $above->{$current->get_id} )
	{
		$self->loop_error( $field, keys %{$above} );
		return;
	}
	$set->{$current->get_id} = $current;	
	my %above2 = %{$above};
	$above2{$current->get_id} = $current; # copy the hash contents
	$set->{$current->get_id} = $current;	
	
	my @later = $current->later_in_thread( $field );
	foreach my $later_eprint (@later)
	{
		$self->_collect_thread( $field, $later_eprint, $set, \%above2 );
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
	
	my $latest;
	my @later = ( $self );
	my $above = {};
	while( scalar @later > 0 )
	{
		$latest = $later[0];
		if( defined $above->{$latest->get_id} )
		{
			$self->loop_error( $field, keys %{$above} );
			last;
		}
		$above->{$latest->get_id} = 1;
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

	return unless( $self->get_value( "eprint_status" ) eq "archive" );

	# Remove thread info in this eprint
	$self->set_value( "succeeds", undef );
	$self->set_value( "commentary", undef );
	$self->commit;

	my @related = $self->get_all_related;
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
			$eprint->commit;
		}
	}

	# Update static pages for each eprint
	foreach $eprint (@related)
	{
		next if( $eprint->get_value( "eprintid" ) eq $this_id );
		$eprint->generate_static; 
	}
}

#
# $eprint->succeed_thread_modified
#
# Something either started or stopped succeeding this eprint.
# Update the metadata_visibility flag accordingly.
# If metadata visibility is "hide" then do nothing as this must not
# be overridden.

sub succeed_thread_modified
{
	my( $self ) = @_;

	my $mvis = $self->get_value( "metadata_visibility" );

	if( $mvis eq "hide" )
	{
		# do nothing
		return;
	}

	my $ds = $self->{session}->get_repository->get_dataset( "eprint" );

	my $last_in_thread = $self->last_in_thread( $ds->get_field( "succeeds" ) );
	my $replacement_id = $last_in_thread->get_value( "eprintid" );

	if( $replacement_id == $self->get_value( "eprintid" ) )
	{
		# This IS the last in the thread, so we should make
		# the metadata discoverable, if it isn't already.
		if( $mvis eq "no_search" )
		{
			$self->set_value( "metadata_visibility", "show" );
			$self->commit;
		}
		return;
	}

	# this is _not_ the last in its thread, so we should hide the
	# metadata from searches and browsing.
	
	if( $mvis eq "show" )
	{
		$self->set_value( "metadata_visibility", "no_search" );
		$self->commit;
	}
	return;
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
	
	$ul->appendChild( $first_version->_render_version_thread_aux( $field, $self, {} ) );
	
	return( $ul );
}

######################################################################
# 
# $xhtml = $eprint->_render_version_thread_aux( $field, $eprint_shown, $above )
#
# $above is a hash ref, the keys of which are ID's of eprints already 
# seen above this item. One item CAN appear twice, just not as it's
#  own decentant.
#
######################################################################

sub _render_version_thread_aux
{
	my( $self, $field, $eprint_shown, $above ) = @_;

	my $li = $self->{session}->make_element( "li" );

	if( defined $above->{$self->get_id} )
	{
		$self->loop_error( $field, keys %{$above} );
		$li->appendChild( $self->{session}->make_text( "ERROR, THREAD LOOPS: ".join( ", ",keys %{$above} ) ));
		return $li;
	}
	
	my $cstyle = "thread_".$field->get_name;

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
		my %above2 = %{$above};
		$above2{$self->get_id} = 1;
		# if there are, start a new list
		my $ul = $self->{session}->make_element( "ul" );
		foreach my $version (@later)
		{
			$ul->appendChild( $version->_render_version_thread_aux(
				$field, $eprint_shown, \%above2 ) );
		}
		$li->appendChild( $ul );
	}
	
	return( $li );
}

######################################################################
=pod

=item $eprint->loop_error( $field, @looped_ids )

This eprint is part of a threading loop which is not allowed. Log a
warning.

=cut
######################################################################

sub loop_error
{
	my( $self, $field, @looped_ids ) = @_;

	$self->{session}->get_repository->log( 
"EPrint ".$self->get_id." is part of a thread loop.\n".
"This means that either the commentary or succeeds form a complete\n".
"circle. Break the circle to disable this warning.\n".
"Looped field is '".$field->get_name."'\n".
"Loop is: ".join( ", ",@looped_ids ) );
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



######################################################################
=pod

=item $xhtml_ul_list = $eprint->render_export_links( [$staff] )

Return a <ul> list containing links to all the formats this eprint
is available in. 

If $staff is true then show all formats available to staff, and link
to the staff export URL.

=cut
######################################################################
	
sub render_export_links
{
	my( $self, $staff ) = @_;

	my $vis = "all";
	$vis = "staff" if $staff;
	my $id = $self->get_value( "eprintid" );
	my $ul = $self->{session}->make_element( "ul" );
	my @plugins = $self->{session}->plugin_list( 
					type=>"Export",
					can_accept=>"dataobj/eprint", 
					is_advertised=>1,
					is_visible=>$vis );
	foreach my $plugin_id ( @plugins ) {
		my $li = $self->{session}->make_element( "li" );
		my $plugin = $self->{session}->plugin( $plugin_id );
		my $url = $plugin->dataobj_export_url( $self, $staff );
		my $a = $self->{session}->render_link( $url );
		$a->appendChild( $plugin->render_name );
		$li->appendChild( $a );
		$ul->appendChild( $li );
	}
	return $ul;
}


######################################################################
=pod

=item @roles = $eprint->user_roles( $user )

Return the @roles $user has on $eprint.

=cut
######################################################################

sub user_roles
{
	my( $self, $user ) = @_;
	my $session = $self->{session};
	my @roles;

	return () unless defined( $user );
	
	# $user owns this eprint if their userid matches ours
	if( $self->get_value( "userid" ) eq $user->get_value( "userid" ) )
	{
		push @roles, qw( eprint.owner );
	}
	
	return @roles;
}

######################################################################
=pod

=item $eprint->datestamp

DEPRECATED.

=cut
######################################################################

sub datestamp
{
	my( $self ) = @_;

	my( $package,$filename,$line,$subroutine ) = caller(2);
	$self->{session}->get_repository->log( 
"The \$eprint->datestamp method is deprecated. It was called from $filename line $line." );
}

######################################################################
=pod

=item $boolean = $eprint->in_editorial_scope_of( $possible_editor )

Returns true if $possible_editor can edit this eprint. This is
according to the user editperms. 

This does not mean the user has the editor priv., just that if they
do then they may edit the given item.

=cut
######################################################################

sub in_editorial_scope_of
{
	my( $self, $possible_editor ) = @_;

	my $session = $self->{session};

	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $ef_field = $user_ds->get_field( 'editperms' );

	my $searches = $possible_editor->get_value( 'editperms' );
	if( scalar @{$searches} == 0 )
	{
		return 1;
	}

	foreach my $s ( @{$searches} )
	{
		my $search = $ef_field->make_searchexp( $session, $s );
		my $r = $search->get_conditions->item_matches( $self );
		$search->dispose;

		return 1 if $r;
	}

	return 0;
}

######################################################################
=pod

=item $boolean = $eprint->has_owner( $possible_owner )

Returns true if $possible_owner can edit this eprint. This is
according to the user editperms. 

This does not mean the user has the editor priv., just that if they
do then they may edit the given item.

Uses the callback "does_user_own_eprint" if available.

=cut
######################################################################

sub has_owner
{
	my( $self, $possible_owner ) = @_;

	my $fn = $self->{session}->get_repository->get_conf( "does_user_own_eprint" );

	if( !defined $fn )
	{
		if( $possible_owner->get_value( "userid" ) == $self->get_value( "userid" ) )
		{
			return 1;
		}
		return 0;
	}

	return &$fn( $self->{session}, $possible_owner, $self );
}

######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

__END__

=head1 CALLBACKS

Callbacks may optionally be defined in the ArchiveConfig.

=over 4

=item validate_field

	validate_field( $field, $value, $session, [$for_archive] )

=item validate_eprint

	validate_eprint( $eprint, $session, [$for_archive] )
	
=item set_eprint_defaults

	set_eprint_defaults( $data, $session )

=item set_eprint_automatic_fields

	set_eprint_automatic_fields( $eprint )

=item eprint_render

	eprint_render( $eprint, $session )

See L<ArchiveRenderConfig/eprint_render>.

=back
