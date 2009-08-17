######################################################################
#
# EPrints::DataSet
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

B<EPrints::DataSet> - a dataset is a set of records in the eprints system with
the same metadata.

=head1 SYNOPSIS

	my $dataset = $repository->get_dataset( "inbox" );

	print sprintf("There are %d records in the inbox\n",
		$dataset->count);

=head1 DESCRIPTION

This module describes an EPrint dataset.

A repository has several datasets that make up the repository's database.
The list of dataset ids can be obtained from the repository object
(see L<EPrints::Repository>).

A normal dataset (eg. "user") has a package associated with it 
(eg. EPrints::DataObj::User) which must be a subclass of EPrints::DataObj 
and a number of SQL tables which are prefixed with the dataset name.
Most datasets also have a set of associated EPrints::MetaField's which
may be optional or compulsary depending on the type eg. books have editors
but posters don't but they are both EPrints.

The fields contained in a dataset are defined by the data object and by
any additional fields defined in cfg.d. Some datasets don't have any
fields while others may just be "virtual" datasets made from others.

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

use strict;

# filters is the filters to apply to this dataset before returning
# values.

# dataset_id_field is a field to write the dataset id to when an item
# is created. 

# These are both used by the virtual datasets inbox, buffer etc.

my $INFO = {
	event_queue => {
		sqlname => "event_queue",
		class => "EPrints::DataObj::EventQueue",
		datestamp => "datestamp",
	},
	upload_progress => {
		sqlname => "upload_progress",
		class => "EPrints::DataObj::UploadProgress",
	},
	file => {
		sqlname => "file",
		class => "EPrints::DataObj::File",
		datestamp => "mtime",
	},
	import => {
		sqlname => "import",
		class => "EPrints::DataObj::Import",
		datestamp => "datestamp",
	},
	metafield => {
		sqlname => "mf", # identifiers get too long
		class => "EPrints::DataObj::MetaField",
		datestamp => "mfdatestamp",
	},
	cachemap => {
		sqlname => "cachemap",
		class => "EPrints::DataObj::Cachemap",
	},
	message => {
		sqlname => "message",
		class => "EPrints::DataObj::Message",
		datestamp => "datestamp",
	},
	loginticket => {
		sqlname => "loginticket",
		class => "EPrints::DataObj::LoginTicket",
	},
	counter => {
		sqlname => "counters",
		virtual => 1,
	},
	user => {
		sqlname => "user",
		class => "EPrints::DataObj::User",
		import => 1,
		index => 1,
		datestamp => "joined",
	},
	archive => {
		sqlname => "eprint",
		virtual => 1,
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		index => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'archive', describe=>0 } ],
		dataset_id_field => "eprint_status",
		datestamp => "lastmod",
	},
	buffer => {
		sqlname => "eprint",
		virtual => 1,
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		index => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'buffer', describe=>0 } ],
		dataset_id_field => "eprint_status",
		datestamp => "lastmod",
	},
	inbox => {
		sqlname => "eprint",
		virtual => 1,
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		index => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'inbox', describe=>0 } ],
		dataset_id_field => "eprint_status",
		datestamp => "lastmod",
	},
	deletion => {
		sqlname => "eprint",
		virtual => 1,
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		index => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'deletion', describe=>0 } ],
		dataset_id_field => "eprint_status",
		datestamp => "lastmod",
	},
	eprint => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		index => 1,
		datestamp => "lastmod",
	},
	document => {
		sqlname => "document",
		class => "EPrints::DataObj::Document",
		import => 1,
		index => 1,
	},
	subject => {
		sqlname => "subject",
		class => "EPrints::DataObj::Subject",
		import => 1,
		index => 1,
	},
	history => {
		sqlname => "history",
		class => "EPrints::DataObj::History",
		import => 1,
		index => 1,
		datestamp => "timestamp",
	},
	saved_search => {
		sqlname => "saved_search",
		class => "EPrints::DataObj::SavedSearch",
		import => 1,
		index => 1,
	},
	access => {
		sqlname => "access",
		class => "EPrints::DataObj::Access",
		import => 1,
		datestamp => "datestamp",
	},
	request => {
		sqlname => "request",	
		class => "EPrints::DataObj::Request",
		import => 1,
		index => 1,
		datestamp => "datestamp",
	},
};

######################################################################
=pod

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

=cut
######################################################################

sub new
{
	my( $class, %properties ) = @_;
	
	if( !defined $properties{repository} )
	{
		EPrints::abort( "Requires repository property" );
	}
	if( !defined $properties{name} )
	{
		EPrints::abort( "Requires name property" );
	}

	# We support the field properties of "name" and "type"

	# datasets are identified by "id", not "name"
	$properties{id} ||= delete $properties{name};

	# type is a short-cut for specifying the object class
	# (We have to maintain case though, because DataObj classes are
	# camelcased)
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

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};

	$self->{default_order} = $repository->
			get_conf( "default_order", $self->{confid} );

	# copy fields from the real dataset
	if(
		$self->{id} ne $self->{confid} &&
		defined(my $cdataset = $repository->get_dataset( $self->{confid} ))
	  )
	{
		for(qw( fields system_fields field_index ))
		{
			$self->{$_} = $cdataset->{$_};
		}
	}
	else
	{
		my $oclass = $self->get_object_class;
		if( defined $oclass )
		{
			foreach my $fielddata ( $oclass->get_system_field_info() )
			{
				$self->process_field( $fielddata, 1 );
			}
		}
		my $repository_fields = $repository->get_conf( "fields", $self->{confid} );
		if( $repository_fields )
		{
			foreach my $fielddata ( @{$repository_fields} )
			{
				$self->process_field( $fielddata, 0 );
			}
		}

		# lock these metadata fields against being modified again.
		foreach my $field ( @{$self->{fields}} )
		{
			$field->final;
		}
	}

	return $self;
}

=item $info = EPrints::DataSet::get_system_dataset_info()

Returns a hash reference of core system datasets.

=cut

sub get_system_dataset_info
{
	return $INFO;
}

=back

=head2 Object Methods

=over 4

=cut

=item $field = $ds->process_field( $data [, $system ] )

Creates a new field in this dataset based on $data. If $system is true defines
the new field as a "core" field.

=cut

sub process_field
{
	my( $self, $fielddata, $system ) = @_;

	if( !defined $fielddata->{providence} )
	{
		$fielddata->{providence} = $system ? "core" : "config";
	}

	my $field = EPrints::MetaField->new( 
		dataset => $self, 
		%{$fielddata} );

	$self->register_field( $field, $system );
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		foreach my $inner_field (@{$field->{fields_cache}})
		{
			$self->register_field( $inner_field, $system );
		}
	}

	return $field;
}

=item $ds->register_field( $field [, $system ] )

Register a new field with this dataset.

=cut

sub register_field
{
	my( $self, $field, $system ) = @_;

	push @{$self->{fields}}, $field;
	$self->{field_index}->{$field->get_name()} = $field;
	if( $system )
	{
		push @{$self->{system_fields}} , $field;
	}
}

=item $ds->unregister_field( $field )

Unregister a field from this dataset.

=cut

sub unregister_field
{
	my( $self, $field ) = @_;

	my $name = $field->get_name();

	delete $self->{field_index}->{$name};
	@{$self->{fields}} = grep { $_->get_name() ne $name } @{$self->{fields}};
	@{$self->{system_fields}} = grep { $_->get_name() ne $name } @{$self->{system_fields}};
}

######################################################################
=pod

=item $metafield = $ds->get_field( $fieldname )

Return a MetaField object describing the asked for field
in this dataset, or undef if there is no such field.

=cut
######################################################################

sub get_field
{
	my( $self, $fieldname ) = @_;


	# magic fields which can be searched but do
	# not really exist.
	if( $fieldname eq $EPrints::Utils::FULLTEXT )
	{
		if( !defined $self->{fulltext_field} )
		{
			$self->{fulltext_field} = EPrints::MetaField->new( 
				dataset=>$self , 
				name=>$fieldname,
				multiple=>1,
				type=>"fulltext" );
			$self->{fulltext_field}->set_property( "multiple",1 );
			$self->{fulltext_field}->final;
		}
		return $self->{fulltext_field};
	}
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
		$self->{repository}->log( 
			"dataset ".$self->{id}." has no field: ".
			$fieldname );
		return undef;
	}
	return $self->{field_index}->{$fieldname};
}

######################################################################
=pod

=item $bool = $ds->has_field( $fieldname )

True if the dataset has a field of that name.

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

=item $ordertype = $ds->default_order

Return the id string of the default order for this dataset. 

For example "bytitle" for eprints.

=cut
######################################################################

sub default_order
{
	my( $self ) = @_;

	return $self->{default_order};
}

#
# string confid()
#
#  returns the id string to be used to identify this dataset in the 
#  config and phrases ( in a nutshell "Archive", "Buffer" and "Inbox"
#  all return "eprint" because they all (must) have identical structure.


######################################################################
=pod

=item $confid = $ds->confid

Return the string to use when getting configuration for this dataset.

archive, buffer, inbox and deletion all return "eprint" as they must
have the same configuration.

=cut
######################################################################

sub confid
{
	my( $self ) = @_;
	return $self->{confid};
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

=item $n = $ds->count( $handle )

Return the number of records in this dataset.

=cut
######################################################################

sub count
{
	my( $self, $handle ) = @_;

	if( defined $self->get_filters )
	{
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $self,
			handle => $handle );
		my $list = $searchexp->perform_search;
		my $c = $list->count;
		$list->dispose;
		return $c;
	}

	return $handle->get_database->count_table( $self->get_sql_table_name() );
}
 

######################################################################
=pod

=item $tablename = $ds->get_sql_table_name

Return the name of the main SQL Table containing this dataset.
the other SQL tables names are based on this name.

=cut
######################################################################

sub get_sql_table_name
{
	my( $self ) = @_;

	my $table = $self->{sqlname};

	return $table if defined $table;

	EPrints::abort( "Can't get a SQL table name for dataset: ".$self->{id} );
}



######################################################################
=pod

=item $tablename = $ds->get_sql_index_table_name

Return the name of the SQL table which contains the free text indexing
information.

=cut
######################################################################

sub get_sql_index_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."index";
}

######################################################################
=pod

=item $tablename = $ds->get_sql_grep_table_name

Reutrn the name of the SQL table which contains the strings to
be used with LIKE in a final pass of a search.

=cut
######################################################################

sub get_sql_grep_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."index_grep";
}

######################################################################
=pod

=item $tablename = $ds->get_sql_rindex_table_name

Reutrn the name of the SQL table which contains the reverse text
indexing information. (Used for deleting freetext indexes when
removing a record).

=cut
######################################################################

sub get_sql_rindex_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."rindex";
}

######################################################################
=pod

=item $tablename = $ds->get_ordervalues_table_name( $langid )

Return the name of the SQL table containing values used for ordering
this dataset.

=cut
######################################################################

sub get_ordervalues_table_name
{
	my( $self,$langid ) = @_;
	return $self->get_sql_table_name()."__"."ordervalues_".$langid;
}


######################################################################
=pod

=item $tablename = $ds->get_sql_sub_table_name( $field )

Returns the name of the SQL table which contains the information
on the "multiple" field. $field is an EPrints::MetaField belonging
to this dataset.

=cut
######################################################################

sub get_sql_sub_table_name
{
	my( $self , $field ) = @_;
	return $self->get_sql_table_name()."_".$field->get_sql_name();
}


######################################################################
=pod

=item $fields = $ds->get_fields

Returns a list of the EPrints::Metafields belonging to this dataset.

=cut
######################################################################

sub get_fields
{
	my( $self ) = @_;

	my @fields = @{ $self->{fields} };

	return @fields;
}


######################################################################
=pod

=item $field = $ds->get_key_field

Return the EPrints::MetaField representing the primary key field.
Always the first field.

=cut
######################################################################

sub get_key_field
{
	my( $self ) = @_;
	return $self->{fields}->[0];
}


######################################################################
=pod

=item $obj = $ds->make_object( $handle, $data )

Return an object of the class associated with this dataset, always
a subclass of EPrints::DataObj.

$data is a hash of values for fields of a record in this dataset.

Return $data if no class associated with this dataset.

=cut
######################################################################

sub make_object
{
	my( $self , $handle , $data ) = @_;

	my $class = $self->get_object_class;

	# If this table dosn't have an associated class, just
	# return the data.	

	if( !defined $class ) 
	{
		return $data;
	}

	return $class->new_from_data( 
		$handle,
		$data,
		$self );
}

######################################################################
=pod

=item $obj = $ds->create_object( $handle, $data )

Create a new object in the given dataset. Return the new object.

Return undef if the object could not be created.

If $data describes sub-objects too then those will also be created.

=cut
######################################################################

sub create_object
{
	my( $self , $handle , $data ) = @_;

	my $class = $self->get_object_class;

	return $class->create_from_data( $handle, $data, $self );
}

######################################################################
=pod

=item $class = $ds->get_object_class;

Return the perl class to which objects in this dataset belong.

=cut
######################################################################

sub get_object_class
{
	my( $self, $handle ) = @_;

	return $self->{class};
}

######################################################################
=pod

=item $obj = $ds->get_object( $handle, $id );

Return the object from this dataset with the given id, or undefined.

=cut
######################################################################

sub get_object
{
	my( $self, $handle, $id ) = @_;

	my $class = $self->get_object_class;

	if( !defined $class )
	{
		$handle->get_repository->log(
				"Can't get_object for dataset ".
				$self->{confid} );
		return undef;
	}

	return $class->new( $handle, $id, $self );
}

=item $dataobj = EPrints::DataSet->get_object_from_uri( $handle, $uri )

Returns a the dataobj identified by internal URI $uri.

Returns undef if $uri isn't an internal URI or the object is no longer available.

=cut

sub get_object_from_uri
{
	my( $class, $handle, $uri ) = @_;

	my( $datasetid, $id ) = $uri =~ m# ^/id/([^/]+)/(.+)$ #x;
	return unless defined $id;

	$datasetid = URI::Escape::uri_unescape( $datasetid );

	my $dataset = $handle->get_repository->get_dataset( $datasetid );
	return unless defined $dataset;

	$id = URI::Escape::uri_unescape( $id );

	my $dataobj = $dataset->get_object( $handle, $id );

	return $dataobj;
}

######################################################################
=pod

=item $xhtml = $ds->render_name( $handle )

Return a piece of XHTML describing this dataset, in the language of
the current session.

=cut
######################################################################

sub render_name($$)
{
	my( $self, $handle ) = @_;

        return $handle->html_phrase( "dataset_name_".$self->id() );
}

######################################################################
=pod

=item $ds->map( $handle, $fn, $info )

Maps the function $fn onto every record in this dataset. See 
Search for a full explanation.

=cut
######################################################################

sub map
{
	my( $self, $handle, $fn, $info ) = @_;

	my $searchexp = EPrints::Search->new(
		allow_blank => 1,
		dataset => $self,
		handle => $handle );
	$searchexp->perform_search();
	$searchexp->map( $fn, $info );
	$searchexp->dispose();
}


######################################################################
=pod

=item $repository = $ds->get_repository

Returns the EPrints::Repository to which this dataset belongs.

=cut
######################################################################

sub get_repository
{
	my( $self ) = @_;
	
	return $self->{repository};
}


######################################################################
=pod

=item $ds->reindex( $handle )

Recommits all the items in this dataset. This could take a real long 
time on a large set of records.

Really should not be called reindex anymore as it doesn't.

=cut
######################################################################

sub reindex
{
	my( $self, $handle ) = @_;

	my $fn = sub {
		my( $handle, $dataset, $item ) = @_;
		if( $handle->get_noise() >= 2 )
		{
			print STDERR "Reindexing item: ".$dataset->id()."/".$item->get_id()."\n";
		}
		$item->commit();
	};

	$self->map( $handle, $fn );
}

######################################################################
=pod

=item @ids = EPrints::DataSet::get_dataset_ids()

Deprecated, use $repository->get_dataset_ids().

=cut
######################################################################

sub get_dataset_ids
{
	&EPrints::deprecated;

	return keys %{$INFO};
}

######################################################################
=pod

=item @ids = EPrints::DataSet::get_sql_dataset_ids()

Deprecated, use $repository->get_sql_dataset_ids().

=cut
######################################################################

sub get_sql_dataset_ids
{
	&EPrints::deprecated;

	return grep { !$INFO->{$_}->{"virtual"} } keys %{$INFO};
}

######################################################################
=pod

=item $n = $ds->count_indexes

Return the number of indexes required for the main SQL table of this
dataset. Used to check it's not over 32 (the current maximum allowed
by MySQL)

Assumes things either have 1 or 0 indexes which might not always
be true.

=cut
######################################################################

sub count_indexes
{
	my( $self ) = @_;

	my $n = 0;
	foreach my $field ( $self->get_fields( 1 ) )
	{
		next if $field->get_property( "multiple" );
		next if $field->isa( "EPrints::MetaField::Compound" );
		next unless( defined $field->get_sql_index );
		$n++;
	}
	return $n;
}
		
######################################################################
=pod

=item @ids = $dataset->get_item_ids( $handle )

Return a list of the id's of all items in this set.

=cut
######################################################################

sub get_item_ids
{
	my( $self, $handle ) = @_;

	if( defined $self->get_filters )
	{
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $self,
			handle => $handle );
		my $list = $searchexp->perform_search;
		return $list->get_ids;
	}
	return $handle->get_database->get_values( $self->get_key_field, $self );
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

	my $f = $self->{filters};

	return defined $f ? @{$f} : undef;
}

sub indexable
{
	my( $self ) = @_;

	return $self->{index};
}

######################################################################
=pod

=item $bool = $dataset->is_virtual()

Returns whether this dataset is virtual (i.e. has no database tables).

=cut
######################################################################

sub is_virtual
{
	my( $self ) = @_;

	return $self->{virtual};
}

######################################################################
=pod

=item $field = $dataset->get_datestamp_field()

Returns the datestamp field for this dataset which may be used for incremental
harvesting. Returns undef if no such field is available.

=cut
######################################################################

sub get_datestamp_field
{
	my( $self ) = @_;

	my $datestamp = $self->{datestamp};

	return defined $datestamp ? $self->get_field( $datestamp ) : undef;
}






######################################################################
1;
######################################################################
=pod

=back

=cut

