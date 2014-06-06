######################################################################
#
# EPrints::DataObj 
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::DataObj> - Base class for records in EPrints.

=head1 SYNOPSIS

$dataobj = $dataset->dataobj( $id );

$dataobj->delete;

$dataobj->commit( $force );

$dataset = $dataobj->dataset;

$repo = $dataobj->repository;

$id = $dataobj->id;

$dataobj->set_value( $fieldname, $value );

$value = $dataobj->value( $fieldname );

\@value = $dataobj->value( $fieldname ); # multiple

$boolean = $dataobj->is_set( $fieldname );

$xhtml = $dataobj->render_value( $fieldname );

$xhtml = $dataobj->render_citation( $style, %opts );

$uri = $dataobj->uri;

$url = $dataobj->url;

$string = $dataobj->export( $plugin_id, %opts );

$dataobj = $dataobj->create_subobject( $fieldname, $epdata );

=head1 DESCRIPTION

This module is a base class which is inherited by L<EPrints::DataObj::EPrint>,
L<EPrints::DataObj::User>, L<EPrints::DataObj::Subject> and
L<EPrints::DataObj::Document> and several other classes.

It is ABSTRACT - its methods should not be called directly.

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{data}
#     A reference to a hash containing the metadata of this
#     record.
#
#  $self->{repository}
#     The current EPrints::Session
#
#  $self->dataset
#     The EPrints::DataSet to which this record belongs.
#
######################################################################

package EPrints::DataObj;

use MIME::Base64 ();

use strict;


######################################################################
=pod

=begin InternalDoc

=item $sys_fields = EPrints::DataObj->get_system_field_info

Return an array describing the system metadata of the this 
dataset.

=end InternalDoc

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return ();
}

######################################################################
=pod

=begin InternalDoc

=item $dataobj = EPrints::DataObj->new( $repository, $id [, $dataset] )

Return new data object, created by loading it from the database.

If $dataset is not defined uses the default dataset for this object.

=end InternalDoc

=cut
######################################################################

sub new
{
	my( $class, $repository, $id, $dataset ) = @_;

	if( !defined($dataset) )
	{
		$dataset = $repository->dataset( $class->get_dataset_id );
	}

	# attempts to load the data obj from memcached
	my $data = $repository->cache_get( "dataobj:".$dataset->id.":".$id );

	my $from_cache = 1;
	my $dataobj;	
	if( defined $data )
	{
                # this avoids a lot of calls to MetaField::set_value()
                $dataobj = $dataset->make_dataobj( {} );
                $dataobj->{data} = $data;
	}

	if( !defined $dataobj )
	{
		$dataobj = $repository->get_database->get_single( 
			$dataset,
			$id );
		$from_cache = 0;
	}

	return undef if( !EPrints::Utils::is_set( $dataobj ) );

	# don't let dataobj leak if the dataset and object are not in the same state:
	# TODO if( !$dataobj->dataset->matches_state( ... ) )
	if( defined ( my $ds_state = $dataobj->dataset->state ) )
	{
		if( $ds_state ne $dataobj->state )
		{
			return undef;
		}
	}

	# don't let dataobj leak if the dataobj doesn't match the security context (e.g. 'is owner' )
	if( !$dataobj->dataset->matches_context( $dataobj ) )
	{
		return undef;
	}

	# stores a copy of the object in memcached
	$repository->cache_set( "dataobj:".$dataset->id.":".$id, $dataobj->{data} ) if( !$from_cache );

	return $dataobj;
}

######################################################################
=pod

=begin InternalDoc

=item $dataobj = EPrints::DataObj->new_from_data( $repository, $data [, $dataset ] )

Construct a new EPrints::DataObj object based on the $data hash 
reference of metadata.

Used to create an object from the data retrieved from the database.

=end InternalDoc

=cut
######################################################################

sub new_from_data
{
	my( $class, $repository, $data, $dataset ) = @_;

	my $self = { data=>{}, changed=>{}, non_volatile_change=>0 };
	$self->{repository} = $repository;
	Scalar::Util::weaken($self->{repository})
		if defined &Scalar::Util::weaken;

	$self->{dataset} = $dataset or $repository->dataset( $class->get_dataset_id );
	bless( $self, ref($class) || $class );

	if( defined $data )
	{
		# calling $self->set_value( 'state', ...) will call $state_metafield->set_value( ... ) which will call $self->transfer( ... ) and we don't want that
		# when we init the object
		if( scalar( keys %$data ) && !$self->is_stateless )
		{
			$self->set_value_raw( 'state', delete $data->{state} );
		}

		foreach( keys %{$data} )
		{
			# this will cause an error if the field is unknown
			if( !$self->set_value( $_, $data->{$_} ) )
			{
				# TODO/sf2 - set_value returning FALSE means that the field failed to set the value
				# if we want strict metadata validation, the commit should fail
				# return undef;
			}
		}
	}

	return( $self );
}

# increments the revision number of that data obj
sub increment_revision
{
	my( $self ) = @_;

	my $rev = 0;

	if( $self->dataset->property( 'revision' ) )
	{
		$rev = $self->set_value( 'revision', ( $self->value( 'revision' ) || 0 ) + 1 );
	}

	if( $self->dataset->property( 'lastmod' ) )
	{
                $self->set_value( 'lastmod', EPrints::Time::get_iso_timestamp() );
	}

	return $rev;
}

# sf - new - returns the current revision number of that data obj
sub revision
{
	my( $self ) = @_;

	return ( $self->dataset->property( 'revision' ) ?
			$self->value( 'revision' ) + 0 :
			undef
	);
}

sub save_history
{
	my( $self ) = @_;

	return if( !$self->dataset->property( 'history' ) ||
		 !EPrints::Utils::is_set( $self->{changed } ) );

	my $changed = EPrints::Utils::clone( $self->{changed} );

	# don't save those fields (they'll be stored in the history object)
	delete $changed->{$_} for( qw/ lastmod revision history datestamp / );

	return if( !EPrints::Utils::is_set( $changed ) );

	my $data = JSON->new->utf8(1)->encode( $changed );

	use bytes;
  
        my $epdata = {
                        datasetid => $self->dataset->id,
                        objectid => $self->id,
                        fieldname => "history",		# TODO/sf2 - hard-coded, not good
                        fieldpos => 0,                  # TODO/sf2 - hard-coded, not good
                        filename => "diff.json",
                        filesize => length( $data ),
                        mime_type => "application/json",
                        _content => \$data,
			object_revision => $changed->{revision} || ($self->revision - 1 ),
        };

	my $history = $self->create_subdataobj( "history", $epdata );
	$history->commit;

	return;
}

# revert the dataobj to revision $revision (if history enabled on this dataset)
# note this can ONLY revert metadata (no file content) 
sub revert
{
	my( $self, $revision ) = @_;

	if( !$self->dataset->property( 'history' ) )
	{
		$self->repository->log( 'Dataset %s is not configured to store revision history: failed to revert', $self->dataset->id );
		return;
	}

	my $history = $self->repository->dataset( 'history' )->search(
			filters => [
				{ meta_fields => [qw/ datasetid /], value => $self->dataset->id, match => 'EX' },
				{ meta_fields => [qw/ objectid /], value => $self->id, match => 'EX' },
				{ meta_fields => [qw/ object_revision /], value => $revision, match => 'EX' },
			] )->item( 0 );

	if( defined $history )
	{
		my $epdata = $history->diff_data;

		if( !$epdata )
		{
			$self->repository->log( 'Failed to revert object %s to revision %d (json.diff missing or invalid)', $self->internal_uri, $revision );
			return;
		}
	}
	else
	{
		$self->repository->log( 'Failed to revert object %s to revision %d (history object missing)', $self->internal_uri, $revision )
	}

	return;
}

# sf2 - similar idea than to DataObj::EPrint::_transfer - also seen on Soton APC project
# sf2 - allow to transfer from one state to another iif:
#		- it's a valid state
#		- it's a valid "next" state
#		- if coming from a web request, check that the user is allowed to make the state transition (if from CLI, always allow)
#
# returns:
# - 1 or 0 whether the transfer was succesful or not (if so, should probably call a trigger (TODO) but can't really do that until the object has been 
# committed to the DB)
# - if failed for a security reason, returns the corresponding HTTP status code
#
# note: this doesn't call $self->commit
#
sub transfer
{
        my( $self, $new_state ) = @_;

        if( $self->is_stateless )
        {
                $self->repository->log( "Attempted to change the state of object %s which is state-less", $self->internal_uri );
                return 0;
        }
	
	if( $self->dataset->property( 'read-only' ) )
	{
		$self->repository->log( "Attempt to write read-only dataset: %s at %s", $self->dataset->id, join(",",caller) );
		return 0;
	}

        my $old_state = $self->value( 'state' );

	if( defined $old_state )
	{
		my $valid_transitions = $self->next_states( $old_state );

		if( defined $valid_transitions )
		{
			my $ok = 0;

			foreach( @$valid_transitions )
			{
				$ok = 1, last if $_ eq $new_state;
			}

			return 0 if( !$ok );
		}
      	}
 
	# no-op 
	return 1 if( defined $old_state && $old_state eq $new_state );

	if( $self->repository->is_online )
	{
		# is the user allowed to transfer this object?

		my $rc = $self->permit_action( "move-*", $self->repository->current_user );

		if( !$rc )
		{
			$rc = $self->permit_action( "move-$new_state", $self->repository->current_user );
		}


# TODO - illogical - that's nice but must then be able to propagate the http rc... meh.	that would be to the calling metafield (State->set_value) then whatever set the value (probably $dataobj->update from CRUD)
		if( !$rc )
		{
			my $http_rc = defined $self->repository->current_user ? EPrints::Const::HTTP_FORBIDDEN : EPrints::Const::HTTP_UNAUTHORIZED;
			return( 0, $http_rc );
		}
	}
# else
#	allowed if we're coming from the CLI!
#

        $self->set_value_raw( 'state', $new_state );
	return 1;

}

# like "inbox", "buffer" etc for the EPrint DataSet
sub states
{
	my( $self ) = @_;

	return $self->dataset->states;
}

# returns an ARRAYREF of possible next states given a $state or UNDEF if: stateless OR any transitions are allowed
sub next_states
{
	my( $self, $state ) = @_;

	return undef if( $self->is_stateless || !defined $state );

	my $states = $self->states;
	return undef if !$states;

	my %valid_states = map { $_ => 1 } @{ $states || [] };
	return [] if !$valid_states{$state};

	my $transitions = $self->dataset->property( 'flow', 'transitions' );

	if( defined $transitions )
	{
		# transitions are defined, we must enforce them

		return [] if( !exists $transitions->{$state} );	# no transitions allowed from $state

		return $transitions->{$state};
	}

	return undef;
}

sub is_stateless
{
	my( $self ) = @_;

	return $self->dataset->is_stateless;

	# 'state' SHOULD BE an internal field i.e. people cannot create custom fields called 'state'
	return !$self->dataset->has_field( 'state' );
}

sub state
{
	my( $self ) = @_;

	return $self->value( 'state' );
}


sub clone
{
	my( $self ) = @_;

	return $self->create_from_data( $self->repository, $self->data, $self->dataset );
}

######################################################################
#=pod
#
#=item $dataobj = EPrints::DataObj::create( $repository, @default_data )
#
#ABSTRACT.
#
#Create a new object of this type in the database. 
#
#The syntax for @default_data depends on the type of data object.
#
#=cut
#######################################################################

sub create
{
	my( $repository, @default_data ) = @_;

	Carp::croak( "EPrints::DataObj::create must be overridden" );
}


######################################################################
#=pod
#
#=item $dataobj = EPrints::DataObj->create_from_data( $repository, $data, $dataset )
#
#Create a new object of this type in the database. 
#
#$dataset is the dataset it will belong to. 
#
#$data is the data structured as with new_from_data.
#
#This will create sub objects also.
#
#Call this via $dataset->create_object( $repository, $data )
#
#=cut
######################################################################

sub create_from_data
{
	my( $class, $repository, $data, $dataset ) = @_;

	$data = EPrints::Utils::clone( $data );
	$dataset ||= $repository->dataset( $class->get_dataset_id );

	# <document id="/xx" />
	delete $data->{_id};

	# If there is a field which indicates the virtual dataset,
	# set that now, so it's visible to get_defaults.
	my $ds_id_field = $dataset->get_dataset_id_field;
	if( defined $ds_id_field )
	{
		$data->{$ds_id_field} = $dataset->id;
	}

	# get defaults modifies the hash so we must copy it.
	my $defaults = EPrints::Utils::clone( $data );
	$defaults = $class->get_defaults( $repository, $defaults, $dataset );
	
	# cache the configuration options in variables
	my $migration = $repository->config( "enable_import_fields" );

	my @create_subdataobjs;

	FIELD: foreach my $field ( $dataset->fields )
	{
		my $fieldname = $field->name;

		# strip sub-objects and create them once we exist
		if( $field->isa( "EPrints::MetaField::Subobject" ) )
		{
			push @create_subdataobjs, [ $field, delete $data->{$fieldname} ]
				if defined $data->{$fieldname};
			next FIELD;
		}

		if( !$field->property( "import" ) && !$migration )
		{
			delete $data->{$fieldname};
		}

		if( !EPrints::Utils::is_set( $data->{$fieldname} ) )
		{
			$data->{$fieldname} = $defaults->{$fieldname}
				if exists $defaults->{$fieldname};
		}
	}

	my $self = $class->new_from_data( $repository, $data, $dataset );
	return undef unless defined $self;

	if( !$self->dataset->property( 'virtual' ) )
	{
		# this checks whether the object exists
		my $rc = $repository->database->add_record( $dataset, $self->get_data );
		return undef unless $rc;
	}

	$self->set_under_construction( 1 );

	# create sub-dataobjs
	for(@create_subdataobjs)
	{
		my $field = $_->[0];
		$_->[1] = [$_->[1]] if ref($_->[1]) ne 'ARRAY';

		my @dataobjs;
		my %id_map;

		foreach my $epdata (@{$_->[1]})
		{
			my $dataobj = $self->create_subdataobj( $field->name, $epdata );
			if( !defined $dataobj )
			{
				Carp::carp( $dataset->base_id.".".$self->id." failed to create subdataobj on ".$dataset->id.".".$field->name );
				$self->remove();
				return undef;
			}
			push @dataobjs, $dataobj;
			$id_map{$epdata->{_id}} = $dataobj->internal_uri
				if defined $epdata->{_id};
		}

		foreach my $dataobj (@dataobjs)
		{
			next if !$dataobj->exists_and_set( "relation_uri" );
			my $value = $dataobj->value( "relation_uri" );
			$value = EPrints::Utils::clone( $value );
			foreach my $v (@$value)
			{
				$v = $id_map{$v} if exists $id_map{$v};
			}
			$dataobj->set_value( "relation_uri", $value );
			$dataobj->commit;
		}

		$self->set_value( $field->name, $field->property( "multiple" ) ? \@dataobjs : $dataobjs[0] );
	}

	if( $migration && $dataset->key_field->isa( "EPrints::MetaField::Counter" ) )
	{
		$repository->get_database->counter_minimum(
			$dataset->key_field->property( "sql_counter" ),
			$self->id
		);
	}

	if( $self->dataset->property( 'datestamp' ) )
	{
		# adjusts datestamp of creation
		$self->set_value( 'datestamp', EPrints::Time::get_iso_timestamp() ); 
	}

	$self->set_under_construction( 0 );

	# queue all the fields for indexing.
	$self->queue_all;

	return $self;
}

=begin InternalDoc

=item $dataobj = $dataobj->create_subdataobj( $fieldname, $epdata )

Creates and returns a new dataobj that is a sub-object of this object in field $fieldname with initial data $epdata.

Clears the sub-object cache for this $fieldname which is equivalent to:

	$dataobj->set_value( $fieldname, undef );

=end InternalDoc

=cut

sub create_subdataobj
{
	my( $self, $fieldname, $epdata ) = @_;

	if( ref( $epdata ) ne 'HASH' )
	{
		$self->repository->log( "Non-hash value passed to DataObj::create_subdataobj" );
		return undef;
	}

	my $field = $self->dataset->field( $fieldname );
	if( !defined $field )
	{
		EPrints::abort( "Cannot create sub-object on non-existent field $fieldname" );
	}
	if( !$field->isa( "EPrints::MetaField::Subobject" ) )
	{
		EPrints::abort( "Cannot create sub-object on non-subobject field $fieldname" );
	}

	# sub-objects cache is now out of date
	delete $self->{data}->{$fieldname};

	my $dataset = $self->repository->dataset( $field->property( "datasetid" ) );

	$epdata->{_parent} = $self;

	return $dataset->create_dataobj( $epdata );
}

######################################################################
=pod

=begin InternalDoc

=item $defaults = EPrints::User->get_defaults( $repository, $data, $dataset )

Return default values for this object based on the starting data.

Should be subclassed.

=end InternalDoc

=cut
######################################################################

sub get_defaults
{
	my( $class, $repository, $data, $dataset ) = @_;

	if( !defined $dataset )
	{
		$dataset = $repository->dataset( $class->get_dataset_id );
	}

	my $migration = $repository->config( "enable_import_fields" );

	# set any values that a field has a default for e.g. counters
	foreach my $field ($dataset->fields)
	{
		next if defined $field->get_property( "sub_name" );

		# avoid getting a default value if it's already set
		next if
			EPrints::Utils::is_set( $data->{$field->name} ) &&
			($field->property( "import") || $migration);

		my $value = $field->get_default_value( $repository );
		next unless EPrints::Utils::is_set( $value );

		$data->{$field->name} = $value;
	}

	if( !$dataset->is_stateless )
	{
		$data->{'state'} = $dataset->default_state;
	}

	my $old_default_fn = "set_".$dataset->base_id."_defaults"; 
	if( $repository->can_call( $old_default_fn ) )
	{
		$repository->call( 
			$old_default_fn,
			$data,
 			$repository,
			$data->{_parent} );
	}

	return $data;
}

# Update all the stuff that needs to be updated before
# an object is written to the database.
sub update_triggers 
{
	my( $self ) = @_;

	my $old_auto_fn = "set_".$self->get_dataset_id."_automatic_fields"; 
	if( $self->repository->can_call( $old_auto_fn ) )
	{
		$self->repository->call( $old_auto_fn, $self );
	}

	return;
}


######################################################################
=pod

=over 4

=item $success = $dataobj->delete

Delete this data object from the database and any sub-objects or related files. 

Return true if successful.

=cut
######################################################################

sub delete { shift->remove( @_ ) }
sub remove
{
	my( $self ) = @_;

	$self->dataset->run_trigger( EPrints::Const::EP_TRIGGER_REMOVED,
		dataobj => $self,
	);

	$self->queue_removed;

	# remove sub-objects too  
	# TODO/sf2 can this be dangerous?...
	foreach my $field ($self->dataset->fields)
	{
		if( $field->isa( "EPrints::MetaField::Subobject" ) )
		{
			my $subobjects = $field->value( $self );
			foreach my $dataobj ( ref( $subobjects ) eq 'ARRAY' ? @$subobjects : $subobjects ) 
			{
				$dataobj->remove if( defined $dataobj );
			}
		}
	}

	# ... and remove the object from memcached
	$self->repository->cache_remove( "dataobj:".$self->dataset->id.":".$self->id );

	return $self->repository->database->remove(
		$self->dataset,
		$self->id );
}

=item $dataobj->empty()

Remove all of this object's values that may be imported.

=cut

sub empty
{
	my( $self ) = @_;

	if( $self->dataset->property( 'read-only' ) )
	{
		$self->repository->log( "Attempt to write read-only dataset: ".$self->dataset->id." at ".join(",",caller) );
		return 0;
	}
	
	my $keyfield = $self->dataset->key_field();

	foreach my $field ($self->dataset->fields)
	{
		next if $field->is_virtual;
		next if !$field->property( "import" );

		# sf2 - otherwise CRUD::PUT() calls empty(), emptying the key_field and ref to the object is lost so commit() fails etc
		next if $field->name eq $keyfield->name;
		
		$field->set_value( $self, $field->property( "multiple" ) ? [] : undef );
	}
}

=item $dataobj->update( $epdata [, %opts ] )

Update this object's values from $epdata. Ignores any values that do not exist in the dataset or do not have the 'import' property set.

	include_subdataobjs - replace sub-dataobjs if given

	# replaces all documents in $dataobj
	$dataobj->update( {
		title => "Wombats on Fire",
		documents => [{
			main => "wombat.pdf",
			...
		}],
	}, include_subdataobjs => 1 );

=cut

sub update
{
	my( $self, $epdata, %opts ) = @_;

	if( $self->dataset->property( 'read-only' ) )
	{
		$self->repository->log( "Attempt to write read-only dataset: ".$self->dataset->id." at ".join(",",caller) );
		return 0;
	}

	my $dataset = $self->dataset;

	my $rc = 1;
	foreach my $name (keys %$epdata)
	{
		last if( !$rc );
		next if $name =~ /^_/;
		next if !$dataset->has_field( $name );
		my $field = $dataset->field( $name );
		next if !$field->property( "import" ) && !$self->repository->config( "enable_import_fields" );
		if( $field->isa( "EPrints::MetaField::Subobject" ) )
		{
			next if !$opts{include_subdataobjs};
			local $_;

			my $v = $field->value( $self );

			for($field->property( "multiple" ) ? @$v : $v)
			{
				$_->remove if defined $_;
			}
			$v = $epdata->{$field->name};
			for($field->property( "multiple" ) ? @{$v} : $v)
			{
				next if !defined $_;
				$rc &&= $self->create_subdataobj( $field->name, $_ );
			}
		}
		else
		{
#			 TODO/sf2 - strict value validation
#			if( !$field->validate_value( $epdata->{$name} ) )
#			{
#				return 0;
#			}
			$rc &&= $field->set_value( $self, $epdata->{$name} );
		}
	}

	return $rc;
}

# $dataobj->set_under_construction( $boolean )
#
# Set a flag to indicate this object is being constructed and 
# any house keeping will be handled by the method constructing it
# so don't do it elsewhere

sub set_under_construction
{
	my( $self, $boolean ) = @_;

	$self->{under_construction} = $boolean;
}

# $boolean = $dataobj->under_construction
# 
# True if this object is part way through being constructed.

sub under_construction
{
	my( $self ) = @_;

	return $self->{under_construction};
}

######################################################################
=pod

=begin InternalDoc

=item $dataobj->clear_changed( )

Clear any changed fields, which will result in them not being committed unless
force is used.

This method is used by the Database to avoid unnecessary commits.

=end InternalDoc

=cut
######################################################################

sub clear_changed
{
	my( $self ) = @_;
	
	$self->{non_volatile_change} = 0;
	$self->{changed} = {};
}

######################################################################
=pod

=item $success = $dataobj->commit( [$force] )

Write this object to the database and reset the changed fields.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

Commit may also queue indexer jobs or log changes, depending on the object.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;
	
	if( $self->dataset->property( 'read-only' ) )
	{
		$self->repository->log( "Attempt to write read-only dataset: ".$self->dataset->id." at ".join(",",caller) );
		return 0;
	}
	
	if( scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	# Remove empty slots in multiple fields
	$self->tidy;
	
	$self->dataset->run_trigger( EPrints::Const::EP_TRIGGER_BEFORE_COMMIT,
		dataobj => $self,
		changed => $self->{changed},
	);

	if( $self->{changed}->{state} && !$self->is_stateless )
	{
		# TODO STATE_CHANGE not STATUS_CHANGE?
                $self->dataset->run_trigger( EPrints::Const::EP_TRIGGER_STATUS_CHANGE,
                        dataobj => $self,
                        old_state => $self->{changed}->{state},
                        new_state => $self->{data}->{state}
                );
	}

	# no-op if(!self->dataset->property( 'revision' )
	# also updates lastmod, if enabled
	if( $self->{non_volatile_change} )
	{
		$self->increment_revision;
		if( $self->dataset->property( 'history' ) )
		{
			$self->save_history();
		}
	}

	# mostly useful for unit testing - but allows to create in-memory object from a in-memory dataset
	if( $self->dataset->property( 'virtual' ) )
	{
		return 1;
	}

	# Write the data to the database
	my $success = $self->repository->database->update(
		$self->dataset,
		$self->{data},
		$force ? $self->{data} : $self->{changed} );

	# updates the cached copy in memcached
	$self->repository->cache_set( "dataobj:".$self->dataset->id.":".$self->id, $self->{data} );

	if( !$success )
	{
		my $db_error = $self->repository->database->error;
		$self->repository->log( "Error committing %s/%s: %s", 
			$self->dataset->id,
			$self->id,
			$db_error
		);
		return 0;
	}

	# Queue changes for the indexer (if indexable)
	$self->queue_changes();

	$self->dataset->run_trigger( EPrints::Const::EP_TRIGGER_AFTER_COMMIT,
		dataobj => $self,
		changed => $self->{changed},
	);

	# clear changed fields
	$self->clear_changed();

	return $success;
}




######################################################################
=pod

=item $value = $dataobj->value( $fieldname )

Get a the value of a metadata field. If the field is not set then it returns
undef unless the field has the property multiple set, in which case it returns 
[] (a reference to an empty array).

=cut
######################################################################

sub value { shift->get_value( @_ ) }
sub get_value
{
	my( $self, $fieldname ) = @_;
	
	my $field = $self->dataset->field( $fieldname );

	if( !defined $field )
	{
		EPrints::abort( "Attempt to get value from not existent field: ".$self->dataset->id."/$fieldname" );
	}

	my $r = $field->value( $self );

	if( !EPrints::Utils::is_set( $r ) )
	{
		if( $field->property( "multiple" ) )
		{
			return [];
		}
		else
		{
			return undef;
		}
	}

	return $r;
}

sub get_value_raw
{
	my( $self, $fieldname ) = @_;

	EPrints::abort( "\$fieldname undefined in get_value_raw" ) unless defined $fieldname;

	return $self->{data}->{$fieldname};
}

######################################################################
=pod

=item $dataobj->set_value( $fieldname, $value )

Set the value of the named metadata field in this record.

=cut 
######################################################################

sub set_value
{
	my( $self, $fieldname, $value ) = @_;

	if( !$self->dataset->has_field( $fieldname ) )
	{
		if( $self->repository->get_noise > 0 )
		{
			Carp::carp( "Attempt to set value on not existent field: ".$self->dataset->id().".$fieldname" );
		}
		return 0;
	}
	my $field = $self->dataset->field( $fieldname );

	# sf2 - strict field validation
	# return 0 if( !$field->validate_value( $value ) );

	$field->set_value( $self, $value );
}

# set_value_raw should only be called internally (i.e. by set_value above)
sub set_value_raw
{
	my( $self, $fieldname, $value ) = @_;

	if( $self->dataset->property( 'read-only' ) )
	{
		$self->repository->log( "Attempt to write read-only dataset: ".$self->dataset->id." at ".join(",",caller) );
		return 0;
	}

	if( !defined $self->{changed}->{$fieldname} )
	{
		# if it's already changed once then we don't
		# want to fiddle with it again

		if( !_equal( $self->{data}->{$fieldname}, $value ) )
		{
			$self->{changed}->{$fieldname} = $self->{data}->{$fieldname};
			my $field = $self->dataset->field( $fieldname );
			if( !$field->property( "volatile" ) )
			{
				$self->{non_volatile_change} = 1;
			}
		}
	}

	$self->{data}->{$fieldname} = $value;

	return 1;
}

# internal function
# see if two data-structures are the same.
# TODO/sf2 - move to EPrints::Utils
sub _equal
{
	my( $a, $b ) = @_;

	# both undef is equal
	if( !EPrints::Utils::is_set($a) && !EPrints::Utils::is_set($b) )
	{
		return 1;
	}

	# one xor other undef is not equal
	if( !EPrints::Utils::is_set($a) || !EPrints::Utils::is_set($b) )
	{
		return 0;
	}

	# simple value
	if( ref($a) eq "" )
	{
		return( $a eq $b );
	}

	if( ref($a) eq "ARRAY" )
	{
		# different lengths?
		return 0 if( scalar @{$a} != scalar @{$b} );
		for(my $i=0; $i<scalar @{$a}; ++$i )
		{
			return 0 unless _equal( $a->[$i], $b->[$i] );
		}
		return 1;
	}

	if( ref($a) eq "HASH" )
	{
		my @akeys = sort keys %{$a};
		my @bkeys = sort keys %{$b};

		# different sizes?
		# return 0 if( scalar @akeys != scalar @bkeys );
		# not testing as one might skip a value, the other define it as
		# undef.

		my %testk = ();
		foreach my $k ( @akeys, @bkeys ) { $testk{$k} = 1; }

		foreach my $k ( keys %testk )
		{	
			return 0 unless _equal( $a->{$k}, $b->{$k} );
		}
		return 1;
	}

	if( ref($a) eq "GLOB" )
	{
		return "$a" eq "$b";
	}

	Carp::cluck( "Warning: can't compare $a and $b" );
	return 0;
}

######################################################################
=pod

=item @values = $dataobj->get_values( $fieldnames )

Returns a list of all the values in this record of all the fields specified
by $fieldnames. $fieldnames should be in the format used by browse views - slash
seperated fieldnames with an optional .id suffix to indicate the id part rather
than the main part. 

For example "author.id/editor.id" would return a list of all author and editor
ids from this record.

=cut 
######################################################################

sub get_values
{
	my( $self, $fieldnames ) = @_;

	my %seen;
	my @values;
	foreach my $fieldname ( split( "/" , $fieldnames ) )
	{
		my $field = EPrints::Utils::field_from_config_string( 
					$self->dataset, $fieldname );
		my $value = $field->get_value( $self );
		$value = [$value] if ref($value) ne 'ARRAY';
		foreach my $v (@$value)
		{
			next if $seen{$field->get_id_from_value( $self->repository, $v )}++;
			push @values, $v;
		}
	}

	return @values;
}


######################################################################
=pod

=begin InternalDoc

=item $repository = $dataobj->repository

Returns the EPrints::Repository object to which this record belongs.

=end InternalDoc

=cut
######################################################################

sub repository
{
	my( $self ) = @_;

	return $self->{repository};
}


######################################################################
=pod

=begin InternalDoc

=item $data = $dataobj->get_data

Returns a reference to the hash table of all the metadata for this record keyed 
by fieldname.

=end InternalDoc

=cut
######################################################################

sub get_data
{
	my( $self ) = @_;

	return $self->{data};
}

######################################################################
=pod

=begin InternalDoc

=item $dataset = EPrints::DataObj->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=end InternalDoc

=cut
######################################################################

sub get_dataset_id
{
	my( $class ) = @_;

	Carp::croak( "get_dataset_id must be overridden by $class" );
}


######################################################################
=pod

=begin InternalDoc

=item $dataset = $dataobj->get_dataset

Returns the L<EPrints::DataSet> object to which this record belongs.

=end InternalDoc

=cut
######################################################################

sub dataset { shift->get_dataset( @_ ) }
sub get_dataset
{
	my( $self ) = @_;
	
	return $self->{dataset};
}


######################################################################
=pod 

=item $bool = $dataobj->is_set( $fieldname )

Returns true if the named field is set in this record, otherwise false.

Warns if the field does not exist.

=cut
######################################################################

sub is_set
{
	my( $self, $fieldname ) = @_;

	if( !$self->dataset->has_field( $fieldname ) )
	{
		$self->repository->log( "is_set( %s ): Unknown field", $fieldname );
	}

	my $value = $self->value( $fieldname );

	return EPrints::Utils::is_set( $value );
}

######################################################################
=pod 

=item $bool = $dataobj->exists_and_set( $fieldname )

Returns true if the named field is set in this record, otherwise false.

If the field does not exist, just return false.

This method is useful for plugins which may operate on multiple 
repositories, and the fact a field does not exist is not an issue.

=cut
######################################################################

sub exists_and_set
{
	my( $self, $fieldname ) = @_;

	if( !$self->dataset->has_field( $fieldname ) )
	{	
		return 0;
	}

	return $self->is_set( $fieldname );
}


######################################################################
=pod

=item $id = $dataobj->id

Returns the value of the primary key of this record.

=cut
######################################################################

sub id { shift->get_id( @_ ) }
sub get_id
{
	my( $self ) = @_;

	my $keyfield = $self->dataset->key_field();

	return $self->{data}->{$keyfield->name()};
}

######################################################################
=pod

=begin InternalDoc

=item $id = $dataobj->get_gid

DEPRECATED (see uri())

Returns the globally referential fully-qualified identifier for this object or
undef if this object can not be externally referenced.

=end InternalDoc

=cut
######################################################################

sub get_gid
{
	my( $self ) = @_;

	return $self->uri;
}

=begin InternalDoc

=item $datestamp = $dataobj->get_datestamp

Returns the datestamp of this object in "YYYY-MM-DD hh:mm:ss" format.

=end InternalDoc

=cut

sub get_datestamp
{
	my( $self ) = @_;

	my $dataset = $self->get_dataset;

	my $field = $dataset->get_datestamp_field;
	return unless $field;

	return $field->value( $self );
}

######################################################################
=pod

=item $url = $dataobj->uri

Returns a unique URI for this object. Not certain to resolve as a 
URL.

If $c->{dataobj_uri}->{eprint} is a function, call that to work it out.

=cut
######################################################################

sub uri
{
	my( $self ) = @_;

	return undef if !EPrints::Utils::is_set( $self->get_id );

#	my $ds_id = $self->get_dataset->confid;
	my $ds_id = $self->dataset->id;
	if( $self->repository->can_call( "dataobj_uri", $ds_id ) )
	{
		return $self->repository->call( [ "dataobj_uri", $ds_id ], $self );
	}
	
	return $self->repository->config( 'base_url' ).$self->internal_uri;	
}

=begin InternalDoc

=item $uri = $dataobj->internal_uri()

Return an internal URI for this object (independent of repository hostname).

To retrieve an object by internal URI use L<EPrints::DataSet>::get_object_from_uri().

=end InternalDoc

=cut

sub internal_uri
{
	my( $self ) = @_;

	return undef if !EPrints::Utils::is_set( $self->get_id );

	return sprintf("/data/%s/%s",
		URI::Escape::uri_escape($self->dataset->base_id),
		URI::Escape::uri_escape($self->get_id)
		);
}

=item $path = $dataobj->path

Returns the relative path to this object from the repository's base URL, if the object has a URL.

Does not include any leading slash.

=cut

sub path
{
	return undef;
}

######################################################################
=pod

=item $url = $dataobj->url

Returns the URL for this record, for example the URL of the abstract page
of an eprint.

=cut
######################################################################

sub url { shift->get_url( @_ ) }
sub get_url
{
	my( $self ) = @_;

	return $self->uri;
}

######################################################################
=pod

=begin InternalDoc

=item $url = $dataobj->get_control_url

Returns the URL for the control page for this object. 

=end InternalDoc

=cut
######################################################################

sub get_control_url
{
	my( $self , $staff ) = @_;

	return "EPrints::DataObj::get_control_url should have been over-ridden.";
}


######################################################################
=pod

=begin InternalDoc

=item $type = $dataobj->get_type

Returns the type of this record - type of user, type of eprint etc.

=end InternalDoc

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return "EPrints::DataObj::get_type should have been over-ridden.";
}

######################################################################
=pod

=begin InternalDoc

=item $xmlfragment = $dataobj->to_xml( %opts )

Convert this object into an XML fragment. 

%opts are:

no_xmlns=>1 : do not include a xmlns attribute in the 
outer element. (This assumes this chunk appears in a larger tree 
where the xmlns is already set correctly.

showempty=>1 : fields with no value are shown.

embed=>1 : include the data of a file, not just it's URL.

=end InternalDoc

=cut
######################################################################

sub to_xml
{
	my( $self, %opts ) = @_;

	my $builder = EPrints::XML::SAX::Builder->new(
		repository => $self->repository
	);
	$builder->start_document({});
	$builder->xml_decl({
		Version => '1.0',
		Encoding => 'utf-8',
	});
	$builder->start_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$self->to_sax( %opts, Handler => $builder );
	$builder->end_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$builder->end_document({});

	return $builder->result()->documentElement;
}

=begin InternalDoc

=item $epdata = EPrints::DataObj->xml_to_epdata( $repository, $xml, %opts )

Populates $epdata based on $xml. This is the inverse of to_xml() but doesn't create a new object.

=end InternalDoc

=cut

sub xml_to_epdata
{
	my( $class, $repository, $xml, %opts ) = @_;

	my $epdata = {};

	my $dataset = $repository->dataset( $class->get_dataset_id );

	my $handler = EPrints::DataObj::SAX::Handler->new(
		$class, $epdata, {
			%opts,
			dataset => $dataset,
		},
	);

	EPrints::XML::SAX::Generator->new(
		Handler => $handler,
	)->generate( $xml );

	return $epdata;
}

=begin InternalDoc

=item $dataobj->to_sax( Handler => $handler, %opts )

Stream this object to a SAX handler.

This does not output any document-level events.

=end InternalDoc

=cut

sub to_sax
{
	my( $self, %opts ) = @_;

	my $handler = $opts{Handler};
	my $dataset = $self->dataset;
	my $name = $dataset->base_id;

	my %Attributes;

	my $uri = $self->uri;
	if( defined $uri )
	{
		$Attributes{'{}id'} = {
				Prefix => '',
				LocalName => 'id',
				Name => 'id',
				NamespaceURI => '',
				Value => $uri,
			};
	}

	$handler->start_element({
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
		Attributes => \%Attributes,
	});

	foreach my $field ($dataset->fields)
	{
		next if !$field->property( "export_as_xml" );

		$field->to_sax(
			$field->value( $self ),
			%opts
		);
	}

	$handler->end_element({
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
}

=begin InternalDoc

=item EPrints::Dataobj->start_element( $data, $epdata, $state )

Consumes a SAX event.

$data is the SAX node data.

$epdata is an EPrints data structure to write values to.

$state maintains state between SAX calls but must contain at least:

	dataset - the dataset the class belongs to

=end InternalDoc

=cut

sub start_element
{
	my( $class, $data, $epdata, $state ) = @_;

	$state->{depth}++;

	if( $state->{depth} == 1 )
	{
		$epdata->{_id} = eval { $data->{Attributes}{'{}id'}{Value} };
	}
	elsif( $state->{depth} == 2 )
	{
		if( $state->dataset->has_field( $data->{LocalName} ) )
		{
			$state->{child} = {%$state, depth => 0};
			$state->{handler} = $state->dataset->field( $data->{LocalName} );
			if( exists $epdata->{$data->{LocalName}} && defined $state->{Handler} )
			{
				my $repo = $state->dataset->repository;
				$state->{Handler}->message( "warning", $repo->html_phrase( "Plugin/Import/XML:dup_element", 
						name => $repo->xml->create_text_node( $data->{LocalName} ),
					) );
			}
		}
		else
		{
			$state->{Handler}->message( "warning", $state->dataset->repository->xml->create_text_node( "Invalid XML element: $data->{LocalName}" ) )
				if defined $state->{Handler};
		}
	}

	$state->{handler}->start_element( $data, $epdata, $state->{child} )
		if defined $state->{handler};
}

=begin InternalDoc

=item EPrints::DataObj->end_element( $data, $epdata, $state )

See L</start_element>.

=end InternalDoc

=cut

sub end_element
{
	my( $class, $data, $epdata, $state ) = @_;

	$state->{handler}->end_element( $data, $epdata, $state->{child} )
		if defined $state->{handler};

	if( $state->{depth} == 2 )
	{
		delete $state->{child};
		delete $state->{handler};
	}

	$state->{depth}--;
}

=begin InternalDoc

=item EPrints::DataObj->characters( $data, $epdata, $state )

See L</start_element>.

=end InternalDoc

=cut

sub characters
{
	my( $class, $data, $epdata, $state ) = @_;

	$state->{handler}->characters( $data, $epdata, $state->{child} )
		if defined $state->{handler};
}

######################################################################
=pod

=item $plugin_output = $dataobj->export( $plugin_id, %params )

Apply an output plugin to this items. Return the results.

=cut
######################################################################

sub export
{
	my( $self, $out_plugin_id, %params ) = @_;

	# TODO/sf2 - test cf. export_data
	if( !defined $out_plugin_id )
	{
		# return as PERL exported data (this filters out any fields that should not be exported)
		# and also help formatting sub-objects, such as files.
		return $self->export_data;
	}

	my $plugin_id = "Export::".$out_plugin_id;
	my $plugin = $self->repository->plugin( $plugin_id );

	unless( defined $plugin )
	{
		EPrints->abort( "Could not find plugin $plugin_id" );
	}

	my $req_plugin_type = "dataobj/".$self->dataset->id;

	unless( $plugin->can_accept( $req_plugin_type ) )
	{
		EPrints->abort( "Plugin $plugin_id can't process $req_plugin_type data." );
	}
	
	return $plugin->output_dataobj( $self, %params );
}

# TODO/sf2 - this is experimental
sub export_data
{
        my( $self ) = @_;

        my $data;

	foreach my $field( $self->dataset->fields )
        {
                next if !$field->property( "export" );
                next if !$field->property( "export_as_xml" );
                next if defined $field->{sub_name};

                my $value = $field->value( $self );

		if( $field->isa( 'EPrints::MetaField::Subobject' ) && defined $value )
		{
			if( ref( $value ) eq 'ARRAY' )
			{
				my @subobjects;
				foreach( @$value )
				{
					my $subdata = $_->export_data;
					$subdata->{url} ||= $_->url;
					push @subobjects, $subdata;
				}
				$data->{$field->name} = \@subobjects;
			}
			else
			{
				my $subdata = $value->export_data;
				$subdata->{url} ||= $value->url;
				$data->{$field->name} = $subdata;
			}
		}
		else
		{ 
                	$data->{$field->name} = $value;
		}
        }

        return $data;
}



######################################################################
=pod

=begin InternalDoc

=item $dataobj->queue_changes

Add all the changed fields into the indexers todo queue.

=end InternalDoc

=cut
######################################################################

sub queue_changes
{
	my( $self ) = @_;

	return unless $self->dataset->indexable;

	my $user = $self->repository->current_user;
	my $userid;
	$userid = $user->id if defined $user;

	for(keys %{$self->{changed}})
	{
		next if !$self->dataset->field( $_ )->property( "text_index" );
		EPrints::DataObj::EventQueue->create_unique( $self->repository, {
				pluginid => "Event::Indexer",
				action => "index",
				params => [$self->internal_uri, keys %{$self->{changed}}],
				userid => $userid,
			});
		last;
	}
}

######################################################################
=pod

=begin InternalDoc

=item $dataobj->queue_all

Add all the fields into the indexers todo queue.

=end InternalDoc

=cut
######################################################################

sub queue_all
{
	my( $self ) = @_;

	return unless $self->dataset->indexable;

	my $user = $self->repository->current_user;
	my $userid;
	$userid = $user->id if defined $user;

	EPrints::DataObj::EventQueue->create_unique( $self->repository, {
			pluginid => "Event::Indexer",
			action => "index_all",
			params => [$self->internal_uri],
			userid => $userid,
		});
}

######################################################################
=pod

=begin InternalDoc

=item $dataobj->queue_fulltext

Add a fulltext index into the indexers todo queue.

=end InternalDoc

=cut
######################################################################

sub queue_fulltext
{
	my( $self ) = @_;

	return unless $self->dataset->indexable;

	# don't know how to full-text index other datasets
	return if $self->dataset->base_id ne "eprint";

	my $user = $self->repository->current_user;
	my $userid;
	$userid = $user->id if defined $user;

	EPrints::DataObj::EventQueue->create_unique( $self->repository, {
			pluginid => "Event::Indexer",
			action => "index",
			params => [$self->internal_uri, "documents"],
			userid => $userid,
		});
}

=begin InternalDoc

=item $dataobj->queue_removed()

Add an index removed event to the indexer's queue.

=end InternalDoc

=cut

sub queue_removed
{
	my( $self ) = @_;

	return unless $self->dataset->indexable;

	my $user = $self->repository->current_user;
	my $userid;
	$userid = $user->id if defined $user;

	EPrints::DataObj::EventQueue->create_unique( $self->repository, {
			pluginid => "Event::Indexer",
			action => "removed",
			params => [$self->dataset->base_id, $self->id],
			userid => $userid,
		});
}

######################################################################
=pod

=begin InternalDoc

=item $boolean = $dataobj->has_owner( $user )

Return true if $user owns this record. Normally this means they 
created it, but a group of users could count as owners of the same
record if you wanted.

It's false on most dataobjs, except those which override this method.

=end InternalDoc

=cut
######################################################################

sub has_owner
{
	my( $self, $user ) = @_;

	return 0;
}

# return 1/0 whether the action is public (ie does not require an auth user)
sub public_action
{
	my( $self, $action ) = @_;
	
	return 0 if( !$action );

	# we need a user if the context is set/requested	
	return 0 if( defined $self->dataset->active_context );

	my @privs = @{ EPrints::ACL::privs_from_action( $action, $self->dataset, $self ) || [] };

	my $r = 0;
	
	foreach my $priv ( @privs )
	{
		$r |= 1 if $self->repository->allow_anybody( $priv );

		$self->repository->debug_log( "security", "%s public-allow %s: %d", $self->id, $priv, $r );
		
		last if( $r );
	}

	return $r;
}

# security - check if $action can be carried on this dataobj by an optional $user
sub permit_action
{
	my( $self, $action, $user ) = @_;

	return 0 if( !$action );

	# TODO/sf2 - package this up:
	## EPrints::Security::permit_dataobj_action( $action, $user );

	my @privs = @{ EPrints::ACL::privs_from_action( $action, $self->dataset, $self ) || [] };

	my @ds_contexts = @{ $self->dataset->contexts || [] };

	my $r = 0;
	foreach my $priv ( @privs )
	{
		# note that if a user can do 'movie/view' then it can do 'movie.ANY_STATE/view'
		last if $r;
	
		$r |= 1 if $self->repository->allow_anybody( $priv );

		$self->repository->debug_log( "security", "%s public-allow %s: %d", $self->internal_uri, $priv, $r );

		if( defined $user )
		{
			$r |= 2 if $user->has_privilege( $priv );

			$self->repository->debug_log( "security", "%s user-allow %s: %d", $self->internal_uri, $priv, $r );

			my $active_context = $self->dataset->active_context;
			my $context_def = $self->dataset->property( 'contexts', $active_context );

			# while loop instead?
			foreach my $context (@ds_contexts)
                        {
				last if defined $context_def;

                                # e.g. image.inbox/search:owner
                                if( $user->has_privilege( sprintf "%s:%s", $priv, $context ) )
                                {
                                        # not sure that bit filter is still useful:
                                        $r |= 2;
                                        $self->dataset->set_context( $context );
					
					$context_def = $self->dataset->property( 'contexts', $self->dataset->active_context );
                                }
                        }

			if( defined $context_def )
			{
				my $ctx_matches_fn = $context_def->{matches};

				if( ref( $ctx_matches_fn ) eq 'CODE' )
				{
					my $rc = &$ctx_matches_fn( $self->repository, $self );

					$self->repository->debug_log( "security", "does user match context '%s': %d", $self->dataset->active_context, $rc );

					$r = $rc;
				}
			}
		}
	}

	return $r;
}

=item $rc = $dataobj->permit( $priv [, $user ] )

	# current user can edit via editorial role
	if( $dataobj->permit( "xxx/edit", $user ) & 8 )
	{
		...
	}
	# anyone can view this object
	if( $dataobj->permit( "xxx/view" ) )
	{
	}

Returns true if the current user (or 'anybody') can perform this action.

Returns a bit mask where:

	0 - not permitted
	1 - anybody
	2 - logged in user
	4 - user as owner
	8 - user as editor

See also L<EPrints::Repository/allow_anybody> and L<EPrints::DataObj::User/allow>.

=cut

sub permit
{
	my( $self, $priv, $user ) = @_;

	# by $self->permit_action above
	EPrints->deprecated;

	my $r = 0;

	my $dataset = $self->get_dataset;

	my $vpriv = $priv;
	if( $dataset->id ne $dataset->base_id )
	{
		my $id = $dataset->id;
		my $base_id = $dataset->base_id;
		$vpriv =~ s{^$base_id/}{$base_id/$id/};
	}

	for( $priv eq $vpriv ? ($priv) : ($priv, $vpriv) )
	{
		$r |= 1 if $self->repository->allow_anybody( $_ );

		if( defined $user )
		{
			$r |= 2 if $user->has_privilege( $_ );

			$r |= 4 if $self->has_owner( $user ) && $user->has_privilege( "$_:owner" );

			$r |= 8 if $self->in_editorial_scope_of( $user ) && $user->has_privilege( "$_:editor" );
		}
	}

	return $r;
}

######################################################################
=pod

=begin InternalDoc

=item $boolean = $dataobj->in_editorial_scope_of( $user )

As for has_owner, but if the user is identified as someone with an
editorial scope which includes this record.

Defaults to true. Which doesn't mean that they have the right to 
edit it, just that their scope matches. You also need editor rights
to use this. It's currently used just to filter eprint editors so
that only ones with a scope AND a priv can edit.

=end InternalDoc

=cut
######################################################################

sub in_editorial_scope_of
{
	my( $self, $user ) = @_;

	return 1;
}

=begin InternalDoc

=item $problems = $dataobj->validate( [ $for_archive ], $workflow_id )

Return a reference to an array of XHTML DOM objects describing
validation problems with the entire $dataobj based on $workflow_id.

If $workflow_id is undefined defaults to "default".

A reference to an empty array indicates no problems.

=end InternalDoc

=cut

# Validate this object. Not used on all dataobjs. $for_archive being
# true indicates that the item is beting validated to go live.
sub validate
{
	my( $self, $for_archive ) = @_;

	my @problems;

	my $old_validate_fn = "validate_".$self->get_dataset_id;
	if( $self->repository->can_call( $old_validate_fn ) )
	{
		push @problems, $self->repository->call( 
			$old_validate_fn,
			$self, 
			$self->repository,
			$for_archive );
	}

	return \@problems;
}

=begin InternalDoc

=item $warnings = $dataobj->get_warnings( )

Return a reference to an array of XHTML DOM objects describing
problems with the entire $dataobj.

A reference to an empty array indicates no problems.

=end InternalDoc

=cut

sub get_warnings
{
	my( $self , $for_archive ) = @_;

	my @warnings = ();

	my $old_warnings_fn = $self->get_dataset_id."_warnings";
	if( $self->repository->can_call( $old_warnings_fn ) )
	{
		push @warnings, $self->repository->call( 
			$old_warnings_fn,
			$self, 
			$self->repository,
			$for_archive );
	}

	return \@warnings;
}

# check if a field is valid. Return an array of XHTML problems.

sub validate_field
{
	my( $self, $fieldname ) = @_;

	my $field = $self->dataset->field( $fieldname );
	
	return $field->validate( $self->repository, $self->value( $fieldname ), $self );
}


# Clean up any multiple fields with gaps in.
sub tidy
{
	my( $self ) = @_;

	foreach my $field ( $self->dataset->fields )
	{
		next if !$field->property( "multiple" );
		next if $field->isa( "EPrints::MetaField::Subobject" );
		
		# tidy at the compound-field level only (no sub-fields)
		next if defined $field->property( "parent_name" );

		my $value_arrayref = $field->value( $self );
		next if !EPrints::Utils::is_set( $value_arrayref );

		my @list;
		my $set = 0;
		foreach my $item ( @{$value_arrayref} )
		{
			if( !EPrints::Utils::is_set( $item ) )
			{
				$set = 1;
				next;
			}
			push @list, $item;
		}

		# set if there was a blank line
		if( $set )
		{
			$field->set_value( $self, \@list );
		}

		# directly add this to the data if it's a compound field
		# this is so that the ordervalues code can see it.
		if( $field->isa( "EPrints::MetaField::Compound" ) )
		{
			$self->{data}->{$field->name} = \@list;	
		}
	}
}

######################################################################
=pod

=begin InternalDoc

=item $file = $dataobj->add_stored_file( $filename, $filehandle, $filesize )

Convenience method to add (or replace) the file record for $filename to this object. Reads $filesize bytes from $filehandle.

Returns the file object or undef if the storage failed.

=end InternalDoc

=cut
######################################################################

sub add_stored_file
{
	my( $self, $filename, $filehandle, $filesize ) = @_;

	my $file = $self->get_stored_file( $filename );

	if( defined($file) )
	{
		$file->remove();
	}

	$file = $self->repository->dataset( "file" )->create_dataobj( {
		_parent => $self,
		_content => $filehandle,
		filename => $filename,
		filesize => $filesize,
	} );

	# something went wrong
	if( defined $file && $file->value( "filesize" ) != $filesize )
	{
		$self->repository->log( "Error while writing file '$filename': size mismatch between caller ($filesize) and what was written: ".$file->value( "filesize" ) );
		$file->remove;
		undef $file;
	}

	return $file;
}

######################################################################
=pod

=begin InternalDoc

=item $file = $dataobj->stored_file( $filename )

Get the file object for $filename.

Returns the file object or undef if the file doesn't exist.

=end InternalDoc

=cut
######################################################################

sub get_stored_file { &stored_file }
sub stored_file
{
	my( $self, $filename ) = @_;

	my $file = EPrints::DataObj::File->new_from_filename(
		$self->repository,
		$self,
		$filename
	);

	if( defined $file )
	{
		$file->set_parent( $self );
	}

	return $file;
}

=back

=begin InternalDoc

=head2 Related Objects

=end InternalDoc

=over

=begin InternalDoc

=item $dataobj->add_dataobj_relations( $target, $has => $is [, $has => $is ] )

Add a relation between this object and $target of type $has. If $is is defined will also add the reciprocal relationship $is from $target to this object. May be repeated to add multiple relationships.

You must commit $target after calling this method.

=end InternalDoc

=cut

sub add_object_relations { &add_dataobj_relations }
sub add_dataobj_relations
{
	my( $self, $target, %relations ) = @_;

	my $uri = $target->internal_uri;

	my @types = grep { defined $_ } keys %relations;

	my $relations = $self->value( "relation" );
	push @$relations, map { {
		type => $_,
		uri => $uri,
	} } @types;
	$self->set_value( "relation", $relations );

	my @reciprocal = grep { defined $_ } values %relations;
	if( scalar @reciprocal )
	{
		$target->add_object_relations( $self, map { $_ => undef } @reciprocal );
	}
}

sub _get_related_uris
{
	my( $self, @required ) = @_;

	my $relations = $self->value( "relation" );

	# create a look-up table
	my %haystack;
	foreach my $relation (@$relations)
	{
		next unless defined $relation->{"uri"};
		next unless defined $relation->{"type"};
		$haystack{$relation->{"uri"}}->{$relation->{"type"}} = undef;
	}

	# remove any relations that don't satisfy our @required types
	foreach my $type (@required)
	{
		foreach my $uri (keys %haystack)
		{
			if( !exists( $haystack{$uri}->{$type} ) )
			{
				delete $haystack{$uri};
			}
		}
	}

	return keys %haystack;
}

=begin InternalDoc

=item $bool = $dataobj->has_dataobj_relations( $target, @types )

Returns true if this object is related to $target by all @types.

If @types is empty will return true if any relationships exist.

=end InternalDoc

=cut

sub has_object_relations { &has_dataobj_relations }
sub has_dataobj_relations
{
	my( $self, $target, @required ) = @_;

	my $match = $target->internal_uri;

	my @uris = $self->_get_related_uris( @required );

	foreach my $uri (@uris)
	{
		if( $uri eq $match )
		{
			return 1;
		}
	}

	return 0;
}

=begin InternalDoc

=item $bool = $dataobj->has_related_dataobjs( @types )

Returns true if related_dataobjs() would return some objects, but without actually retrieving the related objects from the database.

=end InternalDoc

=cut

sub has_related_objects { &has_related_dataobjs }
sub has_related_dataobjs
{
	my( $self, @required ) = @_;

	my @uris = $self->_get_related_uris( @required );

	return scalar @uris > 0;
}

=begin InternalDoc

=item @dataobjs = $dataobj->related_dataobjs( @types )

Returns a list of objects related to this object by @types.

=end InternalDoc

=cut

sub get_related_objects { &related_dataobjs }
sub related_dataobjs
{
	my( $self, @required ) = @_;

	my @uris = $self->_get_related_uris( @required );

	# Translate matching uris into real objects
	my @matches;
	foreach my $uri (@uris)
	{
		my $dataobj = EPrints::DataSet->get_object_from_uri( $self->repository, $uri );
		next unless defined $dataobj;

		if(
			$dataobj->isa( "EPrints::DataObj::SubObject" ) &&
			$dataobj->get_parent_dataset_id eq $self->get_parent_dataset_id &&
			$dataobj->get_parent_id eq $self->get_parent_id
		  )
		{
			$dataobj->set_parent( $self->get_parent );
		}

		push @matches, $dataobj;
	}

	return wantarray ? @matches : \@matches;
}

=begin InternalDoc

=item $dataobj->remove_dataobj_relations( $target [, $has => $is [, $has => $is ] )

Remove relations between this object and $target. If $has => $is pairs are defined will only remove those relationships given.

You must L</commit> this object and $target to write the changes.

=end InternalDoc

=cut

sub remove_object_relations { &remove_dataobj_relations }
sub remove_dataobj_relations
{
	my( $self, $target, %relations ) = @_;

	my $uri = $target->internal_uri;

	my @relations;
	foreach my $relation (@{($self->value( "relation" ))})
	{
		# doesn't match $target
		if( $relation->{"uri"} ne $uri )
		{
			push @relations, $relation;
		}
		# we're removing specific relations, and this one isn't given
		elsif( scalar(%relations) && !exists($relations{$relation->{"type"}}) )
		{
			push @relations, $relation;
		}
	}
	$self->set_value( "relation", \@relations );

	my @reciprocal = grep { defined $_ } values %relations;
	if( scalar @reciprocal )
	{
		$target->remove_object_relations( $self, map { $_ => undef } @reciprocal );
	}
}

######################################################################
=pod

=back

=cut
######################################################################

package EPrints::DataObj::SAX::Handler;

sub new
{
	my( $class, @self ) = @_;

	return bless \@self, $class;
}

sub AUTOLOAD {}

sub start_element
{
	my( $self, $data ) = @_;
	$self->[0]->start_element( $data, @$self[1..$#$self] );
}

sub end_element
{
	my( $self, $data ) = @_;
	$self->[0]->end_element( $data, @$self[1..$#$self] );
}

sub characters
{
	my( $self, $data ) = @_;
	$self->[0]->characters( $data, @$self[1..$#$self] );
}

# END OF SAX::Handler

1; # for use success

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

