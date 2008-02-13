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

=head1 DESCRIPTION

This module describes an EPrint dataset.

An repository has one of each type of dataset:

cachemap, counter, user, archive, buffer, inbox, document, subject,
saved_search, deletion, eprint, access.

A normal dataset (eg. "user") has a package associated with it 
(eg. EPrints::DataObj::User) which must be a subclass of EPrints::DataObj 
and a number of SQL tables which are prefixed with the dataset name.
Most datasets also have a set of associated EPrints::MetaField's which
may be optional or compulsary depending on the type eg. books have editors
but posters don't but they are both EPrints.

Datasets have some default fields plus additional ones configured
in Fields.pm.

But there are some exceptions:

=over 4

=item cachemap, counter

Don't have a package or metadata fields associated.

=item archive, buffer, inbox, deletion

All have the same package and metadata fields as eprints, but
are filtered by eprint_status.

=back

EPrints::DataSet objects are cached by the related EPrints::Repository
object and usually obtained by calling.

$ds = $repository->get_dataset( "inbox" );

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
	cachemap => {
		sqlname => "cachemap",
		class => "EPrints::DataObj::Cachemap",
	},
	counter => {
		sqlname => "counters"
	},
	user => {
		sqlname => "user",
		class => "EPrints::DataObj::User",
		import => 1,
	},
	archive => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'archive', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	buffer => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'buffer', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	inbox => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'inbox', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	deletion => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'deletion', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	eprint => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint"
	},
	document => {
		sqlname => "document",
		class => "EPrints::DataObj::Document",
		import => 1,
	},
	subject => {
		sqlname => "subject",
		class => "EPrints::DataObj::Subject",
		import => 1,
	},
	history => {
		sqlname => "history",
		class => "EPrints::DataObj::History",
		import => 1,
	},
	saved_search => {
		sqlname => "saved_search",
		class => "EPrints::DataObj::SavedSearch",
		import => 1,
	},
	access => {
		sqlname => "access",
		class => "EPrints::DataObj::Access",
		import => 1,
	},
	request => {
		sqlname => "request",	
		class => "EPrints::DataObj::Request",
		import => 1,
	},
};


######################################################################
=pod

=item $ds = EPrints::DataSet->new_stub( $id )

Creates a dataset object without any fields. Useful to
avoid problems with something a dataset does depending on loading
the dataset. It can still be queried about other things, such as
SQL table names. 

=cut
######################################################################

sub new_stub
{
	my( $class , $id ) = @_;

	if( !defined $INFO->{$id} )
	{
		# no repository info, so can't log.
		EPrints::abort( "Unknown dataset name: $id" );
	}
	my $self = {};
	bless $self, $class;

	$self->{id} = $id;
	$self->{confid} = $INFO->{$id}->{confid};
	$self->{confid} = $id unless( defined $self->{confid} );

	return $self;
}



######################################################################
=pod

=item $ds = EPrints::DataSet->new( $repository, $id )

Return the dataset specified by $id.

Note that dataset know $repository and vice versa - which means they
will not get garbage collected.

=cut
######################################################################

sub new
{
	my( $class , $repository , $id ) = @_;
	
	my $self = EPrints::DataSet->new_stub( $id );

	$self->{repository} = $repository;

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};

	$self->{default_order} = $self->{repository}->
			get_conf( "default_order" , $self->{confid} );

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

	return $self;
}

sub process_field
{
	my( $self, $fielddata, $system ) = @_;

	my @cfields;
	if( $fielddata->{type} eq "compound" )
	{	
		@cfields = @{$fielddata->{fields}};
	}
	if( $fielddata->{type} eq "multilang" )
	{	
		my $langs = $self->{repository}->get_conf('languages');
		if( defined $fielddata->{languages} )
		{
			$langs = $fielddata->{languages};
		}
		@cfields = (
			@{$fielddata->{fields}},
			{ 
				sub_name=>"lang",
				type=>"langid",
				options => $langs,
			}, 
		);
	}
		
	if( scalar @cfields )
	{	
		$fielddata->{fields_cache} = [];
		foreach my $inner_field ( @cfields )
		{
			my $field = EPrints::MetaField->new( 
				parent_name => $fielddata->{name},
				show_in_html => 0,
				dataset => $self, 
				multiple => $fielddata->{multiple},
				%{$inner_field} );	
			push @{$self->{fields}}	, $field;
			if( $system )
			{
				push @{$self->{system_fields}} , $field;
			}
			$self->{field_index}->{$field->get_name()} = 
				$field;
			push @{$fielddata->{fields_cache}}, $field;
		}
	}

	my $field = EPrints::MetaField->new( 
		dataset => $self, 
		%{$fielddata} );	
	push @{$self->{fields}}	, $field;
	if( $system )
	{
		push @{$self->{system_fields}} , $field;
	}

	$self->{field_index}->{$field->get_name()} = $field;
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

=item $n = $ds->count( $session )

Return the number of records in this dataset.

=cut
######################################################################

sub count
{
	my( $self, $session ) = @_;

	if( defined $self->get_filters )
	{
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $self,
			session => $session );
		my $list = $searchexp->perform_search;
		return $list->count;
	}

	return $session->get_database->count_table( $self->get_sql_table_name() );
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

	my $table = $INFO->{$self->{id}}->{sqlname};

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

=item $obj = $ds->make_object( $session, $data )

Return an object of the class associated with this dataset, always
a subclass of EPrints::DataObj.

$data is a hash of values for fields of a record in this dataset.

Return $data if no class associated with this dataset.

=cut
######################################################################

sub make_object
{
	my( $self , $session , $data ) = @_;

	my $class = $self->get_object_class;

	# If this table dosn't have an associated class, just
	# return the data.	

	if( !defined $class ) 
	{
		return $data;
	}

	return $class->new_from_data( 
		$session,
		$data,
		$self );
}

######################################################################
=pod

=item $obj = $ds->create_object( $session, $data )

Create a new object in the given dataset. Return the new object.

Return undef if the object could not be created.

If $data describes sub-objects too then those will also be created.

=cut
######################################################################

sub create_object
{
	my( $self , $session , $data ) = @_;

	my $class = $self->get_object_class;

	return $class->create_from_data( $session, $data, $self );
}

######################################################################
=pod

=item $class = $ds->get_object_class;

Return the perl class to which objects in this dataset belong.

=cut
######################################################################

sub get_object_class
{
	my( $self, $session ) = @_;

	return $INFO->{$self->{id}}->{class};
}

######################################################################
=pod

=item $obj = $ds->get_object( $session, $id );

Return the object from this dataset with the given id, or undefined.

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

######################################################################
=pod

=item $xhtml = $ds->render_name( $session )

Return a piece of XHTML describing this dataset, in the language of
the current session.

=cut
######################################################################

sub render_name($$)
{
	my( $self, $session ) = @_;

        return $session->html_phrase( "dataset_name_".$self->id() );
}

######################################################################
=pod

=item $ds->map( $session, $fn, $info )

Maps the function $fn onto every record in this dataset. See 
Search for a full explanation.

=cut
######################################################################

sub map
{
	my( $self, $session, $fn, $info ) = @_;

	my $searchexp = EPrints::Search->new(
		allow_blank => 1,
		dataset => $self,
		session => $session );
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
sub get_archive { return $_[0]->get_repository; }

sub get_repository
{
	my( $self ) = @_;
	
	return $self->{repository};
}


######################################################################
=pod

=item $ds->reindex( $session )

Recommits all the items in this dataset. This could take a real long 
time on a large set of records.

Really should not be called reindex anymore as it doesn't.

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

=item @ids = EPrints::DataSet::get_dataset_ids( get_dataset_ids )

Return a list of all dataset ids.

=cut
######################################################################

sub get_dataset_ids
{
	return keys %{$INFO};
}


######################################################################
=pod

=item @ids = EPrints::DataSet::get_sql_dataset_ids

Return a list of all dataset ids of datasets which are directly mapped
into SQL (not counters or cache which work a bit differently).

=cut
######################################################################

sub get_sql_dataset_ids
{
	return( qw/ cachemap eprint user document saved_search subject history access request / );
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
		next if( $field->get_property( "multiple" ) );
		next unless( defined $field->get_sql_index );
		$n++;
	}
	return $n;
}
		
######################################################################
=pod

=item @ids = $dataset->get_item_ids( $session )

Return a list of the id's of all items in this set.

=cut
######################################################################

sub get_item_ids
{
	my( $self, $session ) = @_;

	if( defined $self->get_filters )
	{
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $self,
			session => $session );
		my $list = $searchexp->perform_search;
		return $list->get_ids;
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

	my $f = $INFO->{$self->{id}}->{dataset_id_field};

	return $f;
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

	my $f = $INFO->{$self->{id}}->{filters};

	return () unless defined $f;

	return @{$f};
}






######################################################################
1;
######################################################################
=pod

=back

=cut

