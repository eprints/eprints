######################################################################
#
# EPrints::System::MSWin32
#
######################################################################
#
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
use Win32::Daemon;
use Win32::DriveInfo;

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

	$dir =~ s/\//\\/g;

	my $drive = $dir =~ /^([a-z]):/i ? $1 : 'c';

	my $free_space = (Win32::DriveInfo::DriveSpace($drive))[6];

	if( !defined $free_space )
	{
		EPrints->abort( "Win32::DriveSpace::DriveSpace $dir: $^E" );
	}

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

sub quotemeta
{
	my( $self, $str ) = @_;

	$str =~ s/"//g; # safe but means you can't pass "
	$str = "\"$str\"" if $str =~ /[\s&|<>?]/;

	return $str;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

