######################################################################
#
# EPrints::Apache::AnApache::RequestWrapper
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

B<EPrints::Apache::AnApache::RequestWrapper> - Pretends to be an apache request.

=head1 DESCRIPTION

A EPrints::Apache::AnApache::RequestWrapper is created from a real apache request and
a hash of "dir_config" options. It will pass all methods straight
through to the origional apache request except for dir_config()
which it will return its own config instead.

It's a hack used by EPrints::Apache::Auth - you really do not want to go
near it!

This is the version for use with Apache 1.3. EPrints::Apache::Auth will
pick which to use based on EPrints::SystemSettings 

=over 4

=cut



package EPrints::Apache::AnApache::RequestWrapper;

use strict;

use Apache;


sub new
{
	my( $class , $real_request , $conf ) = @_;
	my $self ={};
	bless $self,$class;
	$self->{real_request} = $real_request;
	$self->{conf} = $conf;
	return $self;
}


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
######################################################################
=pod

=back

=cut

