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

package EPrints::Site;

use EPrints::Site::General;
use EPrints::DataSet;

use Filesys::DiskSpace;

my %ID2SITE = ();


## WP1: BAD
sub new_site_by_url
{
	my( $class, $url ) = @_;
	print STDERR "($url)\n";
	$hostpath = $url;
	$hostpath =~ s#^[a-z]+://##;
	print STDERR "($hostpath)\n";
	return new_site_by_host_and_path( $class , $hostpath );
}

## WP1: BAD
sub new_site_by_host_and_path
{
	my( $class, $hostpath ) = @_;

	print STDERR "($hostpath)\n";

	foreach( keys %EPrints::Site::General::sites )
	{
		if( substr( $hostpath, 0, length($_) ) eq $_ )
		{
			return new_site_by_id( $class, $EPrints::Site::General::sites{$_} );
		}
	}
	return undef;
}


## WP1: BAD
sub new_site_by_id
{
	my( $class, $id ) = @_;

	print STDERR "Loading: $id\n";

	if( $id !~ m/[a-z_]+/ )
	{
		die "Site ID illegal: $id\n";
	}
	
	if( defined $ID2SITE{$id} )
	{
		return $ID2SITE{$id};
	}
	my $self = {};
	bless $self, $class;

	unless( require "EPrints/Site/$id.pm" )
	{
print STDERR "FAILED TO LOAD: $id\n";
		return undef;
	}
	$ID2SITE{$id} = $self;

	$self->{class} = "EPrints::Site::$id";
	my $function= $self->{class}."::get_conf";
	$self->{config} = &{$function}();

	$self->{id} = $id;
	$self->{datasets} = {};
	foreach( 
		"user", 
		"document", 
		"subscription", 
		"subject", 
		"eprint", 
		"deletion" )
        {
		$self->{datasets}->{$_} = EPrints::DataSet->new( $self, $_ );
	}

$self->log("done: $id");
	return $self;
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
	$self->log( "Calling $cmd with (".join(",",@params).")" );
	return &{$self->{class}."::".$cmd}( @params );
}

## WP1: GOOD
sub get_data_set
{
	my( $self , $setname ) = @_;

	if( !defined $self->{datasets}->{$setname} ) 
	{
		$self->{datasets}->{$setname} = 
		EPrints::DataSet->new( $self, $setname );
		$self->log( "Had to create DS:$setname, should have been".
			    " in the cache." );
	}
	
	return $self->{datasets}->{$setname};
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

1;
