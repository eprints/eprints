######################################################################
#
# COMMENTME
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::DataSet;

use EPrints::Document;

#cjg Should deletion be just another "eprints" dataset.



my $INFO = {
	tempmap => {
		sqlname => "Xtempmap"
	},
	counter => {
		sqlname => "Xcounters"
	},
	user => {
		sqlname => "Xusers",
		class => "EPrints::User"
	},
	archive => {
		sqlname => "Xarchive",
		class => "EPrints::EPrint",
		confid => "eprint"
	},
	buffer => {
		sqlname => "Xbuffer",
		class => "EPrints::EPrint",
		confid => "eprint"
	},
	inbox => {
		sqlname => "Xinbox",
		class => "EPrints::EPrint",
		confid => "eprint"
	},
	document => {
		sqlname => "Xdocument",
		class => "EPrints::Document"
	},
	subject => {
		sqlname => "Xsubject",
		class => "EPrints::Subject"
	},
	subscription => {
		sqlname => "Xsubscription",
		class => "EPrints::Subscription"
	},
	deletion => {
		sqlname => "Xdeletion",
		class => "EPrints::Deletion"
	},
	eprint => {
		class => "EPrints::EPrint"
	},
	# language and security are here so they can be used in
	# "datatype" fields.
	language => {},
	security => {}
};

#
# EPrints::Dataset new_stub( $datasetname )
#                           string
#
#  Creates a stub of a dataset on which functions such as 
#  get_sql_table_name can be called, but which dosn't know anything
#  about it's fields. 

## WP1: BAD
sub new_stub
{
	my( $class , $datasetname ) = @_;

	if( !defined $INFO->{$datasetname} )
	{
		# no archive info, so can't log.
		print STDERR "Unknown dataset name: $datasetname\n";	
		&EPrints::Session::bomb;
		die( "Unknown dataset name: $datasetname" );
	}
	my $self = {};
	bless $self, $class;
	$self->{datasetname} = $datasetname;

	$self->{id} = $INFO->{$datasetname}->{confid};
	$self->{confid} = $INFO->{$datasetname}->{confid};
	$self->{confid} = $datasetname unless( defined $self->{confid} );

	return $self;
}


# EPrints::DataSet new( $archive, $datasetname )
#                       |      string
#                       EPrints::Site
#
#  Create a new dataset object and get all the information
#  on types, system fields, and user fields from the various
#  sources - the packages and the archive config module.

## WP1: BAD
# note that dataset know $archive and vice versa - bad for GCollection.
sub new
{
	my( $class , $archive , $datasetname , $typesconf ) = @_;
	
	my $self = EPrints::DataSet->new_stub( $datasetname );

	$self->{archive} = $archive;

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};
	$self->{types} = {};
	$self->{typeorder} = [];

	if( $datasetname eq "language" )
	{	
		foreach( EPrints::Config::get_languages() )
		{
			$self->{types}->{$_} = [];
			push @{$self->{typeorder}},$_;
		}
		return $self;
	}

	if( defined $INFO->{$self->{confid}}->{class} )
	{
		my $class = $INFO->{$datasetname}->{class};
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
		$self->{typeorder} = $typesconf->{$self->{confid}}->{_order};
		foreach $typeid ( keys %{$typesconf->{$self->{confid}}} )
		{
			next if( $typeid eq "_order" );

			$self->{types}->{$typeid} = [];

			# System fields are now not part of the "type" fields
			# unless expicitly set.

			# foreach( @{$self->{system_fields}} )
			# {
			#	 push @{$self->{types}->{$typeid}}, $_;
			# }
			
			my $f;
			foreach $f ( @{$typesconf->{$self->{confid}}->{$typeid}} )
			{
				my $field = $self->{field_index}->{$f->{id}}->clone();
				if( !defined $field )
				{
					$archive->log( "Unknown field: $_ in ".
						$self->{confid}."($typeid)" );
				}
				$field->set_property( "required" , $f->{required} );
				push @{$self->{types}->{$typeid}}, $field;
			}
		}
	}
	$self->{default_order} = $self->{archive}->
			get_conf( "default_order" , $self->{confid} );

	return $self;
}

# EPrints::MetaField get_field( $fieldname )
#                              string
#  
#  returns a MetaField object describing the asked for field
#  in this dataset, or undef if there is no such field.

## WP1: BAD
sub get_field
{
	my( $self, $fieldname ) = @_;

	my $value = $self->{field_index}->{$fieldname};
	if (!defined $value) {
		$self->{archive}->log( 
			"dataset ".$self->{datasetname}." has no field: ".
			$fieldname );
		return undef;
	}
	return $self->{field_index}->{$fieldname};
}

# 
# string default_order()
#
#  returns the id of the default order type.  

## WP1: BAD
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

## WP1: BAD
sub confid
{
	my( $self ) = @_;
	return $self->{confid};
}
sub id
{
	my( $self ) = @_;
	return $self->{id};
}

# string get_sql_table_name()
#
#  This returns the name of the main SQL Table containing this dataset.
#  the other SQL tables names are based on this name.
 
## WP1: BAD
sub get_sql_table_name
{
	my( $self ) = @_;
	return $INFO->{$self->{datasetname}}->{sqlname};
}

# string get_sql_index_table_name()
#
#  Gives the name of the SQL table which contains the free text indexing
#  information.

## WP1: BAD
sub get_sql_index_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."index";
}

# string get_sql_sub_table_name( $field )
#                            EPrints::MetaField
#
#  Returns the name of the SQL Table which contains the information
#  on the "multiple" field.

## WP1: BAD
sub get_sql_sub_table_name
{
	my( $self , $field ) = @_;
	return $self->get_sql_table_name()."_".$field->get_name();
}

# (Array of EPrints::MetaField) get_fields()
#
#  returns all the fields of this DataSet, in order.

## WP1: BAD
sub get_fields
{
	my( $self ) = @_;
	return @{ $self->{fields} };
}

# EPrints::MetaField get_key_field()
#
#  returns the keyfield for this dataset, the unqiue identifier field.
#  (always the first field).

sub get_key_field
{
	my( $self ) = @_;
	return $self->{fields}->[0];
}

# EPrints::????? make_object( $session, $item )
#                            |         hash ref
#                            EPrints::Session
#
#  This rather strange method turns the hash array in item into 
#  an object of the type belonging to this dataset.

## WP1: BAD
sub make_object
{
	my( $self , $session , $item ) = @_;

	my $class = $INFO->{$self->{datasetname}}->{class};

	# If this table dosn't have an associated class, just
	# return the item.	

	if( !defined $class ) 
	{
		return $item;
	}

	## EPrints have a slightly different
	## constructor.

	if ( $class eq "EPrints::EPrint" ) 
	{
		return EPrints::EPrint->new( 
			$session,
			$self,
			undef,
			$item );
	}

	return $class->new( 
		$session,
		undef,
		$item );

}

# (array of strings) ref get_types()
#
#  returns a reference to a list of all types of this dataset (eg. 
#  eprint record types or types of user)

## WP1: BAD
sub get_types
{
	my( $self ) = @_;

	return $self->{typeorder};
}

# hash ref get_type_names( $session )
#                        EPrints::Session
#
#  returns a reference to a hash table which maps the id's of types given
#  by get_types to printable names in the language of the session. 

## WP1: BAD
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

sub get_type_name
{
	my( $self, $session, $type ) = @_;

	if( $self->{confid} eq "language" )
	{
		if( $type eq "?" )
		{
			return $session->phrase( "lib/dataset:no_language" );
		}
		return EPrints::Config::lang_title( $type );
	}

        return $session->phrase( $self->confid()."_typename_".$type );
}

sub render_type_name
{
	my( $self, $session, $type ) = @_;

	if( $self->{confid} eq "language" )
	{
		return $session->make_text( $self->get_type_name( $session, $type ) );
	}
        return $session->html_phrase( $self->confid()."_typename_".$type );
}

sub get_type_fields
{
	my( $self, $type ) = @_;

	return @{$self->{types}->{$type}};
}

# fields which are required for the given type, or just
# generally required.
sub get_required_type_fields
{
	my( $self, $type ) = @_;
	
	my %req = ();
	my $field;

	foreach $field ( $self->get_fields(), $self->get_type_fields( $type ) )
	{
		if( $field->get_property( "required" ) )
		{	
			$req{$field->get_name()}=$field;
		}
	}

	return values %req;
}


sub is_valid_type
{
	my( $self, $type ) = @_;
	return( defined $self->{types}->{$type} );
}

# STATIC
sub get_dataset_ids
{
	return keys %{$INFO};
}

1;
