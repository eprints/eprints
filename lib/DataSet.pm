
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

sub newStub
{
	my( $class , $datasetname ) = @_;

	if( !defined $INFO->{$datasetname} )
	{
		$site->log( "Unknown dataset name: $datasetname" );
		exit;
	}
	my $self = {};
	bless $self, $class;
	$self->{datasetname} = $datasetname;

	return $self;
}



sub new
{
	my( $class , $site , $datasetname ) = @_;
	
	my $self = EPrints::DataSet->newStub( $datasetname );

	$site->log( "New DataSet: ($datasetname)" );

	$self->{site} = $site;

	my $confid = $INFO->{$datasetname}->{confid};
	$confid = $datasetname unless( defined $confid );

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};

	if( defined $INFO->{$confid}->{class} )
	{
		my $class = $INFO->{$datasetname}->{class};
		my $fielddata;
		print STDERR "START FD!\n";
		foreach $fielddata ( $class->get_system_field_info( $site ) )
		{
			print STDERR "NEXT FD!\n";
			my $field = EPrints::MetaField->new( $self , $fielddata );	
			push @{$self->{fields}}	, $field;
			push @{$self->{system_fields}} , $field;
			$self->{field_index}->{$field->get_name()} = $field;
		}
	}
	if( defined $site->getConf("sitefields")->{$confid} )
	{
		$site->log( "$datasetname has EXTRA FIELDS!" );
		print STDERR "START FD!\n";
		foreach $fielddata ( @{$site->getConf("sitefields")->{$confid}} )
		{
			print STDERR "NEXT FD!\n";
			my $field = EPrints::MetaField->new( $self , $fielddata );	
			push @{$self->{fields}}	, $field;
			$self->{field_index}->{$field->get_name()} = $field;
		}
	}

	$self->{types} = {};
	if( defined $site->getConf("types")->{$confid} )
	{
		my $type;
		foreach $type ( keys %{$site->getConf("types")->{$confid}} )
		{
			$self->{types}->{$type} = [];
			foreach( @{$self->{system_fields}} )
			{
				push @{$self->{types}->{$type}}, $_;
			}
			foreach ( @{$site->getConf("types")->{$confid}->{$type}} )
			{
				my $required = ( s/^REQUIRED:// );
				my $field = $self->{field_index}->{$_};
				if( !defined $field )
				{
					$site->log( "Unknown field: $_ in ".
							"$confid($type)" );
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
			getConf( "default_order" )->{$confid};

	$self->{confid} = $confid;

	return $self;
}

sub get_field
{
	my( $self, $fieldname ) = @_;

	my $value = $self->{field_index}->{$fieldname};
	if (!defined $value) {
		$self->{site}->log( 
			"dataset ".$self->{datasetname}." no field ".
			$fieldname );
	}
	return $self->{field_index}->{$fieldname};
}

sub default_order
{
	my( $self ) = @_;

	return $self->{default_order};
}

sub confid
{
	my( $self ) = @_;
	return $self->{confid};
}

sub toString
{
	my( $self ) = @_;
	return $self->{datasetname};
}

sub getSQLTableName
{
	my( $self ) = @_;
	return $INFO->{$self->{datasetname}}->{sqlname};
}

sub getFields
{
	my( $self ) = @_;
	return @{ $self->{fields} };
}

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


1;
