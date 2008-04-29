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

	my $pnotes = $r->pnotes;
	my %pnotes = %$pnotes;

	for(qw( datasetid bucket filename ))
	{
		if( !defined($pnotes{$_}) )
		{
			EPrints::abort( "Fatal error in storage retrieval: required note '$_' is not defined in mod_perl pnotes" );
		}
	}

	my $datasetid = $pnotes{ "datasetid" };
	my $bucket = $pnotes{ "bucket" };
	my $filename = $pnotes{ "filename" };

	my $dataset = $session->get_repository->get_dataset( $datasetid );
	if( !$dataset )
	{
		EPrints::abort( "Fatal error in storage retrieval: dataset '$datasetid' defined in mod_perl pnotes is not a valid dataset" );
	}

	my $dataobj;

	# Retrieve document via eprintid + pos
	if( $datasetid eq "document" && defined($pnotes{ "eprintid" }) && defined($pnotes{ "pos" }) )
	{
		$dataobj = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
			$session,
			$pnotes{ "eprintid" },
			$pnotes{ "pos" }
		);
	}
	else
	{
		my( $keyfield ) = $dataset->get_fields();
		my $keyname = $keyfield->get_name;

		my $id = $pnotes{ $keyname };

		if( !defined( $id ) )
		{
			EPrints::abort( "Fatal error in storage retrieval: expected to find a mod_perl pnote for '$keyname' (keyfield for '$datasetid'), but didn't" );
		}

		$dataobj = $dataset->get_object( $session, $id );
	}

	if( !defined( $dataobj ) )
	{
		return 404;
	}

	$rc = check_auth( $session, $r, $dataobj );

	if( $rc != OK )
	{
		return $rc;
	}

	# Now get the file object itself
	$dataobj = $dataobj->get_stored_files( $bucket, $filename );

	if( !defined( $dataobj ) )
	{
		return 404;
	}

	my $content_type = $dataobj->get_value( "mime_type" );
	my $content_length = $dataobj->get_value( "filesize" );

	EPrints::Apache::AnApache::header_out( 
		$r,
		"Content-Length" => $content_length
	);

	$session->send_http_header(
		content_type => $content_type,
	);

	my $fh = $dataobj->get_fh();
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
