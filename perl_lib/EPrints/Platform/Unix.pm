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
use warnings;

use EPrints::Time;
use EPrints::SystemSettings;
use Carp;

sub chmod 
{
	return CORE::chmod( @_ );
} 

sub chown 
{
	return CORE::chown( @_ );
}

sub getgrnam 
{
	return CORE::getgrnam( $_[0] );
}

sub getpwnam 
{
	return CORE::getpwnam( $_[0] );
}

sub test_uid
{
	#my $req($login,$pass,$uid,$gid) = getpwnam($user)
	my $req_username = $EPrints::SystemSettings::conf->{user};
	my $req_group = $EPrints::SystemSettings::conf->{group};
	my $req_uid = (CORE::getpwnam($req_username))[2];
	my $req_gid = (CORE::getgrnam($req_group))[2];

	my $username = (CORE::getpwuid($>))[0];

	if( $username ne $req_username )
	{
		EPrints::abort( 
"We appear to be running as user: ".$username."\n".
"We expect to be running as user: ".$req_username );
	}
}

sub mkdir
{
	my( $full_path, $perms ) = @_;

	# Default to "dir_perms"
	$perms = eval($EPrints::SystemSettings::conf->{"dir_perms"})
		if @_ < 2;
	if( !defined( $perms ))
	{
		EPrints::abort( "mkdir requires dir_perms is set in SystemSettings");
	}

	# Make sure $dir is a plain old string (not unicode) as
	# Unicode::String borks mkdir

	my $dir="";
	my @parts = split( "/", "$full_path" );
	while( scalar @parts )
	{
		$dir .= "/".(shift @parts );
		if( !-d $dir )
		{
			my $ok = mkdir( $dir, $perms );
			if( !$ok )
			{
				print STDERR "Failed to mkdir $dir: $!\n";
				return 0;
			}
			EPrints::Utils::chown_for_eprints( $dir );
		}
	}		

	return 1;
}

sub join_path
{
	return join('/', @_);
}

sub exec 
{
	my( $repository, $cmd_id, %map ) = @_;

 	if( !defined $repository ) { EPrints::abort( "exec called with undefined repository" ); }

	my $command = $repository->invocation( $cmd_id, %map );

	my $rc = 0xffff & system $command;

	return $rc;
}	

sub read_perl_script
{
	my( $repository, $tmp, @args ) = @_;

	no warnings; # suppress "only used once" warnings

	my $perl = $repository->get_conf( "executables", "perl" );

	my $perl_lib = $repository->get_conf( "base_path" ) . "/perl_lib";

	open(OLDERR,">&STDERR");
	open(OLDOUT,">&STDOUT");

	open(STDOUT,">","$tmp") or die "Can't redirect stdout to $tmp: $!";
	open(STDERR,">&STDOUT") or die "Can't dup stdout: $!";

	select(STDERR); $| = 1;
	select(STDOUT); $| = 1;

	unshift @args, $perl, "-I$perl_lib";
	my $cmd = join " ", map { quotemeta($_) } @args;
	my $rc = system($cmd);

	close(STDOUT);
	close(STDERR);

	open(STDOUT, ">&OLDOUT");
	open(STDERR, ">&OLDERR");

	return 0xffff & $rc;
}

sub get_hash_name
{
	return EPrints::Time::get_iso_timestamp().".xsh";
}

##############################################################################
#
# disk-free utility methods
#
# This is intended to be bullet-proof. Modules are checked in this order:
#  Filesys::DfPortable, Filesys::Df, Filesys::DiskSpace (built in), df
#
# For debugging purposes $DF_METHOD will contain the actual method used.
#
#############################################################################

our $DF_METHOD = undef;

sub _filesys_dfportable
{
	my( $dir ) = @_;

	my $info = Filesys::DfPortable::dfportable($dir);
	return $info->{bavail};
}

sub _filesys_df
{
	my( $dir ) = @_;

	my $info = Filesys::Df::df($dir);
	return $info->{bavail};
}

sub _check_statfs
{
	my( $dir ) = @_;

	my ($fmt, $res) = ('', -1);

# try with statvfs..
	eval 
	{  
		{
			package main;
			require "sys/syscall.ph";
		}
		$fmt = "\0" x 512;
		$res = syscall (&main::SYS_statvfs, $dir, $fmt) ;
	}
# try with statfs..
	|| eval 
	{ 
		{
			package main;
			require "sys/syscall.ph";
		}	
		$fmt = "\0" x 512;
		$res = syscall (&main::SYS_statfs, $dir, $fmt);
	};

	return $res == 0;
}

sub _filesys_diskspace
{
	my( $dir ) = @_;

	my @retval = Filesys::DiskSpace::df( $dir );
	return @retval ? $retval[3] * 1024 : undef; # df returns Kb
}

sub _gnu_df
{
	my( $dir ) = @_;

	$dir = quotemeta($dir);
	my $fh;
	# -P is available in RH7.3, FC6, Mac OS X, Solaris
	$ENV{POSIXLY_CORRECT} = 1; # Needed for GNU df?
	unless( open($fh, "df -P $dir|") )
	{
		warn("DEBUG: Error calling df for [$dir] under POSIX: $!");
		return;
	}
	my @lines = <$fh>;
	close $fh;
	# /dev/hda5            1975365632  36544512 1838477312       2% /tmp
	unless( $lines[$#lines] =~ /^\S+\s+\w+\s+\w+\s+(\d+)\s+/ )
	{
		warn("DEBUG: Error scanning df output for [$dir] under POSIX: ".$lines[$#lines]);
		return;
	}
	my $free = $1;
	return $free * 512; # POSIX standard is 512 byte chunks
}

sub _enable_free_space
{
	my $dir = $EPrints::SystemSettings::conf->{'base_path'};
	eval "use Filesys::DfPortable ()";
	eval {
		if( !$@ and _filesys_dfportable($dir) )
		{
			$DF_METHOD = '_filesys_dfportable';
			*EPrints::Platform::Unix::free_space = \&_filesys_dfportable;
		}
	};
	return if $DF_METHOD;
	eval "use Filesys::Df ()";
	eval {
		if( !$@ and _filesys_df($dir) > 0 )
		{
			$DF_METHOD = '_filesys_df';
			*EPrints::Platform::Unix::free_space = \&_filesys_df;
			return;
		}
	};
	return if $DF_METHOD;
	eval "use Filesys::DiskSpace ()";
	eval {
		# Replicates the previous method, but with an actual invocation check
		if( !$@ and _check_statfs($dir) and _filesys_diskspace($dir) )
		{
			$DF_METHOD = '_filesys_diskspace';
			*EPrints::Platform::Unix::free_space = \&_filesys_diskspace;
			return;
		}
	};
	return if $DF_METHOD;
	if( _gnu_df($dir) )
	{
		$DF_METHOD = '_gnu_df';
		*EPrints::Platform::Unix::free_space = \&_gnu_df;
		return;
	}
	EPrints::abort("No available method worked to get disk free space: either install Filesys::DfPortable or set disable_df to 1 in perl_lib/EPrints/SystemSettings.pm to disable disk space checking. This error will also occur if [$dir] has zero bytes free (in which case you probably want to free some space up!).");
}

if( $EPrints::SystemSettings::conf->{'disable_df'} )
{
	*EPrints::Platform::Unix::free_space = sub { Carp::croak("Call to EPrints::Platform::Unix::free_space not supported when disable_df is enabled in perl_lib/EPrints/SystemSettings.pm") }
}
else
{
	&_enable_free_space;
	#warn "Using $DF_METHOD for DF\n";
}

##############################################################################
#
# End of disk-free methods
#
##############################################################################

sub proc_exists
{
	my( $pid ) = @_;

	return -d "/proc/$pid";
}

1;
