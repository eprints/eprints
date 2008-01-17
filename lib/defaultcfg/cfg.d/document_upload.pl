
######################################################################
#
#  Document file upload information
#
######################################################################

# AT LEAST one of the following formats will be required. If you do
# not want this requirement, then make the list empty (Although this
# means users will be able to submit eprints with ZERO documents.
#
# Available formats are configured elsewhere. See the docs.

$c->{required_formats} = 
[
#	"text/html",
#	"application/pdf",
#	"application/postscript",
#	"text/plain",
];

# if you want to make this depend on the values in the eprint then
# you can make it a function pointer instead. The function should
# return a list as above.

# This example requires all normal formats for all eprints except
# for those of type book where a document is optional.
#
# $c->{required_formats} = sub {
# 	my( $eprint ) = @_;
# 
# 	if( $eprint->get_value( 'type' ) eq "book" )
# 	{
# 		return [];
# 	}
# 	return [
#		'text/html',
#		'application/pdf',
#		'application/postscript',
#		'text/plain',
#	];
# };

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$c->{diskspace_error_threshold} = 64*1024;

# If ever the amount of free space drops below this threshold, the
# repository administrator is sent a warning email. In kilobytes.
$c->{diskspace_warn_threshold} = 512*1024;


# make a very loose stab at the file format
# By default this just looks at the filename suffix, but there's no reason
# It can't be much more clever.
# It must return a legal document format id.
$c->{guess_doc_type} = sub
{
	my( $session, $filename ) = @_;

	my @formats = $session->get_repository->get_types( "document" );

	if( $filename=~m/\.([^.]+)$/ )
	{
		my $suffix = "\L$1";

		return "text/html" if $suffix eq "htm";
		return "text/html" if $suffix eq "html";
		return "application/pdf" if $suffix eq "pdf";
		return "application/postscript" if $suffix eq "ps";
		return "text/plain" if $suffix eq "txt";
		return "application/vnd.ms-powerpoint" if $suffix eq "ppt";
		return "application/vnd.ms-excel" if $suffix eq "xls";
		return "application/msword" if $suffix eq "doc";
		return "image/jpeg" if $suffix eq "jpg";
		return "image/jpeg" if $suffix eq "jpeg";
		return "image/png" if $suffix eq "png";
		return "image/gif" if $suffix eq "gif";
		return "image/bmp" if $suffix eq "bmp";
		return "image/tiff" if $suffix eq "tiff";
		return "image/tiff" if $suffix eq "tif";
		return "video/mpeg" if $suffix eq "mpg";
		return "video/mpeg" if $suffix eq "mpeg";
		return "video/quicktime" if $suffix eq "mov";
		return "video/x-msvideo" if $suffix eq "avi";
	}

	return "other";
};

# This subroutine is called every time that the files in a document are
# modified (added or removed).
# You can place hooks for things like automatic data extraction here.

$c->{on_files_modified} = sub
{
	my( $session, $document ) = @_;

	# do your stuff
};


