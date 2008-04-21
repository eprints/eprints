package EPrints::Apache::Storage;

# This handler serves document files and thumbnails

use strict;
use warnings;

sub handler
{
	my( $r ) = @_;

	my $session = EPrints::Session->new();
	my $repository = $session->get_repository;

	my $rel_path = $repository->get_conf( "rel_path" );

	# Get just the eprint/document/filename part
	my $uri = $session->get_uri;
	$uri = substr($uri, length($rel_path));
	$uri =~ s/^\///;

	my $use_thumbnails = 0;

	# If it's thumbnails/document we want the thumbnail path
	if( $uri =~ s/^(\d+)\/thumbnails/$1/ )
	{
		$use_thumbnails = 1;
	}

	my( $eprintid, $pos, $filename ) = split /\//, $uri;

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$session,
		$eprintid,
		$pos
	);

	if( !$doc )
	{
		return 404;
	}

	my $stored_uri;

	if( $use_thumbnails )
	{
		$stored_uri = $doc->get_storage_uri( "thumbnail", $filename );
	}
	else
	{
		$stored_uri = $doc->get_storage_uri( "bitstream", $filename );
	}

	my $fh = $doc->retrieve( $stored_uri );

	# Thumbnails are all PNG format at the moment
	if( $use_thumbnails )
	{
		my $content_type = "image/png";
		$session->send_http_header( content_type => $content_type );
	}
	# Otherwise set the content type to the document type
	elsif( $filename eq $doc->get_value( "main" ) )
	{
		my $content_type = $doc->get_value( "format" );
		$session->send_http_header( content_type => $content_type );
	}
	# Don't have any MIME type to set for other files
	else
	{
		# print STDERR "Unknown content type for $filename [".$doc->get_value( "main" )."]\n";
	}

	# byte semantics are much faster
	{
		use bytes;
		binmode($fh);
		binmode(STDOUT);
		my $buffer;
		while(sysread($fh,$buffer,4096))
		{
			print $buffer;
		}
	}

	close($fh);

	$session->terminate;

	return 0;
}

1;
