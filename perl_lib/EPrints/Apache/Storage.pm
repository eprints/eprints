package EPrints::Apache::Storage;

# This handler serves document files and thumbnails

use EPrints::Apache::AnApache; # exports apache constants

use strict;
use warnings;

sub handler
{
	my( $r ) = @_;

	my $rc = OK;

	my $handle = EPrints->get_handle();

	my $datasetid = $r->pnotes( "datasetid" );
	my $dataset = $handle->get_repository->get_dataset( $datasetid );
	return 404 unless defined $dataset;

	my $filename = $r->pnotes( "filename" );
	return 404 unless defined $filename;

	my $dataobj;
	if( $dataset->confid eq "document" && !defined $r->pnotes( "docid" ) )
	{
		$dataobj = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
				$handle,
				$r->pnotes( "eprintid" ),
				$r->pnotes( "pos" )
			);
	}
	else
	{
		my $id = $r->pnotes( $dataset->get_key_field->get_name );
		return 404 unless defined $id;
		$dataobj = $dataset->get_object( $handle, $id );
	}

	return 404 unless defined $dataobj;

	my $relations = $r->pnotes( "relations" );
	$relations = [] unless defined $relations;

	foreach my $relation (@$relations)
	{
		$relation = EPrints::Utils::make_relation( $relation );
		$dataobj = $dataobj->get_related_objects( $relation )->[0];
		return 404 unless defined $dataobj;
		$filename = $dataobj->get_main();
	}

	$r->pnotes( dataobj => $dataobj );

	$rc = check_auth( $handle, $r, $dataobj );

	if( $rc != OK )
	{
		return $rc;
	}

	# Now get the file object itself
	my $fileobj = $dataobj->get_stored_file( $filename );

	return 404 unless defined $fileobj;

	my $url = $fileobj->get_remote_copy();
	if( defined $url )
	{
		$handle->redirect( $url );

		return $rc;
	}

	# Use octet-stream for unknown mime-types
	my $content_type = $fileobj->is_set( "mime_type" )
		? $fileobj->get_value( "mime_type" )
		: "application/octet-stream";

	my $content_length = $fileobj->get_value( "filesize" );

	EPrints::Apache::AnApache::header_out( 
		$r,
		"Content-Length" => $content_length
	);

	# Can use download=1 to force a download
	my $download = $handle->param( "download" );
	if( $download )
	{
		EPrints::Apache::AnApache::header_out(
			$r,
			"Content-Disposition" => "attachment; filename=$filename",
		);
	}
	else
	{
		EPrints::Apache::AnApache::header_out(
			$r,
			"Content-Disposition" => "inline; filename=$filename",
		);
	}

	$handle->send_http_header(
		content_type => $content_type,
	);

	if( !$fileobj->write_copy_fh( \*STDOUT ) )
	{
		EPrints::abort( "Error in file retrieval: failed to get file contents" );
	}

	$handle->terminate;

	return $rc;
}

sub check_auth
{
	my( $handle, $r, $doc ) = @_;

	my $security = $doc->get_value( "security" );

	my $result = $handle->get_repository->call( "can_request_view_document", $doc, $r );

	return OK if( $result eq "ALLOW" );
	return FORBIDDEN if( $result eq "DENY" );
	if( $result ne "USER" )
	{
		$handle->get_repository->log( "Response from can_request_view_document was '$result'. Only ALLOW, DENY, USER are allowed." );
		return FORBIDDEN;
	}

	my $rc;
	if( $handle->get_repository->get_conf( "cookie_auth" ) ) 
	{
		$rc = EPrints::Apache::Auth::auth_cookie( $r, $handle, 1 );
	}
	else
	{
		$rc = EPrints::Apache::Auth::auth_basic( $r, $handle );
	}

	if( $rc eq OK )
	{
		my $user = $handle->current_user;
		return FORBIDDEN unless defined $user; # Shouldn't happen
		$rc = $doc->user_can_view( $user ) ? OK : FORBIDDEN;
	}

	return $rc;
}

1;
