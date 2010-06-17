######################################################################
#
# EPrints::System
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

B<EPrints::System> - Wrappers for system calls

=head1 METHODS

=over 4

=cut

package EPrints::System;

use strict;

=item $sys = EPrints::System->new();

Returns a new EPrints::System object.

=cut

sub new
{
	my( $class, %opts ) = @_;

	my $osname = $^O;

	my $platform = $EPrints::SystemSettings::conf->{platform};
	if( defined $platform && $platform ne "unix" && $platform ne "win32" )
	{
		$osname = $platform;
	}

	my $real_class = $class;
	$real_class = __PACKAGE__ . "::$osname" if $real_class eq __PACKAGE__;

	eval "use $real_class; 1";
	die $@ if $@;

	my $self = bless \%opts, $real_class;

	$self->init();

	return $self;
}

=item $sys->init()

Perform any platform-specific initialisation.

=cut

sub init
{
	my( $self ) = @_;

	if( !defined $self->{uid} )
	{
		$self->{uid} = ($self->getpwnam( $EPrints::SystemSettings::conf->{user} ))[2];
	}
	if( !defined $self->{gid} )
	{
		$self->{gid} = $self->getgrnam( $EPrints::SystemSettings::conf->{group} );
	}

	if( !defined $self->{uid} )
	{
		EPrints->abort( sprintf( "'%s' is not a valid user on this system - check your SystemSettings",
			$EPrints::SystemSettings::conf->{user}
		) );
	}
	if( !defined $self->{gid} )
	{
		EPrints->abort( sprintf( "'%s' is not a valid group on this system - check your SystemSettings",
			$EPrints::SystemSettings::conf->{group}
		) );
	}
}

=item $sys->chmod( MODE, @filelist )

Change the access control on files listed in @filelist to MODE.

=cut

sub chmod 
{
	my( $self, $mode, @files ) = @_;

	return CORE::chmod( $mode, @files );
} 

=item $sys->chown( $uid, $gid, @filelist )

Change the user and group on files listed in @filelist to $uid and
$gid. $uid and $gid are as returned by L<getpwnam> (usually numeric).

=cut

sub chown 
{
	my( $self, $mode, @files ) = @_;

	return CORE::chown( $mode, @files );
}

=item $sys->chown_for_eprints( @filelist )

Change the user and group on files listed in @filelist to the current EPrints user and group.

=cut

sub chown_for_eprints
{
	my( $self, @files ) = @_;

	$self->chown( $self->{uid}, $self->{gid}, @files );
}

=item $gid = $sys->getgrnam( $group )

Return the system group id of the group $group.

=cut

sub getgrnam 
{
	return CORE::getgrnam( $_[1] );
}

=item ($user, $crypt, $uid, $gid ) = $sys->getpwnam( $user )

Return the login-name, password crypt, uid and gid for user $user.

=cut

sub getpwnam 
{
	return CORE::getpwnam( $_[1] );
}

=item $sys->current_uid()

Returns the current uid of the user running this process.

=cut

sub current_uid
{
	return $>;
}

=item $sys->test_uid()

Test whether the current user is the same that is configured in L<EPrints::SystemSettings>.

=cut

sub test_uid
{
	my( $self ) = @_;

	my $cur_uid = $self->current_uid;
	my $req_uid = $self->{uid};

	if( $cur_uid ne $req_uid )
	{
		my $username = (CORE::getpwuid($cur_uid))[0];
		my $req_username = (CORE::getpwuid($req_uid))[0];

		EPrints::abort( 
"We appear to be running as user: $username ($cur_uid)\n".
"We expect to be running as user: $req_username ($req_uid)" );
	}
}

=item $sys->mkdir( $path, MODE )

Create a directory $path (including parent directories as necessary)
set to mode MODE. If MODE is undefined defaults to dir_perms in
SystemSettings.

=cut

sub mkdir
{
	my( $self, $full_path, $perms ) = @_;

	# Default to "dir_perms"
	$perms = eval($EPrints::SystemSettings::conf->{"dir_perms"}) if @_ < 3;
	if( !defined( $perms ))
	{
		EPrints->abort( "mkdir requires dir_perms is set in SystemSettings");
	}

	my $dir = "";
	my @parts = grep { length($_) } split( "/", "$full_path" );
	my @newdirs;
	while( scalar @parts )
	{
		$dir .= "/".(shift @parts );
		if( !-d $dir )
		{
			my $ok = CORE::mkdir( $dir, $perms );
			if( !$ok )
			{
				print STDERR "Failed to mkdir $dir: $!\n";
				return 0;
			}
			push @newdirs, $dir;
		}
	}

	# mkdir ignores sticky bits (01000, 02000, 04000)
	$self->chmod( $perms, @newdirs );
	# fix the file ownership
	$self->chown_for_eprints( @newdirs );

	return 1;
}

=item $sys->exec( $repo, $cmd_id, %map )

Executes certain named tasks, which were once (and may be) handled
by external binaries. This allows a per-platform solution to each
task. (example is unpacking a .tar.gz file).

=cut

sub exec 
{
	my( $self, $repository, $cmd_id, %map ) = @_;

 	if( !defined $repository ) { EPrints::abort( "exec called with undefined repository" ); }

	my $command = $repository->invocation( $cmd_id, %map );

	my $rc = 0xffff & system $command;

	return $rc;
}	

=item $rc = read_exec( $repo, $filename, $cmd_id, %map )

Execute $cmd_id with parameters from %map and write the STDOUT and STDERR to $filename.

Returns the exit status of the called command.

=cut

sub read_exec
{
	my( $self, $repo, $tmp, $cmd_id, %map ) = @_;

	my $cmd = $repo->invocation( $cmd_id, %map );

	return $self->_read_exec( $repo, $tmp, $cmd );
}

=item $rc = read_perl_script( $repo, $filename, @args )

Executes Perl with @args, including the current EPrints library path. Writes
output from the script to $filename (errors and stdout).

Returns 0 on success.

=cut

sub read_perl_script
{
	my( $self, $repo, $tmp, @args ) = @_;

	my $perl = $repo->config( "executables", "perl" );

	my $perl_lib = $repo->config( "base_path" ) . "/perl_lib";

	unshift @args, "-I$perl_lib";

	return $self->_read_exec( $repo, $tmp, $perl, @args );
}

sub _read_exec
{
	my( $self, $repo, $tmp, $cmd, @args ) = @_;

	my $perl = $repo->config( "executables", "perl" );

	my $fn = Data::Dumper->Dump( ["$tmp"], ['fn'] );
	my $args = Data::Dumper->Dump( [[$cmd, @args]], ['args'] );

	my $script = <<EOP;
$fn$args
open(STDOUT,">>", \$fn);
open(STDERR,">>", \$fn);
exit(0xffff & system( \@\{\$args\} ));
EOP

	my $rc = system( $perl, "-e", $script );

	seek($tmp,0,0); # reset the file handle

	return 0xffff & $rc;
}

=item $sys->free_space( $dir )

Return the amount of free space (in bytes) available at $dir. $dir may contain a drive (C:) on Windows platforms.

=cut

sub free_space
{
	my( $self, $dir ) = @_;

	# use -P for most UNIX platforms to get POSIX-compatible block counts

	$dir = quotemeta($dir);
	open(my $fh, "df -P $dir|") or EPrints->abort( "Error calling df: $!" );

	my @output = <$fh>;
	my( $dev, $size, $used, $free, $capacity, undef ) = split /\s+/, $output[$#output], 6;

	return $free * 1024; # POSIX output mode block is 512 bytes
}

=item $bool = $sys->proc_exists( $pid )

Returns true if a process exists for id $pid.

Returns undef if process identification is unsupported.

=cut

sub proc_exists
{
	my( $self, $pid ) = @_;

	return -d "/proc/$pid";
}

=item get_hash_name()

Returns the last part of the filename of the hashfile for a document.
(yes, it's a bad function name.)

=cut

sub get_hash_name
{
	return EPrints::Time::get_iso_timestamp().".xsh";
}

1;
