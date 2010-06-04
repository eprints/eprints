package EPrints::EPM;

use strict;
use File::Path;
use File::Copy;
use Digest::MD5;

sub unpack_package 
{
	my ($repository, $app_path, $directory) = @_;
	
	my $mime_type = $repository->call('guess_doc_type',$repository ,$app_path );

	my $type;

	if ($mime_type eq "application/x-tar") {
		$type = "targz";
	} else {
		$type = "zip";
	}

	
	my $rc = $repository->get_repository->exec(
			$type,
			DIR => $directory,
			ARC => $app_path );

	return $rc;

}

sub remove_cache_package
{
	my ($repository,$package) = @_;
	
	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/cache/";
	my $cache_package_path = $epm_path . "/" . $package;

	my $rc = rmtree($cache_package_path);
	
	if ($rc < 1) 
	{
		return (1, "Failed to remove cached package");
	}
	return (0, "Cache Package Removed");

}

sub cache_package 
{
	my ($repository, $tmpfile) = @_;

	my $directory;

	$directory = File::Temp->newdir( CLEANUP => 1 );
	my $rc = unpack_package($repository, $tmpfile, $directory);
	if ($rc) {
		return (1,"failed to unpack package");
	}
	
	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/cache/";
	
	if ( !-d $epm_path ) {
		mkpath($epm_path);
	}
        
	if( !-d $epm_path )
        {
                return (1,"Failed to create package management cache");
        }

	my $package_name;
	my $cache_package_path;

	$rc = 1;

        File::Find::find( {
                no_chdir => 1,
                wanted => sub {
                        return unless $rc and !-d $File::Find::name;
                        my $filepath = $File::Find::name;
                        my $filename = substr($filepath, length($directory));
                        open(my $filehandle, "<", $filepath);
                        unless( defined( $filehandle ) )
                        {
                                $rc = 0;
                                return;
                        }
			if ( (substr $filename, -5) eq ".spec" ) {
				$package_name = substr $filename, 0, -5;
				$cache_package_path = $epm_path . "/" . $package_name;
			}
                },
        }, "$directory" );


	if ( !-d $cache_package_path ) {
		mkpath($cache_package_path);
	} else {
		rmtree($cache_package_path);
		mkpath($cache_package_path);
	}
        
	if( !-d $cache_package_path )
        {
                return (1,"Failed to create package cache");
        }
	
	$rc = unpack_package($repository, $tmpfile, $cache_package_path);
	
	my $message = "Package copied into cache";
	if ($rc) {
		$message = "Failed to unpack package to cache";
	}
	return ($rc,$message);
	
}

sub install 
{
	my ($repository, $app_path, $force) = @_;

	my $directory;

	my $rc = 1;

	if ( -d $app_path ) {
		$directory = $app_path;
	} else {
		$directory = File::Temp->newdir( CLEANUP => 1 );
		my $rc = unpack_package($repository, $app_path, $directory);
		if ($rc) {
			return (1,"failed to unpack package");
		}
	}

	my $message;
	
	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/packages/";
	
	if ( !-d $epm_path ) {
		mkpath($epm_path);
	}
        
	if( !-d $epm_path )
        {
                return (1,"Failed to create package management cache");
        }

	my $package_name;
	my $package_path;
	my $file_md5s;
	my $backup_directory;
	my $abort = 0;
	my $spec_file_in;
       	my $spec_file;

        $rc = 1;
	File::Find::find( {
                no_chdir => 1,
                wanted => sub {
                        return unless $rc and !-d $File::Find::name;
                        my $filepath = $File::Find::name;
                        my $filename = substr($filepath, length($directory));
                        open(my $filehandle, "<", $filepath);
                        unless( defined( $filehandle ) )
                        {
                                $rc = 0;
                                return;
                        }
			if ( (substr $filename, -5) eq ".spec" ) {
				$package_name = substr $filename, 0, -5;
				$package_path = $epm_path . "/" . $package_name;
				$spec_file = $package_path . "/" . $filename;
				
				$spec_file_in = $filepath;
			}
		}
        }, "$directory" );
	
	if (! (defined $spec_file_in)) {
		$message = "Could not find package spec file, aborting";
		return (1, $message);
	}

	my $keypairs_in = read_spec_file($spec_file_in);

	if ( -e $spec_file and $force < 1) {

		my $keypairs_installed = read_spec_file($spec_file);

		my $installed_version = $keypairs_installed->{version};
		my $this_version = $keypairs_in->{version};

		if ($this_version lt $installed_version) {
			$message = "Package is already installed, use --force to override";	
			$abort = 1;
			return;
		}

		$backup_directory = make_backup($repository, $package_name);

	}

	my $package_files;
	my $icon_file = $directory . "/" . "$keypairs_in->{icon}";

	$package_files->{$spec_file_in} = 1;
	$package_files->{$icon_file} = 1;
	
	mkpath($package_path);
	
	$rc = 1;
        File::Find::find( {
                no_chdir => 1,
                wanted => sub {
                        return unless $rc and !-d $File::Find::name;
                        my $filepath = $File::Find::name;
                        my $filename = substr($filepath, length($directory));
                        open(my $filehandle, "<", $filepath);
                        unless( defined( $filehandle ) )
                        {
                                $rc = 0;
                                return;
                        }
			if ($package_files->{$filepath} > 0) {
				my $dst_file = $package_path . "/" . $filename;
				copy($filepath, $dst_file);
			} else {
				my $path_separator = '/';
			 	$filepath =~ m/[^\Q$path_separator\E]*$/;
				my $required_dir = substr ($`, length($directory));
				my $required_path = $archive_root . "/" . $required_dir;

				mkpath($required_path);
				
				my $installed_path = $archive_root . $filename;
				my $config_file = 0;

				if ( ( substr $filename. 0, 9 ) eq "cfg/cfg.d" ) {
					$config_file = 1;
				}

				if ( -e $installed_path and $force < 1) {
					my $installed_md5 = md5sum($installed_path);
					my $this_md5 = md5sum($filepath);
					my $package_managed = 1;
					if ( defined $backup_directory ) {
						$package_managed = check_required_md5($repository,$package_name,$backup_directory,$installed_path);
					}
					if ($package_managed < 1 and $config_file < 1) {
						write_md5s($repository,$package_path,$file_md5s); 
						remove($repository, $package_name, 1);
						if ( defined $backup_directory) {
							install($repository, $backup_directory, 1);
						}
						$message = "Install Failed: $installed_path has been changed outside the package manager, use --force to override";
						$abort = 1;
						return;
					} elsif ($package_managed < 1 and $config_file) {
						$message = "Config file has changed, not installing use --force to override";
					} 
				}
					
				copy($filepath, $installed_path);

				if ( !-e $installed_path ) {
					write_md5s($repository,$package_path,$file_md5s); 
					my ($rmrc, $rmmessage) = remove($repository, $package_name, 1);
					if ( defined $backup_directory) {
						install($repository, $backup_directory, 1);
					}
					$message = "Failed to install $filepath, installation aborted and reverted with message: " . $rmmessage;
					$abort = 1;
					return;
				} else {
					my $md5 = "-";
					if ( ( substr $filename. 0, 9 ) eq "cfg/cfg.d" ) {
					} else {
						$md5 = md5sum($filepath);
					}
					$file_md5s .= $installed_path . " " . $md5 . "\n"
				}
			}
                },
        }, "$directory" );
	if ($abort > 0) {
		return (1,$message);
	}

	write_md5s($repository,$package_path,$file_md5s); 
	
	if (!defined $message) {
		$rc = 0;
		$message = "Package Successfully Installed";
	
	} 
	
	my $installed = check_install($repository);
	if ($installed > 0) {
		my ($rc2,$extra) = remove($repository,$package_name,1);
		$message = "Package Install Failed (compilation error), package was removed again with message: " . $extra;
		$rc = 1;
	}

	return ( $rc,$message );

}

sub check_install
{

	my ( $repository ) = @_;

	my ( $rc , $output ) = $repository->test_config();

	return $rc;

}

sub read_spec_file
{
        my ($spec_file) = @_;

        my $key_pairs;

        open (SPECFILE, $spec_file);
        while (<SPECFILE>) {
                chomp;
                my @bits = split(":",$_,2);
                my $key = $bits[0];
                my $value = trim($bits[1]);
                $key_pairs->{$key} = $value;
        }
        close (SPECFILE);

        return $key_pairs;

}

sub trim 
{
	my ($string) = @_;	
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;

}

sub check_required_md5
{
	my ( $repository, $package_name, $backup_dir, $installed_path ) = @_;

	my $md5_file = $backup_dir . "/checksums";
	
	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $path_to_file = substr($installed_path, length($archive_root));

	open (MD5FILE, $md5_file);
	while (<MD5FILE>) {
		chomp;
		my @bits = split(/ /,$_);
		my $file = $bits[0];
		my $md5 = $bits[1];
		$file =~ s/$archive_root//;
		if ($file eq $path_to_file){
			my $installed_md5 = md5sum($installed_path);
			if ($installed_md5 eq $md5) {
				return 1;
			}
		}
	}
	close (MD5FILE);
	
	return 0;

} 

sub write_md5s 
{
	my ( $repository, $package_path, $file_md5s ) = @_;

	if ( defined $file_md5s) {
		my $md5_file = $package_path . "/checksums";
		open (MD5FILE, ">$md5_file");
		print MD5FILE $file_md5s;	
	}
}


sub make_backup 
{
	my ($repository, $package_name) = @_;
	
	my $backup_directory = File::Temp->newdir( CLEANUP => 1 );

	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/packages/";
	my $package_path = $epm_path . "/" . $package_name;
	
	my $spec_file = $package_path . "/" . $package_name . ".spec";
	my $md5_file = $package_path . "/checksums";

	copy($package_path . "/" . $package_name . ".spec", $backup_directory . "/" . $package_name . ".spec");
	copy($package_path . "/checksums", $backup_directory . "/checksums");

	open (MD5FILE, $md5_file);
	while (<MD5FILE>) {
		chomp;
		my @bits = split(/ /,$_);
		my $file = $bits[0];
		my $md5 = $bits[1];
		
		my $path_separator = '/';
		$file =~ m/[^\Q$path_separator\E]*$/;
		my $required_dir = substr ($`, length($archive_root));
		my $required_path = $backup_directory . "/" . $required_dir;
		mkpath($required_path);
		my $file_sub = substr($file, length($archive_root));

		if ( -e $file ) {
			copy($file,$backup_directory . "/" . $file_sub);
		}
	}
	close (MD5FILE);
	return $backup_directory;
}


sub remove
{
	my ($repository, $package_name, $force) = @_;
	
	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/packages/";
	my $package_path = $epm_path . "/" . $package_name;
	
	my $spec_file = $package_path . "/" . $package_name . ".spec";
	my $md5_file = $package_path . "/checksums";

	if ( !-e $spec_file or !-e $md5_file and $force < 1) {
                
		return (1,"Cannot locate installed package : " . $package_name);
		
	}
	

	my $pass = 1;
	my @files;

	open (MD5FILE, $md5_file);
	while (<MD5FILE>) {
		chomp;
		my @bits = split(/ /,$_);
		my $file = $bits[0];
		my $md5 = $bits[1];
		my $config_file = 0;
		my $file_end = substr($file, length($archive_root)+1);
		if ( ( substr $file_end, 0, 9 ) eq "cfg/cfg.d" ) {
			$config_file = 1;
		}
		push @files, $file;
		if ( -e $file and !$config_file) {
			my $re_check = md5sum($file);
			if (!($re_check eq $md5)) {
				$pass = 0;
			}
		}
	}
	close (MD5FILE);

	if ($pass != 1 and $force != 1 ) {
	
                return (1,"Warning: Package has changed since install! Use --force to override");

	}  
	
	my $backup_directory = make_backup($repository, $package_name);

	my $rc = 0;
	my $failed_flag = 0;

	foreach my $file (@files) {
		if ( -e $file ) {
			$rc = unlink $file;
			if ($rc != 1) {
				$failed_flag = 1;
			}
		}
	}

	if ($failed_flag != 0) {
		
		install($repository, $backup_directory, 1);

		return (1,"Warning: Failed to remove package! Use --force to override");
			
	}
	
	rmtree($package_path);

	return (0,"Package Successfully Removed");
	

}

sub md5sum
{
	my $file = shift;
	my $digest = "";
	eval{
		open(FILE, $file) or die "Can't find file $file\n";
		my $ctx = Digest::MD5->new;
		$ctx->addfile(*FILE);
		$digest = $ctx->hexdigest;
		close(FILE);
	};
	if($@){
		print $@;
		return "";
	}
	return $digest;
}

1;
