=head1 NAME

EPrints::Plugin::Storage::SunCSS - storage in Sun CSS

=head1 SYNOPSIS

	# cfg.d/plugins.pl
	$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_bucket} = "...";
	$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_access_key_id} = "...";
	$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_secret_access_key} = "...";

	# lib/storage/default.xml
	<plugin name="AmazonS3"/>

=head1 DESCRIPTION

See L<EPrints::Plugin::Storage> for available methods.

To enable this module you must configure the bucket name, access key id and secret access key in your configuration.

If the bucket does not already exist the plugin will attempt to create it before any writes occur.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Storage::SunCSS;

use URI;
use URI::Escape;

use EPrints::Plugin::Storage::AmazonS3;

@ISA = ( "EPrints::Plugin::Storage::AmazonS3" );

use HTTP::Request;
eval "use LWP::UserAgent::SunCSS";

our $DISABLE = $@ ? 1 : 0;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Sun Cloud Simple Storage";
	$self->{storage_class} = "z_cloud_storage";
	
	if( $self->{session} )
	{
		my $suncss_access_key_id = $self->param( "suncss_access_key_id" );
		my $suncss_secret_access_key = $self->param( "suncss_secret_access_key" );
		my $suncss_bucket = $self->param( "suncss_bucket" );
		if( $suncss_secret_access_key && $suncss_access_key_id && $suncss_bucket )
		{
			$self->{ua} = LWP::UserAgent::SunCSS->new(
				suncss_access_key_id => $suncss_access_key_id,
				suncss_secret_access_key => $suncss_secret_access_key,
				);
			$self->{suncss_bucket} = $suncss_bucket;
		}
		else
		{
			$self->{visible} = "";
			$self->{error} = "Requires suncss_secret_access_key and suncss_access_key_id and suncss_bucket";
		}
	}

	return $self;
}

# Sun doesn't support slashes in object names
sub uri
{
	my( $self, $fileobj ) = @_;

	my $uri = URI->new( $self->{ua}->_proto . "://" . $self->{suncss_bucket} . "." . $self->{ua}->_host );

	if( defined $fileobj )
	{
		$uri->path( URI::Escape::uri_escape( $fileobj->get_id . "_" . $fileobj->get_value( "filename" ) ) );
	}

	return $uri;
}

sub get_remote_copy
{
	return undef;
}

=back

=cut

1;
