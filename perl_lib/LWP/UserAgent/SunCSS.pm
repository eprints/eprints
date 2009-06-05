package LWP::UserAgent::SunCSS;

use strict;
use warnings;

require LWP::UserAgent;
require LWP::UserAgent::AmazonS3;
use HTTP::Date;
use Digest::HMAC_SHA1;
use MIME::Base64;
use URI;
use Carp;

our @ISA = qw(LWP::UserAgent::AmazonS3);

our $VERSION = '1.00';

# Preloaded methods go here.

sub new
{
	my( $class, %self ) = @_;

	$self{aws_access_key_id} = delete $self{suncss_access_key_id}
		or Carp::croak( "Requires suncss_access_key_id" );
	$self{aws_secret_access_key} = delete $self{suncss_secret_access_key}
		or Carp::croak( "Requires suncss_secret_access_key" );

	return $class->SUPER::new( %self );
}

sub _proto { 'http' }
sub _host { 'object.storage.network.com' }

sub prepare_request
{
	my( $self, $req ) = @_;

	$req->protocol( "HTTP/1.1" );

	# Expand PUT => /golf_clubs to http://s3.amazonaws.com/golf_clubs
	my $uri = URI->new_abs( $req->uri, $self->_proto . "://" . $self->_host );
	# Sun requires buckets have a trailing slash
	if( !length($uri->path) or
		($uri->host eq $self->_host and $uri->path =~ m# ^/[^/]+$ #x) )
	{
		$uri->path( $uri->path . "/" );
	}
	$req->uri( $uri );

	$req = $self->SUPER::prepare_request( $req );

	# Add expires and authorization parameter
	my $expires = time+3600;
	my @params = $uri->query_form();
	push @params,
		AWSAccessKeyId => $self->aws_access_key_id,
		Expires => $expires,
		Signature => $self->gen_signature( $req, $expires );
	$uri->query_form( @params );
	$req->uri( $uri );

	return $req;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

LWP::UserAgent::SunCSS - utility for REST access to Sun Cloud Storage Service

=head1 SYNOPSIS

  use LWP::UserAgent::SunCSS;

  my $css = LWP::UserAgent::SunCSS->new(
  	suncss_access_key_id => $suncss_access_key_id,
	suncss_secret_access_key => $suncss_secret_access_key,
	);

  my $req = HTTP::Request->new( PUT => "/my_bucket/" );
  # CSS requires content-length be set for PUT requests
  $req->header( "Content-Length" => 0 );
  my $r = $css->request( $req );

  my $req = HTTP::Request->new( DELETE => "/my_bucket/" );
  my $r = $css->request( $req );

=head1 DESCRIPTION

This module subclasses L<LWP::UserAgent::AmazonS3> to provide the necessary additional HTTP headers required to access Sun CSS.

It adds two required keys to the LWP::UserAgent new() method - suncss_access_key_id and suncss_secret_access_key.

=back

=head2 EXPORT

None by default.

=head1 SEE ALSO

Sun Cloud Storage Service - http://storage.network.com/

Amazon S3 - http://aws.amazon.com/s3/

L<LWP::UserAgent>

=head1 AUTHOR

Tim D Brody, E<lt>tdb01r@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Tim D Brody

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
