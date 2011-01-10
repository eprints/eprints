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

use Win32::Service;
use Win32::Process;
use Win32::Daemon;

use EPrints::Index::Daemon::MSWin32;

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
	my( $self, $dir ) = @_;

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

sub proc_exists
{
	my( $self, $pid ) = @_;

	return 1 if Win32::Process::Open(my $obj, $pid, 0) != 0;
	return 1 if $^E == 5; # Access is denied
	return 0;
}

sub mkdir
{
	my( $self, $full_path, $perms ) = @_;

	my( $drive, $dir ) = split /:/, $full_path, 2;
	($drive,$dir) = ($dir,$drive) if !$dir;

	if( !$drive )
	{
		if( $EPrints::SystemSettings::conf->{base_path} =~ /^([A-Z]):/i )
		{
			$drive = $1;
		}
	}

	my @parts = grep { length($_) } split "/", $dir;
	foreach my $i (1..$#parts)
	{
		my $dir = "$drive:/".join("/", @parts[0..$i]);
		if( !-d $dir && !CORE::mkdir($dir) )
		{
			print STDERR "Failed to mkdir $dir: $!\n";
			return 0;
		}
	}

	return 1;
}

1;
