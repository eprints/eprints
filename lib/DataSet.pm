
package EPrints::DataSet;

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
	}
};

#
# EPrints::Dataset newStub( $datasetname )
#                           string
#
#  Creates a stub of a dataset on which functions such as 
#  getSQLTableName can be called, but which dosn't know anything
#  about it's fields. 

## WP1: BAD
sub newStub
{
	my( $class , $datasetname ) = @_;

	if( !defined $INFO->{$datasetname} )
	{
		&EPrints::Session::bomb;
		die( "Unknown dataset name: $datasetname" );
	}
	my $self = {};
	bless $self, $class;
	$self->{datasetname} = $datasetname;

	$self->{confid} = $INFO->{$datasetname}->{confid};
	$self->{confid} = $datasetname unless( defined $self->{confid} );

	return $self;
}


# EPrints::DataSet new( $site, $datasetname )
#                       |      string
#                       EPrints::Site
#
#  Create a new dataset object and get all the information
#  on types, system fields, and user fields from the various
#  sources - the packages and the site config module.

## WP1: BAD
sub new
{
	my( $class , $site , $datasetname ) = @_;
	
	my $self = EPrints::DataSet->newStub( $datasetname );

	$site->log( "New DataSet: ($datasetname)" );

	$self->{site} = $site;

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};

	if( defined $INFO->{$self->{confid}}->{class} )
	{
		my $class = $INFO->{$datasetname}->{class};
		my $fielddata;
		foreach $fielddata ( $class->get_system_field_info( $site ) )
		{
			my $field = EPrints::MetaField->new( $self , $fielddata );	
			push @{$self->{fields}}	, $field;
			push @{$self->{system_fields}} , $field;
			$self->{field_index}->{$field->getName()} = $field;
		}
	}
	my $sitefields = $site->getConf( "sitefields", $self->{confid} );
	if( $sitefields )
	{
		$site->log( "$datasetname has EXTRA FIELDS!" );
		foreach $fielddata ( @{$sitefields} )
		{
			my $field = EPrints::MetaField->new( $self , $fielddata );	
			push @{$self->{fields}}	, $field;
			$self->{field_index}->{$field->getName} = $field;
		}
	}

	$self->{types} = {};
	if( defined $site->getConf( "types", $self->{confid} ) )
	{
		my $type;
		foreach $type ( keys %{$site->getConf( "types", $self->{confid} )} )
		{
			$self->{types}->{$type} = [];
			foreach( @{$self->{system_fields}} )
			{
				push @{$self->{types}->{$type}}, $_;
			}
			foreach ( @{$site->getConf( "types", $self->{confid}, $type )} )
			{
				my $required = ( s/^REQUIRED:// );
				my $field = $self->{field_index}->{$_};
				if( !defined $field )
				{
					$site->log( "Unknown field: $_ in ".
						$self->{confid}."($type)" );
				}
				if( $required )
				{
					$field = $field->clone();
					$field->{required} = 1;
				}
				push @{$self->{types}->{$type}}, $field;
			}
		}
	}
	
	$self->{default_order} = $self->{site}->
			getConf( "default_order" , $self->{confid} );

	return $self;
}

# EPrints::MetaField getField( $fieldname )
#                              string
#  
#  returns a MetaField object describing the asked for field
#  in this dataset, or undef if there is no such field.

## WP1: BAD
sub getField
{
	my( $self, $fieldname ) = @_;

	my $value = $self->{field_index}->{$fieldname};
	if (!defined $value) {
		$self->{site}->log( 
			"dataset ".$self->{datasetname}." has no field: ".
			$fieldname );
		return undef;
	}
	return $self->{field_index}->{$fieldname};
}

# 
# string defaultOrder()
#
#  returns the id of the default order type.  

## WP1: BAD
sub defaultOrder
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

#
# string toString()
#
#  This returns a printable name of this dataset, for logging and errors.

## WP1: BAD
sub toString
{
	my( $self ) = @_;
	return $self->{datasetname};
}

# string getSQLTableName()
#
#  This returns the name of the main SQL Table containing this dataset.
#  the other SQL tables names are based on this name.
 
## WP1: BAD
sub getSQLTableName
{
	my( $self ) = @_;
	return $INFO->{$self->{datasetname}}->{sqlname};
}

# string getSQLIndexTableName()
#
#  Gives the name of the SQL table which contains the free text indexing
#  information.

## WP1: BAD
sub getSQLIndexTableName
{
	my( $self ) = @_;
	return $self->getSQLTableName()."__"."index";
}

# string getSQLSubTableName( $field )
#                            EPrints::MetaField
#
#  Returns the name of the SQL Table which contains the information
#  on the "multiple" field.

## WP1: BAD
sub getSQLSubTableName
{
	my( $self , $field ) = @_;
	return $self->getSQLTableName()."_".$field->getName();
}

# (Array of EPrints::MetaField) getFields()
#
#  returns all the fields of this DataSet, in order.

## WP1: BAD
sub getFields
{
	my( $self ) = @_;
	return @{ $self->{fields} };
}

# EPrints::MetaField getKeyField()
#
#  returns the keyfield for this dataset, the unqiue identifier field.
#  (always the first field).

## WP1: BAD
sub getKeyField
{
	my( $self ) = @_;
	return $self->{fields}->[0];
}

# EPrints::????? makeObject( $session, $item )
#                            |         hash ref
#                            EPrints::Session
#
#  This rather strange method turns the hash array in item into 
#  an object of the type belonging to this dataset.

## WP1: BAD
sub makeObject
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

# (array of strings) ref getTypes()
#
#  returns a reference to a list of all types of this dataset (eg. 
#  eprint record types or types of user)

## WP1: BAD
sub getTypes
{
	my( $self ) = @_;

	my @types = sort keys %{$self->{types}};
	return \@types;
}

# hash ref getTypeNames( $session )
#                        EPrints::Session
#
#  returns a reference to a hash table which maps the id's of types given
#  by getTypes to printable names in the language of the session. 

## WP1: BAD
sub getTypeNames
{
	my( $self, $session ) = @_;
		
	my %names = ();
	foreach( keys %{$self->{types}} ) 
	{
		$names{$_} = $self->getTypeName( $session, $_ );
	}
	return( \%names );
}

# string getTypeName( $session, $type )
#                     |         string
#                     EPrints::Session
# 
#  returns the printable name of the $type belonging to this
#  dataset, in the language of the $session.

## WP1: BAD
sub getTypeName
{
	my( $self, $session, $type ) = @_;

        return $session->phrase( "typename_".$self->confid."_".$type );
}


1;
