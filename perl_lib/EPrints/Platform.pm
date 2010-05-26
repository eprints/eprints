######################################################################
#
# EPrints::Platform
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

=for Pod2Wiki

=head1 NAME

B<EPrints::Platform> - handles platform specific code.

=head1 DESCRIPTION

When you call a method in this class, it is sent to the appropriate
EPrints::Platform::xxx module. Usually this is 
EPrints::Platform::Unix

Which module is used is configured by the {platform} setting in
SystemSettings.pm

All file and directory names are absolute and joined by the Unix
file separator character '/'.

=over 4

=cut

package EPrints::Platform;

use EPrints::SystemSettings;
use strict;
no strict 'refs';

my $platform = $EPrints::SystemSettings::conf->{platform};
my $real_module = "EPrints::Platform::\u$platform";
eval "use $real_module;";

#####################################################################

=item chmod( MODE, @filelist )

Change the access control on files listed in @filelist to MODE.

=cut

#####################################################################

sub chmod { return &{$real_module."::chmod"}( @_ ); }

#####################################################################

=item chown( $uid, $gid, @filelist )

Change the user and group on files listed in @filelist to $uid and
$gid. $uid and $gid are as returned by L<getpwnam> (usually numeric).

=cut

#####################################################################

sub chown { return &{$real_module."::chown"}( @_ ); }

#####################################################################

=item getpwnam( $user )

Return the login-name, password crypt, uid and gid for user $user.

=cut

#####################################################################

sub getpwnam { return &{$real_module."::getpwnam"}( $_[0] ); }

#####################################################################

=item getpwnam( $user )

Return the login-name, password crypt, uid and gid for user $user.

=cut

#####################################################################

sub getgrnam { return &{$real_module."::getgrnam"}( $_[0] ); }

#####################################################################

=item test_uid()

Test whether the current user is the same that is configured in
SystemSettings.

=cut

#####################################################################
 
sub test_uid { return &{$real_module."::test_uid"}( @_ ); }

#####################################################################

=item mkdir( $path, MODE )

Create a directory $path (including parent directories as necessary)
set to mode MODE. If MODE is undefined defaults to dir_perms in
SystemSettings.

=cut

#####################################################################

sub mkdir { return &{$real_module."::mkdir"}( @_ ); }

#####################################################################

=item exec()

Executes certain named tasks, which were once (and may be) handled
by external binaries. This allows a per-platform solution to each
task. (example is unpacking a .tar.gz file).

=cut

#####################################################################
 
sub exec { return &{$real_module."::exec"}( @_ ); }

sub read_exec { return &{$real_module."::read_exec"}( @_ ); }

#####################################################################

=item $rc = read_perl_script( $repository, $filename, @args )

Executes Perl with @args, including the current EPrints library path. Writes
output from the script to $filename (errors and stdout).

Returns 0 on success.

=cut

#####################################################################

sub read_perl_script { return &{$real_module."::read_perl_script"}( @_ ); }

#####################################################################

=item get_hash_name()

Returns the last part of the filename of the hashfile for a document.
(yes, it's a bad function name.)

=cut

#####################################################################
 
sub get_hash_name { return &{$real_module."::get_hash_name"}( @_ ); }

#####################################################################

=item free_space( $dir )

Return the amount of free space (in bytes) available at $dir. $dir may contain a drive (C:) on Windows platforms.

=cut

#####################################################################

sub free_space { return &{$real_module."::free_space"}( @_ ); }

#####################################################################

=item $bool = proc_exists( $pid )

Returns true if a process exists using id $pid.

Returns undef if process identification is unsupported.

=cut

#####################################################################

sub proc_exists { &{$real_module."::proc_exists"} }

# TODO: fixme!
sub join_path { join('/', @_) }

1;

=back
