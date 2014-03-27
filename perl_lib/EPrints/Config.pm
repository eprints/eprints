######################################################################
#
# EPrints::Config
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::Config> - software configuration handler

=head1 DESCRIPTION

This module handles loading the main configuration for an instance
of the eprints software - such as the list of language id's and 
the top level configurations for repositories - the XML files in /archives/

=head1 METHODS

=head2 Deprecated Methods

=over 4

=item EPrints::Config::abort

Deprecated, use L<EPrints>::abort.

=item EPrints::Config::get_archive_config
=item EPrints::Config::get_archive_ids
=item EPrints::Config::load_archive_config_module

Deprecated, use *_repository_*.

=back

=head2 Normal Methods

=over 4

=cut

######################################################################

#cjg SHOULD BE a way to configure an repository NOT to load the
# module except on demand (for buggy / testing ones )

package EPrints::Config;

use warnings;
use strict;

my $SYSTEMCONF = $EPrints::SystemSettings::conf;
my @LANGLIST;
my @SUPPORTEDLANGLIST;
my %ARCHIVES;
#my %ARCHIVEMAP;

# deprecated support for abort()
sub abort { &EPrints::abort( @_ ) }

# deprecated
sub ensure_init {}

######################################################################
=pod

=item EPrints::Config::init()

Load the EPrints configuration.

Do not use this method directly, it will be automatically called
when using EPrints.

=cut
######################################################################

sub init
{
	# cjg Should these be hardwired? Probably they should.
	$SYSTEMCONF->{cgi_path} = $SYSTEMCONF->{base_path}."/cgi";
	$SYSTEMCONF->{cfg_path} = $SYSTEMCONF->{base_path}."/cfg";
	$SYSTEMCONF->{lib_path} = $SYSTEMCONF->{base_path}."/lib";
	$SYSTEMCONF->{arc_path} = $SYSTEMCONF->{base_path}."/archives";
	$SYSTEMCONF->{bin_path} = $SYSTEMCONF->{base_path}."/bin";
	$SYSTEMCONF->{var_path} = $SYSTEMCONF->{base_path}."/var";
	
	###############################################
	
	$SYSTEMCONF->{repository} = {};

	load_system_config();

	if( opendir( my $dh, $SYSTEMCONF->{arc_path} ) )
	{
		while( my $id = readdir( $dh ) )
		{
			next if( $id =~ m/^\./ );
			next if( !-d $SYSTEMCONF->{arc_path}."/".$id );
			next if $SYSTEMCONF->{repository}->{$id} && $SYSTEMCONF->{repository}->{$id}->{disabled};
			
			$ARCHIVES{$id} = {};
		}
		closedir( $dh );
	}
}

=item EPrints::Config::load_system_config()

Load the system configuration files.

=cut

sub load_system_config
{
	my $syslibcfgd = $SYSTEMCONF->{"lib_path"}."/syscfg.d";
	my $syscfgd = $SYSTEMCONF->{"cfg_path"}."/cfg.d";

	my $files = {};

	foreach my $dir ( $syslibcfgd, $syscfgd )
	{
		next if !-e $dir;
		opendir(my $dh, $dir) or die "Error opening $dir: $!";
		foreach my $file (readdir($dh)) 
		{
			next if $file =~ m/^\./;
			next if $file !~ m/\.pl$/;
			$files->{$file} = "$dir/$file";
		}
		closedir($dh);
	}

	{
		no strict 'refs';
		${"EPrints::SystemSettings::config"} = $SYSTEMCONF;
	}

	eval &_bootstrap( "EPrints::SystemSettings" );

	# we want to sort by filename because we interleave files from default and
	# custom locations
	foreach my $file (sort keys %$files)
	{
		my $filepath = $files->{$file};
		my $err = EPrints::SystemSettings::load_config_file( $filepath );
		EPrints->abort( "Error in configuration:\n$err\n" ) if $err;
	}
}

=item $conf = EPrints::Config::system_config()

Returns the system configuration variable. To access a specific configuration
option use L</get>.

=cut

sub system_config
{
	return $SYSTEMCONF;
}

######################################################################
=pod

=item $repository = EPrints::Config::get_repository_config( $id )

Returns a hash of the basic configuration for the repository with the
given id. This hash will include the properties from SystemSettings.

=cut
######################################################################
sub get_archive_config { return get_repository_config( @_ ); }

sub get_repository_config
{
	my( $id ) = @_;

	return $ARCHIVES{$id};
}




######################################################################
=pod

=item @ids = EPrints::Config::get_repository_ids()

Return a list of ids of all repositories belonging to this instance of
the eprints software.

=cut
######################################################################
sub get_archive_ids { return get_repository_ids(); }

sub get_repository_ids
{
	return keys %ARCHIVES;
}



######################################################################
=pod

=item $arc_conf = EPrints::Config::load_repository_config_module( $id )

Load the full configuration for the specified repository unless the 
it has already been loaded.

Return a reference to a hash containing the full repository configuration. 

=cut
######################################################################
sub load_archive_config_module { return load_repository_config_module( @_ ); }

sub load_repository_config_module
{
	my( $id ) = @_;

	my $info = bless {}, "EPrints::RepositoryConfig";
	
	%$info = %{ EPrints::Utils::clone( $SYSTEMCONF ) };

	$info->{archiveroot} = $info->{arc_path}."/".$id;
	$info->{documents_path} = $info->{archiveroot}."/documents";
	$info->{config_path} = $info->{archiveroot}."/cfg";
	$info->{htdocs_path} = $info->{archiveroot}."/html";
	$info->{cgi_path} = $info->{archiveroot}."/cgi";

	if( !-d $info->{archiveroot} )
	{
		print STDERR "No repository named '$id' found in ".$info->{arc_path}.".\n\n";
		exit 1;
	}

	if( !exists $ARCHIVES{$id} )
	{
		print STDERR "Repository named '$id' disabled by configuration.\n";
		exit 1;
	}

	my $libcfgd = $SYSTEMCONF->{"lib_path"}."/cfg.d";
	my $repcfgd = $info->{archiveroot}."/cfg/cfg.d";
	my %files_map = ();

	my $site_lib_cfgd = $SYSTEMCONF->{"base_path"}."/site_lib/cfg.d";

	foreach my $dir ( $libcfgd, $site_lib_cfgd, $repcfgd )
	{
		next if( ! -e $dir );
		opendir( my $dh, $dir ) || EPrints::abort( "Can't read cfg.d config files from $dir: $!" );
		while( my $file = readdir( $dh ) )
		{
			next if $file =~ /^\./;
			next unless $file =~ /\.pl$/;
			$files_map{$file} = "$dir/$file";
		}
		closedir( $dh );
	}

	{
		no strict 'refs';
		${"EPrints::Config::${id}::config"} = $info;
	}

	eval &_bootstrap( "EPrints::Config::".$id );

	# we want to sort by filename because we interleave files from default and
	# custom locations
	foreach my $file (sort keys %files_map)
	{
		my $filepath = $files_map{$file};
		no strict 'refs';
		my $err = &{"EPrints::Config::${id}::load_config_file"}( $filepath );
		EPrints->abort( "Error in configuration:\n$err\n" ) if $err;
	}

	return $info;
}

sub _bootstrap
{
	my( $class ) = @_;

	return <<EOP;
package $class;
use EPrints::Const qw( :trigger );
use Time::HiRes;

our \$c = \$${class}::config;

{
no warnings; # suppress redef warnings when re-loading
sub load_config_file
{
	use warnings; # but still show warnings when loading files
	my( \$filepath ) = \@_;

	my \$cfgfile;
	open(my \$fh, "<", \$filepath) or return "Error opening '\$filepath': \$!";
	sysread(\$fh, \$cfgfile, -s \$fh);
	close(\$fh);

	eval "\$cfgfile";
	return if !\$@;

	my \$err = \$@;
	\$err =~ s/,[^,]+\$//;
	\$err =~ s/\\([^)]+\\)(.*?)\$/\$filepath\$1/;
	return \$err;
}
}

EOP
}


######################################################################
=pod

=item $value = EPrints::Config::get( $confitem )

Return the value of a given eprints configuration item. These
values are obtained from SystemSettings plus a few extras for
paths.

=cut
######################################################################

sub get
{
	my( $confitem ) = @_;

	return $SYSTEMCONF->{$confitem};
}

1;

######################################################################
=pod

=back

=cut


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

