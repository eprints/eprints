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

#our $DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "HoneyComb storage";
	$self->{storage_class} = "m_local_archival_storage";
	
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
	my( $self, $fileobj, $f ) = @_;

	use bytes;
	use integer;

	my $parent = $fileobj->get_parent();

	my $metadata = {
		'dc.isPartOf' => $self->{session}->get_repository->get_conf( 'base_url' ),
	};

	if( $fileobj->is_set( "mime_type" ) )
	{
		$metadata->{'dc.format'} = $fileobj->get_value( "mime_type" );
	}

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

	my $oid = $self->{honey}->store_both(
		$f,
		undef,
		$metadata
	);

	# error handling?

	return $oid;
}

sub retrieve
{
	my( $self, $fileobj, $oid, $f ) = @_;

	my $fh = File::Temp->new();

	binmode($fh);
	$self->{honey}->retrieve_fh( $fh, $oid );

	seek($fh, 0, 0);

	my $rc = 1;

	my $buffer;
	while(sysread($fh,$buffer,4096))
	{
		$rc &&= &$f($buffer);
		last unless $rc;
	}

# This clobbers temp files/directories due to fork()/exit()
#	my $fh = $self->{honey}->get_fh( $oid );

	return $rc;
}

sub delete
{
	my( $self, $fileobj, $oid ) = @_;

	my $ok = $self->{honey}->delete( $oid );

	return $ok;
}

=back

=cut

1;
