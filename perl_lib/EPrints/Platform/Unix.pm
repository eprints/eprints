######################################################################
#
# EPrints::Platform::Unix
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

B<EPrints::Platform> - Functions for the UNIX Platform

=over 4

=cut

package EPrints::Platform::Unix;

use strict;

sub chmod 
{
	return CORE::chmod( @_ );
} 

sub chown 
{
	return CORE::chown( @_ );
}

sub getpwnam 
{
	return CORE::getpwnam( @_ );
}

sub test_uid
{
	#my $req($login,$pass,$uid,$gid) = getpwnam($user)
	my $req_username = $EPrints::SystemSettings::conf->{user};
	my $req_group = $EPrints::SystemSettings::conf->{group};
	my $req_uid = (getpwnam($req_username))[2];
	my $req_gid = (getgrnam($req_group))[2];

	my $username = (getpwuid($>))[0];

	if( $username ne $req_username )
	{
		abort( 
"We appear to be running as user: ".$username."\n".
"We expect to be running as user: ".$req_username );
	}
}


1;
