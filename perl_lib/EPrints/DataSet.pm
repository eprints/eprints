######################################################################
#
# EPrints::DataSet
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::DataSet> - a set of records with the same metadata scheme

=head1 SYNOPSIS

	my $dataset = $repository->dataset( "inbox" );

	print sprintf("There are %d records in the inbox\n",
		$dataset->count);

	$string = $dataset->base_id; # eprint
	$string = $dataset->id; # inbox

	$dataobj = $dataset->create_dataobj( $data );
	$user = $dataset->dataobj( 23 );

	$search = $dataset->prepare_search( %options );
	$list = $dataset->search( %options ); # prepare_search( %options )->execute
	$list = $dataset->search; # match ALL

	$metafield = $dataset->field( $fieldname );
	$metafield = $dataset->key_field;
	@metafields = $dataset->fields; 

	$dataset->search->map( sub {}, $ctx );
	$n = $dataset->search->count; 
	$ids = $dataset->search->ids;
	$list = $dataset->list( \@ids );

=head1 DESCRIPTION

This module describes a dataset.

A repository has several datasets that make up the repository's metadata schema.
The list of dataset ids can be obtained from the repository object
(see L<EPrints::Repository>).

A normal dataset (eg. "user") has a package associated with it 
(eg. L<EPrints::DataObj::User>) which must be a subclass of L<EPrints::DataObj> 
and a number of SQL tables which are prefixed with the dataset name.
Most datasets also have a set of associated L<EPrints::MetaField>'s which
may be optional or required depending on the type eg. books have editors
but posters don't but they are both EPrints.

The fields contained in a dataset are defined by the data object and by
any additional fields defined in cfg.d. Some datasets don't have any
fields.

Some datasets are "virtual" datasets made from others. Examples include 
"inbox", "archive", "buffer" and "deletion" which are all virtual datasets 
of of the "eprint" dataset. That is to say "inbox" is a subset of "eprint" 
and by inference contains L<EPrints::DataObj::EPrint>. You can define your 
own virtual datasets which opperate on existing datasets.

=head1 CREATING CUSTOM DATASETS

New datasets can be defined in a configuration file, e.g.

	$c->{datasets}->{bread} = {
		class => "EPrints::DataObj::Bread",
		sqlname => "bread",
	};

This defines a dataset with the id C<bread> (must be unique). The dataobj package (class) to instantiate objects with is C<EPrints::DataObj::Bread>, which must be a sub-class of L<EPrints::DataObj>. Lastly, the database tables used by the dataset will be called 'bread' or prefixed 'bread_'.

Other optional properties:

	columns - an array ref of field ids to default the user view to
	datestamp - field id to use to sort this dataset
	import - is the dataset importable?
	index - is the dataset text-indexed?
	order - is the dataset orderable?
	virtual - completely virtual dataset (no database tables)

To make one dataset a virtual dataset of another (as 'inbox' is to 'eprint') use the following properties:

	confid - the super-dataset this is a virtual sub-dataset of
	dataset_id_field - the field containing the sub-dataset id
	filters - an array ref of filters to apply when retrieving records

As with system datasets, the L<EPrints::MetaField>s can be defined via L<EPrints::DataObj/get_system_field_info> or via configuration:

	$c->add_dataset_field(
		"bread",
		{ name => "breadid", type => "counter", sql_counter => "bread" }
	);
	$c->add_dataset_field(
		"bread",
		{ name => "toasted", type => "bool", }
	);
	$c->add_dataset_field(
		"bread",
		{ name => "description", type => "text", }
	);

See L<EPrints::RepositoryConfig/add_dataset_field> for details on C<add_dataset_field>.

Creating a fully-operational dataset will require more configuration files. You will probably want at least a L<workflow|EPrints::Workflow>, L<citations|EPrints::Citation> for the summary page, search results etc, and permissions and searching settings:

	push @{$c->{user_roles}->{admin}}, qw(
		+bread/create
		+bread/edit
		+bread/view
		+bread/destroy
		+bread/details
	);
	push @{$c->{plugins}->{"Export::SummaryPage"}->{params}->{accept}}, qw(
		dataobj/bread
	);
	$c->{datasets}->{bread}->{search}->{simple} = {
		search_fields => {
			id => "q",
			meta_fields => [qw(
				breadid
				description
			)],
		},
	};

=begin InternalDoc

=over 4

=item cachemap, counter

Don't have a package or metadata fields associated.

=item archive, buffer, inbox, deletion

All have the same package and metadata fields as B<eprints>, but
are filtered by B<eprint_status>.

=back

EPrints::DataSet objects are cached by the related EPrints::Repository
object and usually obtained by calling.

$ds = $repository->get_dataset( "inbox" );

=end InternalDoc

=head1 METHODS

=head2 Class Methods

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{id}
#     The id of this dataset.
#
#  $self->{confid}
#     The config-id of this dataset, usual the same as {id} but is always
#     "eprints" for inbox,archive,buffer,deletion as they share the same
#     configuration.
#
#  $self->{repository}
#     A reference to the EPrints::Repository to which this dataset belongs.
#
#  $self->{fields}
#     An array of all the EPrints::MetaField's belonging to this dataset.
#
#  $self->{system_fields}
#     An array of the non-optional EPrints::MetaField's which are hard
#     coded into this dataset.
#
#  $self->{field_index}
#     A hash keyed on fieldname containing the fields in {fields}
#
#  $self->{default_order}
#     The default option for "order by?" in a search form.
#
######################################################################

package EPrints::DataSet;

use EPrints;
use EPrints::Const qw( :trigger );

use strict;

# filters is the filters to apply to this dataset before returning
# values.

# dataset_id_field is a field to write the dataset id to when an item
# is created. 

# These are both used by the virtual datasets inbox, buffer etc.



######################################################################
=pod

=begin InternalDoc

=item $ds = EPrints::DataSet->new( %properties )

Creates and returns a new dataset based on %properties.

Requires at least B<repository> and B<name> properties.

Available properties:

=over 4

=item repository OBJ

Reference to the repository object.

=item name STRING

Name of the dataset.

=item confid STRING

Name of the dataset this dataset is a subset of (e.g. 'archive' is a subset of 'eprint'). If defined requires dataset_id_field.

=item dataset_id_field

Name of the text field that contains the subset dataset id.

=item sql_name STRING

Name of the primary database table.

=item virtual BOOL

Set to 1 if this dataset doesn't require it's own database tables.

=item type STRING

Type of data object the dataset contains e.g. for L<EPrints::DataObj::EPrint>
specify "EPrint".

=item class STRING

Explicit class to use for data objects. To use the default object specify L<EPrints::DataObj>.

=item filters ARRAYREF

Filters to apply to this dataset before searching (see L<EPrints::Search>).

=item datestamp STRING

The field name that contains a datestamp to order this dataset by.

=item index BOOL

Whether this dataset should be indexed.

=item import BOOL

Whether you can import into this dataset.

=back

=end InternalDoc

=cut
######################################################################


# those fields are internal, cannot be defined in user-space!
# they are added automatically by EPrints when certain dataset properties are set
my $SYSTEM_FIELDS = {

	lastmod => {
		name => "lastmod",
		type => "time",
		sql_index => 0,
		export => 1,
	},

	revision => {
		name => "revision",
		type => "int",
		sql_index => 0,
		export => 1
	},

	history => {
		name => "history",
		datasetid => "history",
		type => "file",
		sql_index => 0,
		export => 0,
	},

	datestamp => {
		name => "datestamp",
		type => "time",
		sql_index => 0,
		export => 1,
	},

	state => {},	# properties for 'state' are defined in-situ
};


sub new
{
	my( $class, %properties ) = @_;
	
	if( !defined $properties{repository} )
	{
		EPrints->abort( "Requires repository property" );
	}
	if( !defined $properties{name} )
	{
		EPrints->abort( "Requires name property" );
	}

	# We support the field properties of "name" and "type"

	# datasets are identified by "id", not "name"
	$properties{id} ||= delete $properties{name};

	# type is a short-cut for specifying the object class
	# (We have to maintain case though, because DataObj classes are
	# uppercased)
	my $type = delete $properties{type};
	if( defined $type )
	{
		$properties{class} = "EPrints::DataObj::$type";
	}

	my $self = bless \%properties, $class;

	$self->{confid} = $self->{id} unless defined $self->{confid};

	my $repository = $self->{repository};
	Scalar::Util::weaken($self->{repository})
		if defined &Scalar::Util::weaken;

# TODO/sf2/document - added new properties:
# - flow: to replace eprint_status etc - describes the states an object can be in (inbox,archive..) and the valid transitions (it's a graph basically)
#		(implemented)
# - revision: adds a "revision" field which stores the current revision number of the data obj - incremented each time a modif' is made to the data obj.
# - acl: enables ACL for this dataset (implemented)
# - read-only: makes the dataset read-only 
# - history: keeps the history of changes in JSON (implemented) - http://www.mediawiki.org/wiki/Extension:Memento (Accept-Datetime)
# - lastmod: a field storing the last mod date of a data obj
	my $default_properties	= {
		"flow" => undef,
		"revision" => 1,
		"acl" => 0,
		"read-only" => 0,
		"history" => 0,
		"lastmod" => 1,
		"core_fields" => [],
		"contexts" => {},
# below: existing properties
		"virtual" => 0,
		"fields" => [],
		"system_fields" => [],
		"field_index" => {},
		"default_order" => $repository->config( "default_order", $self->{confid} ),
		"class" => "EPrints::DataObj",
	};

	# force init the above properties	
	foreach my $property ( keys %$default_properties )
	{
		if( !exists $self->{$property} )
		{
			$self->{$property} = $default_properties->{$property};
		}
	}

	# history implies revision
	if( $self->property( 'history' ) )
	{
		$self->{revision} = 1;
	}

	# virtual implies no-history
	if( $self->property( 'virtual' ) )
	{
		$self->{history} = 0;
	}

	my $oclass = $self->get_object_class;
	if( defined $oclass )
	{
		# TODO/sf2 - perhaps remove get_system_field_info from DataObj (this loads hard-coded fields from the
		# DataObj class but fields should maybe just be set in the local conf)
		foreach my $fielddata ( $oclass->get_system_field_info() )
		{
			$self->process_field( $fielddata, 1 );
		}
	}

	my @repository_fields = @{ delete $self->{core_fields} || [] };
	my $legacy_fields_def = $repository->config( "fields", $self->{confid} );
	push @repository_fields, @$legacy_fields_def if( $legacy_fields_def );

	foreach my $fielddata ( @repository_fields )
	{
		if( defined $fielddata->{name} && exists $SYSTEM_FIELDS->{$fielddata->{name}} )
		{
			$self->repository->log( "Attempt to re-use system field '$fielddata->{name}' on dataset ".$self->id );
			next;
		}
		$self->process_field( $fielddata, 0 );
	}

	my $flow = $self->property( 'flow' );
	if( EPrints::Utils::is_set( $flow ) )
	{
		my $states = $flow->{states};
		if( !EPrints::Utils::is_set( $states ) || ref( $states ) ne 'ARRAY' )
		{
			$self->repository->log( sprintf "Wrong flow definition in dataset %s (missing 'states')", $self->id );
		}
		else
		{
			my $default = $flow->{default} || $states->[0];
			my %valid_states = map { $_ => 1 } @$states;
			if( !defined $default || !exists $valid_states{$default} )
			{
				$self->repository->log( sprintf "Invalid default state '%s' on dataset %s. Using '%s' instead", $default, $self->id, $states->[0] ) if( defined $default );
				$self->{flow}->{default} = $default = $states->[0];
			}
			my $state_field_def = {
				name => 'state',
				type => 'state',
				states => $states,
				repository => $self->repository,
				text_index => 1
			};

			$self->process_field( $state_field_def, 1 );
		}
	}

	# adds automatic fields e.g. revision
	foreach my $sysfield ( keys %$SYSTEM_FIELDS )
	{
		next if( !$self->property( $sysfield ) );
		if( $self->has_field( $sysfield ) )
		{
			$repository->log( "Attempt to add existing '$sysfield' field to dataset ".$self->id );
		}
		else
		{
			my $field_definition = $SYSTEM_FIELDS->{$sysfield} or next;
			$field_definition->{repository} = $repository;
			$self->process_field( $field_definition, 1 );
		}
	}

	# lock these metadata fields against being modified again.
	foreach my $field ( @{$self->{fields}} )
	{
		$field->final;
	}

	# contexts (ACL's/security)

	# TODO well could check the contexts are OK?

	return $self;
}

# like MetaField get_property
sub property
{
	my( $self, @properties ) = @_;
	
	my $ptr = $self;
	my $i = 0;

	foreach my $property (@properties)
	{
		return undef if( !$property );
		my $next_ptr = $ptr->{$property};

		if( ++$i < scalar( @properties ) )
		{
			return undef if( !defined $next_ptr || ref( $next_ptr ) ne 'HASH' );
		}

		$ptr = $next_ptr;
	}

	# to avoid returning '$self'
	return $ptr if( $i > 0 );

	return undef;
}


=back

=head2 Object Methods

=over 4

=cut

=item $id = $ds->base_id

	$ds = $repo->dataset( "inbox" );
	$id = $ds->base_id; # returns "eprint"

Returns the identifier of the base dataset for this dataset (same as L</id> unless this dataset is virtual).

=cut

# TODO/sf2: deprecate "confid"
sub confid { &base_id }
sub base_id
{
	my( $self ) = @_;

	# now returns ->{id} - the concept of {confid} (eg 'inbox' is sub-dataset of 'eprint') has been replaced by
	# the generic "states"
	return $self->id;
}

=begin InternalDoc

=item $field = $ds->process_field( $data [, $system ] )

Creates a new field in this dataset based on $data. If $system is true defines
the new field as a "core" field.

=end InternalDoc

=cut

sub process_field
{
	my( $self, $fielddata, $system ) = @_;

	if( !defined $fielddata->{provenance} )
	{
		$fielddata->{provenance} = $system ? "core" : "config";
	}

	my $field = EPrints::MetaField->new( 
		dataset => $self, 
		%{$fielddata} );

	$self->register_field( $field, $system );

	# TODO/sf2 - disabled (i think this is to make compound more like multipart fields i.e. stored in a single table)
#	if( $field->isa( "EPrints::MetaField::Compound" ) )
#	{
#		foreach my $inner_field (@{$field->{fields_cache}})
#		{
#			$self->register_field( $inner_field, $system );
#		}
#	}

	return $field;
}

=begin InternalDoc

=item $ds->register_field( $field [, $system ] )

Register a new field with this dataset.

=end InternalDoc

=cut

sub register_field
{
	my( $self, $field, $system ) = @_;

	my $fieldname = $field->name();

	if( exists $self->{field_index}->{$fieldname} )
	{
		my $old_field = $self->{field_index}->{$fieldname};
		if(
			$system ||
			$old_field->property( "provenance" ) ne "core" ||
			!$field->property( "replace_core" )
		  )
		{
			EPrints->abort( "Duplicate field name encountered: ".$self->base_id.".".$fieldname );
		}
		$self->unregister_field( $old_field );
	}

	push @{$self->{fields}}, $field;
	$self->{field_index}->{$fieldname} = $field;
	if( $system )
	{
		push @{$self->{system_fields}} , $field;
	}
}

=begin InternalDoc

=item $ds->unregister_field( $field )

Unregister a field from this dataset.

=end InternalDoc

=cut

sub unregister_field
{
	my( $self, $field ) = @_;

	my $name = $field->name();

	delete $self->{field_index}->{$name};
	@{$self->{fields}} = grep { $_->name() ne $name } @{$self->{fields}};
	@{$self->{system_fields}} = grep { $_->name() ne $name } @{$self->{system_fields}};
}

######################################################################
=pod

=item $metafield = $ds->field( $fieldname )

Returns the L<EPrints::MetaField> from this dataset with the given name, or undef.

=cut
######################################################################

sub get_field { &field }
sub field
{
	my( $self, $fieldname ) = @_;

	# magic fields which can be searched but do
	# not really exist.
	if( $fieldname =~ m/^_/ )
	{
		my $field = EPrints::MetaField->new( 
			dataset=>$self , 
			name=>$fieldname,
			type=>"longtext" );
		return $field;
	}

	my $value = $self->{field_index}->{$fieldname};
	if (!defined $value) 
	{
		$self->repository->log( "dataset %s has no field %s", $self->id, $fieldname );
		return undef;
	}
	return $self->{field_index}->{$fieldname};
}

######################################################################
=pod

=begin InternalDoc

=item $bool = $ds->has_field( $fieldname )

True if the dataset has a field of that name.

=end InternalDoc

=cut
######################################################################

sub has_field
{
	my( $self, $fieldname ) = @_;

	# magic fields which can be searched but do
	# not really exist.
	return 1 if( $fieldname =~ m/^_/ );
	
	return defined $self->{field_index}->{$fieldname};
}

######################################################################
=pod

=begin InternalDoc

=item $ordertype = $ds->default_order

Return the id string of the default order for this dataset. 

For example "bytitle" for eprints.

=end InternalDoc

=cut
######################################################################

sub default_order
{
	my( $self ) = @_;

	return $self->{default_order};
}

######################################################################
=pod

=item $id = $ds->id

Return the id of this dataset.

=cut
######################################################################

sub id
{
	my( $self ) = @_;
	return $self->{id};
}


######################################################################
=pod

=item $n = $ds->count( $repository )

Return the number of records in this dataset.

=cut
######################################################################

sub count
{
	my( $self, $repository ) = @_;

	if( $self->get_filters )
	{
		return $self->search->count;
	}

	return $repository->database->count_table( $self->get_sql_table_name() );
}
 

######################################################################
=pod

=begin InternalDoc

=item $tablename = $ds->get_sql_table_name

Return the name of the main SQL Table containing this dataset.
the other SQL tables names are based on this name.

=end InternalDoc

=cut
######################################################################

sub get_sql_table_name
{
	my( $self ) = @_;

	$self->{sqlname} ||= $self->base_id;

	return $self->{sqlname};

#	my $table = $self->{sqlname};
#
#	return $table if defined $table;
#
#	EPrints::abort( "Can't get a SQL table name for dataset: ".$self->{id} );
}



######################################################################
=pod

=begin InternalDoc

=item $tablename = $ds->get_sql_sub_table_name( $field )

Returns the name of the SQL table which contains the information
on the "multiple" field. $field is an EPrints::MetaField belonging
to this dataset.

=end InternalDoc

=cut
######################################################################

sub get_sql_sub_table_name
{
	my( $self , $field ) = @_;
	return $self->get_sql_table_name()."_".$field->get_sql_name();
}


######################################################################
=pod

=item @fields = $ds->fields

Returns a list of the L<EPrints::MetaField>s belonging to this dataset.

=cut
######################################################################

sub get_fields { EPrints->deprecated; &fields }
sub fields
{
	my( $self ) = @_;
	return @{ $self->{fields} };
}

######################################################################
=pod

=item $field = $ds->key_field

Return the L<EPrints::MetaField> representing the primary key field.

Always the first field.

=cut
######################################################################

sub get_key_field { EPrints->deprecated; &key_field }
sub key_field
{
	my( $self ) = @_;
	return $self->{fields}->[0];
}


=item $dataobj = $ds->make_dataobj( $epdata )

Return an object of the class associated with this dataset, always
a subclass of L<EPrints::DataObj>.

$epdata is a hash of values for fields in this dataset.

Returns $epdata if no class is associated with this dataset.

=cut

sub make_object { $_[0]->make_dataobj( $_[2] ) }
sub make_dataobj
{
	my( $self, $epdata ) = @_;

	my $class = $self->get_object_class;

	return $epdata if !defined $class;

	return $class->new_from_data(
		$self->repository,
		$epdata,
		$self );
}

######################################################################
=pod

=item $obj = $ds->create_dataobj( $data )

Returns a new object in this dataset based on $data or undef on failure.

If $data describes sub-objects then those will also be created.

=cut
######################################################################

sub create_object
{
	my( $self , $repository , $data ) = @_;

	return $self->create_dataobj( $data );
}
sub create_dataobj
{
	my( $self, $data ) = @_;

	# dataset default values (for internal fields)
	if( $self->property( 'revision' ) )
	{
		$data->{revision} = 1;
	}
	
	my $datestamp;
	if( $self->property( 'lastmod' ) )
	{
		$datestamp = $data->{lastmod} = EPrints::Time::get_iso_timestamp();
	}
	
	if( $self->property( 'datestamp' ) )
	{
		$data->{datestamp} = $datestamp || EPrints::Time::get_iso_timestamp();
	}

	my $dataobj = $self->dataobj_class->create_from_data( $self->repository, $data, $self );

	$self->run_trigger( EP_TRIGGER_CREATED, dataobj => $dataobj );

	return $dataobj;
}

######################################################################
=pod

=begin InternalDoc

=item $class = $ds->get_object_class;

Return the perl class to which objects in this dataset belong.

=end InternalDoc

=cut
######################################################################

sub get_object_class { &dataobj_class }
sub dataobj_class
{
	my( $self, $repository ) = @_;
	return $self->{class};
}


=item $dataobj = $ds->dataobj( $id )

Returns the object from this dataset with the given id, or undefined.

=cut

sub dataobj
{
	my( $self, $id ) = @_;

	return undef if( ref( $self ) eq '' );

	# dataobj_class->new makes sure that objects from a sub-dataset ('inbox')
	# do not leak to another dataset ('archive')
	return $self->dataobj_class->new( $self->repository, $id, $self );
}

=begin InternalDoc

=item $dataobj = EPrints::DataSet->get_object_from_uri( $repository, $uri )

Returns a the dataobj identified by internal URI $uri.

Returns undef if $uri isn't an internal URI or the object is no longer available.

=end InternalDoc

=cut

sub get_object_from_uri
{
	my( $class, $repository, $uri ) = @_;

# TODO move this method to e.g. Utils - it's not an object method

	my( $datasetid, $id ) = $uri =~ m# ^/id/([^/]+)/(.+)$ #x;
	return unless defined $id;

	$datasetid = URI::Escape::uri_unescape( $datasetid );

	my $dataset = $repository->dataset( $datasetid );
	return unless defined $dataset;

	$id = URI::Escape::uri_unescape( $id );

	return $dataset->dataobj( $id );
}

######################################################################
=pod

=begin InternalDoc

=item $xhtml = $ds->render_name( $repository )

Return a piece of XHTML describing this dataset, in the language of
the current repository.

=end InternalDoc

=cut
######################################################################

sub render_name
{
	my( $self ) = @_;
EPrints->deprecated;
	return $self->repository->html_phrase( "datasetname_".$self->id() );
}

######################################################################
=pod

=begin InternalDoc

=item $ds->map( $fn, $info )

Maps the function $fn onto every record in this dataset. See 
Search for a full explanation.

=end InternalDoc

=cut
######################################################################

sub map
{
	my( $self, $fn, $info ) = @_;

	return __PACKAGE__ if( ref( $self ) eq '' );

	if( ref( $fn ) eq 'CODE' )
	{
		return $self->search->map( $fn, $info );
	}

	# sf2 - backcompat
	if( defined $fn && $fn->isa( "EPrints::Repository" ) )
	{
		EPrints->deprecated( "dataset->map( repository, function, info ) is deprecated. Use dataset->map( function, info ) instead" );
		return $self->search->map( $_[2], $_[3] );
	}

	return undef;
}


######################################################################
=pod

=item $repository = $ds->repository

Returns the L<EPrints::Repository> to which this dataset belongs.

=cut
######################################################################

sub get_repository { EPrints->deprecated; &repository }
sub repository
{
	my( $self ) = @_;
	return $self->{repository};
}


######################################################################
=pod

=begin InternalDoc

=item $ds->reindex( $repository )

Recommits all the items in this dataset. This could take a real long 
time on a large set of records.

Really should not be called reindex anymore as it doesn't.

=end InternalDoc

=cut
######################################################################

sub reindex
{
	my( $self, $repository ) = @_;

	my $fn = sub {
		my( $repository, $dataset, $item ) = @_;
		if( $repository->get_noise() >= 2 )
		{
			print STDERR "Reindexing item: ".$dataset->id()."/".$item->get_id()."\n";
		}
		$item->commit();
	};

	$self->map( $repository, $fn );
}


######################################################################
=pod

=begin InternalDoc

=item @ids = $dataset->get_item_ids( $repository )

Return a list of the id's of all items in this set.

=end InternalDoc

=cut
######################################################################

sub get_item_ids
{
	my( $self, $repository ) = @_;

	if( $self->get_filters )
	{
		return $self->search->get_ids;
	}
	return $repository->database->get_values( $self->get_key_field, $self );
}


######################################################################
# 
# $field_id = $ds->get_dataset_id_field
# 
# If this is a virtual dataset, return the id of a field in the object
# metadata which should be set to the id of this dataset when the
# object is created.
#
# Otherwise return undef.
#
######################################################################

sub get_dataset_id_field
{
	my( $self ) = @_;

	return $self->{dataset_id_field};
}

######################################################################
# 
# @filters = $ds->get_filters
# 
# Return an array of filters that must always be applied to searches
# on this dataset. Used for inbox, archive etc.
#
######################################################################

sub get_filters
{
	my( $self ) = @_;
	
	my $filters = $self->{filters} || [];
	
	if( !$self->is_stateless && defined ( my $state = $self->state ) )
	{
		$self->repository->debug_log( "security", "dataset->get_filters: adding state '%s' to restrict items", $state );
		push @$filters, { meta_fields => [qw/ state /], value => $state, match => 'EX' };
	}

	if( defined ( my $context_def = $self->property( 'contexts', $self->active_context ) ) )
	{
		my $ctx_get_filters_fn = $context_def->{filters};
		my $ctx_filters;		

		$self->repository->debug_log( "security", "dataset->get_filters: adding context '%s' to restrict items", $self->active_context );

### requires current-user!!

if( !defined $self->repository->current_user )
{
	EPrints->abort( sprintf "Attempted to set security context '%s' without a current_user", $self->active_context );
}

		if( ref( $ctx_get_filters_fn ) eq 'CODE' )
		{
			$ctx_filters = &$ctx_get_filters_fn( $self->repository );
		}
		elsif( ref( $ctx_get_filters_fn ) eq 'ARRAY' )
		{
			$ctx_filters = $ctx_get_filters_fn;
		}

		if( EPrints::Utils::is_set( $ctx_filters ) )
		{
			push @$filters, @$ctx_filters;
		}
	}

	return @$filters;
}

sub indexable
{
	my( $self ) = @_;

	return $self->{index};
}

sub ordered
{
	my( $self ) = @_;

	return $self->{order};
}

######################################################################
=pod

=begin InternalDoc

=item $bool = $dataset->is_virtual()

Returns whether this dataset is virtual (i.e. has no database tables).

=end InternalDoc

=cut
######################################################################

sub is_virtual
{
	my( $self ) = @_;

	return $self->{virtual};
}

######################################################################
=pod

=begin InternalDoc

=item $field = $dataset->get_datestamp_field()

Returns the datestamp field for this dataset which may be used for incremental
harvesting. Returns undef if no such field is available.

=end InternalDoc

=cut
######################################################################

sub get_datestamp_field
{
	my( $self ) = @_;

	my $datestamp = $self->{datestamp};

	return defined $datestamp ? $self->field( $datestamp ) : undef;
}

=item $searchexp = $ds->prepare_search( %options )

Returns a L<EPrints::Search> for this dataset with %options.

=cut

sub prepare_search
{
	my( $self, %opts ) = @_;

	return EPrints::Search->new(
		repository => $self->repository,
		dataset => $self,
		allow_blank => 1,
		%opts,
	);
}

=item $list = $ds->search( %options )

Short-cut to L</prepare_search>( %options )->execute.

=over 4

=item "satisfy_all"=>1 

Satify all conditions specified. 0 means satisfy any of the conditions specified. Default is 1

=item "staff"=>1

Do search as an adminstrator means you get everything back

=item "custom_order" => "field1/-field2/field3"

Order the search results by field order. prefixing the field name with a "-" results in reverse ordering

=item "search_fields" => \@({meta_fields=>[ "field1", "field2" "document.field3" ], merge=>"ANY", match=>"EX", value=>"bees"}, {meta_fields=>[ "field4" ], value=>"honey"});

Return values where field1 field2 or field3 is "bees" and field2  is "honey" (assuming satisfy all is set)

=item "limit" => 10

Only return 10 results

=back

=cut

sub search
{
	my( $self, %opts ) = @_;

	return __PACKAGE__ if( ref( $self ) eq '' );

	return $self->prepare_search( %opts )->perform_search;
}

=item $list = $ds->list( $ids )

Returns a L<EPrints::List> for this dataset for the given $ids list.

=cut

sub list
{
	my( $self, $ids ) = @_;

	return EPrints::List->new(
		repository => $self->repository,
		dataset => $self,
		ids => $ids,
	);
}


=begin InternalDoc

=item $dataset->run_trigger( TRIGGER_ID, %params )

Runs all of the registered triggers for TRIGGER_ID on this dataset.

%params is passed to the trigger functions.

=end InternalDoc

=cut

sub run_trigger
{
	my( $self, $type, %params ) = @_;

	my $fs = $self->repository->config( "datasets", $self->base_id, "triggers", $type );
	return if !defined $fs;

	$params{repository} = $self->repository;
	$params{dataset} = $self;

	my $rc;

	TRIGGER: foreach my $priority ( sort { $a <=> $b } keys %{$fs} )
	{
		foreach my $f ( @{$fs->{$priority}} )
		{
			$rc = &{$f}( %params );
			last TRIGGER if defined $rc && $rc eq EP_TRIGGER_DONE;
		}
	}
}

=item $sconf = $dataset->search_config( $searchid )

Retrieve the search configuration $searchid for this dataset. This typically contains a set of fields to search over, order values and rendering parameters.

=cut

sub search_config
{
	my( $self, $searchid ) = @_;

	my $repo = $self->repository;

	my $sconf;
	if( $self->id eq "archive" )
	{
		$sconf = $repo->config( "search", $searchid );
	}
	if( !defined $sconf )	
	{
		$sconf = $repo->config( "datasets", $self->id, "search", $searchid );
	}
	if( defined $sconf )
	{
		# backwards compat. when _fulltext_ was a magic field
		foreach my $sfs (@{$sconf->{search_fields}})
		{
			for(@{$sfs->{meta_fields}})
			{
				$_ = "documents" if $_ eq "_fulltext_";
			}
		}
	}
	elsif( $searchid eq "simple" )
	{
		$sconf = $self->_simple_search_config();
	}
	elsif( $searchid eq "advanced" )
	{
		$sconf = $self->_advanced_search_config();
	}
	else
	{
		$sconf = {};
	}

	return $sconf;
}

=begin InternalDoc

=item $sconf = $dataset->_simple_search_config()

Returns a simple search configuration based on the dataset's fields.

=end InternalDoc

=cut

sub _simple_search_config
{
	my( $self ) = @_;

	return {
		search_fields => [{
			id => "q",
			meta_fields => [
				map { $_->name }
				grep { !$_->is_virtual && $_->property( "text_index" ) }
				$self->fields
			],
			match => "IN",
		}],
		show_zero_results => 1,
		order_methods => {
			byid => $self->key_field->name,
		},
		default_order => "byid",
	};
}

=begin InternalDoc

=item $sconf = $dataset->_advanced_search_config()

Returns an advanced search configuration based on the dataset's fields.

=end InternalDoc

=cut

sub _advanced_search_config
{
	my( $self ) = @_;

	return {
		search_fields => [
			map { { meta_fields => [$_->name] } }
			grep { !$_->is_virtual && $_->property( "text_index" ) }
			$self->fields
		],
		show_zero_results => 1,
		order_methods => {
			byid => $self->key_field->name,
		},
		default_order => "byid",
	};
}

=begin InternalDoc

=item $citation = $dataset->citation( $style )

Returns the citation object (if any) for $style.

=end InternalDoc

=cut

sub citation
{
	my( $self, $id ) = @_;

	my $repo = $self->repository;

	$id = "default" if !defined $id;

	my $citation = $repo->{citations}->{$self->base_id}->{$id};
	if( !defined $citation )
	{
		# warn?
		$repo->log( "Unknown citation style '$id' for ".$self->base_id." dataset: using default" );
		$citation = $repo->{citations}->{$self->base_id}->{"default"};
	}

	if( !defined $citation )
	{
		$repo->log( "No default citation style for ".$self->base_id." dataset" );
		return;
	}

	# reload the citation if it needs to be
	if( !$repo->{fresh}->{$citation} )
	{
		$repo->{fresh}->{$citation} = 1;
		$citation->freshen;
	}

	return $citation;
}

# return 1/0 whether the action is public (ie does not require an auth user)
sub public_action
{
	my( $self, $action ) = @_;

	# we need a user if the context is set/requested	
	return 0 if( defined $self->active_context );

	my @privs = @{ EPrints::ACL::privs_from_action( $action, $self ) || [] };

	my $r = 0;
	
	foreach my $priv ( @privs )
	{
		$r |= 1 if $self->repository->allow_anybody( $priv );

		$self->repository->debug_log( "security", "%s public-allow %s: %d", $self->id, $priv, $r );
		
		last if( $r );
	}

	return $r;
}

#sf2 - add-on - same as DataObj::permit_action
# TODO - should be able to merge this permit_action sub with the one in 
# Dataobj - they only differ on the few dataobj-specifics checks
# then have only one method on the DataSet object
# this is mostly used by Apache::Auth at the mo'
sub permit_action
{
	my( $self, $action, $user ) = @_;

	return 0 if( !$action );

	# we need a user if the context is set/requested	
	return 0 if( defined $self->active_context && !defined $user );

	my @privs = @{ EPrints::ACL::privs_from_action( $action, $self ) || [] };

	my @contexts = @{ $self->contexts || [] };
	
	my $r = 0;
	
	PRIV: foreach my $priv ( @privs )
	{
		last if( $r );
	
		$r |= 1 if $self->repository->allow_anybody( $priv );

		$self->repository->debug_log( "security", "%s public-allow %s: %d", $self->id, $priv, $r );

		if( defined $user )
		{
			$r |= 2 if $user->has_privilege( $priv );
		
			$self->repository->debug_log( "security", "%s user-allow %s: %d", $self->id, $priv, $r );

			# may force a context without checking the user perms
			my $active_context = $self->active_context;
			@contexts = ( $active_context ) if( defined $active_context );

			foreach my $context (@contexts)
			{
				# e.g. image.inbox/search:owner
				if( $user->has_privilege( sprintf "%s:%s", $priv, $context ) )
				{
					# not sure that bit filter is still useful:
					$r |= 2;
					$self->set_context( $context );	
					$self->repository->debug_log( "security", "set context '%s' on dataset %s", $context, $self->id );
					last PRIV;
				}
			}
		}
	}

	return $r;
}

=pod

flow => {

	default => "inbox",		# optional, default states->[0]
	states => [qw/ inbox live /],	# compulsory!
	transitions => {		# optional, default all allowed
		inbox => [qw/ live /],
		live => [qw/ inbox /],
	},

};

                "default" => "inbox",   # starting state
                "valid_states" => [qw/ inbox live /],
                "flow" => {
                        "inbox" => "live",
                        "live" => "inbox",
                },


=cut

sub set_state
{
	my( $self, $new_state ) = @_;

	return __PACKAGE__ if( ref( $self ) eq '' );
	
	if( !$self->is_valid_state( $new_state ) )
	{
		$self->repository->log( "Invalid state '%s' for dataset %s", $new_state, $self->id );
		return __PACKAGE__;
	}

	$self->{state} = $new_state;

	return $self;	# for nested calls	
}

sub reset_state
{
	my( $self ) = @_;

	delete $self->{state};
}

sub state
{
	my( $self ) = @_;

	return undef if( $self->is_stateless );

	return $self->{state};
}

sub states
{
        my( $self ) = @_;

        return undef if( $self->is_stateless );

        return $self->property( 'flow', 'states' );
}

sub is_valid_state
{
	my( $self, $state ) = @_;

	return 0 if( !defined $state );
	
	return 0 if( $self->is_stateless );

	my %valid_states = map { $_ => 1 } @{ $self->states || [] };
	
	return exists $valid_states{$state};
}

sub is_stateless
{
	my( $self ) = @_;

        # 'state' SHOULD BE an internal field i.e. people cannot create custom fields called 'state'
        return !$self->has_field( 'state' );
}

# TODO/sf2 - unused? remove?
sub check_states
{
	my( $self ) = @_;

	my $states_def = $self->property( 'states' );
	return 1 if( !EPrints::Utils::is_set( $states_def ) );

	my $default = $states_def->{default};

	my $flow = $states_def->{flow};

	# the actual valid states:
	my $states = keys %{ $flow || [] };
	
}

# object states ('inbox', 'archive' ..)
sub default_state
{
	my( $self ) = @_;

	return $self->state if( defined $self->state );

	return $self->property( 'flow', 'default' );
}

sub set_context
{
	my( $self, $context ) = @_;

	return __PACKAGE__ if( ref( $self ) eq '' );

	if( !$self->is_valid_context( $context ) )
	{
		$self->repository->log( "Invalid security context '%s' on dataset %s", $context, $self->id );
		return __PACKAGE__;
	}
	
	$self->{context} = $context;

	return $self;	# to allow nested calls
}

sub reset_context
{
	my( $self ) = @_;
	
	delete $self->{context};
}

# security contexts ('owner', ...)
sub contexts
{
	my( $self ) = @_;

	my @contexts = keys %{ $self->property( 'contexts' ) || {} };

	return \@contexts;
}

sub active_context
{
	my( $self ) = @_;

	return undef if( !$self->{context} );

	return $self->{context};
}

sub is_valid_context
{
	my( $self, $context ) = @_;

	my %valid_contexts = map { $_ => 1 } @{ $self->contexts || [] };

	return exists $valid_contexts{$context};
}

sub matches_context
{
	my( $self, $dataobj ) = @_;

	return 1 if( !defined $self->active_context );

	my $matches = $self->property( 'contexts', $self->active_context, 'matches' );

	if( defined $matches && ref( $matches ) eq 'CODE' )
	{
		return 0 if( !$self->repository->current_user );
		return &$matches( $self->repository, $dataobj );
	}

	return 0;
}

# done via current_user cos that's currently how this works - cf. contexts definition in a cfg.d/.*_dataset
sub user_contexts
{
	my( $self, $dataobj ) = @_;

	return [] if( !defined $self->repository->current_user || !defined $dataobj );

	my @user_contexts;
	foreach my $ctx ( @{ $self->contexts } )
	{
		my $matches = $self->property( 'contexts', $ctx, 'matches' );
		if( defined $matches && ref( $matches ) eq 'CODE' )
		{
			push @user_contexts, $ctx if &$matches( $self->repository, $dataobj );
		}
	}

	return \@user_contexts;
}

######################################################################
1;
######################################################################
=pod

=back

=cut


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

