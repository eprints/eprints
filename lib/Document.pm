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


# cjg this belongs elsewhere
%EPrints::Document::help =
(
	"format"     => "Please select the storage format you wish to upload.",
	"formatdesc" => "If you are uploading a non-listed format, please enter ".
	                "details about the format below. Please be sure to include ".
	                "version information."
);

## WP1: BAD
sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"docid", type=>"text", required=>1, editable=>0 },

		{ name=>"eprintid", type=>"text", required=>1, editable=>0 },

		{ name=>"format", type=>"datatype", required=>1, editable=>1, datasetid=>"document" },

		{ name=>"formatdesc", type=>"text", required=>1, editable=>1 },

		{ name=>"main", type=>"text", required=>1, editable=>1 }
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
	my( $class, $session, $doc_id, $known, $eprint ) = @_;
	
	my $self={};
	bless $self, $class;

	$self->{session} = $session;
	$self->{eprint} = $eprint;
	
	my @row;

	if( !defined $known )
	{
		# Need to read data from the database
		@row = $self->{session}->{database}->retrieve_single(
			EPrints::Database::table_name( "document" ),
			"docid",
			$doc_id );
	}
	else
	{
		@row = @$known;
	}
	
	if( $#row == -1 )
	{
		# No such document
		return( undef );
	}

	# Lob the row data into the relevant fields
	my @fields = $self->{session}->{metainfo}->get_fields( "documents" );

	my $i=0;
	my $field;
	
	foreach $field (@fields)
	{
		my $field_name = $field->get_name();

		$self->{$field_name} = $row[$i];
		$i++;
	}

	return( $self );
}


######################################################################
#
# $doc = create( $session, $eprint, $format )
#
#  Create a new document entry and associated directory, for the given
#  EPrint, in the given format. $format is optional, you can set it
#  later with $doc->set_format( $format ).
#
######################################################################

## WP1: BAD
sub create
{
	my( $session, $eprint, $format ) = @_;
	
	# Generate new doc id
	my $doc_id = _generate_doc_id( $session, $eprint );
	
	# Make directory on filesystem
	my $dir = _create_directory( $doc_id, $eprint );

	unless( defined $dir )
	{
		# Some error while making it
		$session->get_archive()->log( "Error creating directory for Eprint ".$eprint->{eprintid}." format ".$format.": $!" );
		return( undef );
	}

	# Make database entry
# cjg add_record call
	my $success = $session->{database}->add_record(
		EPrints::Database::table_name( "document" ),
		{ "docid"=>$doc_id,
		  "eprintid"=>$eprint->{eprintid},
		  "format"=>$format } );
		  
	if( $success )
	{
		return( EPrints::Document->new( $session, $doc_id, undef, $eprint ) );
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
	
	# Get the EPrint's directory
	my $dir = $eprint->local_path() . "/" . $id;

	# Ensure the path is there. Dir. is made group writable.
	my @created = mkpath( $dir, 0, 0775 );

	# Return undef if dir creation failed. Should always have created 1 dir.
	return( undef ) unless( $#created >= 0 );

	return( $dir );
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
	
	# Get document IDs associated with this EPrint
	my $rows = $session->{database}->retrieve(
		EPrints::Database::table_name( "document" ),
		[ "docid" ],
		[ "eprintid LIKE \"$eprint->{eprintid}\"" ],
		[ "docid" ] );
	
	my $id;

	# Is there already a document for given EPrint?
	if( $#{$rows} >= 0 )
	{
		# Since they're ordered by docid, last in the list will be one we want
		$id = $rows->[$#{$rows}]->[0];

		# Extract all except last two digits
		$id =~ s/.*-//;
		$id++;

		# Add any preceding 0's
		while( length $id < $DIGITS )
		{
			$id = "0".$id;
		}
	}
	else
	{
		# No documents for this EPrint
		$id = "00";
	}

	return( $eprint->{eprintid} . "-" . $id );
}




######################################################################
#
# $clone = clone( $eprint )
#
#  Attempt to clone this document. The clone will be associated with
#  the given EPrint.
#
######################################################################

## WP1: BAD
sub clone
{
	my( $self, $eprint ) = @_;
	
	# First create a new doc object
	my $new_doc = EPrints::Document::create( $self->{session},
	                                         $eprint,
	                                         $self->{format} );
	return( 0 ) if( !defined $new_doc );
	
	# Copy fields across
	$new_doc->{formatdesc} = $self->{formatdesc};
	$new_doc->{main} = $self->{main};
	
	# Copy files
	my $rc = 0xffff & system
		"cp -a ".$self->local_path()."/* ".$new_doc->local_path();

	# If something's gone wrong...
	if ( $rc!=0 )
	{
		$self->{session}->get_archive()->log( "Error copying from ".$self->local_path()." to ".$new_doc->local_path().": $!" );
		return( 0 );
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

## WP1: BAD
sub remove
{
	my( $self ) = @_;

	# Remove database entry
	my $success = $self->{session}->{database}->remove(
		EPrints::Database::table_name( "document" ),
		"docid",
		$self->{docid} );
	
	if( !$success )
	{
		my $db_error = $self->{session}->{database}->error();
		$self->{session}->get_archive()->log( "Error removing document ".$self->{docid}." from database: $db_error" );
		return( 0 );
	}

	# Remove directory and contents
	my $full_path = $self->local_path();
	my $num_deleted = rmtree( $full_path, 0, 0 );

	if( $num_deleted <= 0 )
	{
		$self->{session}->get_archive()->log( "Error removing document files for ".$self->{docid}.", path ".$full_path.": $!" );
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
	                                       $self->{eprintid} );
	
	return( $self->{eprint} );
}


######################################################################
#
# $url = url()
#
#  Return the full URL of the document.
#
######################################################################

## WP1: BAD
sub url
{
	my( $self ) = @_;

	my $eprint = $self->get_eprint();

	return( undef ) if( !defined $eprint );
	
	return( URI::Escape::uri_escape(
		$eprint->url_stem() . $self->{docid} . "/" . $self->{main} ) );
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
	
	return( $eprint->local_path() . "/" . $self->{docid} );
}


######################################################################
#
# %files = files()
#
#  Returns a list of the files associated with this document.
#
######################################################################

## WP1: BAD
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

## WP1: BAD
sub _get_files
{
	my( $files, $root, $dir ) = @_;

	my $fixed_dir = ( $dir eq "" ? "" : $dir . "/" );

	# Read directory contents
	opendir CDIR, $root . "/" . $dir or return( undef );
	my @filesread = readdir CDIR;
	closedir CDIR;

	# Iterate through files
	foreach (@filesread)
	{
		if( $_ ne "." && $_ ne ".." )
		{
			# If it's a directory, recurse
			if( -d $root . "/" . $fixed_dir . $_ )
			{
				_get_files( $files, $root, $fixed_dir . $_ );
			}
			else
			{
				#my @stats = stat( $root . "/" . $fixed_dir . $_ );
				$files->{$fixed_dir.$_} = -s $root . "/" . $fixed_dir . $_;
				#push @files, $fixed_dir . $_;
			}
		}
	}

	#return( @files );
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
	undef $self->{main} if( $filename eq $self->{main} );

	my $count = unlink $self->local_path()."/".$filename;
	
	if( $count != 1 )
	{
		$self->{session}->get_archive()->log( "Error removing file $filename for doc ".$self->{docid}.": $!" );
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
		$self->{session}->get_archive()->log( "Error removing document files for ".$self->{docid}.", path ".$full_path.": $!" );
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
		$self->{main} = $main_file if( defined $all_files{$main_file} );
	}
	else
	{
		# The caller passed in undef, so we unset the main file
		undef $self->{main};
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
	
	return( $self->{main} );
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
	
	$self->{format} = $format;
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
	
	$self->{format_desc} = $format_desc;
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

	# Make the extraction command line
	my $extract_command =
		$self->{session}->get_archive()->{archive_extraction_commands}->{ $archive_format };

	$extract_command =~ s/_DIR_/$dest/g;
	$extract_command =~ s/_ARC_/$arc_tmp/g;
	

	# Do the extraction
	my $rc = 0xffff & system $extract_command;
	
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
	
	# Construct wget command line.
	my $command = $self->{session}->get_archive()->{wget_command};
	#my $escaped_url = uri_escape( $url );
	
	$command =~ s/_CUTDIRS_/$cut_dirs/g;
	$command =~ s/_URL_/"$url"/g;
	
	# Run the command
	my $rc = 0xffff & system $command;

	# If something's gone wrong...
	return( 0 ) if ( $rc!=0 );

	# Otherwise set the main file if appropriate
	if( !defined $self->{main} || $self->{main} eq "" )
	{
		my $endfile = $url;
		$endfile =~ s/.*\///;
		$self->set_main( $endfile );

		# If it's still undefined, try setting it to index.html or index.htm
		$self->set_main( "index.html" ) unless( defined $self->{main} );
		$self->set_main( "index.htm" ) unless( defined $self->{main} );

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
	
	my @fields = $self->{session}->{metainfo}->get_fields( "documents" );

	my $key_field = shift @fields;
	my $key_value = $self->{$key_field->{name}};

	my $success = $self->{session}->{database}->update(
		EPrints::Database::table_name( "document" ),
		$key_field->{name},
		$key_value,
		$self );

	if( !$success )
	{
		my $db_error = $self->{session}->{database}->error();
		$self->{session}->get_archive()->log( "Error committing Document ".$self->{docid}.": ".$db_error );
	}

	return( $success );
}
	



######################################################################
#
# @formats = get_supported_formats()
#
#  [STATIC] - return list of tags of supported document storage
#  formats (e.g. HTML, PDF etc.)
#
######################################################################

# cjg not in use?
#sub get_supported_formats
#{
	##my( $class ) = @_;
	#
	#my @formats = @EPrintSite::SiteInfo::supported_formats;
#
	#push @formats, $EPrints::Document::other
		#if $EPrintSite::SiteInfo::allow_arbitrary_formats;
	#
	#return( @formats );
#}


######################################################################
#
# $required = required_format( $session , $format )
#  [STATIC]
#
#  Return 1 if the given format is one of the list of required formats,
#  0 if not. Always returns 1 if no formats are required.
#
######################################################################

## WP1: BAD
sub required_format
{
	my( $session , $format ) = @_;
	
	return( 1 ) unless( @{$session->get_archive()->{required_formats}} );

	my $req = 0;

	foreach (@{$session->get_archive()->{required_formats}})
	{
		$req = 1 if( $format eq $_ );
	}

	return( $req );
}

## WP1: BAD
sub format_name
{
	my( $session , $format ) = @_;

        #"HTML"                     => "HTML",
        #"PDF"                      => "Adobe PDF",
        #"PS"                       => "Postscript",
        #"ASCII"                    => "Plain ASCII Text"

	return( "LANG SUPPORT PENDING( $format )" );
} 

## WP1: BAD
sub archive_name
{
	my( $sesion, $archivetype ) = @_;

	  #"ZIP"   => "ZIP Archive [.zip]",
        #"TARGZ" => "Compressed TAR archive [.tar.Z, .tar.gz]"

	return( "LANG SUPPORT PENDING( $archivetype )" );
}

######################################################################
#
# $problems = validate()
# array_ref
#
#  Make sure everything is OK with this document, i.e. that files
#  have been uploaded, 
#
######################################################################

## WP1: BAD
sub validate
{
	my( $self ) = @_;

	my @problems;
	
	# System default checks:
	# Make sure there's at least one file!!
	my %files = $self->files();

	if( scalar keys %files ==0 )
	{
		push @problems, $self->{session}->{lang}->phrase( "lib/document:no_files" );
	}
	elsif( !defined $self->{main} || $self->{main} eq "" )
	{
		# No file selected as main!
		push @problems, $self->{session}->{lang}->phrase( "lib/document:no_first" );
	}
	elsif( $self->{format} eq $EPrints::Document::other &&
		( !defined $self->{formatdesc} || $self->{formatdesc} eq "" ) )
	{
		# No description for an alternative format
		push @problems, $self->{session}->{lang}->phrase( "lib/document:no_desc" );
	}
		
	# Site-specific checks
	$self->{session}->get_archive()->validate_document( $self, \@problems );

	return( \@problems );
}

1;
