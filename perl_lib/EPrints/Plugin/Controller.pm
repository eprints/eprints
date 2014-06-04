package EPrints::Plugin::Controller;

use strict;
use EPrints;
use EPrints::Const qw( :http );

our @ISA = qw/ EPrints::Plugin /;

my %ALLOWED_METHODS = map { $_ => undef } qw/ GET POST PUT DELETE HEAD OPTIONS PATCH /;

sub new
{
	my( $class, %params ) = @_;
	
# lower priorities get executed first
	$params{priority} ||= 10_000 if !exists $params{priority};

	$params{endpoints} = [];

	return $class->SUPER::new(%params);
}

# check if this Controller can process the current URL
# if the regex has capture brackets, the captured strings will be bound to the Controller via $self->{arg_name}
sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "can_process" )
	{
		foreach my $endpoint ( @{ $self->endpoints() || [] } )
		{
			my $re = $endpoint->{re} or next;

			if( ( my @matches = ( $param =~ $re ) ) )
			{
				my $params = $endpoint->{params} || [];

				foreach( @$params )
				{
					$self->{$_} = shift @matches;
				}
				return 1;
			}
		}
	}

	# didn't understand this test
	return $self->SUPER::matches( $test, $param );
}

=item undef = $self->register_endpoint( $endpoint, param1, param2, ..)

Register a new $endpoint to be processed by the Controller

An $endpoint is a regex which is matches against the current URL. It is possible to capture strings in the 
regex - in which case a param name must be passed for each captured strings. 

$self->matches will pass each captured elements ($1, $2...) to the Controller so they can accessed via $self->{param1}, $self->{param2}, etc.

=cut
sub register_endpoint
{
	my( $self, $endpoint, @params ) = @_;

	push @{$self->{endpoints}}, {
		re => $endpoint,
		params => \@params,
	};
}

sub endpoints
{
	my( $self, @endpoints ) = @_;

	return $self->{endpoints};
}


# Helper methods, available to each Controller

=item $method = $self->method()

Returns the HTTP method. Always uppercase.

=cut

sub method { $_[0]->{method} }


=item $r = $self->request()

Returns the current L<Apache2::RequestUtil>.

=cut

sub request { $_[0]->{request} }

=item value = $self->header( $header );

Returns the HTTP Header $header. If it has been processed by EPrints, return that one. Otherwise
returns the raw HTTP Header from modperl.

=cut
sub header 
{
	my( $self, $header ) = @_;

	if( exists $self->{headers}->{$header} )
	{
		return $self->{headers}->{$header};
	}

	return $self->request->headers_in->{$header};
}

sub filename
{
	my( $self ) = @_;
	
	return $self->{filename} if exists $self->{filename};

	my $filename;

	my @values = @{(HTTP::Headers::Util::split_header_words( $self->header( 'Content-Disposition' ) || '' ))[0] || []};
	for(my $i = 0; $i < @values; $i += 2)
	{
		if( $values[$i] eq "filename" )
		{
			$filename = $values[$i+1];
		}
	}
		
	if( !EPrints::Utils::is_set( $filename ) )
	{
		$filename = $self->repository->param( 'file' ) || 'main.bin';
	}

	$self->{filename} = $filename;

	return $self->{filename};
}

=item $bool = $self->is_write()

Returns true if the request is not a read-only method.

=cut

sub is_write { $_[0]->method !~ /^GET|HEAD|OPTIONS$/ }


sub send_response
{
	my( $self, $status, $content, $content_type ) = @_;

	$status ||= OK;	
	$content_type ||= "text/html; charset=UTF8";

	$self->request->content_type( $content_type );

	use bytes;

	if( defined $content )
	{
		binmode(STDOUT, ":encoding(UTF-8)");
		print STDOUT $content;
	}

	return $status;
}

# TODO normalise constants
sub init
{
        my( $self ) = @_;

        return HTTP_OK;
}

# MapToStorage
sub storage
{
	return EPrints::Apache::OK;
}

# HeaderParser
sub header_parser
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;

	my %headers;
	$self->{headers} = \%headers;
		
	my %q = URI::http->new( $r->unparsed_uri )->query_form;

	# X-Method (pseudo-PUTs etc. from POST)
	$self->{method} = uc($r->method);
	if( $self->method eq "POST" )
	{
		if( $r->headers_in->{'X-Method'} )
		{
			$self->{method} = uc($r->headers_in->{'X-Method'});
		}
		# or via Ruby-on-Rails "_method" query parameter
		if( $q{_method} )
		{
			$self->{method} = uc($q{_method});
		}
	}

	# Content-Type	
	$headers{'Content-Type'} = $r->headers_in->{'Content-Type'} || 'application/octet-stream';

	# Content-Length
	$headers{'Content-Length'} = $r->headers_in->{'Content-Length'};

	# Content-Range
	my $range = $r->headers_in->{'Content-Range'};
	if( defined $range )
	{
		if( $range =~ m{^(\d+)-(\d+)/(\d+|\*)$} && $1 <= $2 )
		{
			$headers{'Content-Range'} = $range;
			$headers{content_range_offset} = $1;
			$headers{content_range_total} = $3;
			if( !defined $headers{'Content-Length'} )
			{
				$headers{'Content-Length'} = $2 - $1;
			}
		}
		else
		{
			return HTTP_RANGE_NOT_SATISFIABLE;
		}
	}

	# Accept
	$headers{'Accept'} = $r->headers_in->{Accept} || '*/*';

	# Adjust 'Accept' header by looking at EPrints' "format" parameter
	if( $q{format} )
	{
		$headers{'Accept'} = lc( $q{format} );
	}

	return OK;
}

# Access
sub auth
{
	return EPrints::Apache::OK;
}

# Access
sub authz
{
	return EPrints::Apache::OK;
}

# Response
sub response
{
	my( $self ) = @_;
	
	my $method = $self->method;

	if( !exists $ALLOWED_METHODS{$method} )
	{
		return HTTP_METHOD_NOT_ALLOWED;
	}

	# may be undef - note it's "$method()" not "method()"
	return $self->$method();
}

sub GET { return HTTP_METHOD_NOT_ALLOWED; }

# HEAD must return the same content as GET - the content will however be discarded by Apache. This is required by current standards.
sub HEAD { &GET }

sub POST { return HTTP_METHOD_NOT_ALLOWED; }
sub PUT { return HTTP_METHOD_NOT_ALLOWED; }
sub DELETE { return HTTP_METHOD_NOT_ALLOWED; }
sub PATCH { return HTTP_METHOD_NOT_ALLOWED; }
sub OPTIONS { return HTTP_METHOD_NOT_ALLOWED; }

1;
