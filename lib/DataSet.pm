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

An archive has one of each type of dataset:

cachemap, counter, user, archive, buffer, inbox, document, subject,
subscription, deletion, eprint, language, arclanguage, security.

A normal dataset (eg. "user") has a package associated with it 
(eg. EPrints::User) which must be a subclass of EPrints::DataObj 
and a number of SQL tables which are prefixed with the dataset name.
Most datasets also have a set of associated EPrints::MetaField's which
may be optional or compulsary depending on the type eg. books have editors
but posters don't but they are both EPrints.

Types and what fields are in them is configured in metadata-types.xml
for a given archive.

Datasets have some default fields plus additional ones configured
in ArchiveMetadataFieldsConfig.pm.

But there are some exceptions:

=over 4

=item cachemap, counter

Don't have a package, types or metadata fields associated.

=item archive, buffer, inbox, deletion

All have the same types, package and metadata fields, but different
SQL tables.

=item subject

Does not have types.

=item eprint

Does not have SQL tables associated with it. In fact it's a generic
dataset for asking for properties of inbox, archive, buffer & deletion.

=item language, arclanguage

These don't have fields or SQL tables, they are used in metadata
field configuration as their types are part of the system - all known
languages & languages supported by this archive, respectively.

=item security

Does not have fields or SQL tables but does have types - these are the 
security options for a documenmt. A document already has a type - pdf/ps/html 
so the set of security settings belong to this dataset instead. A type with an 
id of an empty string is handled specially as it means publically available.

=back

EPrints::DataSet objects are cached by the related EPrints::Archive
object and usually obtained by calling.

$ds = $archive->get_dataset( "inbox" );

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
#  $self->{archive}
#     A reference to the EPrints::Archive to which this dataset belongs.
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
#  $self->{types}
#     Magic for arclanguage and language, otherwise comes from 
#     metadata-types.xml. Contains a hash keyed by type. Each value is a
#     list of EPrints::MetaFields that may be edited by a user in the
#     order they should be presented with 'required' set as needed.
#
#  $self->{staff_types}
#     As for {types} but for fields which may be edited by an editor or
#     administrator.
#
#  $self->{type_order}
#     A list of type-ids in the order they should be displayed.
#
#  $self->{default_order}
#     The default option for "order by?" in a search form.
#
######################################################################

package EPrints::DataSet;

use EPrints::Document;

use Carp;

my $INFO = {
	cachemap => {
		sqlname => "cachemap"
	},
	counter => {
		sqlname => "counters"
	},
	user => {
		is_sql_dataset => 1,
		sqlname => "users",
		class => "EPrints::User"
	},
	archive => {
		is_sql_dataset => 1,
		sqlname => "archive",
		class => "EPrints::EPrint",
		confid => "eprint"
	},
	buffer => {
		is_sql_dataset => 1,
		sqlname => "buffer",
		class => "EPrints::EPrint",
		confid => "eprint"
	},
	inbox => {
		is_sql_dataset => 1,
		sqlname => "inbox",
		class => "EPrints::EPrint",
		confid => "eprint"
	},
	document => {
		is_sql_dataset => 1,
		sqlname => "document",
		class => "EPrints::Document"
	},
	subject => {
		is_sql_dataset => 1,
		sqlname => "subject",
		class => "EPrints::Subject"
	},
	subscription => {
		is_sql_dataset => 1,
		sqlname => "subscription",
		class => "EPrints::Subscription"
	},
	deletion => {
		is_sql_dataset => 1,
		sqlname => "deletion",
		class => "EPrints::EPrint",
		confid => "eprint"
	},
	eprint => {
		class => "EPrints::EPrint"
	},
	# language and security are here so they can be used in
	# "datatype" fields.
	language => {},
	arclanguage => {},
	security => {}
};


######################################################################
=pod

=item $ds = EPrints::DataSet->new_stub( $id )

Creates a dataset object without any types or fields. Useful to
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
		# no archive info, so can't log.
		confess( "Unknown dataset name: $id" );
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

=item $ds = EPrints::DataSet->new( $archive, $id, $typesconf )

Return the dataset specified by $id. It needs the information
in $typesconf and you probably should not call this directly
but get access to a dataset via the archive object as described
above.

Note that dataset know $archive and vice versa - which means they
will not get garbage collected.

=cut
######################################################################

sub new
{
	my( $class , $archive , $id , $typesconf ) = @_;
	
	my $self = EPrints::DataSet->new_stub( $id );

	$self->{archive} = $archive;

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};
	$self->{types} = {};
	# staff types is the same list, but includes fields
	# which are only shown during staff mode editing. 
	# eg. The "Editor" filter.
	$self->{staff_types} = {};
	$self->{type_order} = [];

	if( $id eq "language" )
	{	
		foreach( EPrints::Config::get_languages() )
		{
			$self->{types}->{$_} = [];
			push @{$self->{type_order}},$_;
		}
		return $self;
	}
	if( $id eq "arclanguage" )
	{	
		foreach( @{$archive->get_conf( "languages" )} )
		{
			$self->{types}->{$_} = [];
			$self->{staff_types}->{$_} = [];
			push @{$self->{type_order}},$_;
		}
		return $self;
	}


	if( defined $INFO->{$self->{confid}}->{class} )
	{
		my $class = $INFO->{$id}->{class};
		my $fielddata;
		foreach $fielddata ( $class->get_system_field_info() )
		{
			my $field = EPrints::MetaField->new( dataset=>$self , %{$fielddata} );	
			push @{$self->{fields}}	, $field;
			push @{$self->{system_fields}} , $field;
			$self->{field_index}->{$field->get_name()} = $field;
		}
	}
	my $archivefields = $archive->get_conf( "archivefields", $self->{confid} );
	if( $archivefields )
	{
		foreach $fielddata ( @{$archivefields} )
		{
			my $field = EPrints::MetaField->new( dataset=>$self , %{$fielddata} );	
			push @{$self->{fields}}	, $field;
			$self->{field_index}->{$field->get_name()} = $field;
		}
	}

	if( defined $typesconf->{$self->{confid}} )
	{
		my $typeid;
		$self->{type_order} = $typesconf->{$self->{confid}}->{_order};
		foreach $typeid ( keys %{$typesconf->{$self->{confid}}} )
		{
			next if( $typeid eq "_order" );

			$self->{types}->{$typeid} = [];
			$self->{staff_types}->{$typeid} = [];

			# System fields are now not part of the "type" fields
			# unless expicitly set.

			# foreach( @{$self->{system_fields}} )
			# {
			#	 push @{$self->{types}->{$typeid}}, $_;
			# }
			
			my $f;
			foreach $f ( @{$typesconf->{$self->{confid}}->{$typeid}} )
			{
				if( !defined $self->{field_index}->{$f->{id}} )
				{
					EPrints::Config::abort( "Could not find field \"".$f->{id}."\" in dataset \"".$id."\", although it is\nrequired for type: \"".$typeid."\"" );
				}
				my $field = $self->{field_index}->{$f->{id}}->clone();
				if( !defined $field )
				{
					$archive->log( "Unknown field: $_ in ".
						$self->{confid}."($typeid)" );
				}

				# set the required flag, but don't override a system level
				# required.
				unless( $field->get_property( "required" ) )
				{
					$field->set_property( "required" , $f->{required} );
				}
				unless( $f->{staffonly} ) 
				{
					push @{$self->{types}->{$typeid}}, $field;
				}
				push @{$self->{staff_types}->{$typeid}}, $field;
			}
		}
	}
	$self->{default_order} = $self->{archive}->
			get_conf( "default_order" , $self->{confid} );

	return $self;
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

	my $value = $self->{field_index}->{$fieldname};
	if (!defined $value) {
		$self->{archive}->log( 
			"dataset ".$self->{id}." has no field: ".
			$fieldname );
		return undef;
	}
	return $self->{field_index}->{$fieldname};
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

	return $session->get_db()->count_table( $self->get_sql_table_name() );
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
	return $INFO->{$self->{id}}->{sqlname};
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

=item $fields = $ds->get_fields( [$split_id] )

Returns a list of the EPrints::Metafields belonging to this dataset.

If $split_id is set then fields with the has_id property are split into
id_part and main_part. This is useful for database functions.

=cut
######################################################################

sub get_fields
{
	my( $self, $split_id ) = @_;

	my @fields = ();
	if( $split_id )
	{
		# Split "id" fields into component parts
		my $field;
		foreach $field ( @{ $self->{fields} } )
		{
			if( $field->get_property( "hasid" ) )
			{
				push @fields,$field->get_id_field();
				push @fields,$field->get_main_field();
			}
			else
			{
				push @fields,$field;
			}
		}
	}
	else
	{
		@fields = @{ $self->{fields} };
	}
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

	my $class = $INFO->{$self->{id}}->{class};

	# If this table dosn't have an associated class, just
	# return the data.	

	if( !defined $class ) 
	{
		return $data;
	}

	## EPrints have a slightly different
	## constructor.

	return $class->new_from_data( 
		$session,
		$data,
		$self );
}


######################################################################
=pod

=item $types = $ds->get_types

Return a reference to a list of all types of this dataset (eg. 
eprint record types or types of user)

=cut
######################################################################

sub get_types
{
	my( $self ) = @_;

	return $self->{type_order};
}


######################################################################
=pod

=item $foo = $ds->get_type_names( $session )

Returns a reference to a hash table which maps the id's of types given
by get_types to printable names in the language of the session (utf-8
encoded). 

=cut
######################################################################

sub get_type_names
{
	my( $self, $session ) = @_;
		
	my %names = ();
	foreach( keys %{$self->{types}} ) 
	{
		$names{$_} = $self->get_type_name( $session, $_ );
	}
	return( \%names );
}


######################################################################
=pod

=item $name = $ds->get_type_name( $session, $type )

Return a utf-8 string containing a human-readable name for the
specified type.

=cut
######################################################################

sub get_type_name
{
	my( $self, $session, $type ) = @_;

	if( $self->{confid} eq "language"  || $self->{confid} eq "arclanguage" )
	{
		if( $type eq "?" )
		{
			return $session->phrase( "lib/dataset:no_language" );
		}
		return EPrints::Config::lang_title( $type );
	}

        return $session->phrase( $self->confid()."_typename_".$type );
}


######################################################################
=pod

=item $xhtml = $ds->render_type_name( $session, $type )

Return a piece of XHTML describing the name of the given type in the
language of the session.

=cut
######################################################################

sub render_type_name
{
	my( $self, $session, $type ) = @_;

	if( $self->{confid} eq "language"  || $self->{confid} eq "arclanguage" )
	{
		return $session->make_text( $self->get_type_name( $session, $type ) );
	}
        return $session->html_phrase( $self->confid()."_typename_".$type );
}


######################################################################
=pod

=item @fields = $ds->get_type_fields( $type, [$staff] )

Return a list of EPrints::MetaField's which may be edited by a user
on a record of the given type. Or by a editor/admin if $staff is
true.

=cut
######################################################################

sub get_type_fields
{
	my( $self, $type, $staff ) = @_;

	return @{$self->{($staff?"staff_types":"types")}->{$type}};
}


######################################################################
=pod

=item @fields = $ds->get_required_type_fields( $type )

Return an array of the EPrints::MetaField's which are required for
the given type.

=cut
######################################################################

sub get_required_type_fields
{
	my( $self, $type ) = @_;
	
	my %req = ();
	my $field;

	# Looks iffy, shouldn't get_fields be get_system_fields?
	# needs to handle staff only required fiedls. cjg
	foreach $field ( $self->get_fields(), $self->get_type_fields( $type ) )
	{
		if( $field->get_property( "required" ) )
		{	
			$req{$field->get_name()}=$field;
		}
	}

	return values %req;
}



######################################################################
=pod

=item $boolean = $ds->is_valid_type( $type )

Returns true if the specified $type is indeed a type in this dataset.

=cut
######################################################################

sub is_valid_type
{
	my( $self, $type ) = @_;
	return( defined $self->{types}->{$type} );
}


######################################################################
=pod

=item $ds->map( $session, $fn, $info )

Maps the function $fn onto every record in this dataset. See 
SearchExpression for a full explanation.

=cut
######################################################################

sub map
{
	my( $self, $session, $fn, $info ) = @_;
	
	my $searchexp = EPrints::SearchExpression->new(
		allow_blank => 1,
		use_oneshot_cache => 1,
		dataset => $self,
		session => $session );
	$searchexp->perform_search();
	$searchexp->map( $fn, $info );
	$searchexp->dispose();
}


######################################################################
=pod

=item $archive = $ds->get_archive

Returns the EPrints::Archive to which this dataset belongs.

=cut
######################################################################

sub get_archive
{
	my( $self ) = @_;
	
	return $self->{archive};
}


######################################################################
=pod

=item $ds->reindex( $session )

Reindex all the items in this dataset. This could take a real long 
time on a large set of records.

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
	my @list = ();
	foreach( keys %{$INFO} )
	{
		push @list, $_ if $INFO->{$_}->{is_sql_dataset};
	}
	return @list;
}

######################################################################
=pod

=item $n = $ds->count_indexes

Return the number of indexes required for the main SQL table of this
dataset. Used to check it's not over 32 (the current maximum allowed
by MySQL)

=cut
######################################################################

sub count_indexes
{
	my( $self ) = @_;

	my $n = 0;
	foreach my $field ( $self->get_fields( 1 ) )
	{
		next if( $field->get_property( "multiple" ) );
		next if( $field->get_property( "multilang" ) );
		next unless( defined $field->get_sql_index );
		$n++;
	}
	return $n;
}
		


1;

######################################################################
=pod

=back

=cut

