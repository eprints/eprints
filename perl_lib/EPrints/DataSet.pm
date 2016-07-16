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

my $INFO = {
	event_queue => {
		sqlname => "event_queue",
		class => "EPrints::DataObj::EventQueue",
		datestamp => "start_time",
		columns => [qw( status start_time pluginid action params )],
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
		order => 1,
		datestamp => "joined",
	},
	archive => {
		sqlname => "eprint",
		virtual => 1,
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		index => 1,
		order => 1,
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
		order => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'buffer', describe=>0 } ],
		dataset_id_field => "eprint_status",
		datestamp => "lastmod",
		columns => [qw( eprintid type status_changed userid )], # default columns for Review screen
	},
	inbox => {
		sqlname => "eprint",
		virtual => 1,
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		index => 1,
		order => 1,
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
		order => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'deletion', describe=>0 } ],
		dataset_id_field => "eprint_status",
		datestamp => "lastmod",
	},
	eprint => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		index => 1,
		order => 1,
		datestamp => "lastmod",
	},
	document => {
		sqlname => "document",
		class => "EPrints::DataObj::Document",
		import => 1,
		order => 1,
		index => 1,
	},
	subject => {
		sqlname => "subject",
		class => "EPrints::DataObj::Subject",
		import => 1,
		index => 1,
		order => 1,
	},
	history => {
		sqlname => "history",
		class => "EPrints::DataObj::History",
		import => 1,
		datestamp => "timestamp",
	},
	saved_search => {
		sqlname => "saved_search",
		class => "EPrints::DataObj::SavedSearch",
		import => 1,
		index => 1,
		columns => [qw( id name )],
	},
	public_saved_search => {
		sqlname => "saved_search",
		class => "EPrints::DataObj::SavedSearch",
		import => 1,
		index => 1,
		virtual => 1,
		confid => "saved_search",
		filters => [ { meta_fields => [ 'public' ], value => 'TRUE', describe=>0 } ],
#		dataset_id_field => "eprint_status",
	},
	access => {
		sqlname => "access",
		class => "EPrints::DataObj::Access",
		import => 1,
		datestamp => "datestamp",
	},
	triple => {
		sqlname => "triple",
		class => "EPrints::DataObj::Triple",
		import => 1,
	},
	request => {
		sqlname => "request",	
		class => "EPrints::DataObj::Request",
		import => 1,
		index => 1,
		datestamp => "datestamp",
	},
	epm => {
		sqlname => "epm",
		class => "EPrints::DataObj::EPM",
		virtual => 1,
	},
};

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
				$self->_process_field( $fielddata, 1 );
			}
		}
		my $repository_fields = $repository->get_conf( "fields", $self->{confid} );
		if( $repository_fields )
		{
			foreach my $fielddata ( @{$repository_fields} )
			{
				$self->_process_field( $fielddata, 0 );
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

=begin InternalDoc

=item $info = EPrints::DataSet::get_system_dataset_info()

Returns a hash reference of core system datasets.

=end InternalDoc

=cut

sub get_system_dataset_info
{
	return $INFO;
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

sub confid { &base_id }
sub base_id
{
	my( $self ) = @_;
	return $self->{confid};
}

=begin InternalDoc

=item $field = $ds->_process_field( $data [, $system ] )

Creates a new field in this dataset based on $data. If $system is true defines
the new field as a "core" field.

=end InternalDoc

=cut

sub _process_field
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
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		foreach my $inner_field (@{$field->{fields_cache}})
		{
			$self->register_field( $inner_field, $system );
		}
	}

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

	my $name = $field->get_name();

	delete $self->{field_index}->{$name};
	@{$self->{fields}} = grep { $_->get_name() ne $name } @{$self->{fields}};
	@{$self->{system_fields}} = grep { $_->get_name() ne $name } @{$self->{system_fields}};
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
		$self->{repository}->log( 
			"dataset ".$self->{id}." has no field: ".
			$fieldname );
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

=item $n = $ds->count( $session )

Return the number of records in this dataset.

=cut
######################################################################

sub count
{
	my( $self, $session ) = @_;

	if( $self->get_filters )
	{
		return $self->search->count;
	}

	return $session->get_database->count_table( $self->get_sql_table_name() );
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

	my $table = $self->{sqlname};

	return $table if defined $table;

	EPrints::abort( "Can't get a SQL table name for dataset: ".$self->{id} );
}



######################################################################
=pod

=begin InternalDoc

=item $tablename = $ds->get_sql_index_table_name

Return the name of the SQL table which contains the free text indexing
information.

=end InternalDoc

=cut
######################################################################

sub get_sql_index_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."index";
}

######################################################################
=pod

=begin InternalDoc

=item $tablename = $ds->get_sql_grep_table_name

Reutrn the name of the SQL table which contains the strings to
be used with LIKE in a final pass of a search.

=end InternalDoc

=cut
######################################################################

sub get_sql_grep_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."index_grep";
}

######################################################################
=pod

=begin InternalDoc

=item $tablename = $ds->get_sql_rindex_table_name

Reutrn the name of the SQL table which contains the reverse text
indexing information. (Used for deleting freetext indexes when
removing a record).

=end InternalDoc

=cut
######################################################################

sub get_sql_rindex_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."rindex";
}

######################################################################
=pod

=begin InternalDoc

=item $tablename = $ds->get_ordervalues_table_name( $langid )

Return the name of the SQL table containing values used for ordering
this dataset.

=end InternalDoc

=cut
######################################################################

sub get_ordervalues_table_name
{
	my( $self,$langid ) = @_;
	return $self->get_sql_table_name()."__"."ordervalues_".$langid;
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

sub get_fields { &fields }
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

sub get_key_field { &key_field }
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
		$self->{repository},
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
	my( $self , $session , $data ) = @_;

	return $self->create_dataobj( $data );
}
sub create_dataobj
{
	my( $self, $data ) = @_;
	
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
	my( $self, $session ) = @_;
	return $self->{class};
}

######################################################################
=pod

=begin InternalDoc

=item $obj = $ds->get_object( $session, $id );

Return the object from this dataset with the given id, or undefined.

=end InternalDoc

=cut
######################################################################

sub get_object
{
	my( $self, $session, $id ) = @_;

	my $class = $self->get_object_class;

	if( !defined $class )
	{
		$session->get_repository->log(
				"Can't get_object for dataset ".
				$self->{confid} );
		return undef;
	}

	return $class->new( $session, $id, $self );
}

=item $dataobj = $ds->dataobj( $id )

Returns the object from this dataset with the given id, or undefined.

=cut

sub dataobj
{
	my( $self, $id ) = @_;
	
	my $dataobj = $self->dataobj_class->new( $self->repository, $id, $self );

	return if !defined $dataobj;

	# Hacky solution to ticket #3749. Stops an eprint in the wrong dataset 
        # being returned. Otherwise stuff could leak out.
	if( $self->{confid} eq "eprint" && $self->{id} ne "eprint" )
	{
		if( $dataobj->get_value( "eprint_status" ) ne $self->{id} )
		{
			return;
		}
	}

	return $dataobj;
}

=begin InternalDoc

=item $dataobj = EPrints::DataSet->get_object_from_uri( $session, $uri )

Returns a the dataobj identified by internal URI $uri.

Returns undef if $uri isn't an internal URI or the object is no longer available.

=end InternalDoc

=cut

sub get_object_from_uri
{
	my( $class, $session, $uri ) = @_;

	my( $datasetid, $id ) = $uri =~ m# ^/id/([^/]+)/(.+)$ #x;
	return unless defined $id;

	$datasetid = URI::Escape::uri_unescape( $datasetid );

	my $dataset = $session->dataset( $datasetid );
	return unless defined $dataset;

	$id = URI::Escape::uri_unescape( $id );

	my $dataobj = $dataset->get_object( $session, $id );

	return $dataobj;
}

######################################################################
=pod

=begin InternalDoc

=item $xhtml = $ds->render_name( $session )

Return a piece of XHTML describing this dataset, in the language of
the current session.

=end InternalDoc

=cut
######################################################################

sub render_name
{
	my( $self ) = @_;

	return $self->{repository}->html_phrase( "datasetname_".$self->id() );
}

######################################################################
=pod

=begin InternalDoc

=item $ds->map( $session, $fn, $info )

Maps the function $fn onto every record in this dataset. See 
Search for a full explanation.

=end InternalDoc

=cut
######################################################################

sub map
{
	my( $self, $session, $fn, $info ) = @_;

	$self->search->map( $fn, $info );
}


######################################################################
=pod

=item $repository = $ds->repository

Returns the L<EPrints::Repository> to which this dataset belongs.

=cut
######################################################################

sub get_archive { &repository }
sub get_repository { &repository }
sub repository
{
	my( $self ) = @_;
	return $self->{repository};
}


######################################################################
=pod

=begin InternalDoc

=item $ds->reindex( $session )

Recommits all the items in this dataset. This could take a real long 
time on a large set of records.

Really should not be called reindex anymore as it doesn't.

=end InternalDoc

=cut
######################################################################

sub reindex
{
	my( $self, $session ) = @_;

	my $fn = sub {
		my( $session, $dataset, $item ) = @_;
		if( $session->get_noise() >= 2 )
		{
			print STDERR "Reindexing item: ".$dataset->id()."/".$item->get_id()."\n";
		}
		$item->commit();
	};

	$self->map( $session, $fn );
}

######################################################################
=pod

=begin InternalDoc

=item @ids = EPrints::DataSet::get_dataset_ids()

Deprecated, use $repository->get_dataset_ids().

=end InternalDoc

=cut
######################################################################

sub get_dataset_ids
{
	&EPrints::deprecated;

	return keys %{$INFO};
}

######################################################################
=pod

=begin InternalDoc

=item @ids = EPrints::DataSet::get_sql_dataset_ids()

Deprecated, use $repository->get_sql_dataset_ids().

=end InternalDoc

=cut
######################################################################

sub get_sql_dataset_ids
{
	&EPrints::deprecated;

	return grep { !$INFO->{$_}->{"virtual"} } keys %{$INFO};
}

######################################################################
=pod

=begin InternalDoc

=item @ids = $dataset->get_item_ids( $session )

Return a list of the id's of all items in this set.

=end InternalDoc

=cut
######################################################################

sub get_item_ids
{
	my( $self, $session ) = @_;

	if( $self->get_filters )
	{
		return $self->search->get_ids;
	}
	return $session->get_database->get_values( $self->get_key_field, $self );
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

	return defined $f ? @{$f} : ();
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

	return defined $datestamp ? $self->get_field( $datestamp ) : undef;
}

=item $searchexp = $ds->prepare_search( %options )

Returns a L<EPrints::Search> for this dataset with %options.

=cut

sub prepare_search
{
	my( $self, %opts ) = @_;

	return EPrints::Search->new(
		session => $self->{repository},
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

Do search as an administrator means you get everything back

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

	return $self->prepare_search( %opts )->perform_search;
}

=item $list = $ds->list( $ids )

Returns a L<EPrints::List> for this dataset for the given $ids list.

=cut

sub list
{
	my( $self, $ids ) = @_;

	return EPrints::List->new(
		session => $self->{repository},
		dataset => $self,
		ids => $ids,
	);
}

=begin InternalDoc

=item $fields = $dataset->columns()

Returns the default list of fields to show the user when browsing this dataset in a table. Returns an array ref of L<EPrints::MetaField> objects.

=end InternalDoc

=cut

sub columns
{
	my( $self ) = @_;

	my $columns = $self->{repository}->config( "datasets", $self->id, "columns" );
	if( !defined $columns )
	{
		$columns = $self->{columns};
	}
	$columns = [] if !defined $columns;

	$columns = [grep { defined $_ } map { $self->field( $_ ) } @$columns];

	return $columns;
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

	my $fs = $self->{repository}->config( "datasets", $self->base_id, "triggers", $type );
	return if !defined $fs;

	$params{repository} = $self->{repository};
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

	my $repo = $self->{repository};

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

