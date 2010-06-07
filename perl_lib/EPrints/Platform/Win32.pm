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

sub read_exec
{
	my( $repo, $tmp, $cmd_id, %map ) = @_;

	my $cmd = $repo->invocation( $cmd_id, %map );

	return _read_exec( $repo, $tmp, $cmd );
}

sub read_perl_script
{
	my( $repo, $tmp, @args ) = @_;

	my $perl = $repo->config( "executables", "perl" );

	my $perl_lib = $repo->config( "base_path" ) . "/perl_lib";

	unshift @args, "-I$perl_lib";

	return _read_exec( $repo, $tmp, $perl, @args );
}

sub _read_exec
{
	my( $repo, $tmp, $cmd, @args ) = @_;

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
