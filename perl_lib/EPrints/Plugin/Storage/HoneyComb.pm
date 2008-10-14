=head1 NAME

EPrints::Plugin::Storage::HoneyComb - storage in a Sun StorageTek 5800

=head1 DESCRIPTION

See L<EPrints::Plugin::Storage> for available methods.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Storage::HoneyComb;

use URI;
use URI::Escape;

use EPrints::Plugin::Storage;

@ISA = ( "EPrints::Plugin::Storage" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "HoneyComb storage";

	my $rc = EPrints::Utils::require_if_exists("Net::Sun::HoneyComb");
	unless( $rc ) 
	{
		$self->{visible} = "";
		$self->{error} = "Failed to load required module Net::Sun::HoneyComb";
		return $self;
	}

	if( $params{session} )
	{
		eval { $self->{honey} = Net::Sun::HoneyComb->new(
			"hc-data",
			8080
		) };
	}

	return $self;
}

sub store
{
	my( $self, $fileobj, $fh ) = @_;

	my $length = 0;

	use bytes;
	use integer;

	my $parent = $fileobj->get_parent();

	my $metadata = {
		'dc.isPartOf' => $self->{session}->get_repository->get_conf( 'base_url' ),
		'dc.format' => $fileobj->get_value( "mime_type" ),
	};

	if( $parent->isa( "EPrints::DataObj::History" ) )
	{
		$metadata->{'dc.identifier'} = $parent->get_parent->uri;
		$metadata->{'eprints.revision'} = $parent->get_parent->get_value( "rev_number" );
		$metadata->{'dc.conformsTo'} = 'http://eprints.org/ep2/data/2.0';
	}
	elsif( $parent->isa( "EPrints::DataObj::Document" ) )
	{
		$metadata->{'dc.identifier'} = $fileobj->uri;
	}
	else
	{
		$metadata->{'dc.identifier'} = $fileobj->uri;
	}

	my $oid = $self->{honey}->store_both( sub {
			my( $ctx, $n ) = @_;
			sysread($ctx, my $buffer, $n);
			$length += length($buffer);
			return $buffer;
		},
		$fh,
		$metadata
	);

	$fileobj->add_plugin_copy( $self, $oid );

	return $length;
}

sub retrieve
{
	my( $self, $fileobj, $revision ) = @_;

	my $oid = $fileobj->get_plugin_copy( $self );

	my $fh = File::Temp->new();

	binmode($fh);
	$self->{honey}->retrieve_fh( $fh, $oid );

	seek($fh, 0, 0);

# This clobbers temp files/directories due to fork()/exit()
#	my $fh = $self->{honey}->get_fh( $oid );

	return $fh;
}

sub delete
{
	my( $self, $fileobj, $revision ) = @_;

	my $oid = $fileobj->get_plugin_copy( $self );

	my $ok = $self->{honey}->delete( $oid );

	return $ok;
}

=back

=cut

1;
