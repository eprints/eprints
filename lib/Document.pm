######################################################################
#
# EPrints Document File class
#
#  Represents the electronic version of the actual document data
#  (not the metadata.)
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

package EPrints::Document;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use EPrints::Database;
use EPrints::EPrint;

use File::Basename;
use File::Path;
use File::Copy;
use Cwd;
use URI::Escape;
use URI::Heuristic;

use strict;

# Field to use for unsupported formats (if archive allows their deposit)
$EPrints::Document::OTHER = "OTHER";

# Digits in generated ID codes (added to EPrints IDs)
my $DIGITS = 2;


## WP1: BAD
sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"docid", type=>"text", required=>1 },

		{ name=>"eprintid", type=>"int", required=>1 },

		{ name=>"format", type=>"datatype", required=>1, datasetid=>"document" },

		{ name=>"formatdesc", type=>"text" },

		{ name=>"language", type=>"datatype", required=>1, datasetid=>"language" },

		{ name=>"security", type=>"datatype", required=>1, datasetid=>"security" },

		{ name=>"main", type=>"text", required=>1 }
	);

}

######################################################################
#
# $doc = new( $session, $doc_id, $known, $eprint )
#
#  Construct a document object corresponding to the given doc ID.
#  If you've already read in the document object's data from the
#  database, you can pass it in as $known. This should be
#  a reference to an array of ALL of the relevant column data.
#
#  $eprint should be the EPrint this document is associated with.
#  Expressing it is optional, but does reduce database accesses.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class, $session, $docid ) = @_;

	return $session->get_db()->get_single( 
		$session->get_archive()->get_dataset( "document" ),
		$docid );
}

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	my $self = {};
	bless $self, $class;
	$self->{data} = $known;
	$self->{dataset} = $session->get_archive()->get_dataset( "document" ),
	$self->{session} = $session;

	return( $self );
}


sub create
{
	my( $session, $eprint ) = @_;
	
	# Generate new doc id
	my $doc_id = _generate_doc_id( $session, $eprint );
	# Make directory on filesystem
	return undef unless _create_directory( $doc_id, $eprint ); 

	my $data = {};
	$session->get_archive()->call( 
			"set_document_defaults", 
			$data,
 			$session,
 			$eprint );
	$data->{docid} = $doc_id;
	$data->{eprintid} = $eprint->get_value( "eprintid" );

	# Make database entry
	my $dataset = $session->get_archive()->get_dataset( "document" );

	my $success = $session->get_db()->add_record(
		$dataset,
		$data );  

	if( $success )
	{
		my $doc = EPrints::Document->new( $session, $doc_id );
		# Make secure area symlink
		my $linkdir = _secure_symlink_path( $eprint );
		$doc->create_symlink( $eprint, $linkdir );
		return $doc;
	}
	else
	{
		return( undef );
	}
}


######################################################################
#
# $success = _create_directory( $id, $eprint )
#
#  Make this Document a directory. $eprint is the EPrint this document
#  is associated with.
#
######################################################################

## WP1: BAD
sub _create_directory
{
	my( $id, $eprint ) = @_;
	
	my $dir = $eprint->local_path()."/".docid_to_path( $eprint->get_session()->get_archive(), $id );

	if( -d $dir )
	{
		$eprint->get_session()->get_archive()->log( "Dir $dir already exists!" );
		return 1;
	}

	# Return undef if dir creation failed. Should always have created 1 dir.
	if(!EPrints::Utils::mkdir($dir))
	{
		$eprint->get_session()->get_archive()->log( "Error creating directory for EPrint ".$eprint->get_value( "eprintid" ).", docid=".$id." ($dir): ".$! );
		return 0;
	}
	else
	{
		return 1;
	}
}

sub create_symlink
{
	my( $self, $eprint, $linkdir ) = @_;

	my $id = $self->get_value( "docid" );

	my $archive = $eprint->get_session()->get_archive();

	my $dir = $eprint->local_path()."/".docid_to_path( $archive, $id );

	unless(-d $linkdir )
	{
		my @created = mkpath( $linkdir, 0, 0775 );

		if( scalar @created == 0 )
		{
			$archive->log( "Error creating symlink target dir for EPrint ".$eprint->get_value( "eprintid" ).", docid=".$id." ($linkdir): ".$! );
			return( 0 );
		}
	}

	my $symlink = $linkdir."/".docid_to_path( $archive, $id );
	if(-e $symlink )
	{
		unlink( $symlink );
	}
	unless( symlink( $dir, $symlink ) )
	{
		$archive->log( "Error creating symlink for EPrint ".$eprint->get_value( "eprintid" ).", docid=".$id." symlink($dir to $symlink): ".$! );
		return( 0 );
	}	

	return( 1 );
}

sub remove_symlink
{
	my( $self, $eprint, $linkdir ) = @_;

	my $id = $self->get_value( "docid" );

	my $archive = $eprint->get_session()->get_archive();

	my $symlink = $linkdir."/".docid_to_path( $archive, $id );

	unless( unlink( $symlink ) )
	{
		$archive->log( "Failed to unlink secure symlink for ".$eprint->get_value( "eprintid" ).", docid=".$id." ($symlink): ".$! );
		return( 0 );
	}
	return( 1 );	
}

#cjg: should this belong to eprint?
sub _secure_symlink_path
{
	my( $eprint ) = @_;

	my $archive = $eprint->get_session()->get_archive();
		
	return( $archive->get_conf( "htdocs_secure_path" )."/".EPrints::EPrint::eprintid_to_path( $eprint->get_value( "eprintid" ) ) );
}

sub docid_to_path
{
	my( $archive, $docid ) = @_;

	$docid =~ m/-(\d+)$/;
	my $id = $1;
	if( !defined $1 )
	{
		$archive->log( "Doc ID did not take expected format: \"".$docid."\"" );
		# Setting id to "badid" is messy, but recoverable. And should
		# be noticed easily enough.
		$id = "badid";
	}
	return $id;
}

######################################################################
#
# $new_id = _generate_doc_id( $session, $eprint )
#
#  Generate an ID for a new document associated with $eprint
#
######################################################################

## WP1: BAD
sub _generate_doc_id
{
	my( $session, $eprint ) = @_;

	my $dataset = $session->get_archive()->get_dataset( "document" );

	my $searchexp = EPrints::SearchExpression->new(
				session=>$session,
				dataset=>$dataset );

	$searchexp->add_field(
		$dataset->get_field( "eprintid" ),
		"PHR:EQ:".$eprint->get_value( "eprintid" ) );
	$searchexp->perform_search();

	my( @docs ) = $searchexp->get_records();

	my $n = 0;
	foreach( @docs )
	{
		my $id = $_->get_value( "docid" );
		$id=~m/-(\d+)$/;
		if( $1 > $n ) { $n = $1; }
	}
	$n = $n + 1;

	return sprintf( "%s-%02d", $eprint->get_value( "eprintid" ), $n );
}


######################################################################
#
# $clone = clone( $eprint )
#
#  Attempt to clone this document. The clone will be associated with
#  the given EPrint.
#
######################################################################

sub clone
{
	my( $self, $eprint ) = @_;
	
	# First create a new doc object
	my $new_doc = EPrints::Document::create( $self->{session}, $eprint );

	return( 0 ) if( !defined $new_doc );
	
	# Copy fields across
	foreach( "format", "formatdesc", "language", "security", "main" )
	{
		$new_doc->set_value( $_, $self->get_value( $_ ) );
	}
	
	# Copy files
	my $rc = system( "cp -a ".$self->local_path()."/* ".$new_doc->local_path() ) & 0xffff;

	# If something's gone wrong...
	if ( $rc!=0 )
	{
		$self->{session}->get_archive()->log( "Error copying from ".$self->local_path()." to ".$new_doc->local_path().": $!" );
		return( undef );
	}

	if( $new_doc->commit() )
	{
		return( $new_doc );
	}
	else
	{
		$new_doc->remove();
		return( undef );
	}
}


######################################################################
#
# $success = remove()
#
#  Attempt to completely delete this document
#
######################################################################

sub remove
{
	my( $self ) = @_;

	# If removing the symlink fails then it's not the end of the 
	# world. We will delete all the files it points to. 

	my $eprint = $self->get_eprint();

	$self->remove_symlink( 
		$self->get_eprint(),
		_secure_symlink_path( $eprint ) );

	# Remove database entry
	my $success = $self->{session}->get_db()->remove(
		$self->{session}->get_archive()->get_dataset( "document" ),
		$self->get_value( "docid" ) );
	

	if( !$success )
	{
		my $db_error = $self->{session}->get_db()->error();
		$self->{session}->get_archive()->log( "Error removing document ".$self->get_value( "docid" )." from database: $db_error" );
		return( 0 );
	}

	# Remove directory and contents
	my $full_path = $self->local_path();
	my $num_deleted = rmtree( $full_path, 0, 0 );

	if( $num_deleted <= 0 )
	{
		$self->{session}->get_archive()->log( "Error removing document files for ".$self->get_value("docid").", path ".$full_path.": $!" );
		$success = 0;
	}

	return( $success );
}


######################################################################
#
# $eprint = get_eprint()
#
#  Returns the EPrint this document is associated with.
#
######################################################################

## WP1: BAD
sub get_eprint
{
	my( $self ) = @_;
	
	# If we have it already just pass it on
	return( $self->{eprint} ) if( defined $self->{eprint} );

	# Otherwise, create object and return
	$self->{eprint} = new EPrints::EPrint( $self->{session},
	                                       undef,
	                                       $self->get_value( "eprintid" ) );
	
	return( $self->{eprint} );
}


######################################################################
#
# $get_url = get_url()
#
#  Return the full URL of the document.
#
######################################################################

sub get_url
{
	my( $self, $staff ) = @_;

	# The $staff param is ignored.

	my $eprint = $self->get_eprint();

	return( undef ) if( !defined $eprint );

	my $archive = $self->{session}->get_archive();

	# Unless this is a public doc in "archive" then the url should
	# point into the secure area. 

	my $basepath;
	if( $self->get_value( "security" ) eq "public"
	 && $eprint->get_dataset()->id() eq "archive" )
	{
		$basepath = $archive->get_conf( "documents_url" );
	}
	else
	{
		$basepath = $archive->get_conf( "secure_url" );
	}
	return $basepath . "/" . 
		sprintf( "%08d", $eprint->get_value( "eprintid" )) . "/" .
		docid_to_path( $archive, $self->get_value( "docid" ) ) . "/" . 
		$self->get_main();
}


######################################################################
#
# $path = local_path()
#
#  Get the full path of the doc on the local filesystem
#
######################################################################

## WP1: BAD
sub local_path
{
	my( $self ) = @_;

	my $eprint = $self->get_eprint();
	
	return( undef ) if( !defined $eprint );
	
	return( $eprint->local_path()."/".docid_to_path( $self->{session}->get_archive(), $self->get_value( "docid" ) ) );
}


######################################################################
#
# %files = files()
#
#  Returns a list of the files associated with this document.
#
######################################################################

## WP1: BAD NEEEEEEEEEEEEEEEEED
sub files
{
	my( $self ) = @_;
	
	my %files;
	_get_files(
		\%files,
		$self->local_path(),
		"" );

	return( %files );
}


######################################################################
#
# %files = _get_files( $root, $dir )
#
#  Recursively get all the files in $dir. Paths are returned relative
#  to $root (i.e. $root is removed from the start of files.)
#
######################################################################

# cjg should this function be in some kind of utils module and
# used by generate_static too?
sub _get_files
{
	my( $files, $root, $dir ) = @_;

	my $fixed_dir = ( $dir eq "" ? "" : $dir . "/" );

	# Read directory contents
	opendir CDIR, $root . "/" . $dir or return( undef );
	my @filesread = readdir CDIR;
	closedir CDIR;

	# Iterate through files
	my $name;
	foreach $name (@filesread)
	{
		if( $name ne "." && $name ne ".." )
		{
			# If it's a directory, recurse
			if( -d $root . "/" . $fixed_dir . $name )
			{
				_get_files( $files, $root, $fixed_dir . $name );
			}
			else
			{
				#my @stats = stat( $root . "/" . $fixed_dir . $name );
				$files->{$fixed_dir.$name} = -s $root . "/" . $fixed_dir . $name;
				#push @files, $fixed_dir . $name;
			}
		}
	}

}


######################################################################
#
# $success = remove_file( $filename )
#
#  Attempt to remove the given file. Give the filename as it is
#  returned by get_files().
#
######################################################################

## WP1: BAD
sub remove_file
{
	my( $self, $filename ) = @_;
	
	# If it's the main file, unset it
	$self->set_value( "main" , undef ) if( $filename eq $self->get_main() );

	my $count = unlink $self->local_path()."/".$filename;
	
	if( $count != 1 )
	{
		$self->{session}->get_archive()->log( "Error removing file $filename for doc ".$self->get_value( "docid" ).": $!" );
	}
	return( $count==1 );
}


######################################################################
#
# $success = remove_all_files()
#
#  Attempt to remove all files associated with this document.
#
######################################################################

## WP1: BAD
sub remove_all_files
{
	my( $self ) = @_;

	my $full_path = $self->local_path()."/*";

	my @to_delete = glob ($full_path);

	my $num_deleted = rmtree( \@to_delete, 0, 0 );

	$self->set_main( undef );

	if( $num_deleted < scalar @to_delete )
	{
		$self->{session}->get_archive()->log( "Error removing document files for ".$self->get_value( "docid" ).", path ".$full_path.": $!" );
		return( 0 );
	}

	return( 1 );
}


######################################################################
#
# set_main( $main_file )
#
#  Sets the main file. Won't affect the database until a commit().
#
######################################################################

## WP1: BAD
sub set_main
{
	my( $self, $main_file ) = @_;
	
	if( defined $main_file )
	{
		# Ensure that the file exists
		my %all_files = $self->files();

		# Set the main file if it does
		$self->set_value( "main", $main_file ) if( defined $all_files{$main_file} );
	}
	else
	{
		# The caller passed in undef, so we unset the main file
		$self->set_value( "main", undef );
	}
}


######################################################################
#
# get_main()
#
#  Gets the main file.
#
######################################################################

## WP1: BAD
sub get_main
{
	my( $self ) = @_;
	
	return( $self->{data}->{main} );
}


######################################################################
#
# set_format( $format )
#
#  Sets format. Won't affect the database until a commit().
#
######################################################################

## WP1: BAD
sub set_format
{
	my( $self, $format ) = @_;
	
	$self->set_value( "format" , $format );
}


######################################################################
#
# set_format_desc( $format_desc )
#
#  Sets the format description.  Won't affect the database until a commit().
#
######################################################################

## WP1: BAD
sub set_format_desc
{
	my( $self, $format_desc ) = @_;
	
	$self->set_value( "format_desc" , $format_desc );
}


######################################################################
#
# $success = upload( $filehandle, $filename )
#
#  uploads the given file into this document
#
######################################################################

## WP1: BAD
sub upload
{
	my( $self, $filehandle, $filename ) = @_;

	# Get the filename. File::Basename isn't flexible enough (setting internal
	# globals in reentrant code very dodgy.)
	my $file = $filename;
	
	$file =~ s/.*\\//;     # Remove everything before a "\" (MSDOS or Win)
	$file =~ s/.*\://;     # Remove everything before a ":" (MSDOS or Win)
	$file =~ s/.*\///;     # Remove everything before a "/" (UNIX)

	$file =~ s/ /_/g;      # Change spaces into underscores

	my( $bytes, $buffer );

	my $out_path = $self->local_path() . "/" . $file;
		
	open OUT, ">$out_path" or return( 0 );
	
	while( $bytes = read( $filehandle, $buffer, 1024 ) )
	{
		print OUT $buffer;
	}

	close OUT;
	
	return( 1 );
}


######################################################################
#
# $success = upload_archive( $filehandle, $filename, $archive_format )
#
#  Uploads the contents of the given archive file.
#
######################################################################

## WP1: BAD
sub upload_archive
{
	my( $self, $filehandle, $filename, $archive_format ) = @_;

	my( $file, $path ) = fileparse( $filename );

	# Grab the archive into a temp file
	$self->upload( $filehandle, $file ) || return( 0 );

	# Get full paths of destination and archive
	my $dest = $self->local_path();
	my $arc_tmp =  $dest . "/" . $file;

	# Do the extraction
	my $rc = $self->{session}->get_archive()->exec( 
			$archive_format, 
			DIR => $dest,
			ARC => $arc_tmp );
	
	# Remove the temp archive
	unlink $arc_tmp;
	
	return( $rc==0 );
}


######################################################################
#
# $success = upload_url( $url_in )
#
#  Attempt to grab stuff from the given URL. Grabbing HTML stuff this
#  way is always problematic, so:
#
#  - Only relative links will be followed
#  - Only links to files in the same directory or subdirectory will
#    be followed
#
######################################################################

## WP1: BAD
sub upload_url
{
	my( $self, $url_in ) = @_;
	
	# Use the URI heuristic module to attempt to get a valid URL, in case
	# users haven't entered the initial http://.
	my $url = URI::Heuristic::uf_uristr( $url_in );

	# save previous dir
	my $prev_dir = cwd();

	# Change directory to destination dir., return with failure if this fails
	unless( chdir $self->local_path() )
	{
		chdir $prev_dir;
		return( 0 );
	}
	
	# Work out the number of directories to cut, so top-level files go in
	# at the top level in the destination dir.
	
	# Count slashes
	my $pos = -1;
	my $count = -1;
	
	do
	{
		$pos = index $url, "/", $pos+1;
		$count++;
	}
	while( $pos >= 0 );
	
	# Assuming http://server/dir/dir/filename, number of dirs to cut is
	# $count - 3.
	my $cut_dirs = $count - 3;
	
	# If the result is less than zero, assume no cut dirs (probably have URL
	# with no trailing slash, an INCORRECT result from URI::Heuristic
	$cut_dirs = 0 if( $cut_dirs < 0 );

	my $rc = $self->{session}->get_archive()->exec( 
			"wget",
			CUTDIRS => $cut_dirs,
			URL => '"'.$url.'"' );
	
	# If something's gone wrong...
	return( 0 ) if ( $rc!=0 );

	# Otherwise set the main file if appropriate
	if( !defined $self->get_main() || $self->get_main() eq "" )
	{
		my $endfile = $url;
		$endfile =~ s/.*\///;
		$self->set_main( $endfile );

		# If it's still undefined, try setting it to index.html or index.htm
		$self->set_main( "index.html" ) unless( defined $self->get_main() );
		$self->set_main( "index.htm" ) unless( defined $self->get_main() );

		# Those are our best guesses, best leave it to the user if still don't
		# have a main file.
	}
	
	return( 1 );
}



######################################################################
#
# $success = commit()
#
#  Commit any changes that have been made to this object to the
#  database.
#
######################################################################

## WP1: BAD
sub commit
{
	my( $self ) = @_;

	my $dataset = $self->{session}->get_archive()->get_dataset( "document" );

	$self->{session}->get_archive()->call( "set_document_automatic_fields", $self );

	my $success = $self->{session}->get_db()->update(
		$dataset,
		$self->{data} );
	
	if( !$success )
	{
		my $db_error = $self->{session}->get_db()->error();
		$self->{session}->get_archive()->log( "Error committing Document ".$self->get_value( "docid" ).": $db_error" );
	}

	return( $success );
}
	


sub validate
{
	my( $self, $for_archive ) = @_;

	my @problems;
	
	# System default checks:
	# Make sure there's at least one file!!
	my %files = $self->files();

	if( scalar keys %files ==0 )
	{
		push @problems, $self->{session}->html_phrase( "lib/document:no_files" );
	}
	elsif( !defined $self->get_main() || $self->get_main() eq "" )
	{
		# No file selected as main!
		push @problems, $self->{session}->html_phrase( "lib/document:no_first" );
	}
		
	# Site-specific checks
	push @problems, $self->{session}->get_archive()->call( 
		"validate_document", 
		$self, 
		$self->{session},
		$for_archive );

	return( \@problems );
}

sub can_view
{
	my( $self, $user ) = @_;

	return $self->{session}->get_archive()->call( 
		"can_user_view_document",
		$self,
		$user );	
}

sub render_value
{
	my( $self, $fieldname, $showall ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );	
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall );
}

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "format" );
}


1;
