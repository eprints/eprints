######################################################################
#
# EPrints::Plugin::Sword::Unpack::Zip
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

######################################################################
#
# PURPOSE:
#
#	This is an unpacker for ZIP files (not gzip). It calls
#	the 'unzip' method shipped with EPrints (cf. perl_lib/EPrints/SystemSettings.pm)
#
#	Returns an array of files (the files which were actually unpacked).
#
# METHODS:
#
# export( $plugin, %opts )
#       The method called by DepositHandler. The %opts hash contains
#       information on which files to process.
#
######################################################################

package EPrints::Plugin::Sword::Unpack::Zip;

@ISA = ( "EPrints::Plugin::Convert" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "SWORD Unpacker - Zip";
	$self->{visible} = "";

	$self->{accept} = "application/zip"; 
	
	return $self;
}


 sub export
{
	my( $plugin, %opts ) = @_;

	my $session = $plugin->{session};

	my $dir = $opts{dir};	# the directory where to unpack to
	my $filename = $opts{filename};

	my $repository = $session->get_repository;

	# use the 'zip' command of the repository (cf. SystemSettings.pm)
	my $cmd_id = 'zip';

        my %cmd_opts = (
                   ARC => $filename,
                   DIR => $dir,
        );

        if( !$repository->can_invoke( $cmd_id, %cmd_opts ) )
        {
		print STDERR "\n[SWORD-ZIP] [INTERNAL-ERROR] This repository has not been set up to use the 'zip' command.";
                return ;
        }

        $repository->exec( $cmd_id, %cmd_opts );

	my $dh;
	if( !opendir( $dh, $dir) )
	{
		print STDERR "\n[SWORD-ZIP] [INTERNAL ERROR] Could not open the temp directory for reading because: $!";
		return;
	}

        my @files = grep { $_ !~ /^\./ } readdir($dh);

        closedir $dh;

        foreach( @files ) 
	{ 
		EPrints::Utils::chown_for_eprints( $_ ); 
	}

	return \@files;

}





1;
