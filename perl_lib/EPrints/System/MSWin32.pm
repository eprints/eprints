######################################################################
#
# EPrints::System::MSWin32
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

B<EPrints::System::MSWin32> - Functions for the Win32 Platform

=over 4

=cut

package EPrints::System::MSWin32;

@ISA = qw( EPrints::System );

use strict;

sub init { }

sub chmod { } 

sub chown { }

sub chown_for_eprints { }

sub getgrnam { }

sub getpwnam { }

sub test_uid { }

sub free_space
{
	my( $dir ) = @_;

	my $free_space = 0;

	$dir =~ s/\//\\/g;

	open(my $fh, "dir $dir|") or die "Error in open: $!";
	while(<$fh>)
	{
		if( $_ =~ /\s([0-9,]+)\sbytes\sfree/ )
		{
			$free_space = $1;
		}
	}
	close($fh);

	$free_space =~ s/\D//g;

	return $free_space;
}

sub proc_exists { }

1;
