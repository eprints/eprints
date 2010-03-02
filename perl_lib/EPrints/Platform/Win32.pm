######################################################################
#
# EPrints::Platform::Win32
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

B<EPrints::Platform::Win32> - Functions for the Win32 Platform

=over 4

=cut

package EPrints::Platform::Win32;

use strict;

sub chmod 
{
} 

sub chown 
{
}

sub getgrnam 
{
}

sub getpwnam 
{
}

sub test_uid
{
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

	my( $dir, @parts ) = split( "/", "$full_path" );
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

sub proc_exists
{
	my( $pid ) = @_;

	return -d "/proc/$pid";
}

1;
