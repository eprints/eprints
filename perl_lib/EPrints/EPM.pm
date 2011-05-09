=head1 NAME

EPrints::EPM

=cut

package EPrints::EPM;

use strict;
use File::Path;
use File::Copy;
use Cwd;
use Digest::MD5;

sub unpack_package 
{
	my ( $repository, $app_path, $directory ) = @_;
	
	my $mime_type = $repository->call('guess_doc_type',$repository ,$app_path );

	my $type = "zip";

	if ($mime_type eq "application/x-tar") {
		$type = "targz";
	}
	
	my $rc = $repository->exec($type, DIR => $directory, ARC => $app_path );

	return $rc;

}

sub remove_cache_package
{
	my ( $repository, $package ) = @_;
	
	my $archive_root = $repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/cache/";
	my $cache_package_path = $epm_path . "/" . $package;

	my $rc = rmtree($cache_package_path);
	
	if ($rc < 1) 
	{
		return ('epm_error_remove_cache_failed');
	}
	return ();

}

sub download_package 
{
        my ($repository, $url) = @_;

        my $tmpdir = File::Temp->newdir(CLEANUP=>0);

        my $filepath = $tmpdir."/temp.epm";

	$repository->{config}->{enable_web_imports} = 1;

        my $response = EPrints::Utils::wget($repository, $url, $filepath);

        if($response->is_success){
                return( $filepath );
        }

        return;
}

sub cache_package 
{
	my ($repository, $tmpfile) = @_;

	my $directory = File::Temp->newdir( CLEANUP => 1 );

	my $rc = unpack_package($repository, $tmpfile, $directory);
	if ($rc) {
		return (1,"failed to unpack package");
	}
	
	my $archive_root = $repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/cache/";
	
	if ( !-d $epm_path ) {
		return('epm_error_no_cache_dir');
		#mkpath($epm_path);
	}

	$rc = 1;

	my $spec_file_incoming = _find_spec_file($directory);
	return("epm_error_no_spec_file" ) if (!defined $spec_file_incoming);
	
	my $package_specs = read_spec_file($spec_file_incoming);

	my $cache_package_path = $epm_path . "/" . $package_specs->{package};

	if ( -d $cache_package_path ) {
		rmtree($cache_package_path);
	}
	mkpath($cache_package_path);
        
	if( !-d $cache_package_path )
        {
                return ('epm_error_failed_to_cache_package');
        }
	
	$rc = unpack_package($repository, $tmpfile, $cache_package_path);

	if ($rc) {
		return('epm_error_failed_to_cache_package');
	}
	
}

sub _find_spec_file
{
	my ( $directory ) = @_;

	opendir(PACKAGEDIR, $directory) || return();

	foreach my $file (readdir(PACKAGEDIR))
	{
		if($file =~ /\.spec$/)
		{
			return $directory.'/'.$file;
		}
	}

	return;
} 

sub install
{
	my ($repository, $app_path, $force) = @_;

	my $message;
	my $archive_root = $repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/packages";
	#Set up variables to be used
	my $file_md5s;
	my $backup_directory;

	my $directory = $app_path;
	if ( !-d $directory ) {
		$directory = File::Temp->newdir( CLEANUP => 1 );
		my $rc = unpack_package($repository, $app_path, $directory);
		if ($rc) {
			return ('epm_error_unpack_failed');
		}
	}

	# Find the Package Spec File 

	my $spec_file_incoming = _find_spec_file($directory);
	return('epm_error_no_spec_file' ) if (!defined $spec_file_incoming);
	
	my $new_specs = read_spec_file($spec_file_incoming);
	my $package_name = $new_specs->{package};

	my $package_path = $epm_path . "/" . $package_name;
	my $installed_spec_file = $package_path . "/" . $package_name . ".spec";

	my $old_version;
	my $md5_sums;

	# if the package is already installed...
	if ( -e $installed_spec_file || $force ) {

		my $installed_specs = read_spec_file($installed_spec_file);

		if ($new_specs->{version} lt $installed_specs->{version}) {
			return('epm_error_later_version_installed');
		}
		
		$old_version = $installed_specs->{version};

		$backup_directory = make_backup($repository, $package_name);

		$md5_sums = package_md5s($repository, $package_path);

	}
	
	mkpath($package_path);

	copy($spec_file_incoming, $package_path."/".$package_name.".spec");
	copy($directory."/"."$new_specs->{icon}", $package_path."/"."$new_specs->{icon}");

	my $schema_before = get_current_schema($repository);

	my @package_files = ();
        File::Find::find( {
                no_chdir => 1,
                wanted => sub {
                        return if -d $File::Find::name;
			push @package_files, $File::Find::name;
                },
        }, "$directory" );

	foreach my $filepath (@package_files){

		my $filename = substr($filepath, length($directory));
		open(my $filehandle, "<", $filepath);
		unless( defined( $filehandle ) )
		{
			next;
		}
		close($filehandle);

		$filepath =~ m/[^\/]*$/;
		my $required_path = $archive_root . "/" . substr ($`, length($directory));

		mkpath($required_path);
		
		my $installed_path = $archive_root . $filename;

		if ( -e $installed_path and defined $backup_directory and !$force) {
			# Upgrade the installed file (if it is controlled by the previous version)
			
		# PATRICK what might this be doing?
			if( $md5_sums->{$installed_path} ne md5sum($installed_path) )
			{
#PATRICK this overwrites the config file even if it has changed currently....
				$message = 'epm_warning_config_changed';
				if ( ( substr $filename, 0, 9 ) ne "cfg/cfg.d" ) 
				{
					write_md5s($repository,$package_path,$md5_sums); 
					
					remove($repository, $package_name, 1);
					
					install($repository, $backup_directory, 1);

					return ('epm_error_file_altered');
				} 
			}
		}
			
		# Install the file, all that logic for this:
		copy($filepath, $installed_path);

		# Now some more logic to check it is installed
		# If it isn't failed and remove. 
		# It is is, write the (new) MD5 ready for upgrade/remove.

		if ( !-e $installed_path ) {
			#something went wrong time to pack up and go home...
			write_md5s($repository,$package_path,$md5_sums); 
			remove($repository, $package_name, 1);
			if ( defined $backup_directory) {
				install($repository, $backup_directory, 1);
			}

			return("epm_error_copy_failed");
		} 

		$md5_sums->{$installed_path} = md5sum($installed_path);
	}


	# Write the md5s out to a file. 
	write_md5s($repository,$package_path,$md5_sums); 

	# Check the repository reloads
	my $install_failed = check_install($repository);
	if ($install_failed) {
		remove($repository,$package_name,1);
		return ('epm_error_compilation_failed');
	}

	$repository->load_config();

	# Make any dataset upgrades (this is upgrade safe :) )
	my $schema_after = get_current_schema($repository);
	my $rc = install_dataset_diffs($repository,$schema_before,$schema_after);
	if ( $rc > 0 ) {
		remove($repository,$package_name,1);
		return('epm_error_datasets_failed');
	}


	# Re-read spec file (ensures we have the installed one) 
	my $keypairs = read_spec_file($installed_spec_file);
	my $config_string = $keypairs->{configuration_file};
	my $new_version = $keypairs->{version};
	my $plugin_id = "Screen::".$config_string;
	my $plugin_path = $config_string;
	$plugin_path =~ s/::/\//g;
	$plugin_path = "EPrints/Plugin/Screen/" . $plugin_path . ".pm";

	my $plugin = $repository->plugin( $plugin_id );

	if (defined $plugin) 
	{
		foreach my $inkey(keys %INC) {
			if ($inkey eq $plugin_path) {
				delete $INC{$inkey};
			}
		}

		$repository->load_config();
		
		# TODO: THIS SHOULD REALLY BE MOVED TO BEFORE THE WHOLE INSTALL IS DONE, SHOULD IT BE EXECUTABLE IS ANOTHER THING (may not ever implement)
		# if ($plugin->can( "action_preinst" )) 
		# {
		#	($return,my $preinst_msg) = $plugin->action_preinst();
		#	if ($return < 1 && $return > 0) {
		#		$message = $preinst_msg;
		#	} else {
		#		$message = "Package Install Failed (preinst failed with error: $preinst_msg), package was removed again with message: ";
		#	}
		# }

		# Call Post Install or Upgrade routine.

		if ($plugin->can( "action_postinst" ) and !$old_version) 
		{
			$plugin->action_postinst();
			return( 'epm_error_postinst_failed');
		} 
		
		if ($old_version && $plugin->can( "action_upgrade" )) 
		{
			$plugin->action_upgrade($old_version, $new_version);
			return('epm_error_upgrade_failed');
		}

		# PATRICK im concerned we dont actually remove the package here.....
		return('epm_error_postinst_failed');

	}

	# package installed! message is either a warning or undef for complete success
	return $message;

}

sub command_line_install_package
{
	my ( $repo, $package ) = @_;

	my $app = retrieve_available_epms($repo,undef,$package);

	return 0 if (!defined $app);

	my $url = $app->{epm};

	my $epm_file = download_package($repo,$url);
        
        if (!defined $epm_file) {
                return 0;
        }

        my $message = install($repo, $epm_file);

        return 1 if(!defined $message);
	
	$message =~ /epm_([^_]*)/;
        print $repo->phrase($message) . "\n\n";
	return 0;
}

sub get_current_schema
{
	my( $repo ) = @_;

	my $data = {};

	foreach my $datasetid ( $repo->get_sql_dataset_ids() )
	{
		my $dataset = $repo->dataset( $datasetid );
		$data->{$datasetid}->{dataset} = $dataset;
		foreach my $field ($repo->dataset( $datasetid )->fields)
		{
			next if defined $field->property( "sub_name" );
			$data->{$datasetid}->{fields}->{$field->name} = $field;
		}
	}

	return $data;
}

sub install_dataset_diffs
{
	my ($repo, $before, $after) = @_;
	
	my $db = $repo->get_db();

	my $rc = 0;

	foreach my $datasetid ( keys %$after )
	{
		my $dataset = $after->{$datasetid}->{dataset};
		my $fields = $after->{$datasetid}->{fields};

		if( !defined $before->{$datasetid} && !$db->has_dataset( $dataset ) )
		{
			$rc = $db->create_dataset_tables( $dataset );
			next;
		}

		foreach my $fieldid ( keys %$fields )
		{
			next if( defined $before->{$datasetid}->{fields}->{$fieldid} );
			$rc = $db->add_field( $dataset, $fields->{$fieldid} );
		}
	}
	
	return $rc;

}

sub remove_dataset_diffs
{
	my ($repo, $before, $after) = @_;
	
	my $db = $repo->get_db();

	my $rc = 0;

	foreach my $datasetid (keys %$before)
	{
		my $dataset = $before->{$datasetid}->{dataset};
		my $fields = $before->{$datasetid}->{fields};

		if( !defined $after->{$datasetid} && $db->has_dataset( $dataset ) )
		{
			$rc = $db->drop_dataset_tables( $dataset );
			next;
		}

		foreach my $fieldid ( keys %$fields )
		{
			next if( defined $after->{$datasetid}->{fields}->{$fieldid} );
			$rc = $db->remove_field( $dataset, $fields->{$fieldid} );
		}
	}
	
	return $rc;

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

sub package_md5s
{
	my ( $repository, $directory) = @_;

	my $md5_sums;

	open (MD5FILE, $directory . "/checksums");
	while (<MD5FILE>) {
		chomp;
		my @bits = split(/ /,$_);
		$md5_sums->{$bits[0]} = $bits[1];
		#$file =~ s/$archive_root//;
	}
	close (MD5FILE);
	
	return $md5_sums;

} 

sub write_md5s 
{
	my ( $repository, $package_path, $file_md5s ) = @_;

	my $md5_file = $package_path . "/checksums";

	open (MD5FILE, ">$md5_file");

	foreach my $file (keys %{$file_md5s})
	{
		print MD5FILE $file." ".$file_md5s->{$file}."\n";;
	}

	close(MD5FILE);
}

sub make_backup 
{
	my ($repository, $package_name) = @_;
	
	my $backup_directory = File::Temp->newdir( CLEANUP => 1 );

	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/packages/";
	my $package_path = $epm_path . "/" . $package_name;
	
	#TODO make this copy everything recusively
	my $spec_file = $package_path . "/" . $package_name . ".spec";
	my $md5_file = $package_path . "/checksums";
	my $datasets_file = $package_path . "/dataset_changes";

	copy($package_path . "/" . $package_name . ".spec", $backup_directory . "/" . $package_name . ".spec");
	copy($package_path . "/checksums", $backup_directory . "/checksums");
	if ( -e $datasets_file) {
		copy($package_path . "/dataset_changes", $backup_directory . "/dataset_changes");
	}
	#END TODO

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
	my $dataset_file = $package_path . "/dataset_changes";

	if ( !-e $spec_file and $force < 1) {
                
		return ('epm_error_no_spec_file');
		
	}
			
	$repository->load_config();
	
	my $package_specs = EPrints::EPM::read_spec_file($spec_file);
	my $plugin_id = "Screen::".$package_specs->{configuration_file};

	my $plugin = $repository->plugin( $plugin_id );

	if (defined $plugin) 
	{
#PATRICK - Not at all happy about this prerm return set is way to complex
		my $message;
		my $return = 0;
		if ($plugin->can( "action_prerm" )) 
		{
			($return,my $prerm_msg) = $plugin->action_prerm();
			$message = $prerm_msg;
			if ( $return >= 1 ) 
			{
				return('epm_error_prerm_failed');
			}
		} 
		if (!$return && $plugin->can( "action_removed_status" ))
		{
			$return = $plugin->action_removed_status();
			$message = "Package cannot be removed as the packages pre-remove script failed.";
		}
		if ($return > 0) {
			return ($return,$message);
		}
	} 

	my $md5_sums = package_md5s($repository, $package_path); 

	foreach my $file (keys %{$md5_sums})
	{
		if($md5_sums->{$file} eq md5sum($file) && ( substr $file, 0, 9 ) eq "cfg/cfg.d" )
		{
			return('epm_error_package_changed');
		}
	}
	
	my $backup_directory = make_backup($repository, $package_name);
	
	my $schema_before = get_current_schema($repository);

	my $remove_auto = 0;

	foreach my $file (keys %{$md5_sums})
	{
		if ( ! -e $file ) { next ;}

		if (index($file,"static/style/") > 0) {
			$remove_auto = 1;				
		}

		my $rc = unlink $file;
		if ($rc != 1) {
			install($repository, $backup_directory, 1);

			return ('epm_error_remove_failed');
		}
	}
	
	if ($remove_auto > 0) {
		remove_auto($repository);
	}

	my $installed = check_install($repository);
	
	$repository->load_config();
	my $schema_after = get_current_schema($repository);
	remove_dataset_diffs($repository,$schema_before,$schema_after);

	rmtree($package_path);

	return ();

}

sub remove_auto {
	
	my ( $repository ) = @_;

	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $style_path = $archive_root . "/html/en/style/";

	rmtree($style_path);
	
	my $javascript_path = $archive_root . "/html/en/javascript/";

	rmtree($javascript_path);
	
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


sub is_installed
{
	my ($repo, $package_name) = @_;

	my $installed_epms = get_installed_epms($repo);

	foreach my $app(@$installed_epms) 
	{
		return 1 if ($app->{'package'} eq $package_name);
	}

	return 0;
}

sub get_installed_epms 
{
	my ($self, $repository) = @_;

	if (!defined $repository)
	{
		$repository = $self;
	}

	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/packages/";

	my $installed_epms = get_local_epms($epm_path);

	return $installed_epms;

}

sub get_cached_epms 
{
	my ($repository) = @_;

	my $archive_root = $repository->get_repository->get_conf("archiveroot");
	my $epm_path = $archive_root . "/var/epm/cache/";

	my $cached_epms = get_local_epms($epm_path);

	return $cached_epms;

}

sub get_local_epms 
{
	my ($epm_path) = @_;

	if ( !-d $epm_path ) {
		return undef;
	}

	my @packages;
	my $rc;

	opendir(my $dh, $epm_path) || die "failed";
	while(defined(my $fn = readdir $dh)) {
		my $short = substr $fn, 0 , 1;
		my $package_name = $fn;

		next if ($short eq ".");

		my $spec_path = $epm_path . $fn . "/" . $package_name . ".spec";
		my $keypairs = EPrints::EPM::read_spec_file($spec_path);
		push @packages, $keypairs;
	}
	closedir ($dh);

	return \@packages;

}

sub get_epm_updates 
{
        my ( $installed_epms, $store_epms ) = @_;

        my @apps;

        foreach my $app (@$installed_epms) {
                foreach my $store_app (@$store_epms) {
			my $app_name = $app->{package};
			my $store_app_name = $store_app->{package};
                        next if ($app_name ne $store_app_name);
			next if !($store_app->{version} gt $app->{version});
                      	push @apps, $store_app;
                }
        }

        if ( scalar @apps < 1) {
                return undef;
        }

        return \@apps;
}

sub retrieve_available_epms
{
	my( $repository, $id, $package_name) = @_;

	my @apps;

	my $sources = $repository->config( "epm_sources" );
	$sources = [] if !defined $sources;

	SOURCE: foreach my $epm_source (@$sources) {

		my $url = $epm_source->{base_url} . "/cgi/search/advanced/export__XML.xml?screen=Public%3A%3AEPrintSearch&_action_export=1&output=XML&exp=0|1|-date%2Fcreators_name%2Ftitle|archive|-|type%3Atype%3AANY%3AEQ%3Aepm|-|eprint_status%3Aeprint_status%3AALL%3AEQ%3Aarchive|metadata_visibility%3Ametadata_visibility%3AALL%3AEX%3Ashow";

		my $tmp = File::Temp->new;

		$url = URI->new( $url )->canonical;
		my $ua = LWP::UserAgent->new;
		my $r = $ua->get( $url, ":content_file" => "$tmp" );

		seek($tmp,0,0);

		my $xml = eval { $repository->xml->parse_file( "$tmp" ) };
		next SOURCE if $@;

		EPRINT: foreach my $node ($xml->documentElement->getElementsByTagName( "eprint" ))
		{
			my $app = get_app_from_eprint( $repository, $node );

			next EPRINT if !defined $app;
			my $count = 0;
			my $skip;
			foreach my $lapp(@apps) {
				splice(@apps,$count,1) if ($lapp->{package} eq $app->{package} && $lapp->{version} lt $app->{version});
				$skip = 1 if ($lapp->{package} eq $app->{package} && $lapp->{version} gt $app->{version});
				$count++;
			}
			push @apps, $app unless $skip;
		}
	}
	foreach my $app(@apps) {
		return $app if defined $id && $id eq $app->{id};
		return $app if defined $package_name && $package_name eq $app->{package};
	}

	return undef if defined $id;
	return undef if defined $package_name;

	return \@apps;
}

sub get_app_from_eprint
{
	my( $repo, $node ) = @_;

	my $epdata = EPrints::DataObj::EPM->xml_to_epdata( $repo, $node );

	return undef if !defined $epdata->{eprintid};

	my $app = {};
	$app->{id} = $epdata->{eprintid};
	$app->{title} = $epdata->{title};
	$app->{uri} = $epdata->{id};
	$app->{date} = $epdata->{datestamp};
	$app->{package} = $epdata->{package_name};
	$app->{description} = $epdata->{abstract};
	$app->{version} = $epdata->{package_version};

	my $match_id;
	foreach my $document (@{$epdata->{documents}})
	{
		my $content = $document->{content};
		$content = "" if !defined $content;
		my $format = $document->{format};
		$format = "" if !defined $format;
		if( $format eq "archive/zip+eprints_package" )
		{
			$app->{epm} = $document->{files}->[0]->{url};
		
			$match_id = $document->{docid};
			next;
		} 

		foreach my $relation (@{$document->{relation}})
		{
			next if $relation->{type} !~ m# ^http://eprints\.org/relation/is(\w+)ThumbnailVersionOf$ #x;
			my $type = $1;
			next if $relation->{uri} !~ m# ^/id/document/$match_id$ #x;
			my $thumb_url = $document->{files}->[0]->{url};
			if ($type eq "preview") {
				$app->{'icon_url'} = $thumb_url;
			}
			$app->{'thumbnail_'.$type} = $thumb_url;
		}
		
	}

	return $app;
}

sub verify_app
{
	my ( $app ) = @_;

	my $message;

	if (!defined $app->{package}) { $message .= " package "; }
	if (!defined $app->{version}) { $message .= " version "; }
	if (!defined $app->{title}) { $message .= " title "; }
	if (!defined $app->{icon}) { $message .= " icon "; }
	if (!defined $app->{description}) { $message .= " package description "; }
	if (!defined $app->{creator}) { $message .= " creator "; }

	if (defined $message) {
		return (0, $message);
	}

	return (1,undef);

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

