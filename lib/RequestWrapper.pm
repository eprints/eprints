######################################################################
#
# EPrints::RequestWrapper
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

B<EPrints::RequestWrapper> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::RequestWrapper;

#cjg Apache::FakeRequest...

use strict;
use Apache;


######################################################################
=pod

=item $thing = EPrints::RequestWrapper->new( $real_request, $conf )

undocumented

=cut
######################################################################

sub new
{
	my( $class , $real_request , $conf ) = @_;
	my $self ={};
	bless $self,$class;
	$self->{real_request} = $real_request;
	$self->{conf} = $conf;
	return $self;
}


######################################################################
=pod

=item $foo = $thing->dir_config ( $key )

undocumented

=cut
######################################################################

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


######################################################################
=pod

=item $foo = $thing->DESTROY

undocumented

=cut
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}
1;


######################################################################
=pod

=back

=cut

