######################################################################
#
# EPrints::Apache::Storage
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Apache::Storage;

# This handler serves document files and thumbnails

=head1 NAME

EPrints::Apache::Storage - deliver file objects via mod_perl

=head1 DESCRIPTION

This mod_perl handle supports the delivery of the content of L<EPrints::DataObj::File> objects.

=head2 Defined HTTP Headers

These headers will be set by this module, where possible.

=over 4

=item Content-Disposition

The string "inline; filename=FILENAME" where FILENAME is the B<filename> value of the file object.

If the I<download> CGI parameter is true disposition is changed from "inline" to "attachment", which will present a download dialog box in sane browsers.

=item Content-Length

The B<filesize> value of the file object.

=item Content-MD5

The MD5 of the file content in base-64 encoding if the B<hash> value is set and B<hash_type> is 'MD5'.

=item Content-Type

The B<mime_type> value of the file object, or "application/octet-stream" if not set.

=item ETag

The B<hash> value of the file object, if set.

=item Expires

The current time + 365 days, if the B<mtime> value is set.

=item Last-Modified

The B<mtime> of the file object, if set.

=back

=head2 Recognised HTTP Headers

The following headers are recognised by this module.

=over 4

=item If-Modified-Since

If greater than or equal to the B<mtime> value of the file object returns "304 Not Modified".

=item If-None-Match

If differs from the B<hash> value of the file object returns "304 Not Modified".

=back

=cut

use EPrints::Apache::AnApache; # exports apache constants
use APR::Date ();
use APR::Base64 ();

use strict;

sub handler
{
	my( $r ) = @_;

	my $rc = OK;

	my $repo = $EPrints::HANDLE->current_repository();

	my $dataobj = $r->pnotes( "dataobj" );
	my $filename = $r->pnotes( "filename" );

	# Now get the file object itself
	my $fileobj = $dataobj->get_stored_file( $filename );
	return NOT_FOUND unless defined $fileobj;

	my $url = $fileobj->get_remote_copy();
	if( defined $url )
	{
		$repo->redirect( $url );

		return $rc;
	}

	# Use octet-stream for unknown mime-types
	my $content_type = $fileobj->is_set( "mime_type" )
		? $fileobj->get_value( "mime_type" )
		: "application/octet-stream";

	my $content_length = $fileobj->get_value( "filesize" );

	$r->content_type( $content_type );

	$repo->set_cookies();

	if( $fileobj->is_set( "hash" ) )
	{
		my $etag = $r->headers_in->{'if-none-match'};
		if( defined $etag && $etag eq $fileobj->value( "hash" ) )
		{
			$r->status_line( "304 Not Modified" );
			return 304;
		}
		EPrints::Apache::AnApache::header_out(
			$r,
			"ETag" => $fileobj->value( "hash" )
		);
		if( $fileobj->value( "hash_type" ) eq "MD5" )
		{
			my $md5 = $fileobj->value( "hash" );
			# convert HEX-coded to Base64 (RFC1864)
			$md5 = APR::Base64::encode( pack("H*", $md5) );
			EPrints::Apache::AnApache::header_out(
				$r,
				"Content-MD5" => $md5
			);
		}
	}

	if( $fileobj->is_set( "mtime" ) )
	{
		my $cur_time = EPrints::Time::datestring_to_timet( undef, $fileobj->value( "mtime" ) );
		my $ims = $r->headers_in->{'if-modified-since'};
		if( defined $ims )
		{
			my $ims_time = APR::Date::parse_http( $ims );
			if( $ims_time && $cur_time && $ims_time >= $cur_time )
			{
				$r->status_line( "304 Not Modified" );
				return 304;
			}
		}
		EPrints::Apache::AnApache::header_out(
			$r,
			"Last-Modified" => Apache2::Util::ht_time( $r->pool, $cur_time )
		);
		# can't go too far into the future or we'll wrap 32bit times!
		EPrints::Apache::AnApache::header_out(
			$r,
			"Expires" => Apache2::Util::ht_time( $r->pool, time() + 365 * 86400 )
		);
	}

	EPrints::Apache::AnApache::header_out( 
		$r,
		"Content-Length" => $content_length
	);

	# Can use download=1 to force a download
	my $download = $repo->param( "download" );
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

	my $rv = eval { $fileobj->write_copy_fh( \*STDOUT ); };
	if( $@ )
	{
		# eval threw an error
		# If the software (web client) stopped listening
		# before we stopped sending then that's not a fail.
		# even if $rv was not set
		if( $@ !~ m/^Software caused connection abort/ )
		{
			EPrints::abort( "Error in file retrieval: $@" );
		}
	}
	elsif( !$rv )
	{
		EPrints::abort( "Error in file retrieval: failed to get file contents" );
	}

	return $rc;
}

1;
