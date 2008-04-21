package EPrints::Apache::Storage;

# This handler serves document files and thumbnails

use EPrints::Apache::AnApache; # exports apache constants

use strict;
use warnings;

sub handler
{
	my( $r ) = @_;

	my $rc = OK;

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

	$rc = check_auth( $session, $r, $doc );

	if( $rc != OK )
	{
		return $rc;
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

	return $rc;
}

sub check_auth
{
	my( $session, $r, $doc ) = @_;

	my $security = $doc->get_value( "security" );

	my $result = $session->get_repository->call( "can_request_view_document", $doc, $r );

	return OK if( $result eq "ALLOW" );
	return FORBIDDEN if( $result eq "DENY" );
	if( $result ne "USER" )
	{
		$session->get_repository->log( "Response from can_request_view_document was '$result'. Only ALLOW, DENY, USER are allowed." );
		return FORBIDDEN;
	}

	my $rc;
	if( $session->get_archive->get_conf( "cookie_auth" ) ) 
	{
		$rc = EPrints::Apache::Auth::auth_cookie( $r, $session, 1 );
	}
	else
	{
		$rc = EPrints::Apache::Auth::auth_basic( $r, $session );
	}

	return $rc;
}

1;
