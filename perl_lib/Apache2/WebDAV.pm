#
# Perl implementation of a WebDAV server running under apache.
#

package Apache2::WebDAV;

use strict;
use warnings;

our $VERSION = '0.01';

use mod_perl2;
use Apache2::Const qw(:common :http);
use Apache2::Util qw(unescape_uri escape_uri);
use Apache2::RequestRec;
use APR::UUID;
use Data::Dumper;
use Encode;
use File::Spec;
use File::Find::Rule::Filesys::Virtual;
use URI;
use URI::Escape;
use XML::Simple qw(:strict);
use XML::LibXML;
use XML::LibXML::SAX;
use Fcntl ':mode';

#
# This module implements an abstract WebDAV server layer.  Like
# Net::DAV::Server, which it was sort of modelled after, this module interacts
# with instances of Filesys::Virtual child classes.
#
# Wherever possible, I have used the response constants from Apache::Constants,
# but sometimes there isn't one, and the code has been used directly.
#

# A list of implemented methods.
my %implemented = (
    copy     => 1,
    delete   => 1,
    get      => 1,
    head     => 1,
    mkcol    => 1,
    move     => 1,
    options  => 1,
    propfind => 1,
    put      => 1,
    #proppatch => 1,
    post     => 1,
    #trace    => 1,
    #lock     => 1,
    #unlock   => 1,
);

#
# Constructor.  Does nothing.
#
sub new
{
    my $class = shift;

    bless {}, $class;
}

#
# Specify which modules will handle which paths.
#
sub register_handlers
{
    my ($self, @handlers) = @_;

    $self->{'handlers'} = \@handlers;
}

#
# Process the request.  The $r is the apache object passed in from the mod_perl
# handler.
#
sub process
{
    my ($self, $r) = @_;

    my $uri    = $r->uri();
    my $method = lc($r->method());

    my $handler = $self->get_handler_for_path($uri);

    if($implemented{$method})
    {
        return $self->$method($r, $handler);
    }
    else
    {
        return DECLINED;
    }
}

#
# Started working on this, targeted clients don't need it, never finished.
#

# sub proppatch
# {
#     my ($self, $r, $handler) = @_;
# 
#     $r->status(200);
#     $r->headers_out->{("Allow",
#                    "OPTIONS, HEAD, GET, PUT, " .
#                    "DELETE, MKCOL, PROPPATCH, PROPFIND, COPY, MOVE");
#     $r->headers_out->{("DAV", "1,<http://apache.org/dav/propset/fs/1>");
#     $r->send_http_header();
# 
#     return OK;
# }

#
# Copy a resource to another location.
#
sub copy
{
    my ($self, $r, $handler) = @_;

    my $path = decode_utf8 $r->uri();

    my $destination = $r->headers_in->{'Destination'};
    my $depth       = $r->headers_in->{'Depth'};
    my $overwrite   = $r->headers_in->{'Overwrite'};

    # Default according to the book is overwrite = T
    if(!defined($overwrite))
    {
        $overwrite = 'T';
    }

    # Translate the destination into a usable format
    $destination = URI::Escape::uri_unescape(URI->new($destination)->path());

    # If it's a regular file, don't sweat it
    if($handler->test('f', $path))
    {
        return $self->copy_file($r, $handler, $path, $destination, $overwrite);
    }

    # Otherwise, we're copying a directory and we have to do it recursively.
    # The logic for this was taken from Net::DAV::Server.  It's creepy.

    # We can't really go to infinity, but we can fake it.
    $depth = 100 if defined($depth) && $depth eq 'infinity';

    # Search for source files that we have to copy
    my @files = map { s|/+|/|g; $_ }
        File::Find::Rule::Filesys::Virtual->virtual($handler)->file->maxdepth($depth)->in($path);

    # Search for source directories that we have to copy (didn't I tell you it
    # was creepy?)
    my @dirs = reverse sort
        grep { $_ !~ m|/\.\.?$| }
         map { s|/+|/|g; $_ }
        File::Find::Rule::Filesys::Virtual->virtual($handler)->directory->maxdepth($depth)->in($path);

    push @dirs, $path;

    # Create all required directories first
    foreach my $dir (sort @dirs)
    {
        my $dest_dir = $dir;

        $dest_dir =~ s/^$path/$destination/;

        if($overwrite eq 'F' && $handler->test('e', $dest_dir))
        {
            return 401;
        }

        if(!$handler->mkdir($dest_dir))
        {
            return 403;
        }

        # If there are no files, we need to properly return from here.
        if(!scalar(@files))
        {
            return 201;
        }
    }

    # Then copy over each file
    foreach my $file (reverse sort @files)
    {
        my $dest_file = $file;

        $dest_file =~ s/^$path/$destination/;

        my $fh = $handler->open_read($file);
        my $contents = join '', <$fh>;

        $handler->close_read($fh);

        # Don't write if the file exists and overwrite is FALSE
        if($handler->test('e', $dest_file) && $overwrite eq 'F')
        {
            return 401;
        }

        # Write the new file
        $fh = $handler->open_write($dest_file);
        print $fh $file;
        $handler->close_write($fh);
    }

    return 201;
}

#
# Copy a single file.
#
sub copy_file
{
    my ($self, $r, $handler, $source, $destination, $overwrite) = @_;

    # If the destination already exists and it's a directory, we can't proceeed
    if($handler->test('d', $destination))
    {
        return HTTP_NO_CONTENT; # litmus/spec requires this...
    }

    # Strange to report NOT_FOUND if we can't read the file... alternatives?
    if(!$handler->test('r', $source))
    {
        return NOT_FOUND;
    }

    # 412 return code specified by the litmus test
    if($handler->test('f', $destination) && $overwrite eq 'F')
    {
        return 412; # Precondition Failed?
    }

    # Finally, read the source file.
    my $fh = $handler->open_read($source);
    my $file = join '', <$fh>;
    $handler->close_read($fh);

    # And write the destination file
    $fh = $handler->open_write($destination);

    # I think this means the destination file was not writable because it
    # doesn't already exist.  Picked the 409 code because that's what the
    # litmus test says I should put here.
    if(!$fh)
    {
        return 409; # huh?
    }

    print $fh $file;
    $handler->close_write($fh);

    return 201; # Created.
}

#
# The delete() method was screwing up the status somehow (even after
# resetting it) because it was handling both deletions and reporting errors.
#
# This method only does the deletes.  The delete method should be
# revised to call this instead of doing actual work.
#
sub delete_resource
{
    my ($self, $r, $handler, $file) = @_;

    unless($handler->test('e', $file))
    {
        return NOT_FOUND;
    }

    if($handler->test('d', $file))
    {
        # Get a list of all files affected by the delete request (we have to do
        # them one by one).  The ->in() method gets a list of all files under the
        # specified path recursively.
        my @files = grep {$_ !~ m|/\.\.?$|} # Make sure it's not a / . ..
                    map { s|/+|/|g; $_ }    # Replace multiple slashes with single
        File::Find::Rule::Filesys::Virtual->virtual($handler)->in($file), $file;

        foreach my $file (@files)
        {
            next unless $handler->test('e', $file); # make sure file exists

            if($handler->test('d', $file))
            {
                $handler->rmdir($file) or return 0;
            }
            else
            {
                $handler->delete($file) or return 0;
            }
        }

        return 1;
    }
    else
    {
        return $handler->delete($file);
    }
}

#
# Delete a file or a collection, recursively.
#
sub delete
{
    my ($self, $r, $handler) = @_;

    my $path = $r->uri();

    unless($handler->test('e', $path))
    {
        return NOT_FOUND;
    }

    # Get a list of all files affected by the delete request (we have to do
    # them one by one).  The ->in() method gets a list of all files under the
    # specified path recursively.
    my @files = grep {$_ !~ m|/\.\.?$|} # Make sure it's not a / or a . or a ..
                 map { s|/+|/|g; $_ }   # Replace multiple slashes with a single
    File::Find::Rule::Filesys::Virtual->virtual($handler)->in($path), $path;

    my @errors;

    foreach my $file (@files)
    {
        next unless $handler->test('e', $file); # make sure file exists

        if($handler->test('f', $file))
        {
            push @errors, $file unless $handler->delete($file);
        }
        elsif($handler->test('d', $file))
        {
            push @errors, $file unless $handler->rmdir($file);
        }
    }

    if(@errors)
    {
        return $self->delete_response($r, \@errors);
    }
    else
    {
        return HTTP_NO_CONTENT;
    }
}

#
# Fetch a resource.
#
sub get
{
    my ($self, $r, $handler) = @_;

    my $path = $r->uri();

    # If the requested path is a readable file, use the Filesys::Virtual
    # interface to read the file and send it back to the client.
    if($handler->test('f', $path) && $handler->test('r', $path))
    {
		use bytes;

        my $fh = $handler->open_read($path) or return NOT_FOUND;

		my $written = 0;
		while(sysread($fh, $_, 4096))
		{
			$written += length($_);
			$r->print($_);
		}

        $handler->close_read($fh);

        $r->status(200);
        $r->headers_out->{'Content-Length'} = $written;
        $r->headers_out->{'Last-Modified'} = $handler->modtime($path);
		my $mime_type = 'application/octet-stream';
		if( $handler->can( "mime_type" ) )
		{
			$mime_type = $handler->mime_type( $path );
		}
		$r->headers_out->{'Content-Type'} = $mime_type;

        return OK;
    }
    # If the requested path is a directory, it's unclear what we're supposed to
    # do.  Net::DAV::Server prints an HTML representation of the directory
    # structure.
    #
    # Update: this happens if you connect with a regular browser, or if you
    # connect using IE but don't check the Web Folder box.  So just print a
    # warning.
    elsif($handler->test('d', $path))
    {
        $r->content_type('text/html; charset="utf-8"');
#        $r->send_http_header();
        $r->print("If you are using IE, please use File -> Open and check the
                   Open As Web Folder box.");
		return OK;
    }
    else
    {
        return NOT_FOUND;
    }
}

#
# Respond to a head request about a file.
#
sub head
{
    my ($self, $r, $handler) = @_;

    my $path = $r->uri();

    if($handler->test('f', $path))
    {
        $r->headers_out->{'Last-Modified'} = $handler->modtime($path);
    }
    elsif($handler->test('d', $path))
    {
        $r->content_type('text/html; charset="utf-8"');
#        $r->send_http_header();
    }
    else
    {
        return NOT_FOUND;
    }

    return OK;
}

#
# Create a "collection" which is actually a directory.
#
sub mkcol
{
    my ($self, $r, $handler) = @_;

    my $path = $r->uri();

    my $content = $self->get_request_content($r);

    if($content)
    {
        return 415; # huh?
    }
    elsif(!$handler->test('e', $path))
    {
        if(!$handler->mkdir($path))
		{
			return 403;
		}
        if(!$handler->test('d', $path))
        {
            return 409; # What?
        }
        else
        {
            return 201; # Created.
        }
    }
    else
    {
        return HTTP_METHOD_NOT_ALLOWED;
    }
}

#
# Move a resource to another location.  I'm specifically performing a copy and
# then a delete, something that sort of makes sense but has specific drawbacks
# according to the WebDAV book.  We'll worry about it later, because it's
# possible that none of our child modules will ever use this functionality.
#
sub move
{
    my ($self, $r, $handler) = @_;

    my $path = decode_utf8 $r->uri();

    my $destination = $r->headers_in->{'Destination'};

    $destination = URI::Escape::uri_unescape(URI->new($destination)->path());

    my $overwrite = $r->headers_in->{'Overwrite'};

    $overwrite = 'T' if !defined($overwrite);

    my $already_exists = $handler->test('e', $destination);

    $already_exists = 0 if !defined($already_exists);

    my $overwrote_collection = 0;

    if($already_exists) # delete it first
    {
        if($overwrite eq 'T')
        {
            if($handler->test('d', $destination))
            {
                $overwrote_collection = 1;
            }

            $r->uri($destination); # Specify the URI for the following deletion

            my $result = $self->delete($r, $handler);

            $r->uri(encode_utf8 $path);        # Reset URI to original value
        }
    }

	if( $handler->can( "rename" ) )
	{
		if( $handler->rename( $path, $destination ) )
		{
			$r->err_headers_out->{'Location'} = $r->headers_in->{'Destination'};
			return 201;
		}
	}
	else
	{
		return FORBIDDEN;
	}

    my $copy_result = $self->copy($r, $handler);

    if($copy_result != 201)
    {
        if($copy_result == 412)
        {
            return 412;
        }
        elsif($copy_result == HTTP_NO_CONTENT) # Directory already existed
        {
            return 403;
        }
        else
        {
            return FORBIDDEN;
        }
    }

    my $delete_result = $self->delete_resource($r, $handler, $path);

    # Did the delete work properly?
    if(!$delete_result)
    {
        return FORBIDDEN;
    }

    if($already_exists)
    {
        return 204;
    }
    else
    {
        return 201;
    }
}

#
# Specify the options this WebDAV server supports.
#
sub options
{
    my ($self, $r, $handler) = @_;

    $r->headers_out->{'Allow'}         = join(',', map { uc } keys %implemented);
    $r->headers_out->{'DAV'}           = '1,2,<http://apache.org/dav/propset/fs/1>';
    $r->headers_out->{'MS-Author-Via'} = 'DAV';
    $r->headers_out->{'Keep-Alive'}    = 'timeout=15, max=96';

#    $r->send_http_header();

    return OK;
}

#
# Get information about a file or a directory (or the contents of a directory).
#
sub propfind
{
    my ($self, $r, $handler) = @_;

    my $depth = $r->headers_in->{'Depth'};
    my $uri   = $self->decode_uri( $r, $r->unparsed_uri() );

    # Make sure the resource exists
    if(!$handler->test('e', $uri))
    {
        return NOT_FOUND;
    }

    $r->status(207);
    $r->content_type('text/xml; charset="utf-8"');

    my @files;

    if($depth == 0)
    {
        @files = ($uri);
    }
    elsif($depth == 1)
    {
        $uri =~ s/\/$//; # strip trailing slash, we don't store it in the db

        @files = $handler->list($uri);

        # remove . and .. from the list
        @files = grep( $_ !~ /^\.\.?$/, @files );

        # Add a trailing slash to the directory if there isn't one already
        if($uri !~ /\/$/)
        {
            $uri .= '/';
        }

        # Add the current folder to the front of the filename
        @files = map { "$uri$_" } @files;

        # Goliath only doesn't want to see the current/base directory in the
        # response.
        if($r->headers_in->{'User-Agent'} !~ /Goliath/)
        {
            push @files, $uri;
        }
    }

    my %wanted_properties = $self->get_wanted_properties($r);

    # The list of properties in order which a stat() call must return.
    my @properties = qw(dev ino mode nlink uid gid rdev getcontentlength
                        atime getlastmodified creationdate);

    # Loop through all the files and call stat() on each one.  Keep track of
    # which properties the client requested.
    my @results;

    foreach my $path (@files)
    {
        my %stat;
        my $info;

        my $handler = $self->get_handler_for_path($path);

		my $mime_type = 'application/octet-stream';
		if( $handler->can( "mime_type" ) )
		{
			$mime_type = $handler->mime_type( $path );
		}
		# Nautilus seems to behave better without the content-type
        if($r->headers_in->{'User-Agent'} =~ /gvfs/)
		{
			$mime_type = undef;
		}

        $info->{'getcontenttype'} = $mime_type;
        $info->{'resourcetype'}   = '';

#        if($handler->test('d', $path))
#        {
#            $info->{'getcontenttype'} = 'httpd/unix-directory';
#            $info->{'resourcetype'}   = 'collection';
#        }

        @stat{@properties} = $handler->stat($path);
		if( $stat{"mode"} & S_IFDIR )
		{
            $info->{'getcontenttype'} = 'httpd/unix-directory';
            $info->{'resourcetype'}   = 'collection';
		}
		$stat{"creationdate"} = iso_datetime( $stat{"creationdate"})
			if defined $stat{"creationdate"};
		$stat{"getlastmodified"} = gmtime($stat{"getlastmodified"})
			if defined $stat{"getlastmodified"};

        foreach my $prop (keys %wanted_properties)
        {
            # These are set above automatically, don't want to overwrite them
            next if $prop eq 'resourcetype';
            next if $prop eq 'getcontenttype';

			if( defined $stat{$prop} )
			{
				$info->{$prop} = $stat{$prop};
			}
        }

        push @results, {
            path => $path,
            stat => $info
        }
    }

    return $self->list_response($r, \@results);
}

#
# Write a file.
#
sub put
{
    my ($self, $r, $handler) = @_;

    my $path = $r->uri();

    my $fh = $handler->open_write($path) or return 403;

    my $content = $self->get_request_content($r);

    print $fh $content;

    $handler->close_write($fh);

    return 201; # Created.
}

#
# lock a resource
# 
sub lock
{
    my ($self, $r, $handler) = @_;

	my $rc = OK;

    my $path = $r->uri();

    # Grab the content of the request so we can parse it and look for which
    # lock properties they want
    my $content = $self->get_request_content($r);

print STDERR "LOCK:\n$content\n";

    # NSExpand expands namespaces so, xmlns:D eq '{DAV:}' in front of every
    # element in that namespace.
    my $xml;

    eval
    {
        $xml = XMLin($content, NSExpand => 1, ForceArray => 0, KeyAttr => []);
    };

    # If parsing the XML file failed, override the 207 status with a 400
    # and return undef.
    if(!$xml)
    {
        return 400;
    }

	my $prefix = "{DAV:}";

	my( $scope ) = keys %{$xml->{"${prefix}lockscope"}};
	$scope =~ s/^$prefix// if $scope;
	if( !$scope or !($scope eq "exclusive" or $scope eq "shared") )
	{
		$r->status_line( "400 Unspecified or unsupported lock scope" );
		return 400;
	}
	my( $type ) = keys %{$xml->{"${prefix}locktype"}};
	$type =~ s/^$prefix// if $type;
	if( !$type or !($type eq "write") )
	{
		$r->status_line( "400 Unspecified or unsupported lock type" );
		return 400;
	}
	my( $owner ) = $xml->{"${prefix}owner"};
	if( !$owner )
	{
		$r->status_line( "400 Unspecified or unsupported owner type" );
		return 400;
	}

	my $uuid = "urn:uuid:" . APR::UUID->new->format;

	$r->headers_out->{'Lock-Token'} = "<$uuid>";

    my $doc = new XML::LibXML::Document('1.0', 'utf-8');
	my $prop = $doc->createElement( "D:prop" );

	$prop->setAttribute( "xmlns:D", "DAV" );
	$doc->setDocumentElement( $prop );

	my $lockdiscovery = $doc->createElement( "D:lockdiscovery" );
	$prop->appendChild( $lockdiscovery );

	my $activelock = $doc->createElement( "D:activelock" );
	$lockdiscovery->appendChild( $activelock );

	$activelock->appendChild( $doc->createElement( "D:locktype" ) )
		->appendChild( $doc->createElement( "D:write" ) );
	$activelock->appendChild( $doc->createElement( "D:lockscope" ) )
		->appendChild( $doc->createElement( "D:exclusive" ) );
	$activelock->appendChild( $doc->createElement( "D:depth" ) )
		->appendChild( $doc->createTextNode( "0" ) );
	$activelock->appendChild( $doc->createElement( "D:owner" ) )
		->appendChild( $doc->createTextNode( $owner ) );
	$activelock->appendChild( $doc->createElement( "D:timeout" ) )
		->appendChild( $doc->createTextNode( "Second-604800" ) );
	$activelock->appendChild( $doc->createElement( "D:locktoken" ) )
		->appendChild( $doc->createElement( "D:href" ) )
		->appendChild( $doc->createTextNode( $uuid ) );
	$activelock->appendChild( $doc->createElement( "D:lockroot" ) )
		->appendChild( $doc->createElement( "D:href" ) )
		->appendChild( $doc->createTextNode( $path ) );

    $r->content_type('text/xml; charset="utf-8"');
    if(!$r->header_only())
    {
		$r->print($doc->toString(1));
print STDERR length($doc->toString(1)). " bytes: ".$doc->toString(1);
	}

	if( $handler->test( "e", $path ) )
	{
		$r->status( 200 );
	}
	else
	{
		$r->status( 201 );
	}

	return OK;
}

#
#
# Helper methods below here.
#
#

#
# This method builds up an xml response to a delete request ONLY IF the delete
# request had errors.  A delete request with no errors sends only a header, not
# an associated XML document.  So again, this method is only used when an error
# occurs.
#
# @arg $r apache object
# @arg $files arrayref of files that had errors
#
# @ret 200 OK
#
sub delete_response
{
    my ($self, $r, $files) = @_;

    # This is a bit screwed up.  WebDrive doesn't properly parse 207 multistatus
    # responses for deletes.  So if it's webdrive, just send a generic error
    # code.  I know this sucks but the majority of our users use webdrive so
    # we have to do it.
    #
    # Here is the response from their tech support:
    # 
    # webdrive is not parsing the 207 multistatus response to look for the
    # error code.  If the DELETE returns an HTTP error like 403 instead of
    # 207 then webdrive would recognize the error.  Webdrive should parse
    # the response but currently it doesn't for the DELETE command.
    # It's nothing you are doing wrong, it's just something that wasn't
    # fully implemented with webdrive and the delete command.
    #
    if($r->headers_in->{'User-Agent'} =~ /WebDrive/)
    {
        $r->status(FORBIDDEN);
#        $r->send_http_header();
        return OK;
    }

    my $doc = new XML::LibXML::Document('1.0', 'utf-8');
    my $multistat = $doc->createElement('D:multistatus');

    $multistat->setAttribute('xmlns:D', 'DAV:');
    $doc->setDocumentElement($multistat);

    foreach my $file (@$files)
    {
        my $response = $doc->createElement('D:response');

        $response->appendTextChild('D:href'   => $file);
        $response->appendTextChild('D:status' => 'HTTP/1.1 403 Forbidden');

        $multistat->addChild($response);
    }

    $r->status(207);
    $r->content_type('text/xml; charset="utf-8"');
#    $r->send_http_header();

    if(!$r->header_only())
    {
        $r->print($doc->toString(1));
    }

    return OK;
}

#
# Build up a WebDAV flavored XML document containing a list of files in a
# directory.  Most of this was copied from Net::DAV::Server, but I took out
# all the stuff specific to HTTP::Daemon, HTTP::Request and HTTP::Response
# (so it would be compatible with apache/mod_perl).
#
# @arg $r apache object
# @arg $files arrayref of files [{path => $path, stat => $info}, {etc...}]
#
# @ret 200 OK
#
sub list_response
{
    my ($self, $r, $files) = @_;

    my $doc = new XML::LibXML::Document('1.0', 'utf-8');
    my $multistat = $doc->createElement('D:multistatus');

    $multistat->setAttribute('xmlns:D', 'DAV:');
    $doc->setDocumentElement($multistat);

    foreach my $file (@$files)
    {
        my $path = $file->{'path'};
        my $stat = $file->{'stat'};
        my $resp = $doc->createElement('D:response');

        $multistat->addChild($resp);

        my $href = $doc->createElement('D:href');

		$href->appendText(
				File::Spec->catdir(
					map { $self->encode_uri($r, $_) } File::Spec->splitdir($path)
				)
			);

        $resp->addChild($href);

        my $okprops = $doc->createElement('D:prop');

        foreach my $wanted_prop (keys %$stat)
        {
            # We set these down there automatically (we are faking quota
            # support to keep webdrive happy).
            next if $wanted_prop eq 'quota';
            next if $wanted_prop eq 'quotaused';
            next if $wanted_prop eq 'quota-available-bytes';
            next if $wanted_prop eq 'quota-used-bytes';
            next if $wanted_prop eq 'quota-assigned-bytes';

            my $prop = $doc->createElement("D:$wanted_prop");

            if($wanted_prop eq 'resourcetype')
            {
                if($stat->{$wanted_prop} eq 'collection')
                {
                    my $collection = $doc->createElement('D:collection');

                    $prop->addChild($collection);
                }
            }
            else
            {
                if(defined($stat->{$wanted_prop}))
                {
                    $prop->appendText($stat->{$wanted_prop});
                }
                else
                {
                    $prop->appendText('');
                }
            }

            $okprops->addChild($prop);
        }

        # Add quota information.  This doesn't appear to be in the WebDAV
        # spec, but if it's not here, WebDrive won't allow any uploads.
        #
        # Update: I found it in a proposal here:
        #
        # http://www.greenbytes.de/tech/webdav/draft-ietf-webdav-quota-07.html
        # 
        # But it doesn't say anything about quota, quotaused, or
        # quota-assigned-bytes - I found out that webdrive was looking for those
        # from its log file.
        my $quota                 = $doc->createElement('D:quota');
        my $quota_used            = $doc->createElement('D:quotaused');
        my $quota_available_bytes = $doc->createElement('D:quota-available-bytes');
        my $quota_used_bytes      = $doc->createElement('D:quota-used-bytes');
        my $quota_assigned_bytes  = $doc->createElement('D:quota-assigned-bytes');

        $quota->appendText('2000000000');
        $quota_used->appendText('0');
        $quota_available_bytes->appendText('2000000000');
        $quota_used_bytes->appendText('0');
        $quota_assigned_bytes->appendText('2000000000');

        $okprops->addChild($quota);
        $okprops->addChild($quota_used);
        $okprops->addChild($quota_available_bytes);
        $okprops->addChild($quota_used_bytes);
        $okprops->addChild($quota_assigned_bytes);

        if($okprops->hasChildNodes())
        {
            my $propstat = $doc->createElement('D:propstat');
            $propstat->addChild($okprops);

            my $stat = $doc->createElement('D:status');
            $stat->appendText('HTTP/1.1 200 OK');

            $propstat->addChild($stat);
            $resp->addChild($propstat);
        }
    }

print STDERR $doc->toString(1);
    $r->print($doc->toString(1));

    return OK;
}

#
# Parse an incoming PROPFIND request to see what information the client wants.
#
sub get_wanted_properties
{
    my ($self, $r) = @_;

    # Grab the content of the request so we can parse it and look for which
    # properties they are requesting.
    my $content = $self->get_request_content($r);

	if( length($content) == 0 &&
		$r->headers_in->{'User-Agent'} =~ /Microsoft Data Access/ )
	{
		return ( allprop => 1 ) unless length($content);
	}

    # NSExpand expands namespaces so, xmlns:D eq '{DAV:}' in front of every
    # element in that namespace.
    my $xml;

    eval
    {
        $xml = XMLin($content, NSExpand => 1, ForceArray => 0, KeyAttr => []);
    };


    # If parsing the XML file failed, override the 207 status with a 400
    # and return undef.
    if(!$xml)
    {
		print STDERR "Error parsing XML: $@\n";
        $r->status(400);
#        $r->send_http_header();
        return;
    }

    my %wanted_properties;

    my $prop_key = '{DAV:}prop';

    foreach my $prop (keys %{$xml->{$prop_key}})
    {
        # Only pay attention if the property is in the DAV namespace.
        if($prop =~ s/^{DAV:}//)
        {
            $wanted_properties{$prop} = 1;
        }
    }

    return %wanted_properties;
}

#
# Note from Apache docs:
#
# The $r->content method will return the entity body read from the client, but
# only if the request content type is application/x-www-form-urlencoded.
#
# Can't use $r->content() because the content type is text/xml, not
# application/x-www-form-urlencoded (I don't know why the Apache module puts
# that restriction on there in the first place).
#
sub get_request_content
{
    my ($self, $r) = @_;

	use bytes;
	use integer;

    my $content = "";
    my $length = $r->headers_in->{'Content-Length'};
	my $connection = $r->headers_in->{'Connection'};
	my $te = $r->headers_in->{'TE'};

	if( defined($length) )
	{
		$r->read($content, $length) if $length > 0;
	}
	elsif( $connection && lc($connection) eq "te" )
	{
		my $ok = 1;
		# Read chunks
		while($ok)
		{
			my $line = _read_line( $r, 4096 );
			$ok = undef, last unless defined $line;
			$ok = undef, last unless $line =~ /^(\d+)$/;
			my $to_read = $1;
			last if $to_read == 0; # end of chunks
			while( $to_read > 0 )
			{
				$to_read -= $r->read( $content, $to_read, length($content) )
					or last;
			}
		}
		my( $key, $value );
		while($ok)
		{
			my $line = _read_line( $r, 4096 );
			$ok = undef, last unless defined $line;
			last if $line eq "";
			if( $line =~ s/^ // )
			{
				$r->headers_in->{$key} .= $line if defined $key;
			}
			else
			{
				( $key, $value ) = split /:/, $line, 2;
				$r->headers_in->{$key} = $value;
			}
		}
		$r->discard_request_body; # discard anything left
	}
	else
	{
		print STDERR "Unsupported/unknown method for posting content\n";
	}

    return $content;
}

sub _read_line
{
	use bytes;
	use integer;

	my $line = "";
	while( $_[0]->read( $line, 1, length($line)) and $line !~ /\r\n$/ )
	{
		return undef if length($line) > $_[1];
	}
	return substr($line,0,-2);
}

#
# Based on the requested path, figure out which module will handle the request.
#
sub get_handler_for_path
{
    my ($self, $uri) = @_;

    # Based on the requested path ($uri), figure out which module will
    # handle the request.  The modules must be subclasses of
    # Filesys::Virtual.
    my $module;
    my $path_handled;
    my %args;

    foreach my $mod (@{$self->{'handlers'}})
    {
        my $path = $mod->{'path'};

        if($uri =~ /^$path/)
        {
            $module       = $mod->{'module'};
            $path_handled = $path;
            %args         = %{$mod->{'args'}} if defined($mod->{'args'});
        }
    }

    my $handler = $module->new({
        root_path => $path_handled,
        cwd       => $uri,
        %args
    });

    return $handler;
}

sub iso_datetime
{
	my( $time ) = @_;

	my @time = gmtime($time);

	return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
		$time[5]+1900,
		$time[4]+1,
		$time[3],
		@time[2,1,0]
		);
}

# encode/decode uris according to each client's perculiarities
sub encode_uri
{
    my ($self, $r, $uri) = @_;

	if( 0 && $r->headers_in->{'User-Agent'} =~ /Microsoft Data Access/ )
	{
		$uri =~ s/([;\/?\:\@&=+\$,%\x80-\xff])/sprintf("%%%02x", ord($1))/eg;
		return $uri;
	}
	if($r->headers_in->{'User-Agent'} =~ /gvfs/)
	{
		return uri_escape(encode_utf8($uri),"^A-Za-z0-9-_.!~*'()=");
	}

	return uri_escape encode_utf8 $uri;
}

sub decode_uri
{
    my ($self, $r, $uri) = @_;

	# Web Folders emits weird URLs which contain chars in the range 0x80-0xff
	# encoded as %XX but leaves higher bit chars as bytes
	if( $r->headers_in->{'User-Agent'} =~ /Microsoft Data Access/ )
	{
		$uri = decode_utf8 $uri;
		$uri =~ s/%([0-9a-fA-F]{2})/
			hex($1) > 0x80 ? chr(hex($1)) : "\%$1"
		/eg;
		$uri = encode_utf8 $uri;
	}

	$uri = URI->new($uri)->path;

	return decode_utf8 uri_unescape $uri;
}

1;
__END__

=head1 NAME

Apache2::WebDAV - Extensible WebDAV server for Apache.

=head1 SYNOPSIS

  use Apache2::WebDAV;

=head1 ABSTRACT

Write perl modules to handle file transfers through WebDAV.

=head1 DESCRIPTION

Apache2::WebDAV is a WebDAV server implementation.  It was originally based on Net::DAV::Server (which isn't compatible with Apache), but has undergone significant architectural changes.  Apache2::WebDAV can be used with a simple mod_perl handler and tied to Filesys::Virtual::Plain to provide a simple, file-system-based WebDAV server.  However, the real power of this module lies in its ability to use any Filesys::Virtual subclass as a storage mechanism.  For example, you can write a subclass of Filesys::Virtual to store and retrieve data directly from a database.

It is also possible to use different Filesys::Virtual subclasses to respond to different paths under your WebDAV root.  This allows you to have some sections interact with the filesystem, others with a database, etc.

=head1 WebDAV Standards Compatibility

The WebDAV protocol is unclear and client behavior differs drastically.  During development of this module, the following clients were identified as targets for support:

 WebDrive  (windows)
 Transmit  (osx)
 Goliath   (osx)
 Cadaver   (linux)
 Konqueror (linux)
 HTTP::DAV (perl)

The MacOSX Finder is also supported, assuming your Filesys::Virtual subclass is fully and correctly implemented.  Specifically, you can't expect the Finder to "PUT" a file in one nice step, rather, it takes multiple requests and it's difficult to programmatically determine when the file is "finished" uploading.

In addition, depending on your Filesys::Virtual subclass, of course, this module passes most of the WebDAV Litmus tests (http://www.webdav.org/neon/litmus/) without errors or warnings.  Specifically:

 OPTIONS for DAV: header 
 PUT, GET with byte comparison 
 MKCOL 
 DELETE (collections, non-collections) 
 COPY, MOVE using combinations of: 
  overwrite t/f 
  destination exists/doesn't exist 
  collection/non-collection

However, there is currently no support for LOCKING or PROPERTY MANIPULATION.

Finally, there are certain pieces of code in this module that purposefully break from the WebdAV protocol in order to support a specific client.  As of this writing, both Goliath and WebDrive require these hacks.  (Both are commented in the code.)

Microsoft Internet Explorer "Web Folders" do not seem to work and no effort has been made to figure out why.

Here is the output of the Litmus Test when running basic, copymove, and http:

    $ echo $TESTS
    basic copymove http
    lozier@ruggles:~$ litmus http://pg.ruggles:8080/ApacheDAV
    -> running `basic':
     0. init.................. pass
     1. begin................. pass
     2. options............... pass
     3. put_get............... pass
     4. put_get_utf8_segment.. pass
     5. mkcol_over_plain...... pass
     6. delete................ pass
     7. delete_null........... pass
     8. delete_fragment....... WARNING: DELETE removed collection resource with Request-URI including fragment; unsafe
        ...................... pass (with 1 warning)
     9. mkcol................. pass
    10. mkcol_again........... pass
    11. delete_coll........... pass
    12. mkcol_no_parent....... pass
    13. mkcol_with_body....... pass
    14. finish................ pass
    <- summary for `basic': of 15 tests run: 15 passed, 0 failed. 100.0%
    -> 1 warning was issued.
    -> running `copymove':
     0. init.................. pass
     1. begin................. pass
     2. copy_init............. pass
     3. copy_simple........... pass
     4. copy_overwrite........ pass
     5. copy_nodestcoll....... pass
     6. copy_cleanup.......... pass
     7. copy_coll............. pass
     8. move.................. pass
     9. move_coll............. pass
    10. move_cleanup.......... pass
    11. finish................ pass
    <- summary for `copymove': of 12 tests run: 12 passed, 0 failed. 100.0%
    -> running `http':
     0. init.................. pass
     1. begin................. pass
     2. expect100............. pass
     3. finish................ pass
    <- summary for `http': of 4 tests run: 4 passed, 0 failed. 100.0%

The props tests mostly fail.

=head1 IMPLEMENTATION

In order to get a working WebDAV server up and running quickly, the following instructions are provided.  It is recommended that you install Filesys::Virtual::Plain and follow the instructions below.  Please be advised that there is no authentication layer built in, so don't just put this out on a public server somewhere and expect it to be secure!  Rather, write your own mod_perl authentication handler.

=head2 mod_perl handler

My theoretical server is "myserver" in all examples.  First you need to write a simple mod_perl handler.  Mine is called DAVHandler.pm.  The code looks like this:

 package DAVHandler;

 use strict;
 use warnings;

 use Apache2::WebDAV;
 use Filesys::Virtual::Plain;

 sub handler
 {
     my $r = shift;

     my $dav = new Apache2::WebDAV();

     my @handlers = (
         {
             path   => '/DAV',
             module => 'Filesys::Virtual::Plain',
             args   => {
                 root_path => '/home/lozier'
             }
         }
     );

     $dav->register_handlers(@handlers);

     return $dav->process($r);
 }

Many Filesys::Virtual subclasses require arguments to their constructors.  Notice the "args" subscript in the @handlers array above.  Use this to pass any required arguments.  If no arguments are present, the root_path will be set to the path that was matched ($handlers[0]->{'path'} in this example), and cwd will be set to the full URI (from $r->uri()).

=head2 Apache Configuration

You will need to tell your apache server to respond to webdav requests on a specific path.  Here is a full example of the required section:

 <Location /DAV>
     SetHandler perl-script
     PerlHandler Finch::Web::Handler::ApacheDAV
 </Location>

Please note, this example doesn't have any authentication requirement.  Please use a mod_perl authentication handler to allow valid users only.

=head1 UNIT TESTS

Since this module requires a running instance of Apache with a properly configured mod_perl handler in order to even run, there are no unit tests provided.  Feedback requested.

=head1 SEE ALSO

Filesys::Virtual
Filesys::Virtual::Plain
Net::DAV::Server
HTTP::DAV

=head1 AUTHOR

Brian Lozier, Geospiza, Inc. L<lozier@geospiza.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 Geospiza, Inc. L<http://www.geospiza.com/>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

