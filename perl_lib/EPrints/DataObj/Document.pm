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

=head1 SYNOPSIS

	Inherrits all methods from EPrints::DataObj.

	# create a new document on $eprint 
	my $doc_data = {
		_parent => $eprint,
		eprintid => $eprint->get_id,
	};
	my $doc_ds = $handle->get_dataset( 'document' );
	my $document = $doc_ds->create_object( $handle, $doc_data );

	# Add files to the document	
	$success = $doc->add_file( $file, $filename, [$preserve_path] );
	$success = $doc->upload( $filehandle, $filename [, $preserve_path [, $filesize ] ] );
	$success = $doc->upload_archive( $filehandle, $filename, $archive_format );
	$success = $doc->add_archive( $file, $archive_format );
	$success = $doc->add_directory( $directory );
	$success = $doc->upload_url( $url );

	# get an existing document
	$document = $handle->get_document( $doc_id );
	# or
	foreach my $doc ( $eprint->get_all_documents ) { ... }

	# eprint to which this document belongs
	$eprint = $doc->get_eprint;

	# delete a document object *forever*:
	$success = $doc->remove;

	$url = $doc->get_url( [$file] );
	$path = $doc->local_path;
	%files = $doc->files;

	# delete a file
	$success = $doc->remove_file( $filename );
	# delete all files
	$success = $doc->remove_all_files;

	# change the file which is used as the URL for the document.
	$doc->set_main( $main_file );

	# icons and previews
	$xhtml = $doc->render_icon_link( %opts );
	$xhtml = $doc->render_preview_link( %opts );

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

=item placement (int)

Placement of the document - the order documents should be shown in.

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
of the namedset "security".

=item content (namedset)

The type of content. Conceptual type, no format. ie. Supporting Material or 
published version. Values from namedset "content"

=item license (namedset)

The type of license for the document. Such as GFDL or creative commons.
Values from namedset "licenses"

=item main (text)

The file which we should link to. For something like a PDF file this is
the only file. For an HTML document with images it would be the name of
the actual HTML file.

=item documents (subobject, multiple)

A virtual field which represents the list of Documents which are
part of this record.

=back

=head1 METHODS

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::DataObj::Document;

@ISA = ( 'EPrints::DataObj::SubObject' );

use EPrints;
use EPrints::Search;

use File::Basename;
use File::Copy;
use File::Find;
use Cwd;
use Fcntl qw(:DEFAULT :seek);

use URI::Heuristic;

use strict;

# Field to use for unsupported formats (if repository allows their deposit)
$EPrints::DataObj::Document::OTHER = "OTHER";

######################################################################
# $metadata = EPrints::DataObj::Document->get_system_field_info
#
# Return an array describing the system metadata of the Document dataset.
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"docid", type=>"counter", required=>1, import=>0, show_in_html=>0, can_clone=>0,
			sql_counter=>"documentid" },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0, show_in_html=>0,
			default_value=>1 },

		{ name=>"files", type=>"subobject", datasetid=>"file", multiple=>1 },

		{ name=>"eprintid", type=>"itemref",
			datasetid=>"eprint", required=>1, show_in_html=>0 },

		{ name=>"pos", type=>"int", required=>1 },

		{ name=>"placement", type=>"int", },

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

		{ name=>"content", type=>"namedset", required=>0, input_rows=>1,
			set_name=>"content" },

		{ name=>"relation", type=>"compound", multiple=>1,
			fields => [
				{
					sub_name => "type",
					type => "namedset",
					set_name => "document_relation",
				},
				{
					sub_name => "uri",
					type => "text",
				},
			],
		},
	);

}

sub main_input_tags
{
	my( $handle, $object ) = @_;

	my %files = $object->files;

	my @tags;
	foreach ( sort keys %files ) { push @tags, $_; }

	return( @tags );
}

sub main_render_option
{
	my( $handle, $option ) = @_;

	return $handle->make_text( $option );
}



sub doc_with_eprintid_and_pos
{
	my( $handle, $eprintid, $pos ) = @_;
	
	my $document_ds = $handle->get_repository->get_dataset( "document" );

	my $searchexp = new EPrints::Search(
		handle =>$handle,
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
# $dataset = EPrints::DataObj::Document->get_dataset_id
# 
# Returns the id of the L<EPrints::DataSet> object to which this record belongs.
######################################################################

sub get_dataset_id
{
	return "document";
}

######################################################################
# $doc = EPrints::DataObj::Document::create( $handle, $eprint )
# 
# Create and return a new Document belonging to the given $eprint object, 
# get the initial metadata from set_document_defaults in the configuration
# for this repository.
# 
# Note that this creates the document in the database, not just in memory.
######################################################################

sub create
{
	my( $handle, $eprint ) = @_;

	return EPrints::DataObj::Document->create_from_data( 
		$handle, 
		{
			_parent => $eprint,
			eprintid => $eprint->get_id
		},
		$handle->get_repository->get_dataset( "document" ) );
}

######################################################################
# $dataobj = EPrints::DataObj::Document->create_from_data( $handle, $data, $dataset )
# 
# Returns undef if a bad (or no) subjectid is specified.
# 
# Otherwise calls the parent method in EPrints::DataObj.
######################################################################

sub create_from_data
{
	my( $class, $handle, $data, $dataset ) = @_;
       
	my $eprintid = $data->{eprintid}; 
	my $eprint = $data->{_parent} ||= delete $data->{eprint};

	my $files = delete $data->{files};

	my $document = $class->SUPER::create_from_data( $handle, $data, $dataset );

	return unless defined $document;

	$document->set_under_construction( 1 );

	my $fileds = $handle->get_repository->get_dataset( "file" );

	my $files_modified = 0;

	foreach my $filedata ( @{$files||[]} )
	{
		# Don't try to add empty file objects
		if( !defined($filedata->{data}) && !defined($filedata->{url}) )
		{
			next;
		}
		$filedata->{objectid} = $document->get_id;
		$filedata->{datasetid} = $document->get_dataset_id;
		$filedata->{_parent} = $document;
		my $fileobj = EPrints::DataObj::File->create_from_data(
				$handle,
				$filedata,
				$fileds,
			);
		if( defined( $fileobj ) )
		{
			$files_modified = 1;
			# Calculate and store the MD5 checksum
			$fileobj->update_md5();
		}
	}

	if( $files_modified )
	{
		$document->files_modified;
	}

	$document->set_under_construction( 0 );

	return $document;
}

######################################################################
# $defaults = EPrints::DataObj::Document->get_defaults( $handle, $data )
#
# Return default values for this object based on the starting data.
######################################################################

sub get_defaults
{
	my( $class, $handle, $data, $dataset ) = @_;

	$class->SUPER::get_defaults( $handle, $data, $dataset );

	$data->{pos} = $handle->get_database->next_doc_pos( $data->{eprintid} );

	$data->{placement} = $data->{pos};

	my $eprint = $data->{_parent};
	if( !defined $eprint )
	{
		$eprint = $handle->get_eprint( $data->{eprintid} );
	}

	$handle->get_repository->call( 
			"set_document_defaults", 
			$data,
 			$handle,
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
	
	my $data = EPrints::Utils::clone( $self->{data} );

	$data->{eprintid} = $eprint->get_id;
	$data->{_parent} = $eprint;

	# First create a new doc object
	my $new_doc = $self->{dataset}->create_object( $self->{handle}, $data );
	return undef if !defined $new_doc;
	
	my $ok = 1;

	# Copy files
	foreach my $file (@{$self->get_value( "files" )})
	{
		$file->clone( $new_doc ) or $ok = 0, last;
	}

	if( !$ok )
	{
		$new_doc->remove();
		return undef;
	}

	return $new_doc;
}


######################################################################
# $success = $doc->remove
#
# Attempt to completely delete this document
######################################################################

sub remove
{
	my( $self ) = @_;

	# remove dependent objects

	foreach my $dataobj (@{($self->get_related_objects( EPrints::Utils::make_relation( "hasVolatileVersion" ) ))})
	{
		next unless $dataobj->has_object_relations( $self, EPrints::Utils::make_relation( "isVolatileVersionOf" ) );
		$dataobj->remove();
	}

	foreach my $file (@{($self->get_value( "files" ))})
	{
		$file->remove();
	}

	# remove relations to us
	foreach my $dataobj (@{($self->get_related_objects())})
	{
		$dataobj->remove_object_relations( $self );
		$dataobj->commit();
	}

	# Remove database entry
	my $success = $self->SUPER::remove();

	if( !$success )
	{
		my $db_error = $self->{handle}->get_database->error;
		$self->{handle}->get_repository->log( "Error removing document ".$self->get_value( "docid" )." from database: $db_error" );
		return( 0 );
	}

	# Remove directory and contents
	my $full_path = $self->local_path();
	my $ok = EPrints::Utils::rmtree( $full_path );

	if( !$ok )
	{
		$self->{handle}->get_repository->log( "Error removing document files for ".$self->get_value("docid").", path ".$full_path.": $!" );
		$success = 0;
	}

	return( $success );
}


######################################################################
=pod

=over 4

=item $eprint = $doc->get_eprint

Return the EPrint this document is associated with.

This is a synonym for get_parent().

=cut
######################################################################

sub get_eprint { &get_parent }
sub get_parent
{
	my( $self, $datasetid, $objectid ) = @_;

	$datasetid = "eprint";
	$objectid = $self->get_value( "eprintid" );

	return $self->SUPER::get_parent( $datasetid, $objectid );
}


######################################################################
# $url = $doc->get_baseurl( [$staff] )
# 
# Return the base URL of the document. Overrides the stub in DataObj.
# $staff is currently ignored.
######################################################################

sub get_baseurl
{
	my( $self ) = @_;

	# The $staff param is ignored.

	my $eprint = $self->get_parent();

	return( undef ) if( !defined $eprint );

	my $repository = $self->{handle}->get_repository;

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

	my $eprint = $self->get_parent;

	return 0 if( $self->get_value( "security" ) ne "public" );

	return 0 if( $eprint->get_value( "eprint_status" ) ne "archive" );

	return 1;
}

######################################################################
=pod

=item $url = $doc->get_url( [$file] )

Return the full URL of the document. 

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
	$file =~ s/([^\/-_\.!~\*'\(\)A-Za-z0-9\/])/sprintf('%%%02X',ord($1))/ge;
	
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

	my $eprint = $self->get_parent();

	if( !defined $eprint )
	{
		$self->{handle}->get_repository->log(
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

	foreach my $file (@{($self->get_value( "files" ))})
	{
		$files{$file->get_value( "filename" )} = $file->get_value( "filesize" );
	}

	return( %files );
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

	my $fileobj = $self->get_stored_file( $filename );

	if( defined( $fileobj ) )
	{
		$fileobj->remove();

		$self->files_modified;
	}
	else
	{
		$self->{handle}->get_repository->log( "Error removing file $filename for doc ".$self->get_value( "docid" ).": $!" );
	}

	return defined $fileobj;
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
		$self->{handle}->get_repository->log( "Error removing document files for ".$self->get_value( "docid" ).", path ".$full_path.": $!" );
		return( 0 );
	}

	$self->files_modified;

	return( 1 );
}


######################################################################
=pod

=item $doc->set_main( $main_file )

Sets the main file. Won't affect the database until a $doc->commit().

This checks the file exists, so is more than an alias for get_value.

=cut
######################################################################

sub set_main
{
	my( $self, $main_file ) = @_;
	
	if( defined $main_file )
	{
		# Ensure that the file exists
		my $fileobj = $self->get_stored_file( $main_file );

		# Set the main file if it does
		$self->set_value( "main", $main_file ) if( defined $fileobj );
	}
	else
	{
		# The caller passed in undef, so we unset the main file
		$self->set_value( "main", undef );
	}
}


######################################################################
# $filename = $doc->get_main
#
# Return the name of the main file in this document.
######################################################################

sub get_main
{
	my( $self ) = @_;
	
	return( $self->{data}->{main} );
}


######################################################################
# $doc->set_format( $format )
# 
# Set format. Won't affect the database until a commit(). Just an alias 
# for $doc->set_value( "format" , $format );
######################################################################

sub set_format
{
	my( $self, $format ) = @_;
	
	$self->set_value( "format" , $format );
}


######################################################################
# $doc->set_format_desc( $format_desc )
# 
# Set the format description.  Won't affect the database until a commit().
# Just an alias for
# $doc->set_value( "format_desc" , $format_desc );
######################################################################

sub set_format_desc
{
	my( $self, $format_desc ) = @_;
	
	$self->set_value( "format_desc" , $format_desc );
}


######################################################################
=pod

=item $success = $doc->upload( $filehandle, $filename [, $preserve_path [, $filesize ] ] )

Upload the contents of the given file handle into this document as
the given filename.

If $preserve_path then make any subdirectories needed, otherwise place
this in the top level.

=cut
######################################################################

sub upload
{
	my( $self, $filehandle, $filename, $preserve_path, $filesize ) = @_;

	my $rc = 1;

	# Get the filename. File::Basename isn't flexible enough (setting 
	# internal globals in reentrant code very dodgy.)

	my $repository = $self->{handle}->get_repository;
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

	$filename = sanitise( $filename );

	if( !$filename )
	{
		$repository->log( "Bad filename in document: no valid characters in file name\n" );
		return 0;
	}

	my $stored = $self->add_stored_file(
		$filename,
		$filehandle,
		$filesize
	);

	$rc = defined($stored);

	$rc &&= $self->files_modified;
	
	return $rc;
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
	open( $fh, "<", $file ) or return( 0 );
	binmode( $fh );
	my $rc = $self->upload( $fh, $filename, $preserve_path, -s $file );
	close $fh;

	return $rc;
}

######################################################################
# $cleanfilename = sanitise( $filename )
# 
# Return just the filename (no leading path) and convert any naughty
# characters to underscore.
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

	use bytes;

	binmode($filehandle);

	my $zipfile = File::Temp->new();
	binmode($zipfile);

	while(sysread($filehandle, $_, 4096))
	{
		syswrite($zipfile, $_);
	}

	my $rc = $self->add_archive( 
		"$zipfile",
		$archive_format );

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

	my $tmpdir = EPrints::TempDir->new( CLEANUP => 1 );

	# Do the extraction
	my $rc = $self->{handle}->get_repository->exec( 
			$archive_format, 
			DIR => $tmpdir,
			ARC => $file );
	
	$self->add_directory( "$tmpdir" );

	$self->files_modified;

	return( $rc==0 );
}

######################################################################
=pod

=item $success = $doc->add_directory( $directory )

Upload the contents of $directory to this document. This will not set the main file.

This method expects $directory to have a trailing slash (/).

=cut
######################################################################

sub add_directory
{
	my( $self, $directory ) = @_;

	$directory =~ s/[\/\\]?$/\//;

	my $rc = 1;

	if( !-d $directory )
	{
		EPrints::abort( "Attempt to call upload_dir on a non-directory: $directory" );
	}

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
			my $stored = $self->add_stored_file(
				$filename,
				$filehandle,
				-s $filepath
			);
			$rc = defined $stored;
		},
	}, $directory );

	return $rc;
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
	my $url = URI::Heuristic::uf_uri( $url_in );
	if( !$url->path )
	{
		$url->path( "/" );
	}

	my $tmpdir = EPrints::TempDir->new( CLEANUP => 1 );

	# save previous dir
	my $prev_dir = getcwd();

	# Change directory to destination dir., return with failure if this 
	# fails.
	unless( chdir "$tmpdir" )
	{
		chdir $prev_dir;
		return( 0 );
	}
	
	# Work out the number of directories to cut, so top-level files go in
	# at the top level in the destination dir.
	
	# Count slashes
	my $cut_dirs = substr($url->path,1) =~ tr"/""; # ignore leading /

	my $rc = $self->{handle}->get_repository->exec( 
			"wget",
			CUTDIRS => $cut_dirs,
			URL => $url );
	
	chdir $prev_dir;

	# If something's gone wrong...

	return( 0 ) if ( $rc!=0 );

	$self->add_directory( "$tmpdir" );

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
# $success = $doc->commit
#
# Commit any changes that have been made to this object to the
# database.
# 
# Calls "set_document_automatic_fields" in the ArchiveConfig first to
# set any automatic fields that may be needed.
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	my $dataset = $self->{handle}->get_repository->get_dataset( "document" );

	$self->{handle}->get_repository->call( "set_document_automatic_fields", $self );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	if( $self->{non_volatile_change} )
	{
		$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	
	}

	my $success = $self->SUPER::commit( $force );
	
	my $eprint = $self->get_parent();
	if( defined $eprint && !$eprint->under_construction )
	{
		# cause a new new revision of the parent eprint.
		# if the eprint is under construction the changes will be committed
		# after all the documents are complete
		$eprint->commit( 1 );
	}
	
	return( $success );
}
	
######################################################################
# $problems = $doc->validate( [$for_archive] )
# 
# Return an array of XHTML DOM objects describing validation problems
# with the entire document, including the metadata and repository config
# specific requirements.
# 
# A reference to an empty array indicates no problems.
######################################################################

sub validate
{
	my( $self, $for_archive ) = @_;

	return [] if $self->get_parent->skip_validation;

	my @problems;

	unless( EPrints::Utils::is_set( $self->get_type() ) )
	{
		# No type specified
		my $fieldname = $self->{handle}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{handle}->html_phrase( 
					"lib/document:no_type",
					fieldname=>$fieldname );
	}
	
	# System default checks:
	# Make sure there's at least one file!!
	my %files = $self->files();

	if( scalar keys %files ==0 )
	{
		my $fieldname = $self->{handle}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{handle}->html_phrase( "lib/document:no_files", fieldname=>$fieldname );
	}
	elsif( !defined $self->get_main() || $self->get_main() eq "" )
	{
		# No file selected as main!
		my $fieldname = $self->{handle}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{handle}->html_phrase( "lib/document:no_first", fieldname=>$fieldname );
	}
		
	# Site-specific checks
	push @problems, $self->{handle}->get_repository->call( 
		"validate_document", 
		$self, 
		$self->{handle},
		$for_archive );

	return( \@problems );
}


######################################################################
# $boolean = $doc->user_can_view( $user )
#
# Return true if this documents security settings allow the given user
# to view it.
######################################################################

sub user_can_view
{
	my( $self, $user ) = @_;

	if( !defined $user )
	{
		$self->{handle}->get_repository->log( '$doc->user_can_view called with undefined $user object.' );
		return( 0 );
	}

	my $result = $self->{handle}->get_repository->call( 
		"can_user_view_document",
		$self,
		$user );	

	return( 1 ) if( $result eq "ALLOW" );
	return( 0 ) if( $result eq "DENY" );

	$self->{handle}->get_repository->log( "Response from can_user_view_document was '$result'. Only ALLOW, DENY are allowed." );
	return( 0 );

}


######################################################################
# $type = $doc->get_type
# 
# Return the type of this document.
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "format" );
}

######################################################################
# $doc->files_modified
# 
# This method does all the things that need doing when a file has been
# modified.
######################################################################

sub files_modified
{
	my( $self ) = @_;

#	$self->rehash;

	# remove the now invalid cache of words from this document
	# (see also EPrints::MetaField::Fulltext::get_index_codes_basic)
	my $indexcodes  = $self->get_related_objects(
			EPrints::Utils::make_relation( "hasIndexCodesVersion" )
		);
	$_->remove for @$indexcodes;

	$self->get_parent->queue_fulltext();

	# nb. The "main" part is not automatically calculated when
	# the item is under contruction. This means bulk imports 
	# will have to set the name themselves.
	unless( $self->under_construction )
	{
		my %files = $self->files;

		# Pick a file to be the one that gets linked. There will 
		# usually only be one, if there's more than one then this
		# uses the first alphabetically.
		if( !$self->get_value( "main" ) || !$files{$self->get_value( "main" )} )
		{
			my @filenames = sort keys %files;
			if( scalar @filenames ) 
			{
				$self->set_value( "main", $filenames[0] );
			}
		}
	}

	$self->make_thumbnails;
	if( $self->{handle}->get_repository->can_call( "on_files_modified" ) )
	{
		$self->{handle}->get_repository->call( "on_files_modified", $self->{handle}, $self );
	}

	$self->commit();
}

######################################################################
# $doc->rehash
# 
# Recalculate the hash value of the document. Uses MD5 of the files (in
# alphabetic order), but can use user specified hashing function instead.
######################################################################

sub rehash
{
	my( $self ) = @_;

	my $files = $self->get_value( "files" );

	my $tmpfile = File::Temp->new;
	my $hashfile = $self->get_value( "docid" ).".".
		EPrints::Platform::get_hash_name();

	EPrints::Probity::create_log_fh( 
		$self->{handle}, 
		$files,
		$tmpfile );

	seek($tmpfile, 0, 0);

	# Probity files must not be deleted when the document is deleted, therefore
	# we store them in the parent Eprint
	$self->get_parent->add_stored_file( $hashfile, $tmpfile, -s "$tmpfile" );
}

######################################################################
# $doc = $doc->make_indexcodes()
# 
# Make the indexcodes document for this document. Returns the generated document or undef on failure.
######################################################################

sub make_indexcodes
{
	my( $self ) = @_;

	# if we're a volatile version of another document, don't make indexcodes 
	if( $self->has_related_objects( EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) )
	{
		return undef;
	}

	$self->remove_indexcodes();
	
	# find a conversion plugin to convert us to indexcodes
	my $type = "indexcodes";
	my %types = $self->{handle}->plugin( "Convert" )->can_convert( $self, $type );
	return undef unless exists($types{$type});
	my $plugin = $types{$type}->{"plugin"};

	# convert us to indexcodes
	my $doc = $plugin->convert(
			$self->get_parent,
			$self,
			$type
		);
	return undef unless defined $doc;

	# relate the new document to us
	$self->add_object_relations( $doc,
			EPrints::Utils::make_relation( "hasIndexCodesVersion" ) =>
			EPrints::Utils::make_relation( "isIndexCodesVersionOf" ),
		);
	$self->commit();
	$doc->commit();

	return $doc;
}

######################################################################
# $doc = $doc->remove_indexcodes()
# 
# Remove any documents containing index codes for this document. Returns the
# number of documents removed.
######################################################################

sub remove_indexcodes
{
	my( $self ) = @_;

	# if we're a volatile version of another document, don't make indexcodes 
	if( $self->has_related_objects( EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) )
	{
		return 0;
	}

	# remove any existing indexcodes documents
	my $docs = $self->get_related_objects(
			EPrints::Utils::make_relation( "hasIndexCodesVersion" )
		);
	$_->remove() for @$docs;
	$self->commit() if scalar @$docs; # Commit changes to relations
	
	return scalar (@$docs);
}

######################################################################
# $filename = $doc->cache_file( $suffix );
#
# Return a cache filename for this document with the given suffix.
######################################################################

sub cache_file
{
	my( $self, $suffix ) = @_;

	my $eprint =  $self->get_parent;
	return unless( defined $eprint );

	return $eprint->local_path."/".
		$self->get_value( "docid" ).".".$suffix;
}
	
######################################################################
# $doc->register_parent( $eprint )
#
# Give the document the EPrints::DataObj::EPrint object that it belongs to.
#
# This may cause reference loops, but it does avoid two identical
# EPrints objects existing at once.
######################################################################

sub register_parent
{
	my( $self, $parent ) = @_;

	$self->set_parent( $parent );
}


sub thumbnail_url
{
	my( $self, $size ) = @_;

	$size = "small" unless defined $size;

	my $relation = "has${size}ThumbnailVersion";

	my( $thumbnail ) = @{($self->get_related_objects( EPrints::Utils::make_relation( $relation ) ))};

	return undef if !defined $thumbnail;

	my $url = $self->get_baseurl();
	$url =~ s! /$ !.$relation/!x;
	$url .= $self->get_main
		if defined $self->get_main;

	return $url;
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

	my $handle = $self->{handle};
	my $langid = $handle->get_langid;
	my @static_dirs = $handle->get_repository->get_static_dirs( $langid );

	my $icon = "unknown.png";
	my $rel_path = "style/images/fileicons";

	# e.g. audio/mp3 will look for "audio_mp3.png" then "audio.png" then
	# "unknown.png"
	my( $major, $minor ) = split /\//, $self->get_value( "format" ), 2;
	$minor = "" if !defined $minor;
	$minor =~ s/\//_/g;

	foreach my $dir (@static_dirs)
	{
		my $path = "$dir/$rel_path";
		if( $minor ne "" && -e "$path/$major\_$minor.png" )
		{
			$icon = "$major\_$minor.png";
			last;
		}
		elsif( -e "$path/$major.png" )
		{
			$icon = "$major.png";
			last;
		}
	}

	return $handle->get_repository->get_conf( "http_url" )."/$rel_path/$icon";
}

######################################################################
=item $frag = $doc->render_icon_link( %opts )

Render a link to the icon for this document.

Options:

=over 4

=item new_window => 1

Make link go to _blank not current window.

=item preview => 1

If possible, provide a preview pop-up.

=item public => 0

Show thumbnail/preview only on public docs.

=item public => 1

Show thumbnail/preview on all docs if poss.

=back

=cut
######################################################################

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
	my $a = $self->{handle}->make_element( "a", %aopts );
	$a->appendChild( $self->{handle}->make_element( 
		"img", 
		class=>"ep_doc_icon",
		alt=>"[img]",
		src=>$self->icon_url( public=>$opts{public} ),
		border=>0 ));
	my $f = $self->{handle}->make_doc_fragment;
	$f->appendChild( $a ) ;
	if( $opts{preview} )
	{
		my $preview = $self->{handle}->make_element( "div",
				id => $preview_id,
				class => "ep_preview", );
		my $table = $self->{handle}->make_element( "table" );
		$preview->appendChild( $table );
		my $tr = $self->{handle}->make_element( "tr" );
		my $td = $self->{handle}->make_element( "td" );
		$tr->appendChild( $td );
		$table->appendChild( $tr );
		$td->appendChild( $self->{handle}->make_element( 
			"img", 
			class=>"ep_preview_image",
			alt=>"",
			src=>$preview_url,
			border=>0 ));
		my $div = $self->{handle}->make_element( "div", class=>"ep_preview_title" );
		$div->appendChild( $self->{handle}->html_phrase( "lib/document:preview"));
		$td->appendChild( $div );
		$f->appendChild( $preview );
	}

	return $f;
}

######################################################################
=item $frag = $doc->render_preview_link( %opts )

Render a link to the preview for this document (if available) using a lightbox.

Options:

=over 4

=item caption => $frag

XHTML fragment to use as the caption, defaults to empty.

=item set => "foo"

The name of the set this document belongs to, defaults to none (preview won't be shown as part of a set).

=back

=cut
######################################################################

sub render_preview_link
{
	my( $self, %opts ) = @_;

	my $f = $self->{handle}->make_doc_fragment;

	my $caption = $opts{caption} || $self->{handle}->make_doc_fragment;
	my $set = $opts{set};
	if( EPrints::Utils::is_set($set) )
	{
		$set = "[$set]";
	}
	else
	{
		$set = "";
	}

	my $url = $self->thumbnail_url( "preview" );
	if( defined( $url ) )
	{
		my $link = $self->{handle}->make_element( "a",
				href=>$url,
				rel=>"lightbox$set",
				title=>EPrints::XML::to_string($caption),
			);
		$link->appendChild( $self->{handle}->html_phrase( "lib/document:preview" ) );
		$f->appendChild( $link );
	}

	EPrints::XML::dispose($caption);

	return $f;
}

sub thumbnail_plugin
{
	my( $self, $size ) = @_;

	my $convert = $self->{handle}->plugin( "Convert" );
	my %types = $convert->can_convert( $self );

	my $def = $types{'thumbnail_'.$size};

	return unless defined $def;

	return $def->{ "plugin" };
}

sub thumbnail_path
{
	my( $self ) = @_;

	my $eprint = $self->get_parent();

	if( !defined $eprint )
	{
		$self->{handle}->get_repository->log(
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

	# If we're a volatile version of another document, don't make thumbnails 
	# otherwise we'll cause a recursive loop
	if( $self->has_related_objects( EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) )
	{
		return;
	}

	my $src = $self->get_stored_file( $self->get_main() );

	return unless defined $src;

	my @list = qw/ small medium preview /;

	if( $self->{handle}->get_repository->can_call( "thumbnail_types" ) )
	{
		$self->{handle}->get_repository->call( "thumbnail_types", \@list, $self->{handle}, $self );
	}

	foreach my $size ( @list )
	{
		my @relations = ( "has${size}ThumbnailVersion", "hasVolatileVersion" );

		my( $tgt ) = @{($self->get_related_objects( @relations ))};

		# remove the existing thumbnail
   		if( defined($tgt) )
		{
			if( $tgt->get_datestamp gt $src->get_datestamp )
			{
				next;
				# src file is older than thumbnail
			}
			$self->remove_object_relations( $tgt );
			$tgt->remove;
		}

		my $plugin = $self->thumbnail_plugin( $size );

		next if !defined $plugin;

		my $doc = $plugin->convert( $self->get_parent, $self, 'thumbnail_'.$size );
		next if !defined $doc;

		$self->add_object_relations(
				$doc,
				EPrints::Utils::make_relation( "has${size}ThumbnailVersion" ) =>
				EPrints::Utils::make_relation( "is${size}ThumbnailVersionOf" )
			);

		$doc->commit();
	}

	if( $self->{handle}->get_repository->can_call( "on_generate_thumbnails" ) )
	{
		$self->{handle}->get_repository->call( "on_generate_thumbnails", $self->{handle}, $self );
	}

	$self->commit();
}

sub mime_type
{
	my( $self, $file ) = @_;

	# Primary doc if no filename
	$file = $self->get_main unless( defined $file );

	my $fileobj = $self->get_stored_file( $file );

	return undef unless defined $fileobj;

	return $fileobj->get_value( "mime_type" );
}

sub get_parent_dataset_id
{
	"eprint";
}

sub get_parent_id
{
	my( $self ) = @_;

	return $self->get_value( "eprintid" );
}

1;

######################################################################
=pod

=back

=cut
