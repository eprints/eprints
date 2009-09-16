######################################################################
#
# EPrints::Plugin::Sword::Unpack::Zip
#
######################################################################
#
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  This file is part of GNU EPrints 3.
#  
#  Copyright (c) 2000-2008 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 3 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 3 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 3; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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
