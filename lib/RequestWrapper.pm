######################################################################
#
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

package EPrints::RequestWrapper;

use strict;
use Apache;

## WP1: BAD
sub new
{
	my( $class , $real_request , $conf ) = @_;
	my $self ={};
	bless $self,$class;
	$self->{real_request} = $real_request;
	$self->{conf} = $conf;
	return $self;
}

## WP1: BAD
sub dir_config 
{ 
	my( $self, $key ) = @_; 
	if( defined $self->{conf}->{$key} )
	{
		return $self->{conf}->{$key};
	}
	return $self->{real_request}->dir_config( $key ); 
}

my $thing;
foreach $thing ( keys %Apache:: )
{
	next if( $thing eq "new" || 
		 $thing eq "dir_config" ||
		 $thing eq "import" );
	my $sub = '';
	$sub.= 'sub '.$thing;
	$sub.= '{ ';
	$sub.= '   my( $self , @args ) = @_; ';
	$sub.= '   return $self->{real_request}->'.$thing.'( @args ); ';
	$sub.= '}';
	eval $sub;
}

1;

