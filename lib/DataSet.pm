
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
		class => "EPrints::EPrint"
	},
	buffer => {
		sqlname => "Xbuffer",
		class => "EPrints::EPrint"
	},
	inbox => {
		sqlname => "Xinbox",
		class => "EPrints::EPrint"
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


sub new
{
	my( $class , $site , $datasetname ) = @_;

	$site->log( "New DataSet: ($datasetname)" );

	if( !defined $INFO->{$datasetname} )
	{
		$site->log( "Unknown dataset name: $datasetname" );
		exit;
	}
	
	my $self = {};
	bless $self, $class;
	$self->{site} = $site;
	$self->{datasetname} = $datasetname;

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};

	if( defined $INFO->{$datasetname}->{class} )
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
		if( defined $site->conf("sitefields")->{$datasetname} )
		{
			$site->log( "$datasetname has EXTRA FIELDS!" );
			print STDERR "START FD!\n";
			foreach $fielddata ( @{$site->conf("sitefields")->{$datasetname}} )
			{
				print STDERR "NEXT FD!\n";
				my $field = EPrints::MetaField->new( $self , $fielddata );	
				push @{$self->{fields}}	, $field;
				$self->{field_index}->{$field->get_name()} = $field;
			}
		}
	}

	$self->{types} = {};
	if( defined $site->conf("types")->{$datasetname} )
	{
		my $type;
		foreach $type ( keys %{$site->conf("types")->{$datasetname}} )
		{
			$self->{types}->{$type} = [];
			foreach( @{$self->{system_fields}} )
			{
				push @{$self->{types}->{$type}}, $_;
			}
			foreach ( @{$site->conf("types")->{$datasetname}->{$type}} )
			{
				my $required = ( s/^REQUIRED:// );
				my $field = $self->{field_index}->{$_};
				if( !defined $field )
				{
					$site->log( "Unknown field: $_ in ".
							"$datasetname($type)" );
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

	return $self;
}

