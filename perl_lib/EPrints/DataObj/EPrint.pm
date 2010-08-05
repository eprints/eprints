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

=pod

=for Pod2Wiki

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
	{ name=>"eprintid", type=>"counter", required=>1, import=>0, can_clone=>0,
		sql_counter=>"eprintid" },

	{ name=>"rev_number", type=>"int", required=>1, can_clone=>0,
		sql_index=>0, default_value=>1 },

	{ name=>"documents", type=>"subobject", datasetid=>'document',
		multiple=>1, text_index=>1 },

	{ name=>"files", type=>"subobject", datasetid=>"file",
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

	{ name=>"lastmod", type=>"timestamp", required=>0, import=>0,
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

	{ name=>"metadata_visibility", type=>"set", required=>1,
		default_value => "show",
		options=>[ "show", "no_search" ] },

	{ name=>"contact_email", type=>"email", required=>0, can_clone=>0 },

	{ name=>"fileinfo", type=>"longtext", 
		text_index=>0,
		export_as_xml=>0,
		volatile=>1,
		render_value=>"EPrints::DataObj::EPrint::render_fileinfo" },

	{ name=>"latitude", type=>"float", required=>0 },

	{ name=>"longitude", type=>"float", required=>0 },

	{ name=>"relation", type=>"compound", multiple=>1,
		fields => [
			{
				sub_name => "type",
				type => "text",
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
				type => "id",
				text_index => 0,
			},
			{
				sub_name => "type",
				type => "id",
				text_index => 0,
				sql_index => 1,
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

	{ 'name' => 'sword_depositor', 'type' => 'itemref', datasetid=>"user" },

	{ 'name' => 'sword_slug', 'type' => 'text' },

	{ 'name' => 'edit_lock', 'type' => 'compound', volatile => 1, export_as_xml=>0,
		'fields' => [
			{ 'sub_name' => 'user',  'type' => 'itemref', 'datasetid' => 'user', sql_index=>0 },
			{ 'sub_name' => 'since', 'type' => 'int', sql_index=>0 },
			{ 'sub_name' => 'until', 'type' => 'int', sql_index=>0 },
		],
		render_value=>"EPrints::DataObj::EPrint::render_edit_lock",
 	},

	);
}

=item $eprint->set_item_issues( $new_issues )

This method updates the issues attached to this eprint based on the new issues
passed.

If an existing issue is set as "discovered" and doesn't exist in $new_issues
its status will be updated to "autoresolved", otherwise the old issue's status
and description are updated.

Any issues in $new_issues that don't already exist will be appended.

=cut

sub set_item_issues
{
	my( $self, $new_issues ) = @_;

	$new_issues = [] if !defined $new_issues;

	# tidy-up issues (should this be in the calling code?)
	for(@$new_issues)
	{
		# default status to "discovered"
		$_->{status} = "discovered"
			if !EPrints::Utils::is_set( $_->{status} );
		# default item_issue_id to item_issue_type
		$_->{id} = $_->{type}
			if !EPrints::Utils::is_set( $_->{id} );
		# default timestamp to 'now'
		$_->{timestamp} = EPrints::Time::get_iso_timestamp();
		# backwards compatibility
		if( ref( $_->{description} ) )
		{
			$_->{description} = $self->{session}->xhtml->to_xhtml( $_->{description} );
		}
	}

	my %issues_map = map { $_->{id} => $_ } @$new_issues;

	my $current_issues = $self->value( "item_issues" );
	$current_issues = [] if !defined $current_issues;
	# clone, otherwise we can't detect changes
	$current_issues = EPrints::Utils::clone( $current_issues );

	# update existing issues
	foreach my $issue (@$current_issues)
	{
		my $new_issue = delete $issues_map{$issue->{id}};
		if( defined $new_issue )
		{
			# update description (may have changed)
			$issue->{description} = $new_issue->{description};
			$issue->{status} = $new_issue->{status};
		}
		elsif( $issue->{status} eq "discovered" )
		{
			$issue->{status} = "autoresolved";
		}
	}

	# append all other new issues
	foreach my $new_issue (@$new_issues)
	{
		next if !exists $issues_map{$new_issue->{id}};
		push @$current_issues, $new_issue;
	}

	$self->SUPER::set_value( "item_issues", $current_issues );
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

=item $eprint->fileinfo()

The special B<fileinfo> field contains the icon URL and main-file URL for each non-volatile document in the eprint. This is a performance tweak to avoid having to retrieve documents when rendering eprint citations.

Example:

	/style/images/fileicons/application_pdf.png;/20/1/paper.pdf|/20/4.hassmallThumbnailVersion/tdb_portrait.jpg;/20/4/tdb_portrait.jpg

These URLs are relative to the current repository base path ('http_url').

=cut

sub fileinfo
{
	my( $self ) = @_;

	my $base_url = $self->{session}->config( 'http_url' );

	local $self->{session}->{preparing_static_page} = 1; # force full URLs

	my @finfo = ();
	foreach my $doc ( $self->get_all_documents )
	{
		my $icon = substr($doc->icon_url,length($base_url));
		my $url = substr($doc->get_url,length($base_url));
		push @finfo, "$icon;$url";
	}

	return join '|', @finfo;
}

sub render_fileinfo
{
	my( $session, $field, $value, $alllangs, $nolink, $eprint ) = @_;

	my $baseurl = $session->config( 'rel_path' );
	if( $session->{preparing_static_page} )
	{
		$baseurl = $session->config( 'http_url' );
	}

	my $f = $session->make_doc_fragment;
	my @fileinfo = map { split /;/, $_ } split /\|/, $value;
	for(my $i = 0; $i < @fileinfo; $i+=2)
	{
		my( $icon, $url ) = @fileinfo[$i,$i+1];
		$icon = $baseurl . $icon if $icon !~ /^https?:/;
		$url = $baseurl . $url if $url !~ /^https?:/;
		my $a = $session->render_link( $url );
		$a->appendChild( $session->make_element( 
			"img", 
			class=>"ep_doc_icon",
			alt=>"file",
			src=>$icon,
			border=>0 ));
		$f->appendChild( $a );
	}

	return $f;
}



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

	my $new_eprint = $class->SUPER::create_from_data( $session, $data, $dataset );
	
	return undef unless defined $new_eprint;

	$new_eprint->set_value( "fileinfo", $new_eprint->fileinfo );

	$session->get_database->update(
		$new_eprint->{dataset},
		$new_eprint->{data},
		$new_eprint->{changed} );

	$new_eprint->clear_changed;

	$new_eprint->update_triggers();

	# we only need to update the DB and queue changes (if necessary)
	$new_eprint->SUPER::commit();

	my $user = $session->current_user;
	my $userid = undef;
	$userid = $user->get_id if defined $user;

	my $history_ds = $session->get_repository->get_dataset( "history" );
	my $event = $history_ds->create_object( 
		$session,
		{
			_parent=>$new_eprint,
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$new_eprint->get_id,
			revision=>$new_eprint->get_value( "rev_number" ),
			action=>"create",
			details=>undef,
		}
	);
	$event->set_dataobj_xml( $new_eprint );

	return $new_eprint;
}

# Update all the stuff that needs updating before an eprint
# is written to the database.

sub update_triggers
{
	my( $self ) = @_;

	$self->SUPER::update_triggers();

	my $action = "clear_triples";
	if( $self->get_value( "eprint_status" ) eq "archive" )
	{
		$action = "update_triples";
	}
			

	my $user = $self->{session}->current_user;
	my $userid;
	$userid = $user->id if defined $user;

	EPrints::DataObj::EventQueue->create_unique( $self->{session}, {
		unique => "TRUE",
		pluginid => "Event::RDF",
		action => $action,
		params => [$self->internal_uri],
		userid => $userid,
	});
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
	my( $class, $session, $data, $dataset ) = @_;

	$class->SUPER::get_defaults( $session, $data, $dataset );

	$data->{dir} = $session->get_store_dir . "/" . eprintid_to_path( $data->{eprintid} );

	$data->{status_changed} = $data->{lastmod};
	if( $data->{eprint_status} eq "archive" )
	{
		$data->{datestamp} = $data->{lastmod};
	}
	
	return $data;
}

sub store_path
{
	my( $self ) = @_;

	return eprintid_to_path( $self->id );
}

sub eprintid_to_path
{
	my( $id ) = @_;

	my $path = sprintf("%08d", $id);
	$path =~ s#(..)#/$1#g;
	substr($path,0,1) = '';

	return $path;
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

	$new_eprint->{under_construction} = 1;

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
		my %map;
		my @clones;
		foreach my $doc (@{$self->get_value( "documents" )})
		{
			my $new_doc = $doc->clone( $new_eprint );
			$ok = 0, last if !defined $new_doc;
			push @clones, $new_doc;
			$map{$doc->internal_uri} = $new_doc->internal_uri;
		}
		# fixup the relations
		foreach my $clone (@clones)
		{
			last if !$ok;
			my $relation = EPrints::Utils::clone( $clone->value( "relation" ) );
			foreach my $r (@$relation)
			{
				if( exists $map{$r->{uri}} )
				{
					$r->{uri} = $map{$r->{uri}};
				}
			}
			$clone->set_value( "relation", $relation );
			$clone->commit();
		}
	}

	$new_eprint->{under_construction} = 0;

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
			_parent=>$self,
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
			_parent=>$self,
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
			_parent=>$self,
			userid=>$userid,
			datasetid=>"eprint",
			objectid=>$self->get_id,
			revision=>$self->get_value( "rev_number" ),
			action=>"destroy",
			details=>undef,
		}
	);

	foreach my $doc ( @{($self->get_value( "documents" ))} )
	{
		$doc->remove;
	}

	foreach my $file (@{($self->get_value( "files" ))} )
	{
		$file->remove;
	}

	my $success = $self->SUPER::remove();

	# remove the webpages associated with this record.
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

	# get_all_documents() is called several times during commit
	# setting _documents will cause it to be returned instead of searching
	local $self->{_documents} = [$self->get_all_documents];

	$self->update_triggers();

	$self->set_value( "fileinfo", $self->fileinfo );

	if( $self->{non_volatile_change} )
	{
		my $rev_number = $self->get_value( "rev_number" ) || 0;
		$rev_number += 1;
	
		$self->set_value( "rev_number", $rev_number );

		$self->set_value( 
			"lastmod" , 
			EPrints::Time::get_iso_timestamp() );

		my $user = $self->{session}->current_user;
		my $userid = undef;
		$userid = $user->get_id if defined $user;
	
		my $history_ds = $self->{session}->get_repository->get_dataset( "history" );
		my $event = $history_ds->create_object( 
			$self->{session},
			{
				_parent=>$self,
				userid=>$userid,
				datasetid=>"eprint",
				objectid=>$self->get_id,
				revision=>$self->get_value( "rev_number" ),
				action=>"modify",
				details=>undef
			}
		);
		$event->set_dataobj_xml( $self );
	}

	unless( $self->under_construction )
	{
		$self->remove_static;
	}

	# commit changes and clear changed fields
	my $success = $self->SUPER::commit( $force );

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

	binmode($tmpfile, ":utf8");

	print $tmpfile '<?xml version="1.0" encoding="utf-8" ?>'."\n";
	print $tmpfile $self->export( "XML" );

	seek($tmpfile,0,0);

	$self->add_stored_file( $filename, $tmpfile, -s "$tmpfile" );
}


######################################################################
=pod

=item $problems = $eprint->validate( [$for_archive], $workflow_id )

Return a reference to an array of XHTML DOM objects describing
validation problems with the entire eprint based on $workflow_id.

If $workflow_id is undefined defaults to "default".

A reference to an empty array indicates no problems.

Calls L</validate_eprint> for the C<$eprint>.

=cut
######################################################################

sub validate
{
	my( $self , $for_archive, $workflow_id ) = @_;

	return [] if $self->skip_validation;
	
	$workflow_id = "default" if !defined $workflow_id;

	# get the workflow

	my %opts = ( item=> $self, session=>$self->{session} );
	$opts{STAFF_ONLY} = [$for_archive ? "TRUE" : "FALSE","BOOLEAN"];
 	my $workflow = EPrints::Workflow->new( $self->{session}, $workflow_id, %opts );

	my @problems = ();

	push @problems, $workflow->validate;

	my $super_v = $self->SUPER::validate( $for_archive );
	push @problems, @{$super_v};

	return( \@problems );
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

Documents that have a relation of "isVolatileVersionOf" will only be returned if there is no reciprocal document in this EPrint (i.e. orphaned).

=cut
######################################################################

sub get_all_documents
{
	my( $self ) = @_;

	my @docs;

	my $relation = EPrints::Utils::make_relation( "isVolatileVersionOf" );
	my $irelation = EPrints::Utils::make_relation( "hasVolatileVersion" );

	# Filter out any documents that are volatile versions
	foreach my $doc (@{($self->get_value( "documents" ))})
	{
		if( my @dataobjs = @{$doc->get_related_objects( $relation )} )
		{
			if( !$dataobjs[0]->has_object_relations( $doc, $irelation ) )
			{
				push @docs, $doc;
			}
		}
		else
		{
			push @docs, $doc;
		}
	}

	return sort { ($a->get_value( "placement" )||0) <=> ($b->get_value( "placement" )||0) } @docs;
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

	$self->{session}->{preparing_static_page} = 1; 

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

		my( $page, $title, $links, $template ) = $self->render;
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
			{title=>$title, page=>$page, head=>$links, template=>$self->{session}->make_text($template) },
			 );
	}
	$self->{session}->change_lang( $real_langid );
	delete $self->{session}->{preparing_static_page};
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
	
	# Do the actual pdates
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
		$self->store_path;
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

	my( $dom, $title, $links, $template );

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
		( $dom, $title, $links, $template ) = 
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
	
	return( $dom, $title, $links, $template );
}

sub render_box_list
{
	my( $session, $eprint, $list ) = @_;

	my $processor = EPrints::ScreenProcessor->new(
		session => $session,
		eprint => $eprint,
		eprintid => $eprint->get_id,
	);
	my $some_plugin = $session->plugin( "Screen", processor=>$processor );

	my $chunk = $session->make_doc_fragment;
	foreach my $item ( $some_plugin->list_items( $list ) )
	{
		my $i = $session->get_next_id;

		my %options;
		$options{session} = $session;
		$options{id} = "ep_summary_box_$i";
		$options{title} = $item->{screen}->render_title;
		$options{content} = $item->{screen}->render;
		$options{collapsed} = $item->{screen}->render_collapsed;
		# $options{content_style} = "height: 100px; overflow: auto";
		$chunk->appendChild( EPrints::Box::render( %options ) );
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

	return undef unless $self->is_set( "userid" );

	if( defined($self->{user}) )
	{
		# check we still have the same owner
		if( $self->{user}->get_id eq $self->get_value( "userid" ) )
		{
			return $self->{user};
		}
	}

	$self->{user} = EPrints::User->new( 
		$self->{session}, 
		$self->get_value( "userid" ) );

	return $self->{user};
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

	my $dataset = $self->{session}->dataset( "archive" );

	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [$field->name],
				value => $self->value( "eprintid" )
			},
		],
		custom_order => "-datestamp" );

	return $results->slice;
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

=item $boolean = $eprint->obtain_lock( $user )

=cut
######################################################################

sub obtain_lock
{
	my( $self, $user ) = @_;

	if( ! $self->{session}->get_repository->get_conf( "locking", "eprint", "enable" ) )
	{
		# locking not enabled
		return 1;
	}

	if( !$self->is_locked() )
	{
		# not currently locked, so lock.
		$self->set_value( "edit_lock_since", time );
		$self->set_value( "edit_lock_user", $user->get_id );
	}
	elsif( $self->get_value( "edit_lock_user" ) != $user->get_id )
	{
		# is locked, and not by $user, so fail to obtain lock.
		return 0;
	}
	
	my $timeout = $self->{session}->get_repository->get_conf( "locking", "eprint", "timeout" );
	$timeout = 3600 unless defined $timeout;
	$self->set_value( "edit_lock_until", time + $timeout );

	$self->commit;

	return 1;
}

######################################################################
=pod

=item $boolean = $eprint->could_obtain_lock( $user )

=cut
######################################################################

sub could_obtain_lock
{
	my( $self, $user ) = @_;

	if( ! $self->{session}->get_repository->get_conf( "locking", "eprint", "enable" ) )
	{
		# locking not enabled
		return 1;
	}

	if(
		$self->is_locked() &&
		$self->get_value( "edit_lock_user" ) ne $user->get_id
	  )
	{
		return 0;
	}

	return 1;
}

######################################################################
=pod

=item $boolean = $eprint->is_locked()

=cut
######################################################################

sub is_locked
{
	my( $self ) = @_;

	if( ! $self->{session}->get_repository->get_conf( "locking", "eprint", "enable" ) )
	{
		# locking not enabled
		return 0;
	}

	my $lock_until = $self->get_value( "edit_lock_until" );

	return 0 unless $lock_until;

	return( $lock_until > time );
}

######################################################################
=pod

=item $xhtml = render_edit_lock( $session, $value )

=cut
######################################################################

sub render_edit_lock
{
	my( $session, $field, $value, $alllangs, $nolink, $eprint ) = @_;

	if( $value->{"until"} < time ) 
	{
		return $session->html_phrase( "lib/eprint:not_locked" );
	}

	my $f = $field->get_property( "fields_cache" );
	return $session->html_phrase( "lib/eprint:locked", 
		locked_by => $f->[0]->render_single_value( $session, $value->{user}, $eprint ),
		locked_until => $session->make_text( EPrints::Time::human_time( $value->{"until"} ) ) );

	return $f;
};




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



