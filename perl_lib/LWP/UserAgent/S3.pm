package LWP::UserAgent::S3;

use strict;
use warnings;

require LWP::UserAgent;
use HTTP::Date;
use Digest::HMAC_SHA1;
use MIME::Base64;
use URI;
use Carp;

our @ISA = qw(LWP::UserAgent);

our $VERSION = '1.00';


# Preloaded methods go here.

sub new
{
	my( $class, %self ) = @_;

	my $aws_access_key_id = delete $self{aws_access_key_id}
		or Carp::croak( "Requires aws_access_key_id" );
	my $aws_secret_access_key = delete $self{aws_secret_access_key}
		or Carp::croak( "Requires aws_secret_access_key" );

	$self{agent} ||= "$class/$VERSION";
	$self{requests_redirectable} = [qw( GET HEAD DELETE PUT )];
	$self{keep_alive} = 10;

	my $self = $class->SUPER::new( %self );

	$self->aws_access_key_id($aws_access_key_id);
	$self->aws_secret_access_key($aws_secret_access_key);

	return $self;
}

sub _proto { 'http' }
sub _host { 's3.amazonaws.com' }

sub aws_access_key_id     { shift->_elem('aws_access_key_id',          @_); }
sub aws_secret_access_key { shift->_elem('aws_secret_access_key',      @_); }

sub gen_stringtosign
{
	my( $self, $req ) = @_;

	my $stringtosign = "";

	$stringtosign .= $req->method . "\n";
	$stringtosign .= ($req->header( "Content-MD5" ) || "") . "\n";
	$stringtosign .= ($req->header( "Content-Type" ) || "") . "\n";
	$stringtosign .= ($req->header( "Date" ) || "") . "\n";

	my %amz_headers;
	$req->headers->scan( sub {
		my( $h, $v ) = @_;
		$h = lc($h);
		push @{$amz_headers{$h}}, $v if $h =~ /^x-amz-/;
	} );
	foreach my $h (sort keys %amz_headers)
	{
		$stringtosign .= $h . ":" . join(',', @{$amz_headers{$h}}) . "\n";
	}

	my $uri = URI->new( $req->uri );
	my $host = $uri->host;
	my $bucket = substr($host,0,length($host) - length($self->_host));
	if( $bucket )
	{
		chop($bucket); # chop the dot
		my $path = $uri->path;
		$path =~ s!^/$bucket!!;
		$stringtosign .= "/$bucket$path";
	}
	else
	{
		$stringtosign .= $uri->path;
	}
	if( defined($uri->query) and $uri->query =~ /^\w+$/ )
	{
		$stringtosign .= '?' . $uri->query;
	}

	return $stringtosign;
}

sub hash_stringtosign
{
	my( $self, $stringtosign ) = @_;

	my $hmac = Digest::HMAC_SHA1->new( $self->aws_secret_access_key );
	$hmac->add( $stringtosign );
	my $b64 = MIME::Base64::encode_base64( $hmac->digest );

	return $b64;
}

sub gen_signature
{
	my( $self, $req ) = @_;

	my $stringtosign = $self->gen_stringtosign( $req );
	my $b64 = $self->hash_stringtosign( $stringtosign );

	return $b64;
}

sub prepare_request
{
	my( $self, $req ) = @_;

	$req->protocol( "HTTP/1.1" );

	# Expand PUT => /golf_clubs to http://s3.amazonaws.com/golf_clubs
	my $uri = URI->new_abs( $req->uri, $self->_proto . "://" . $self->_host );
	$req->uri( $uri );

	$req->header( Date => HTTP::Date::time2str() );
	$req->header( Authorization => sprintf("AWS %s:%s",
		$self->aws_access_key_id,
		$self->gen_signature( $req ),
		) );

	if( defined($req->content) and
		($req->method eq "PUT" or $req->method eq "POST") )
	{
		$req->header( "Expect" => "100-continue" );
	}

	return $self->SUPER::prepare_request( $req );
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

LWP::UserAgent::S3 - utility for REST access to Amazon S3

=head1 SYNOPSIS

  use LWP::UserAgent::S3;

  my $s3 = LWP::UserAgent::S3->new(
  	aws_access_key_id => $aws_access_key_id,
	aws_secret_access_key => $aws_secret_access_key,
	);

  my $req = HTTP::Request->new( PUT => "/my_bucket" );
  my $r = $s3->request( $req );

  my $req = HTTP::Request->new( DELETE => "/my_bucket" );
  my $r = $s3->request( $req );

=head1 DESCRIPTION

This module subclasses L<LWP::UserAgent> to provide the necessary additional HTTP headers required to access Amazon S3.

It adds two required keys to the LWP::UserAgent new() method - aws_access_key_id and aws_secret_access_key.

=head2 Why yet another Amazon S3 module?

I need to be able to read/write to S3 using file handles/sockets. All the existing S3 modules seem to only support reading from local disk or memory.

=over 4

=item Amazon::S3

Non-core dependencies: XML::Simple, Class::Accessor::Fast, HTTP::Date, Digest::HMAC_SHA1, Digest::MD5::File, LWP::UserAgent::Determined

L<Amazon::S3>

=item Net::Amazon::S3

Non-core dependencies: Class::Accessor::Fast, XML::LibXML, XML::LibXML::XPathContext, Regexp::Common, Moose, Digest::MD5::File, Data::Stream::Bulk::Callback, LWP::UserAgent::Determined, Digest::HMAC_SHA1

L<Net::Amazon::S3>

=item SOAP::Amazon::S3

Non-core dependencies: XML::MyXML, Digest::HMAC_SHA1, SOAP::MySOAP

L<SOAP::Amazon::S3>

=back

=head2 EXPORT

None by default.



=head1 SEE ALSO

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
