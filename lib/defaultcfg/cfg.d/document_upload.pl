
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
		my $guess = $session->config( "mimemap", $suffix );
		return $guess if( defined $guess );
	}

	return "other";
};

$c->{mimemap}->{htm}  = "text/html";
$c->{mimemap}->{html} = "text/html";
$c->{mimemap}->{txt}  = "text/plain";
$c->{mimemap}->{xml}  = "text/xml";
$c->{mimemap}->{n3}   = "text/n3";
$c->{mimemap}->{pdf}  = "application/pdf";
$c->{mimemap}->{ps}   = "application/postscript";
$c->{mimemap}->{ppt}  = "application/vnd.ms-powerpoint";
$c->{mimemap}->{pptx} = "application/vnd.ms-powerpoint";
$c->{mimemap}->{xls}  = "application/vnd.ms-excel";
$c->{mimemap}->{xlsx} = "application/vnd.ms-excel";
$c->{mimemap}->{doc}  = "application/msword";
$c->{mimemap}->{docx} = "application/msword";
$c->{mimemap}->{rtf}  = "application/rtf";
$c->{mimemap}->{bz2}  = "application/bzip2";
$c->{mimemap}->{gz}   = "application/x-gzip";
$c->{mimemap}->{tgz}  = "application/x-gzip";
$c->{mimemap}->{zip}  = "application/zip";
$c->{mimemap}->{rdf}  = "application/rdf+xml";
$c->{mimemap}->{jpg}  = "image/jpeg";
$c->{mimemap}->{jpeg} = "image/jpeg";
$c->{mimemap}->{png}  = "image/png";
$c->{mimemap}->{gif}  = "image/gif";
$c->{mimemap}->{bmp}  = "image/bmp";
$c->{mimemap}->{tiff} = "image/tiff";
$c->{mimemap}->{tif}  = "image/tiff";
$c->{mimemap}->{mpg}  = "video/mpeg";
$c->{mimemap}->{mpeg} = "video/mpeg";
$c->{mimemap}->{mov}  = "video/quicktime";
$c->{mimemap}->{avi}  = "video/x-msvideo";
$c->{mimemap}->{mp4}  = "video/mp4";
$c->{mimemap}->{m4v}  = "video/x-m4v";
$c->{mimemap}->{mp2t} = "video/mp2t";
$c->{mimemap}->{flv}  = "video/x-flv";
$c->{mimemap}->{wmv}  = "video/x-ms-wmv";
$c->{mimemap}->{wav}  = "audio/x-wav";
$c->{mimemap}->{mp3}  = "audio/mpeg";
$c->{mimemap}->{ogg}  = "audio/ogg";
$c->{mimemap}->{flac} = "audio/flac";
$c->{mimemap}->{wma}  = "audio/x-ms-wma";

# This subroutine is called every time that the files in a document are
# modified (added or removed).
# You can place hooks for things like automatic data extraction here.

$c->{on_files_modified} = sub
{
	my( $session, $document ) = @_;

	# do your stuff
};


