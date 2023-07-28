# These configuration variables are mostly unused and should be deprecated.

{
	my $uri = URI->new( "http://" );
	if( EPrints::Utils::is_set( $c->{host} ) )
	{
		$uri->scheme( "http" );
		$uri->host( $c->{host} );
		$uri->port( $c->{port} );
		$uri = $uri->canonical;
		$uri->path( $c->{http_root} );
	}
	else
	{
		$uri->scheme( "https" );
		$uri->host( $c->{securehost} );
		$uri->port( $c->{secureport} );
		$uri = $uri->canonical;
		$uri->path( $c->{https_root} );
	}

# EPrints base URL without trailing slash
	$c->{base_url} = "$uri";
# CGI base URL without trailing slash
	$c->{perl_url} = "$uri/cgi";
}

# If you don't want EPrints to respond to a specific URL add it to the
# exceptions here. Each exception is matched against the uri using regexp:
#  e.g. /myspecial/cgi
# Will match http://yourrepo/myspecial/cgi
#$c->{rewrite_exceptions} = [];
#

#if turned on, the abstract page url will be: http://domain.com/id/eprint/43/. This format helps google scholar to index eprints repository.
#if turned off: http://domain.com/43/
$c->{use_long_url_format} = 0;
