######################################################################
#
# EPrints::DataObj::Document
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

B<EPrints::DataObj::Document> - A single format of a record.

=head1 DESCRIPTION

Document represents a single format of an EPrint (eg. PDF) - the 
actual file(s) rather than the metadata.

This class is a subclass of DataObj, with the following metadata fields: 

=over 4

=item docid (text)

The unique ID of the document. This is a string of the format 123-02
where the first number is the eprint id and the second is the document
number within that eprint.

This should probably have been and "int" but isn't. I later version
of EPrints may change this.

=item eprintid (itemref)

The id number of the eprint to which this document belongs.

=item format (namedset)

The format of this document. One of the types of the dataset "document".

=item formatdesc (text)

An additional description of this document. For example the specific version
of a format.

=item language (namedset)

The ISO ID of the language of this document. The default configuration of
EPrints does not set this.

=item security (namedset)

The security type of this document - who can view it. One of the types
of the dataset "security".

=item main (text)

The file which we should link to. For something like a PDF file this is
the only file. For an HTML document with images it would be the name of
the actual HTML file.

=item documents (subobject, multiple)

A virtual field which represents the list of Documents which are
part of this record.

=back

Document has all the methods of dataobj with the addition of the following.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::DataObj::Document;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::Search;

use File::Basename;
use File::Copy;
use Cwd;
use Fcntl qw(:DEFAULT :seek);

use URI::Heuristic;

use strict;

# Field to use for unsupported formats (if repository allows their deposit)
$EPrints::DataObj::Document::OTHER = "OTHER";

######################################################################
=pod

=item $metadata = EPrints::DataObj::Document->get_system_field_info

Return an array describing the system metadata of the Document dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"docid", type=>"int", required=>1, import=>0, show_in_html=>0, can_clone=>0 },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0, show_in_html=>0 },

		{ name=>"files", type=>"file", multiple=>1 },

		{ name=>"eprintid", type=>"itemref",
			datasetid=>"eprint", required=>1, show_in_html=>0 },

		{ name=>"pos", type=>"int", required=>1 },

		{ name=>"format", type=>"namedset", required=>1, input_rows=>1,
			set_name=>"document" },

		{ name=>"formatdesc", type=>"text", input_cols=>40 },

		{ name=>"language", type=>"namedset", required=>1, input_rows=>1,
			set_name=>"languages" },

		{ name => "permission_group", multiple => 1, type => "namedset", 
			set_name => "permission_group", },

		{ name=>"security", type=>"namedset", required=>1, input_rows=>1,
			set_name=>"security" },

		{ name=>"license", type=>"namedset", required=>0, input_rows=>1,
			set_name=>"licenses" },

		{ name=>"main", type=>"set", required=>1, options=>[], input_rows=>1,
			input_tags=>\&main_input_tags,
			render_option=>\&main_render_option },

		{ name=>"date_embargo", type=>"date", required=>0,
			min_resolution=>"year" },	

	);

}

sub main_input_tags
{
	my( $session, $object ) = @_;

	my %files = $object->files;

	my @tags;
	foreach ( sort keys %files ) { push @tags, $_; }

	return( @tags );
}

sub main_render_option
{
	my( $session, $option ) = @_;

	return $session->make_text( $option );
}



######################################################################
=pod

=item $thing = EPrints::DataObj::Document->new( $session, $docid )

Return the document with the given $docid, or undef if it does not
exist.

=cut
######################################################################

sub new
{
	my( $class, $session, $docid ) = @_;

	return $session->get_database->get_single( 
		$session->get_repository->get_dataset( "document" ),
		$docid );
}

sub doc_with_eprintid_and_pos
{
	my( $session, $eprintid, $pos ) = @_;
	
	my $document_ds = $session->get_repository->get_dataset( "document" );

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$document_ds );

	$searchexp->add_field(
		$document_ds->get_field( "eprintid" ),
		$eprintid );
	$searchexp->add_field(
		$document_ds->get_field( "pos" ),
		$pos );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records(0,1);
	$searchexp->dispose();
	
	return $records[0];
}

######################################################################
=pod

=item $doc = EPrints::DataObj::Document->new_from_data( $session, $data )

Construct a new EPrints::DataObj::Document based on the ref to a hash of metadata.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "document" ) );
}



######################################################################
# =pod
# 
# =item $doc = EPrints::DataObj::Document::create( $session, $eprint )
# 
# Create and return a new Document belonging to the given $eprint object, 
# get the initial metadata from set_document_defaults in the configuration
# for this repository.
# 
# Note that this creates the document in the database, not just in memory.
# 
# =cut
######################################################################

sub create
{
	my( $session, $eprint ) = @_;

	return EPrints::DataObj::Document->create_from_data( 
		$session, 
		{ eprintid=>$eprint->get_id },
		$session->get_repository->get_dataset( "document" ) );
}

######################################################################
# 
# $eprintid = EPrints::DataObj::Document::_create_id( $session )
#
#  Create a new Document ID code. 
#
######################################################################

sub _create_id
{
	my( $session ) = @_;
	
	return $session->get_database->counter_next( "documentid" );

}

######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj::Document->create_from_data( $session, $data, $dataset )
# 
# Returns undef if a bad (or no) subjectid is specified.
# 
# Otherwise calls the parent method in EPrints::DataObj.
# 
# =cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;
       
	my $eprintid = $data->{eprintid}; 
	my $eprint = delete $data->{eprint};

	my $document = $class->SUPER::create_from_data( $session, $data, $dataset );

	return unless defined $document;

	# Hint for get_eprint()
	$document->{eprint} = $eprint;

	$document->set_under_construction( 1 );

	my $dir = $document->local_path();

	if( -d $dir )
	{
		$session->get_repository->log( "Dir $dir already exists!" );
	}
	elsif(!EPrints::Platform::mkdir($dir))
	{
		$session->get_repository->log( "Error creating directory for EPrint $eprintid, docid=".$document->get_value( "docid" )." ($dir): ".$! );
		return undef;
	}


	if( defined $data->{files} )
	{
		foreach my $filedata ( @{$data->{files}} )
		{
			if( defined $filedata->{data} )
			{
				my $srcfile = $filedata->{data};		
				$srcfile =~ s/^\s+//;
				$srcfile =~ s/\s+$//;
				$document->add_file( $srcfile, $filedata->{filename}, 1 );	
			}
			elsif( defined $filedata->{url} )
			{
				my $tmpfile = File::Temp->new;

				my $r = EPrints::Utils::wget( $session, $filedata->{url}, $tmpfile );
				if( $r->is_success )
				{
					# upload fseeks to zero
					$document->upload( $tmpfile, $filedata->{filename}, 1 );	
				}
				else
				{
					$session->get_repository->log( "Failed to retrieve $filedata->{url}: " . $r->code . " " . $r->message );
				}
			}
		}
	}

	$document->set_under_construction( 0 );

	return $document;
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::Document->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $eprint = EPrints::DataObj::EPrint->new( $session, $data->{eprintid} );

	$data->{docid} = $session->get_database->counter_next( "documentid" );

	$data->{pos} = $session->get_database->next_doc_pos( $data->{eprintid} );

	$data->{rev_number} = 1;

	$session->get_repository->call( 
			"set_document_defaults", 
			$data,
 			$session,
			$eprint );

	return $data;
}









######################################################################
=pod

=item $newdoc = $doc->clone( $eprint )

Attempt to clone this document. Both the document metadata and the
actual files. The clone will be associated with the given EPrint.

=cut
######################################################################

sub clone
{
	my( $self, $eprint ) = @_;
	
	# First create a new doc object
	my $new_doc = $self->{dataset}->create_object( $self->{session},
		{ eprintid=>$eprint->get_id } );

	return( 0 ) if( !defined $new_doc );
	
	# Copy fields across
	foreach( "format", "formatdesc", "language", "security", "main" )
	{
		$new_doc->set_value( $_, $self->get_value( $_ ) );
	}
	
	# Copy files
	
	my $repository = $self->{session}->get_repository;
	
	my $rc = $repository->exec( "cpall", SOURCE=>$self->local_path(), TARGET=>$new_doc->local_path() ); 

	# If something's gone wrong...
	if ( $rc!=0 )
	{
		$repository->log( "Error copying from ".$self->local_path()." to ".$new_doc->local_path().": $!" );
		return( undef );
	}

	if( $new_doc->commit() )
	{
		$new_doc->files_modified;
		return( $new_doc );
	}
	else
	{
		$new_doc->remove();
		return( undef );
	}
}


######################################################################
=pod

=item $success = $doc->remove

Attempt to completely delete this document

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	my $eprint = $self->get_eprint();

	# Remove database entry
	my $success = $self->{session}->get_database->remove(
		$self->{session}->get_repository->get_dataset( "document" ),
		$self->get_value( "docid" ) );
	

	if( !$success )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( "Error removing document ".$self->get_value( "docid" )." from database: $db_error" );
		return( 0 );
	}

	# Remove directory and contents
	my $full_path = $self->local_path();
	my $ok = EPrints::Utils::rmtree( $full_path );

	if( !$ok )
	{
		$self->{session}->get_repository->log( "Error removing document files for ".$self->get_value("docid").", path ".$full_path.": $!" );
		$success = 0;
	}

	$self->remove_thumbnails;

	return( $success );
}


######################################################################
=pod

=item $eprint = $doc->get_eprint

Return the EPrint this document is associated with.

=cut
######################################################################

sub get_eprint
{
	my( $self ) = @_;
	
	# If we have it already just pass it on
	return( $self->{eprint} ) if( defined $self->{eprint} );

	# Otherwise, create object and return
	$self->{eprint} = new EPrints::DataObj::EPrint( 
		$self->{session},
		$self->get_value( "eprintid" ) );
	
	return( $self->{eprint} );
}


######################################################################
=pod

=item $url = $doc->get_baseurl( [$staff] )

Return the base URL of the document. Overrides the stub in DataObj.
$staff is currently ignored.

=cut
######################################################################

sub get_baseurl
{
	my( $self ) = @_;

	# The $staff param is ignored.

	my $eprint = $self->get_eprint();

	return( undef ) if( !defined $eprint );

	my $repository = $self->{session}->get_repository;

	my $docpath = $self->get_value( "pos" );

	return $eprint->url_stem.$docpath.'/';
}

######################################################################
=pod

=item $boolean = $doc->is_public()

True if this document has no security set and is in the live archive.

=cut
######################################################################

sub is_public
{
	my( $self ) = @_;

	my $eprint = $self->get_eprint;

	return 0 if( $self->get_value( "security" ) ne "public" );

	return 0 if( $eprint->get_value( "eprint_status" ) ne "archive" );

	return 1;
}

######################################################################
=pod

=item $url = $doc->get_url( [$file] )

Return the full URL of the document. Overrides the stub in DataObj.

If file is not specified then the "main" file is used.

=cut
######################################################################

sub get_url
{
	my( $self, $file ) = @_;

	$file = $self->get_main unless( defined $file );

	# just in case we don't *have* a main part yet.
	return $self->get_baseurl unless( defined $file );

	# unreserved characters according to RFC 2396
	$file =~ s/([^-_\.!~\*'\(\)A-Za-z0-9])/sprintf('%%%02X',ord($1))/ge;
	
	return $self->get_baseurl.$file;
}


######################################################################
=pod

=item $path = $doc->local_path

Return the full path of the directory where this document is stored
in the filesystem.

=cut
######################################################################

sub local_path
{
	my( $self ) = @_;

	my $eprint = $self->get_eprint();

	if( !defined $eprint )
	{
		$self->{session}->get_repository->log(
			"Document ".$self->get_id." has no eprint (eprintid is ".$self->get_value( "eprintid" )."!" );
		return( undef );
	}	
	
	return( $eprint->local_path()."/".sprintf( "%02d", $self->get_value( "pos" ) ) );
}


######################################################################
=pod

=item %files = $doc->files

Return a hash, the keys of which are all the files belonging to this
document (relative to $doc->local_path). The values are the sizes of
the files, in bytes.

=cut
######################################################################

sub files
{
	my( $self ) = @_;
	
	my %files;

	my $root = $self->local_path();
	if( defined $root )
	{
		_get_files( \%files, $root, "" );
	}

	return( %files );
}


# cjg should this function be in some kind of utils module and
# used by generate_static too?
######################################################################
# 
# %files = EPrints::DataObj::Document::_get_files( $files, $root, $dir )
#
#  Recursively get all the files in $dir. Paths are returned relative
#  to $root (i.e. $root is removed from the start of files.)
#
######################################################################

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
=pod

=item $success = $doc->remove_file( $filename )

Attempt to remove the given file. Give the filename as it is
returned by get_files().

=cut
######################################################################

sub remove_file
{
	my( $self, $filename ) = @_;
	
	# If it's the main file, unset it
	$self->set_value( "main" , undef ) if( $filename eq $self->get_main() );

	my $count = unlink $self->local_path()."/".$filename;
	
	if( $count != 1 )
	{
		$self->{session}->get_repository->log( "Error removing file $filename for doc ".$self->get_value( "docid" ).": $!" );
	}

	$self->files_modified;

	return( $count==1 );
}


######################################################################
=pod

=item $success = $doc->remove_all_files

Attempt to remove all files associated with this document.

=cut
######################################################################

sub remove_all_files
{
	my( $self ) = @_;

	my $full_path = $self->local_path()."/*";

	my @to_delete = glob ($full_path);

	my $ok = EPrints::Utils::rmtree( \@to_delete );

	$self->set_main( undef );

	if( !$ok )
	{
		$self->{session}->get_repository->log( "Error removing document files for ".$self->get_value( "docid" ).", path ".$full_path.": $!" );
		return( 0 );
	}

	$self->files_modified;

	return( 1 );
}


######################################################################
=pod

=item $doc->set_main( $main_file )

Sets the main file. Won't affect the database until a $doc->commit().

=cut
######################################################################

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
=pod

=item $filename = $doc->get_main

Return the name of the main file in this document.

=cut
######################################################################

sub get_main
{
	my( $self ) = @_;
	
	return( $self->{data}->{main} );
}


######################################################################
=pod

=item $doc->set_format( $format )

Set format. Won't affect the database until a commit(). Just an alias 
for $doc->set_value( "format" , $format );

=cut
######################################################################

sub set_format
{
	my( $self, $format ) = @_;
	
	$self->set_value( "format" , $format );
}


######################################################################
=pod

=item $doc->set_format_desc( $format_desc )

Set the format description.  Won't affect the database until a commit().
Just an alias for
$doc->set_value( "format_desc" , $format_desc );

=cut
######################################################################

sub set_format_desc
{
	my( $self, $format_desc ) = @_;
	
	$self->set_value( "format_desc" , $format_desc );
}


######################################################################
=pod

=item $success = $doc->upload( $filehandle, $filename, [$preserve_path] )

Upload the contents of the given file handle into this document as
the given filename.

if $preserve_path then make any subdirectories needed, otherwise place
this in the top level.

=cut
######################################################################

sub upload
{
	my( $self, $filehandle, $filename, $preserve_path ) = @_;

	# Get the filename. File::Basename isn't flexible enough (setting 
	# internal globals in reentrant code very dodgy.)

	my $repository = $self->{session}->get_repository;
	if( $filename =~ m/^~/ )
	{
		$repository->log( "Bad filename for file '$filename' in document: starts with ~ (will not add)\n" );
		return 0;
	}
	if( $filename =~ m/\/~/ )
	{
		$repository->log( "Bad filename for file '$filename' in document: contains /~ (will not add)\n" );
		return 0;
	}
	if( $filename =~ m/\/\.\./ )
	{
		$repository->log( "Bad filename for file '$filename' in document: contains /.. (will not add)\n" );
		return 0;
	}
	if( $filename =~ m/^\.\./ )
	{
		$repository->log( "Bad filename for file '$filename' in document: starts with .. (will not add)\n" );
		return 0;
	}
	if( $filename =~ m/^\// )
	{
		$repository->log( "Bad filename for file '$filename' in document: starts with slash (will not add)\n" );
		return 0;
	}
	my $out_file = $self->local_path() . "/" . sanitise( $filename );
	if( $preserve_path )
	{
		if( $filename=~m/^(.*)\/([^\/]+)$/ )
		{
			EPrints::Platform::mkdir( $self->local_path()."/".$1 );
		}
		$out_file = $self->local_path() . "/" . $filename;
	}

	seek( $filehandle, 0, SEEK_SET );

	my $size = 0;
	my $buffer;	
	open OUT, ">$out_file" or return( 0 );
	binmode( OUT );
	while( my $bytes = read( $filehandle, $buffer, 1024 ) )
	{
		$size += $bytes;
		print OUT $buffer;
	}
	close OUT;

	if( $size == 0 )
	{
		unlink( $out_file );
		return 0;
	}

	$self->files_modified;
	
	return( 1 );
}

######################################################################
=pod

=item $success = $doc->add_file( $file, $filename, [$preserve_path] )

$file is the full path to a file to be added to the document, with
name $filename.

If $preserve_path then keep the filename as is (including subdirs and
spaces)

=cut
######################################################################

sub add_file
{
	my( $self, $file, $filename, $preserve_path ) = @_;

	my $fh;
	open( $fh, $file ) or return( 0 );
	binmode( $fh );
	my $rc = $self->upload( $fh, $filename, $preserve_path );
	close $fh;

	return $rc;
}

######################################################################
=pod

=item $cleanfilename = sanitise( $filename )

Return just the filename (no leading path) and convert any naughty
characters to underscore.

=cut
######################################################################

sub sanitise 
{
	my( $filename ) = @_;
	$filename =~ s/.*\\//;     # Remove everything before a "\" (MSDOS or Win)
	$filename =~ s/.*\///;     # Remove everything before a "/" (UNIX)

	$filename =~ s/ /_/g;      # Change spaces into underscores

	return $filename;
}

######################################################################
=pod

=item $success = $doc->upload_archive( $filehandle, $filename, $archive_format )

Upload the contents of the given archive file. How to deal with the 
archive format is configured in SystemSettings. 

(In case the over-loading of the word "archive" is getting confusing, 
in this context we mean ".zip" or ".tar.gz" archive.)

=cut
######################################################################

sub upload_archive
{
	my( $self, $filehandle, $filename, $archive_format ) = @_;

	my $file = $self->local_path.'/'.$filename;

	# Grab the archive into a temp file
	$self->upload( 
		$filehandle, 
		$filename ) || return( 0 );

	my $rc = $self->add_archive( 
		$file,
		$archive_format );

	# Remove the temp archive
	unlink $file;

	return $rc;
}

######################################################################
=pod

=item $success = $doc->add_archive( $file, $archive_format )

$file is the full path to an archive file, eg. zip or .tar.gz 

This function will add the contents of that archive to the document.

=cut
######################################################################

sub add_archive
{
	my( $self, $file, $archive_format ) = @_;

	# Do the extraction
	my $rc = $self->{session}->get_repository->exec( 
			$archive_format, 
			DIR => $self->local_path,
			ARC => $file );
	
	$self->files_modified;

	return( $rc==0 );
}


######################################################################
=pod

=item $success = $doc->upload_url( $url )

Attempt to grab stuff from the given URL. Grabbing HTML stuff this
way is always problematic, so (by default): only relative links will 
be followed and only links to files in the same directory or 
subdirectory will be followed.

This (by default) uses wget. The details can be configured in
SystemSettings.

=cut
######################################################################

sub upload_url
{
	my( $self, $url_in ) = @_;
	
	# Use the URI heuristic module to attempt to get a valid URL, in case
	# users haven't entered the initial http://.
	my $url = URI::Heuristic::uf_uristr( $url_in );

	# save previous dir
	my $prev_dir = getcwd();

	# Change directory to destination dir., return with failure if this 
	# fails.
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

	my $rc = $self->{session}->get_repository->exec( 
			"wget",
			CUTDIRS => $cut_dirs,
			URL => $url );
	
	chdir $prev_dir;

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
	
	$self->files_modified;

	return( 1 );
}


######################################################################
=pod

=item $success = $doc->commit

Commit any changes that have been made to this object to the
database.

Calls "set_document_automatic_fields" in the ArchiveConfig first to
set any automatic fields that may be needed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "document" );

	$self->{session}->get_repository->call( "set_document_automatic_fields", $self );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	if( $self->{non_volatile_change} )
	{
		$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	
	}

	$self->tidy;
	my $success = $self->{session}->get_database->update(
		$dataset,
		$self->{data} );
	
	if( !$success )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( "Error committing Document ".$self->get_value( "docid" ).": $db_error" );
	}

	$self->queue_changes;

	unless( !defined $self->{eprint} || $self->{eprint}->under_construction )
	{
		# cause a new new revision of the parent eprint.
		$self->get_eprint->commit( 1 );
	}
	
	return( $success );
}
	



	


######################################################################
=pod

=item $problems = $doc->validate( [$for_archive] )

Return an array of XHTML DOM objects describing validation problems
with the entire document, including the metadata and repository config
specific requirements.

A reference to an empty array indicates no problems.

=cut
######################################################################

sub validate
{
	my( $self, $for_archive ) = @_;

	return [] if $self->get_eprint->skip_validation;

	my @problems;

	unless( EPrints::Utils::is_set( $self->get_type() ) )
	{
		# No type specified
		my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{session}->html_phrase( 
					"lib/document:no_type",
					fieldname=>$fieldname );
	}
	
	# System default checks:
	# Make sure there's at least one file!!
	my %files = $self->files();

	if( scalar keys %files ==0 )
	{
		my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{session}->html_phrase( "lib/document:no_files", fieldname=>$fieldname );
	}
	elsif( !defined $self->get_main() || $self->get_main() eq "" )
	{
		# No file selected as main!
		my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{session}->html_phrase( "lib/document:no_first", fieldname=>$fieldname );
	}
		
	# Site-specific checks
	push @problems, $self->{session}->get_repository->call( 
		"validate_document", 
		$self, 
		$self->{session},
		$for_archive );

	return( \@problems );
}


######################################################################
#
# $boolean = $doc->user_can_view( $user )
#
# Return true if this documents security settings allow the given user
# to view it.
#
######################################################################

sub user_can_view
{
	my( $self, $user ) = @_;

	if( !defined $user )
	{
		$self->{session}->get_repository->log( '$doc->user_can_view called with undefined $user object.' );
		return( 0 );
	}

	my $result = $self->{session}->get_repository->call( 
		"can_user_view_document",
		$self,
		$user );	

	return( 1 ) if( $result eq "ALLOW" );
	return( 0 ) if( $result eq "DENY" );

	$self->{session}->get_repository->log( "Response from can_user_view_document was '$result'. Only ALLOW, DENY are allowed." );
	return( 0 );

}


######################################################################
=pod

=item $type = $doc->get_type

Return the type of this document.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "format" );
}

######################################################################
=pod

=item $doc->files_modified

This method does all the things that need doing when a file has been
modified.

=cut
######################################################################

sub files_modified
{
	my( $self ) = @_;

	$self->rehash;

	$self->{session}->get_database->index_queue( 
		$self->get_eprint->get_dataset->id,
		$self->get_eprint->get_id,
		$EPrints::Utils::FULLTEXT );

	# remove the now invalid cache of words from this document
	unlink $self->words_file if( -e $self->words_file );

	# nb. The "main" part is not automatically calculated when
	# the item is under contruction. This means bulk imports 
	# will have to set the name themselves.
	unless( $self->under_construction )
	{

		# Pick a file to be the one that gets linked. There will 
		# usually only be one, if there's more than one then this
		# uses the first alphabetically.
		if( !$self->get_value( "main" ) )
		{
			my %files = $self->files;
			my @filenames = sort keys %files;
			if( scalar @filenames ) 
			{
				$self->set_value( "main", $filenames[0] );
			}
		}
	
		$self->commit( 1 );
	}

	$self->make_thumbnails;
	if( $self->{session}->get_repository->can_call( "on_files_modified" ) )
	{
		$self->{session}->get_repository->call( "on_files_modified", $self->{session}, $self );
	}
}

######################################################################
=pod

=item $doc->rehash

Recalculate the hash value of the document. Uses MD5 of the files (in
alphabetic order), but can use user specified hashing function instead.

=cut
######################################################################

sub rehash
{
	my( $self ) = @_;

	my %f = $self->files;
	my @filelist = ();
	foreach my $file ( keys %f )
	{
		push @filelist, $self->local_path."/".$file;
	}

	my $eprint = $self->get_eprint;
	unless( defined $eprint )
	{
		$self->{session}->get_repository->log(
"rehash: skipped document with no associated eprint (".$self->get_id.")." );
		return;
	}

	my $hashfile = $self->get_eprint->local_path."/".
		$self->get_value( "docid" ).".".
		EPrints::Platform::get_hash_name();

	EPrints::Probity::create_log( 
		$self->{session}, 
		\@filelist,
		$hashfile );
}

######################################################################
=pod

=item $text = $doc->get_text

Get the text of the document as a UTF-8 encoded string, if possible.

This is used for full-text indexing. The text will probably not
be well formated.

=cut
######################################################################

sub get_text
{
	my( $self ) = @_;

	# Get the main conversion plugin
	my $session = $self->{ "session" };
	my $convert = $session->plugin( "Convert" );

	# Find a 'text/plain' converter
	my $type = "text/plain";
	my %types = $convert->can_convert( $self );
	my $def = $types{$type} or return '';

	# Convert the document
	my $tempdir = EPrints::TempDir->new( UNLINK => 1 );
	my @files = $def->{ "plugin" }->export( $tempdir, $self, $type );
	
	# Read all the outputted files
	my $buffer = '';
	for( @files )
	{
		open my $fi, "<:utf8", "$tempdir/$_" or next;
		while( $fi->read($buffer,4096,length($buffer)) ) 
		{
			last if length($buffer) > 4 * 1024 * 1024;
		}
		close $fi;
	}

	return $buffer;
}

######################################################################
=pod

=item $filename = $doc->words_file

Return the filename in which this document uses to cache words 
extracted from the full text.

=cut
######################################################################

sub words_file
{
	my( $self ) = @_;
	return $self->cache_file( 'words' );
}

######################################################################
=pod

=item $filename = $doc->indexcodes_file

Return the filename in which this document uses to cache indexcodes 
extracted from the words cache file.

=cut
######################################################################

sub indexcodes_file
{
	my( $self ) = @_;
	return $self->cache_file( 'indexcodes' );
}

######################################################################
=pod

=item $filename = $doc->cache_file( $suffix );

Return a cache filename for this document with the givven suffix.

=cut
######################################################################

sub cache_file
{
	my( $self, $suffix ) = @_;

	my $eprint =  $self->get_eprint;
	return unless( defined $eprint );

	return $eprint->local_path."/".
		$self->get_value( "docid" ).".".$suffix;
}
	
######################################################################
#
# $doc->register_parent( $eprint )
#
# Give the document the EPrints::DataObj::EPrint object that it belongs to.
#
# This may cause reference loops, but it does avoid two identical
# EPrints objects existing at once.
#
######################################################################

sub register_parent
{
	my( $self, $parent ) = @_;

	$self->{eprint} = $parent;
}


sub thumbnail_url
{
	my( $self, $size ) = @_;

	$size = "small" unless defined $size;

	if( ! -e $self->thumbnail_path."/".$size.".png" )	
	{
		return;
	}

	my $eprint = $self->get_eprint();

	return( undef ) if( !defined $eprint );

	my $repository = $self->{session}->get_repository;

	my $docpath = $self->get_value( "pos" );

	return $eprint->url_stem."thumbnails/$docpath/$size.png";
}

# size => "small","medium","preview" (small is default)
# public => 0 : show thumbnail only on public docs
# public => 1 : show thumbnail on all docs if poss.
sub icon_url 
{
	my( $self, %opts ) = @_;

	$opts{public} = 1 unless defined $opts{public};
	$opts{size} = "small" unless defined $opts{size};

	if( !$opts{public} || $self->is_public )
	{
		my $thumbnail_url = $self->thumbnail_url( $opts{size} );

		return $thumbnail_url if defined $thumbnail_url;
	}

	my $type = $self->get_value( "format" );
	$type =~ s/\//_/g;

	return $self->{session}->get_repository->get_conf( "http_url" ).
			"/style/images/fileicons/$type.png";
}

# options:
#
# new_window => 1 : make link go to _blank not current window
# preview => 1 : if possible, provide a preview pop-up
# public => 0 : show thumbnail/preview only on public docs
# public => 1 : show thumbnail/preview on all docs if poss.
# 
sub render_icon_link
{
	my( $self, %opts ) = @_;

	$opts{public} = 1 unless defined $opts{public};
	if( $opts{public} && !$self->is_public )
	{
		$opts{preview} = 0;
	}

	my %aopts;
	$aopts{href} = $self->get_url;
	$aopts{target} = "_blank" if( $opts{new_window} );
	my $preview_id = "doc_preview_".$self->get_id;
	my $preview_url;
	if( $opts{preview} )
	{
		$preview_url = $self->thumbnail_url( "preview" );
		if( !defined $preview_url ) { $opts{preview} = 0; }
	}
	if( $opts{preview} )
	{
		$aopts{onmouseover} = "EPJS_ShowPreview( event, '$preview_id' );";
		$aopts{onmouseout} = "EPJS_HidePreview( event, '$preview_id' );";
	}
	my $a = $self->{session}->make_element( "a", %aopts );
	$a->appendChild( $self->{session}->make_element( 
		"img", 
		class=>"ep_doc_icon",
		alt=>"[img]",
		src=>$self->icon_url( public=>$opts{public} ),
		border=>0 ));
	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $a ) ;
	if( $opts{preview} )
	{
		my $preview = $self->{session}->make_element( "div",
				id => $preview_id,
				class => "ep_preview", );
		my $table = $self->{session}->make_element( "table" );
		$preview->appendChild( $table );
		my $tr = $self->{session}->make_element( "tr" );
		my $td = $self->{session}->make_element( "td" );
		$tr->appendChild( $td );
		$table->appendChild( $tr );
		$td->appendChild( $self->{session}->make_element( 
			"img", 
			class=>"ep_preview_image",
			alt=>"",
			src=>$preview_url,
			border=>0 ));
		my $div = $self->{session}->make_element( "div", class=>"ep_preview_title" );
		$div->appendChild( $self->{session}->html_phrase( "lib/document:preview"));
		$td->appendChild( $div );
		$f->appendChild( $preview );
	}

	return $f;
}

sub thumbnail_plugin
{
	my( $self, $size ) = @_;

	my $convert = $self->{session}->plugin( "Convert" );
	my %types = $convert->can_convert( $self );

	my $def = $types{'thumbnail_'.$size};

	return unless defined $def;

	return $def->{ "plugin" };
}

sub thumbnail_path
{
	my( $self ) = @_;

	my $eprint = $self->get_eprint();

	if( !defined $eprint )
	{
		$self->{session}->get_repository->log(
			"Document ".$self->get_id." has no eprint (eprintid is ".$self->get_value( "eprintid" )."!" );
		return( undef );
	}	
	
	return( $eprint->local_path()."/thumbnails/".sprintf("%02d",$self->get_value( "pos" )) );
}


sub remove_thumbnails
{
	my( $self ) = @_;

	EPrints::Utils::rmtree( $self->thumbnail_path );
}

sub make_thumbnails
{
	my( $self ) = @_;

	my $src = $self->local_path."/".$self->get_value( "main" );
	
	if( !-e $src || !-r $src )
	{
		return undef;
	}
	
	my $tgtdir = $self->thumbnail_path;

	my @list = qw/ small medium preview /;

	if( $self->{session}->get_repository->can_call( "thumbnail_types" ) )
	{
		$self->{session}->get_repository->call( "thumbnail_types", \@list, $self->{session}, $self );
	}

	foreach my $size ( @list )
	{
		my $tgt = "$tgtdir/".$self->get_id.".".$size.".png";

		# check mtime
		my @s1 = stat( $src );
		my @s2 = stat( $tgt );
    		if( defined $s1[9] && defined $s2[9] && $s2[9] > $s1[9] )
		{
			next;
			# src file is older than thumbnail
		}

		EPrints::Platform::mkdir( $tgtdir );
	
		my $plugin = $self->thumbnail_plugin( $size );

		next if !defined $plugin;

		# make a thumbnail
		$plugin->export( $tgtdir, $self, 'thumbnail_'.$size );
	}

	if( $self->{session}->get_repository->can_call( "on_generate_thumbnails" ) )
	{
		$self->{session}->get_repository->call( "on_generate_thumbnails", $self->{session}, $self );
	}
}

sub mime_type
{
	my( $self, $file ) = @_;

	# Primary doc if no filename
	$file = $self->get_main unless( defined $file );

	my $path = $self->local_path . "/" . $file;

	return undef unless -e $path;
	return undef unless -r $path;
	return undef if -d $path;

	my $repository = $self->{session}->get_repository;

	my %params = ( SOURCE => $path );

	return undef if( !$repository->can_invoke( "file", %params ) );

	my $command = $repository->invocation( "file", %params );
	my $mime_type = `$command`;
	$mime_type =~ s/\015?\012?$//s;
	($mime_type) = split /,/, $mime_type, 2; # file can return a 'sub-type'

	return undef if !defined $mime_type;

	return length($mime_type) > 0 ? $mime_type : undef;

	return undef;
}



1;

######################################################################
=pod

=back

=cut

