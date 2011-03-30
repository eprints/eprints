package LWP::UserAgent::OAuth;

=head1 NAME

LWP::UserAgent::OAuth - generate signatures for OAuth requests

=head1 SYNOPSIS

	require LWP::UserAgent::OAuth;
	
	# Google uses 'anonymous' for unregistered Web/offline applications or the
	# domain name for registered Web applications
	my $ua = LWP::UserAgent::OAuth->new(
		oauth_consumer_secret => "anonymous",
	);
	
	# request a 'request' token
	my $r = $ua->post( "https://www.google.com/accounts/OAuthGetRequestToken",
		[
			oauth_consumer_key => 'anonymous',
			oauth_callback => 'http://example.net/oauth',
			xoauth_displayname => 'Example Application',
			scope => 'https://docs.google.com/feeds/',
		]
	);
	die $r->as_string if $r->is_error;
	
	# update the token secret from the HTTP response
	$ua->oauth_update_from_response( $r );
	
	# open a browser for the user 
	
	# data are returned as form-encoded
	my $uri = URI->new( 'http:' );
	$uri->query( $r->content );
	my %oauth_data = $uri->query_form;
	
	# Direct the user to here to grant you access:
	# https://www.google.com/accounts/OAuthAuthorizeToken?
	# 	oauth_token=$oauth_data{oauth_token}\n";
	
	# turn the 'request' token into an 'access' token with the verifier
	# returned by google
	$r = $ua->post( "https://www.google.com/accounts/OAuthGetAccessToken", [
		oauth_consumer_key => 'anonymous',
		oauth_token => $oauth_data{oauth_token},
		oauth_verifier => $oauth_verifier,
	]);
	
	# update the token secret from the HTTP response
	$ua->oauth_update_from_response( $r );
	
	# now use the $ua to perform whatever actions you want

=head1 METHODS

=over 4

=item $ua->oauth_token_secret( HTTP::Response OR token string )

Set the token secret, auto-magically from an L<HTTP::Response> if given.

=back

=head1 SEE ALSO

L<LWP::UserAgent>

=cut

use LWP::UserAgent;
use URI::Escape;
use Digest::SHA;
use MIME::Base64;

@ISA = qw( LWP::UserAgent );

use strict;

sub new
{
	my( $class, %self ) = @_;

	my $self = $class->SUPER::new( %self );

	for(qw( oauth_consumer_key oauth_consumer_secret oauth_token oauth_token_secret ))
	{
		$self->{$_} = $self{$_};
	}

	return $self;
}

sub request
{
	my( $self, $request, @args ) = @_;

	$self->sign_hmac_sha1( $request );

	return $self->SUPER::request( $request, @args );
}

sub oauth_encode_parameter
{
	my( $str ) = @_;
	return URI::Escape::uri_escape_utf8( $str, '^\w.~-' ); # 5.1
}

sub oauth_nonce
{
	my $nonce = '';
	$nonce .= sprintf("%02x", int(rand(255))) for 1..16;
	return $nonce;
}

sub oauth_authorization_param
{
	my( $request, @args ) = @_;

	if( @args )
	{
		my @parts;
		for(my $i = 0; $i < @args; $i+=2)
		{
			# header values are in quotes
			push @parts, sprintf('%s="%s"',
				map { oauth_encode_parameter( $_ ) }
				@args[$i,$i+1]
			);
		}
		$request->header( 'Authorization', sprintf('OAuth %s',
			join ',', @parts ) );
	}

	my $authorization = $request->header( 'Authorization' );
	return if !$authorization;
	return if $authorization !~ s/^\s*OAuth\s+//i;

	return
		map { URI::Escape::uri_unescape( $_ ) }
		map { $_ =~ /([^=]+)="(.*)"/; ($1, $2) }
		split /\s*,\s*/,
		$authorization;
}

sub sign_hmac_sha1
{
	my( $self, $request ) = @_;

	my $method = $request->method;
	my $uri = URI->new( $request->uri )->canonical;
	my $content_type = $request->header( 'Content-Type' );
	$content_type = '' if !defined $content_type;
	my $oauth_header = $request->header( "Authorization" );

	# build the parts of the string to sign
	my @parts;

	push @parts, $method;

	my $request_uri = $uri->clone;
	$request_uri->query( undef );
	push @parts, "$request_uri";

	# build up a list of parameters
	my @params;

	# CGI parameters (OAuth only supports urlencoded)
	if(
		$method eq "POST" &&
		$content_type eq 'application/x-www-form-urlencoded'
	)
	{
		$uri->query( $request->content );
	}
	
	push @params, $uri->query_form;

	# HTTP OAuth Authorization parameters
	my @auth_params = oauth_authorization_param( $request );
	my %auth_params = @auth_params;
	if( !exists($auth_params{oauth_nonce}) )
	{
		push @auth_params, oauth_nonce => oauth_nonce();
	}
	if( !exists($auth_params{oauth_timestamp}) )
	{
		push @auth_params, oauth_timestamp => time();
	}
	if( !exists($auth_params{oauth_version}) )
	{
		push @auth_params, oauth_version => '1.0';
	}
	for(qw( oauth_consumer_key oauth_token ))
	{
		if( !exists($auth_params{$_}) && defined($self->{$_}) )
		{
			push @auth_params, $_ => $self->{$_};
		}
	}
	push @auth_params, oauth_signature_method => "HMAC-SHA1";

	push @params, @auth_params;

	# lexically order the parameters as bytes (sorry for obscure code)
	{
		use bytes;
		my @pairs;
		push @pairs, [splice(@params,0,2)] while @params;
		# order by key name then value
		@pairs = sort {
			$a->[0] cmp $b->[0] || $a->[1] cmp $b->[0]
		} @pairs;
		@params = map { @$_ } @pairs;
	}

	# re-encode the parameters according to OAuth spec.
	my @query;
	for(my $i = 0; $i < @params; $i+=2)
	{
		next if $params[$i] eq "oauth_signature"; # 9.1.1
		push @query, sprintf('%s=%s',
			map { oauth_encode_parameter( $_ ) }
			@params[$i,$i+1]
		);
	}
	push @parts, join '&', @query;

	# calculate the data to sign and the secret to use (encoded again)
	my $data = join '&',
		map { oauth_encode_parameter( $_ ) }
		@parts;
	my $secret = join '&',
		map { defined($_) ? oauth_encode_parameter( $_ ) : '' }
		$self->{oauth_consumer_secret},
		$self->{oauth_token_secret};

	# 9.2
	my $digest = Digest::SHA::hmac_sha1( $data, $secret );

	push @auth_params,
		oauth_signature => MIME::Base64::encode_base64( $digest, '' );

	oauth_authorization_param( $request, @auth_params );
}

sub oauth_update_from_response
{
	my( $self, $r ) = @_;

	my $uri = URI->new( 'http:' );
	$uri->query( $r->content );
	my %oauth_data = $uri->query_form;

	for(qw( oauth_token oauth_token_secret ))
	{
		$self->{$_} = $oauth_data{$_};
	}
}

sub oauth_consumer_key
{
	my $self = shift;
	if( @_ )
	{
		$self->{oauth_consumer_key} = shift;
	}
	return $self->{oauth_consumer_key};
}

sub oauth_consumer_secret
{
	my $self = shift;
	if( @_ )
	{
		$self->{oauth_consumer_secret} = shift;
	}
	return $self->{oauth_consumer_secret};
}

sub oauth_token
{
	my $self = shift;
	if( @_ )
	{
		$self->{oauth_token} = shift;
	}
	return $self->{oauth_token};
}

sub oauth_token_secret
{
	my $self = shift;
	if( @_ )
	{
		$self->{oauth_token_secret} = shift;
	}
	return $self->{oauth_token_secret};
}

1;
