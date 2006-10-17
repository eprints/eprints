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

package EPrints::Platform;

use strict;

sub chmod 
{
	return chmod( @_ );
} 

sub chown 
{
	return chown( @_ );
}


1;
