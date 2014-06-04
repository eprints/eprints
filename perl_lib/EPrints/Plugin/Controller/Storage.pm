package EPrints::Plugin::Controller::Storage;

use strict;
use EPrints;
use EPrints::Const qw( :http );
use APR::Date ();
use APR::Base64 ();

our @ISA = qw/ EPrints::Plugin::Controller /;

sub new
{
	my( $class, %params ) = @_;
	
	# TODO/sf2 should files - as digital objects - be served under /file/{id} ??

	$params{priority} = 15;

	my $self = $class->SUPER::new(%params);

	$self->register_endpoint( qr[^/data/(file|thumbnail)/(\d+)$], 'datasetid', 'objectid' );

	# alternative thumbnail delivery URL: /data/file/123/thumbnail/small	
	$self->register_endpoint( qr{^/data/file/(\d+)(/thumbnail/([^/]+))$}, 'fileid', 'thumbnail', 'thumbnail_type' );

	return $self;
}

sub init
{
	my( $self ) = @_;

	my $dataobj;
	my $dataset;

	if( $self->{thumbnail} )
	{
		my $fileid = $self->{fileid};
		my $type = $self->{thumbnail_type};

		$dataset = $self->repository->dataset( 'thumbnail' );

		# delivering a thumbnail via eg /data/file/123/thumbnail/small
		$dataobj = $dataset->search(
		filters => [
			{
				meta_fields => [qw( datasetid )],
				value => "file",
				match => "EX",
			},
			{
				meta_fields => [qw( objectid )],
				value => $fileid,
				match => "EX",
			},
			{
				meta_fields => [qw( fieldname )],
				value => "thumbnails",
				match => "EX",
			},
			{
				meta_fields => [qw( type )],
				value => "thumbnail_$type",
				match => "EX",
			},
		])->item( 0 );
	}
	else
	{
		# normal file
		my $datasetid = $self->{datasetid};
		my $objectid= $self->{objectid};

		if( !defined $datasetid || !defined $objectid )
		{
			# 500 cos the matching regex should have captured dataset id and object id
			return HTTP_INTERNAL_SERVER_ERROR;
		}

		$dataset = $self->repository->dataset( $datasetid );

		$dataobj = $dataset->dataobj( $objectid );
	}
	
	if( !defined $dataobj )
	{
		return HTTP_NOT_FOUND;
	}

	$self->{dataset} = $dataset;
	$self->{dataobj} = $dataobj;

	return HTTP_OK;
}

sub action
{
	my( $self ) = @_;
	
	my $method = $self->method;

	if( $method eq 'GET' )
	{
		return 'view';
	}
	elsif( $method =~ /POST|PUT|PATCH/ )
	{
		return 'edit';
	}
	elsif( $method eq 'DELETE' )
	{
		return 'destroy';
	}

	return;
}

# Access handler
sub auth
{
	my( $self ) = @_;

	return EPrints::Apache::Auth::authen_dataobj_action(
		repository => $self->repository,
		request => $self->{request},
		dataobj => $self->{dataobj},
		dataset => $self->{dataset},
		action => $self->action,
	);
}

# Access handler
sub authz
{
	my( $self ) = @_;
	
	return EPrints::Apache::Auth::authz_dataobj_action(
		repository => $self->repository,
		request => $self->{request},
		dataobj => $self->{dataobj},
		dataset => $self->{dataset},
		action => $self->action,
	);
}

sub GET
{
	my( $self ) = @_;

	my $rc = OK;

	my $repo = $self->repository;
	my $r = $self->{request};

	# TODO the MIME-type/content negotiation must be generalised somehow!
	my @accepts = EPrints::Utils::parse_media_range( $r->headers_in->{Accept} || '*/*' );

	my $do_it = 0;

	my %valid_mimes = map { $_ => undef } ( 'application/xhtml+xml', 'text/html', '*/*' );

	foreach my $choice ( @accepts )
	{
		my( $mime_type, undef, %params ) = @$choice;

		if( exists $valid_mimes{$mime_type} )
		{
			$do_it = 1;
			last;
		}
	}

	# TODO - sf2/oouch
	# cannot return undef here (too late)
	# perhaps the Accept should be part of the selection of the plug-in?!	
	if( !$do_it )
	{
		return undef;
	}

	my $dataobj = $self->{dataobj};
		
	# TODO doesn't seem to be ever set (came from pnotes( "filename "))
	my $filename = undef;	

	# Now get the file object itself
	
	my $fileobj;
	if( defined $dataobj && $dataobj->isa( "EPrints::DataObj::File" ) )
	{
		$fileobj = $dataobj;
		$filename = $dataobj->value( 'filename' );
	}
	
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
		EPrints::Apache::header_out(
			$r,
			"ETag" => $fileobj->value( "hash" )
		);
		if( $fileobj->value( "hash_type" ) eq "MD5" )
		{
			my $md5 = $fileobj->value( "hash" );
			# convert HEX-coded to Base64 (RFC1864)
			$md5 = APR::Base64::encode( pack("H*", $md5) );
			EPrints::Apache::header_out(
				$r,
				"Content-MD5" => $md5
			);
		}
	}

	if( $fileobj->is_set( "lastmod" ) )
	{
		my $cur_time = EPrints::Time::datestring_to_timet( undef, $fileobj->value( "lastmod" ) );
		my $ims = $r->headers_in->{'if-modified-since'};
		if( defined $ims )
		{
			my $ims_time = APR::Date::parse_http( $ims );
			if( $ims_time && $cur_time && $ims_time >= $cur_time )
			{
				return HTTP_NOT_MODIFIED;
			}
		}
		EPrints::Apache::header_out(
			$r,
			"Last-Modified" => Apache2::Util::ht_time( $r->pool, $cur_time )
		);
		# can't go too far into the future or we'll wrap 32bit times!
		EPrints::Apache::header_out(
			$r,
			"Expires" => Apache2::Util::ht_time( $r->pool, time() + 365 * 86400 )
		);
	}

	# Can use download=1 to force a download
	my $download = $repo->param( "download" );
	if( $download )
	{
		EPrints::Apache::header_out(
			$r,
			"Content-Disposition" => "attachment; filename=".EPrints::Utils::uri_escape_utf8( $filename ),
		);
	}
	else
	{
		EPrints::Apache::header_out(
			$r,
			"Content-Disposition" => "inline; filename=".EPrints::Utils::uri_escape_utf8( $filename ),
		);
	}

	EPrints::Apache::header_out(
		$r,
		"Accept-Ranges" => "bytes"
	);

	# did the file retrieval fail?
	my $rv;

	my @chunks;
	my $rres = EPrints::Apache::ranges( $r, $content_length, \@chunks );
	if( $rres == HTTP_PARTIAL_CONTENT && @chunks == 1 )
	{
		$r->status( $rres );
		my $chunk = shift @chunks;
		EPrints::Apache::header_out( $r,
			"Content-Range" => sprintf( "bytes %d-%d/%d",
				@$chunk[0,1],
				$content_length
			) );
		EPrints::Apache::header_out( 
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
		EPrints::Apache::header_out( 
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
		EPrints::Apache::header_out( 
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

sub DELETE
{
	my( $self ) = @_;

	my $dataobj = $self->{dataobj};
	if( $dataobj->remove )
	{
		return HTTP_OK;
	}

	return HTTP_INTERNAL_SERVER_ERROR;
}

1;
