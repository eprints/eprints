######################################################################
#
# EPrints::Apache::Storage
#
######################################################################
#
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

=item Accept-Ranges

Sets Accept-Ranges to bytes.

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

use EPrints::Const qw( :http );
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
	return HTTP_NOT_FOUND unless defined $fileobj;

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

	if( $fileobj->is_set( "hash" ) )
	{
		my $etag = $r->headers_in->{'if-none-match'};
		if( defined $etag && $etag eq $fileobj->value( "hash" ) )
		{
			return HTTP_NOT_MODIFIED;
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
				return HTTP_NOT_MODIFIED;
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

	# Can use download=1 to force a download
	my $download = $repo->param( "download" );
	if( $download )
	{
		EPrints::Apache::AnApache::header_out(
			$r,
			"Content-Disposition" => "attachment; filename=".EPrints::Utils::uri_escape_utf8( $filename ),
		);
	}
	else
	{
		EPrints::Apache::AnApache::header_out(
			$r,
			"Content-Disposition" => "inline; filename=".EPrints::Utils::uri_escape_utf8( $filename ),
		);
	}

	EPrints::Apache::AnApache::header_out(
		$r,
		"Accept-Ranges" => "bytes"
	);

	# did the file retrieval fail?
	my $rv;

	my @chunks;
	my $rres = EPrints::Apache::AnApache::ranges( $r, $content_length, \@chunks );
	if( $rres == HTTP_PARTIAL_CONTENT && @chunks == 1 )
	{
		$r->status( $rres );
		my $chunk = shift @chunks;
		EPrints::Apache::AnApache::header_out( $r,
			"Content-Range" => sprintf( "bytes %d-%d/%d",
				@$chunk[0,1],
				$content_length
			) );
		EPrints::Apache::AnApache::header_out( 
			$r,
			"Content-Length" => $chunk->[1] - $chunk->[0] + 1
		);
		$rv = eval { $fileobj->get_file(
				sub { print $_[0] }, # CALLBACK
				$chunk->[0], # OFFSET
				$chunk->[1] - $chunk->[0] + 1 ) # n bytes
			};
	}
	elsif( $rres == HTTP_PARTIAL_CONTENT && @chunks > 1 )
	{
		$r->status( $rres );
		my $boundary = '4876db1cd4aa85af6';
		my @boundaries;
		my $body_length = 0;
		$r->content_type( "multipart/byteranges; boundary=$boundary" );
		for(@chunks)
		{
			$body_length += $_->[1] - $_->[0] + 1; # 0-0 means byte zero
			push @boundaries, sprintf("\r\n--%s\r\nContent-type: %s\r\nContent-range: bytes %d-%d/%d\r\n\r\n",
				$boundary,
				$content_type,
				@$_,
				$content_length
			);
			$body_length += length($boundaries[$#boundaries]);
		}
		push @boundaries, "\r\n--$boundary--\r\n";
		$body_length += length($boundaries[$#boundaries]);
		EPrints::Apache::AnApache::header_out( 
			$r,
			"Content-Length" => $body_length
		);
		for(@chunks)
		{
			print shift @boundaries;
			$rv = eval { $fileobj->get_file(
					sub { print $_[0] }, # CALLBACK
					$_->[0], # OFFSET
					$_->[1] - $_->[0] + 1 ) # n bytes
				};
			last if !$rv;
		}
		print shift( @boundaries ) if $rv;
	}
	elsif( $rres == HTTP_RANGE_NOT_SATISFIABLE )
	{
		return HTTP_RANGE_NOT_SATISFIABLE;
	}
	else # OK normal response
	{
		EPrints::Apache::AnApache::header_out( 
			$r,
			"Content-Length" => $content_length
		);
		$rv = eval { $fileobj->get_file( sub { print $_[0] } ) };
	}

	if( $@ )
	{
		# eval threw an error
		# If the software (web client) stopped listening
		# before we stopped sending then that's not a fail.
		# even if $rv was not set
		if(
			$@ !~ m/^Software caused connection abort/ &&
			$@ !~ m/:Apache2 IO write: \(104\) Connection reset by peer/ &&
			$@ !~ m/:Apache2 IO write: \(32\) Broken pipe/ &&
			$@ !~ m/:Apache2 IO write: \(70007\) The timeout specified has expired/
		  )
		{
			EPrints::abort( "Error in file retrieval: $@" );
		}
		else
		{
			# Shows in httpd logs as 499, even though the client
			# received a '200 Ok' response. From nginx
			return 499;
		}
	}
	elsif( !$rv )
	{
		EPrints::abort( "Error in file retrieval: failed to get file contents" );
	}

	return $rc;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

