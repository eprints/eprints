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

=for Pod2Wiki

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
of the dataset "security".

=item main (text)

The file which we should link to. For something like a PDF file this is
the only file. For an HTML document with images it would be the name of
the actual HTML file.

=item documents (subobject, multiple)

A virtual field which represents the list of Documents which are
part of this record.

=back

=head1 METHODS

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
					type => "text",
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



sub doc_with_eprintid_and_pos
{
	my( $repository, $eprintid, $pos ) = @_;
	
	my $dataset = $repository->dataset( "document" );

	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [qw( eprintid )],
				value => $eprintid
			},
			{
				meta_fields => [qw( pos )],
				value => $pos
			},
		]);

	return $results->item( 0 );
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::Document->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "document";
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
		{
			_parent => $eprint,
			eprintid => $eprint->get_id
		},
		$session->get_repository->get_dataset( "document" ) );
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
	my $eprint = $data->{_parent} ||= delete $data->{eprint};

	my $files = $data->{files};
	$files = [] if !defined $files;

	if( !EPrints::Utils::is_set( $data->{main} ) && @$files > 0 )
	{
		$data->{main} = $files->[0]->{filename};
	}

	my $document = $class->SUPER::create_from_data( $session, $data, $dataset );

	return undef unless defined $document;

	if( scalar @$files )
	{
		$document->queue_files_modified;
	}

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
	my( $class, $session, $data, $dataset ) = @_;

	$class->SUPER::get_defaults( $session, $data, $dataset );

	$data->{pos} = $session->get_database->next_doc_pos( $data->{eprintid} );

	$data->{placement} = $data->{pos};

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

	# cloning within the same eprint, in which case get a new position!
	if( defined $self->parent && $eprint->id eq $self->parent->id )
	{
		$data->{pos} = undef;
	}

	$data->{eprintid} = $eprint->get_id;
	$data->{_parent} = $eprint;

	# First create a new doc object
	my $new_doc = $self->{dataset}->create_object( $self->{session}, $data );
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
=pod

=item $success = $doc->remove

Attempt to completely delete this document

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	# remove dependent objects and relations
	foreach my $dataobj (@{($self->get_related_objects())})
	{
		if( $dataobj->has_object_relations( $self, EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) )
		{
			$dataobj->remove_object_relations( $self ); # avoid infinite loop
			$dataobj->remove();
		}
		else
		{
			$dataobj->remove_object_relations( $self );
			$dataobj->commit;
		}
	}

	foreach my $file (@{($self->get_value( "files" ))})
	{
		$file->remove();
	}

	# Remove database entry
	my $success = $self->SUPER::remove();

	if( !$success )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( "Error removing document ".$self->get_value( "docid" )." from database: $db_error" );
		return( 0 );
	}

	return( $success );
}


######################################################################
=pod

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

	my $eprint = $self->get_parent();

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

	my $eprint = $self->get_parent;

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
	utf8::encode($file);
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

	foreach my $file (@{($self->get_value( "files" ))})
	{
		$files{$file->get_value( "filename" )} = $file->get_value( "filesize" );
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
	
	my $fileobj = $self->get_stored_file( $filename );

	if( defined( $fileobj ) )
	{
		$fileobj->remove();

		$self->queue_files_modified;
	}
	else
	{
		$self->{session}->get_repository->log( "Error removing file $filename for doc ".$self->get_value( "docid" ).": $!" );
	}

	return defined $fileobj;
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
=pod

=item $filename = $doc->get_main

Return the name of the main file in this document.

=cut
######################################################################

sub get_main
{
	my( $self ) = @_;

	if( defined $self->{data}->{main} )
	{
		return $self->{data}->{main};
	}

	# If there's only one file then just claim that's
	# the main one!
	my %files = $self->files;
	my @filenames = keys %files;
	if( scalar @filenames == 1 )
	{
		return $filenames[0];
	}

	return;
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

	$filename = sanitise( $filename );

	if( !$filename )
	{
		$repository->log( "Bad filename in document: no valid characters in file name\n" );
		return 0;
	}

	my $fileobj = $self->add_stored_file(
		$filename,
		$filehandle,
		$filesize
	);

	if( defined $fileobj )
	{
		if( !$self->is_set( "main" ) )
		{
			$self->set_value( "main", $fileobj->value( "filename" ) );
			$self->commit();
		}
		$self->queue_files_modified;
	}

	return defined $fileobj;
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

	$self->queue_files_modified;

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
	my $rc = $self->{session}->get_repository->exec( 
			$archive_format, 
			DIR => $tmpdir,
			ARC => $file );
	
	$self->add_directory( "$tmpdir" );

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

	my $rc = $self->{session}->get_repository->exec( 
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
	
	$self->queue_files_modified;

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

	$self->update_triggers();

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

	return [] if $self->get_parent->skip_validation;

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
	push @problems, @{ $self->SUPER::validate( $for_archive ) };

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

sub queue_files_modified
{
	my( $self ) = @_;

	EPrints::DataObj::EventQueue->create_from_data( $self->{session}, {
			pluginid => "Event::FilesModified",
			action => "files_modified",
			params => [$self->internal_uri],
		});
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

	# remove the now invalid cache of words from this document
	# (see also EPrints::MetaField::Fulltext::get_index_codes_basic)
	my $indexcodes  = $self->get_related_objects(
			EPrints::Utils::make_relation( "hasIndexCodesVersion" )
		);
	$_->remove for @$indexcodes;

	my $rc = $self->make_thumbnails;

	if( $self->{session}->can_call( "on_files_modified" ) )
	{
		$self->{session}->call( "on_files_modified", $self->{session}, $self );
	}

	$self->commit;

	$self->get_parent->queue_fulltext;

	return $rc;
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

	my $files = $self->get_value( "files" );

	my $tmpfile = File::Temp->new;
	my $hashfile = $self->get_value( "docid" ).".".
		EPrints::Platform::get_hash_name();

	EPrints::Probity::create_log_fh( 
		$self->{session}, 
		$files,
		$tmpfile );

	seek($tmpfile, 0, 0);

	# Probity files must not be deleted when the document is deleted, therefore
	# we store them in the parent Eprint
	$self->get_parent->add_stored_file( $hashfile, $tmpfile, -s "$tmpfile" );
}

######################################################################
=pod

=item $doc = $doc->make_indexcodes()

Make the indexcodes document for this document. Returns the generated document or undef on failure.

=cut
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
	my %types = $self->{session}->plugin( "Convert" )->can_convert( $self, $type );
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
=pod

=item $doc = $doc->remove_indexcodes()

Remove any documents containing index codes for this document. Returns the
number of documents removed.

=cut
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
=pod

=item $filename = $doc->cache_file( $suffix );

Return a cache filename for this document with the givven suffix.

=cut
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
	if( defined(my $file = $self->get_main) )
	{
		utf8::encode($file);
		$file =~ s/([^\/-_\.!~\*'\(\)A-Za-z0-9\/])/sprintf('%%%02X',ord($1))/ge;
		$url .= $file;
	}

	if( $self->{session}->{preparing_static_page} )
	{
		return $url;
	}

	$url = substr($url,length($self->{session}->config( "http_url" )));

	return $self->{session}->config( "rel_path" ) . $url;
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

	my $session = $self->{session};
	my $langid = $session->get_langid;
	my @static_dirs = $session->get_repository->get_static_dirs( $langid );

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

	if( $session->{preparing_static_page} )
	{
		return $session->get_repository->get_conf( "http_url" )."/$rel_path/$icon";
	}

	return $session->get_repository->get_conf( "rel_path" )."/$rel_path/$icon";
}

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

sub render_preview_link
{
	my( $self, %opts ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	my $caption = $opts{caption} || $self->{session}->make_doc_fragment;
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
		my $link = $self->{session}->make_element( "a",
				href=>$url,
				rel=>"lightbox$set",
				title=>EPrints::XML::to_string($caption),
			);
		$link->appendChild( $self->{session}->html_phrase( "lib/document:preview" ) );
		$f->appendChild( $link );
	}

	EPrints::XML::dispose($caption);

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

	my $eprint = $self->get_parent();

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

	my @list = qw/ small medium preview /;

	if( $self->{session}->get_repository->can_call( "thumbnail_types" ) )
	{
		$self->{session}->get_repository->call( "thumbnail_types", \@list, $self->{session}, $self );
	}

	foreach my $size (@list)
	{
		my $relation = EPrints::Utils::make_relation( "has${size}ThumbnailVersion" );
		foreach my $doc ($self->related_dataobjs( $relation ))
		{
			if( $doc->has_dataobj_relations( $self, EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) )
			{
				$doc->remove;
			}
		}
	}

	$self->commit;
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

	my $src_main = $self->get_stored_file( $self->get_main() );

	return unless defined $src_main;

	my @list = qw/ small medium preview /;

	if( $self->{session}->get_repository->can_call( "thumbnail_types" ) )
	{
		$self->{session}->get_repository->call( "thumbnail_types", \@list, $self->{session}, $self );
	}

	SIZE: foreach my $size ( @list )
	{
		my @relations = ( EPrints::Utils::make_relation( "has${size}ThumbnailVersion" ), EPrints::Utils::make_relation( "hasVolatileVersion" ) );

		my( $tgt ) = @{($self->get_related_objects( @relations ))};

		# remove the existing thumbnail
   		if( defined($tgt) )
		{
			my $tgt_main = $tgt->get_stored_file( $tgt->get_main() );
			if( defined $tgt_main && $tgt_main->get_datestamp gt $src_main->get_datestamp )
			{
				# ignore if tgt's main file is newer than document's main file
				next SIZE;
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

	if( $self->{session}->get_repository->can_call( "on_generate_thumbnails" ) )
	{
		$self->{session}->get_repository->call( "on_generate_thumbnails", $self->{session}, $self );
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

