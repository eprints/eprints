=head1 NAME

EPrints::Plugin::Storage::AmazonS3 - storage in Amazon S3

=head1 DESCRIPTION

See L<EPrints::Plugin::Storage> for available methods.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Storage::AmazonS3;

use URI;
use URI::Escape;
use File::Basename;

use EPrints::Plugin::Storage;

@ISA = ( "EPrints::Plugin::Storage" );

use HTTP::Request;
eval "use LWP::UserAgent::S3";

our $DISABLE = $@ ? 1 : 0;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Amazon S3 storage";
	if( $self->{session} )
	{
		my $aws_access_key_id = $self->param( "aws_access_key_id" );
		my $aws_secret_access_key = $self->param( "aws_secret_access_key" );
		my $aws_bucket = $self->param( "aws_bucket" );
		if( $aws_secret_access_key && $aws_access_key_id && $aws_bucket )
		{
			$self->{ua} = LWP::UserAgent::S3->new(
				aws_access_key_id => $aws_access_key_id,
				aws_secret_access_key => $aws_secret_access_key,
				);
			$self->{bucket} = $aws_bucket;
		}
		else
		{
			$self->{visible} = "";
			$self->{error} = "Requires aws_secret_access_key, aws_access_key_id and aws_bucket";
		}
	}

	return $self;
}

sub request { shift->{ua}->request( @_ ); }

sub uri
{
	my( $self, $fileobj ) = @_;

	my $uri = URI->new( $self->{ua}->_proto . "://" . $self->{bucket} . "." . $self->{ua}->_host );

	my $path = "/";

	if( $fileobj )
	{
		$path .= $fileobj->get_id;
		$path .= "/" . URI::Escape::uri_escape( $fileobj->get_value( "filename" ) );
	}

	$uri->path( $path );

	return $uri;
}

sub create_bucket
{
	my( $self ) = @_;

	my $uri = $self->uri;

	my $req = HTTP::Request->new( HEAD => $uri );

	my $r = $self->request( $req );

	return $r if $r->is_success;

	$req = HTTP::Request->new( PUT => $uri );

	$r = $self->request( $req );

	return $r;
}

sub store
{
	my( $self, $fileobj, $fh ) = @_;

	use bytes;
	use integer;

	my $length = 0;

	$self->create_bucket();

	my $uri = $self->uri( $fileobj );

	my $req = HTTP::Request->new( "PUT" => $uri );
	$req->header( "Content-Length" => $fileobj->get_value( "filesize" ) );
	my $buffer;
	$req->content( sub {
		return "" unless sysread($fh,$buffer,4096);
		$length += length($buffer);
		return $buffer;
	} );

# FIXME: make everything public
	$req->header( "x-amz-acl" => "public-read" );

	my $r = $self->request( $req );

	unless( $r->is_success )
	{
		$self->{session}->log( $r->as_string );
	}

	return undef unless $r->is_success;

	$fileobj->add_plugin_copy( $self, $uri );

	return $length;
}

sub retrieve
{
	my( $self, $fileobj ) = @_;

	my $uri = $self->uri( $fileobj );

	my $req = HTTP::Request->new( GET => $uri );

	my $tmpfile = File::Temp->new();

	binmode($tmpfile);
	my $r = $self->request( $req, "$tmpfile" );
	seek($tmpfile,0,0);

	return $r->is_success ? $tmpfile : undef;
}

sub delete
{
	my( $self, $fileobj ) = @_;

	my $req = HTTP::Request->new( DELETE => $self->uri( $fileobj ) );

	return $self->request( $req )->is_success;
}

=back

=cut

1;
