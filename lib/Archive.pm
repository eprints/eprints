######################################################################
#
# cjg: NO INTERNATIONAL GUBBINS YET
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

#cjg NOT data_set !!!
#cjg why not make loads of accessors instead of get_dataset?
package EPrints::Archive;

use EPrints::Config;
use EPrints::DataSet;
use EPrints::Language;

use Filesys::DiskSpace;

my %ARCHIVE_CACHE = ();

## WP1: BAD
sub new_archive_by_host_port_path
{
	my( $class, $hostpath ) = @_;
	my $archive;
	print STDERR "a($hostpath)\n";

	my $id = EPrints::Config::get_id_from_host_port_path( $hostpath );

print STDERR "id: $id\n";
	return if( !defined $id );

	return new_archive_by_id( $class, $id );
}

## WP1: BAD
sub new_archive_by_id
{
	my( $class, $id, $noxml ) = @_;

	print STDERR "Loading: $id\n";

	if( $id !~ m/[a-z_]+/ )
	{
		die "Archive ID illegal: $id\n";
	}
	
	if( defined $ARCHIVE_CACHE{$id} )
	{
		return $ARCHIVE_CACHE{$id};
	}
	
	print STDERR "******** REALLY LOADING $id *********\n";

	my $self = {};
	bless $self, $class;

	$self->{config} = EPrints::Config::load_archive_config_module( $id );

	$self->{class} = "EPrints::Config::$id";

	$ARCHIVE_CACHE{$id} = $self;

	$self->{id} = $id;

	unless( $noxml )
	{
		$self->_load_datasets();
		$self->_load_languages();
		$self->_load_templates();
		$self->_load_citation_specs();
	}

	$self->log("done: new($id)");
	return $self;
}

sub _load_languages
{
	my( $self ) = @_;
	
	my @langs = @{$self->get_conf( "languages" )};
	my $defaultid = splice( @langs, 0, 1 );
	$self->{langs}->{$defaultid} = 
		EPrints::Language->new( $defaultid , $self );

	my $langid;
	foreach $langid ( @{$self->get_conf( "languages" )} )
	{
		$self->{langs}->{$langid} =
			 EPrints::Language->new( 
				$langid , 
				$self , 
				$self->{langs}->{$defaultid} );
	}
}

sub get_language
{
	my( $self , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = ($self->get_conf( "languages" ))[0];
	}
	return $self->{langs}->{$langid};
}

sub _load_citation_specs
{
	my( $self ) = @_;

	my $langid;
	foreach $langid ( @{$self->get_conf( "languages" )} )
	{
		my $file = $self->get_conf( "config_path" ).
				"/citations-$langid.xml";
		my $doc = $self->parse_xml( $file , ParseParamEnt=>0 );

		my $citations = ($doc->getElementsByTagName( "citations" ))[0];
		if( !defined $citations )
		{
			die "Missing <citations> tag in $file";
		}

		my $citation;
		foreach $citation ($doc->getElementsByTagName( "citation" ))
		{
			my( $type ) = $citation->getAttribute( "type" );
			
			my( $frag ) = $doc->createDocumentFragment();
			foreach( $citation->getChildNodes )
			{
				$citation->removeChild( $_ );
				$frag->appendChild( $_ );
			}
			$self->{cstyles}->{$langid}->{$type} = $frag;
		}
		$doc->dispose();

	}
}

sub get_citation_spec
{
	my( $self, $langid, $type ) = @_;

	return $self->{cstyles}->{$langid}->{$type};
}

sub _load_templates
{
	my( $self ) = @_;

	my $langid;
	foreach $langid ( @{$self->get_conf( "languages" )} )
	{
		my $file = $self->get_conf( "config_path" ).
				"/template-$langid.xml";
		my $doc = $self->parse_xml( $file );

		my $html = ($doc->getElementsByTagName( "html" ))[0];
		if( !defined $html )
		{
			die "Missing <html> tag in $file";
		}
		$doc->removeChild( $html );
		$doc->dispose();
		$self->{html_templates}->{$langid} = $html;
	}
}

sub get_template
{
	my( $self, $langid ) = @_;

	return $self->{html_templates}->{$langid};
}

sub _load_datasets
{
	my( $self ) = @_;

	my $file = $self->get_conf( "config_path" ).
			"/metadata-types.xml";
	my $doc = $self->parse_xml( $file );

	my $types_tag = ($doc->getElementsByTagName( "metadatatypes" ))[0];
	if( !defined $types_tag )
	{
		die "Missing <metadatatypes> tag in $file";
	}

	my $dsconf = {};

	my $ds_tag;	
	foreach $ds_tag ( $types_tag->getElementsByTagName( "dataset" ) )
	{
		my $ds_id = $ds_tag->getAttribute( "name" );
		my $type_tag;
		$dsconf->{$ds_id}->{_order} = [];
		foreach $type_tag ( $ds_tag->getElementsByTagName( "type" ) )
		{
			my $type_id = $type_tag->getAttribute( "name" );
			my $field_tag;
			$dsconf->{$ds_id}->{$type_id} = [];
			push @{$dsconf->{$ds_id}->{_order}}, $type_id;
			foreach $field_tag ( $type_tag->getElementsByTagName( "field" ) )
			{
				my $finfo = {};
				$finfo->{id} = $field_tag->getAttribute( "name" );
				if( $field_tag->getAttribute( "required" ) eq "yes" )
				{
					$finfo->{required} = 1;
				}
				push @{$dsconf->{$ds_id}->{$type_id}},$finfo;
			}
		}
	}
	
#print EPrints::Session::render_struct( $dsconf );	
	
	$self->{datasets} = {};
	my $ds_id;
	foreach $ds_id ( EPrints::DataSet::get_dataset_ids() )
	{
		$self->{datasets}->{$ds_id} = 
			EPrints::DataSet->new( $self, $ds_id, $dsconf );
	}

	$doc->dispose();
}

sub get_dataset
{
	my( $self , $setname ) = @_;

	return $self->{datasets}->{$setname};
}


## WP1: GOOD
sub get_conf
{
	my( $self, $key, @subkeys ) = @_;

	my $val = $self->{config}->{$key};
	foreach( @subkeys )
	{
		$val = $val->{$_};
	} 

	return $val;
}

## WP1: BAD
sub log
{
	my( $self , @params) = @_;
	&{$self->{class}."::log"}( $self, @params );
}

## WP1: BAD
sub call
{
	my( $self, $cmd, @params ) = @_;
#$self->log( "Calling $cmd with (".join(",",@params).")" );
	return &{$self->{class}."::".$cmd}( @params );
}

sub get_store_dirs
{
	my( $self ) = @_;

	my $docroot = $self->get_conf( "local_document_root" );

	opendir( DOCSTORE, $docroot ) || return undef;

	my( @dirs, $dir );
	while( $dir = readdir( DOCSTORE ) )
	{
		next if( $dir =~ m/^\./ );
		next unless( -d $docroot."/".$dir );
		push @dirs, $dir;	
	}

	closedir( DOCSTORE );

	return @dirs;
}

sub get_store_dir_size
{
	my( $self , $dir ) = @_;

	my $filepath = $self->get_conf( "local_document_root" )."/".$dir;

	if( ! -d $filepath )
	{
		return undef;
	}

	return( ( df $filepath)[3] );
} 



sub parse_xml
{
	my( $self, $file, %config ) = @_;

	unless( defined $config{Base} )
	{
		$config{Base} = $self->get_conf( "system_files_path" )."/";
	}
	
	my $doc = EPrints::Config::parse_xml( $file, %config );
	#$self->log( "Loaded&Parsed: $file" );
	return $doc;
}

sub get_id 
{
	my( $self ) = @_;

	return $self->{id};
}

sub exec
{
	my( $self, $cmd_id, %map ) = @_;

	my $command = $self->invocation( $cmd_id, %map );

	my $rc = 0xffff & system $command;

	return $rc;
}	

sub invocation
{
	my( $self, $cmd_id, %map ) = @_;

	my $execs = $self->get_conf( "executables" );
	foreach( keys %{$execs} )
	{
		$map{$_} = $execs->{$_};
	}

	my $command = $self->get_conf( "invocation" )->{ $cmd_id };

	$command =~ s/\$\(([a-z]*)\)/$map{$1}/gei;

	return $command;
}



1;
