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

my %ID2SITE = ();


sub new_site_by_url
{
	my( $class, $url ) = @_;
	print STDERR "($url)\n";
	$hostpath = $url;
	$hostpath =~ s#^[a-z]+://##;
	print STDERR "($hostpath)\n";
	return new_site_by_host_and_path( $class , $hostpath );
}

sub new_site_by_host_and_path
{
	my( $class, $hostpath ) = @_;

	print STDERR "($hostpath)\n";

	foreach( keys %EPrints::Site::General::sites )
	{
print STDERR "++".substr( $hostpath, 0, length($_) )."++$_++\n";
		if( substr( $hostpath, 0, length($_) ) eq $_ )
		{
			return new_site_by_id( $class, $EPrints::Site::General::sites{$_} );
		}
	}
	return undef;
}


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
my $f= $self->{class}."::get_conf";
print STDERR "($f)\n";
print STDERR "($f)\n";
	$self->{config} = &{$f}();

	$self->{id} = $id;
$self->log("ID: $id");
	$self->{datasets} = {};
	foreach( "user", "document", "subscription", "subject", "eprint", "deletion" )
        {
$self->log("DS: $_");
		$self->{datasets} = EPrints::DataSet->new( $self, $_ );
	}

$self->log("done: $id");
	return $self;
}

sub getConf
{
	my( $self, $key, @subkeys ) = @_;
	my $val = $self->{config}->{$key};
	foreach( @subkeys )
	{
		$val = $val->{$_};
	} 
	return $val;
}

sub log
{
	my( $self , @params) = @_;
	&{$self->{class}."::log"}( $self, @params );
}

sub call
{
	my( $self, $cmd, @params ) = @_;

	return &{$self->{class}."::".$cmd}( @params );
}

sub getDataSet
{
	my( $self , $setname ) = @_;

	return EPrints::DataSet->new( $self, $setname );
}

1;
