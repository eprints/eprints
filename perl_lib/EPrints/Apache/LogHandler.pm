######################################################################
#
# EPrints::Apache::LogHandler
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

EPrints::Apache::LogHandler - Main handler for Apache log events

=head1 CONFIGURATION

To enable the Apache::LogHandler add to your ArchiveConfig:

   $c->{loghandler}->{enable} = 1;

You also need to specify the C<geoip> configuration option in SystemSettings:

	geoip => {
		class => "Geo::IP",
		country => "/usr/local/share/GeoIP/GeoIP.dat",
		organisation => "/usr/local/share/GeoIP/GeoIPOrg.dat",
	},

=head1 DATA FORMAT

=over 4

=item requester

The requester is stored using their IP in URN format: C<urn:ip:x.x.x.x>.

=item serviceType

ServiceType is in format L<info:ofi/fmt:kev:mtx:sch_svc|http://alcme.oclc.org/openurl/servlet/OAIHandler?verb=GetRecord&metadataPrefix=oai_dc&identifier=info:ofi/fmt:kev:mtx:sch_svc>.

The value is encoded as C<?name=yes> (where C<name> is one of the services defined).

=item referent, referringEntity

These are stored in URN format: C<info:oai:repositoryid:eprintid>.

=item referent_docid

The document id as a fragment of the referent: C<#docid>.

=back

=head1 METHODS

=over 4

=cut

package EPrints::Apache::LogHandler;

use strict;
use warnings;

use vars qw( $GEOIP $GEOIP_DB $GEOORG_DB );

$GEOIP = 0;

use URI;

use EPrints;
use EPrints::Apache::AnApache;

use constant NOT_MODIFIED => 304;

sub handler
{
	my( $r ) = @_;

	# If you're confused its probably because your browser is issuing NOT
	# MODIFIED SINCE (304 NOT MODIFIED)
	unless( $r->status == 200 ) 
	{
		return DECLINED;
	}

	my $session = new EPrints::Session or return DECLINED;
	my $repository = $session->get_repository;

	# Open the GeoIP databases once on the first request
#	unless( $GEOIP )
#	{
#		my $conf = $repository->get_conf( "geoip" );
#
#		unless( defined $conf )
#		{
#			EPrints::abort( "geoip not configured in SystemSettings" );
#		}
#
#		geoip_open( $conf );
#		$GEOIP = 1;
#	}

	my $c = $r->connection;
	my $ip = $c->remote_ip;
	my $uri = URI->new($r->uri);

	my $access = {};
	$access->{datestamp} = EPrints::Utils::get_iso_timestamp( $r->request_time );
	$access->{requester_id} = 'urn:ip:' . $ip;
	$access->{referent_id} = $r->uri;
	$access->{referent_docid} = undef;
	$access->{referring_entity_id} = $r->headers_in->{ "Referer" };
	$access->{service_type_id} = '';
	$access->{requester_user_agent} = $r->headers_in->{ "User-Agent" };
	if( $GEOIP_DB )
	{
		$access->{country} = $GEOIP_DB->country_code_by_addr( $ip );
	}
	if( $GEOORG_DB )
	{
		$access->{institution} = $GEOORG_DB->org_by_name( $ip );
	}

	# External full-text request
	if( $r->filename and $r->filename =~ /redirect$/ )
	{
	}
	else
	{
		my $eprintid = uri_to_eprintid( $session, $uri );
		unless( defined $eprintid )
		{
			# Not interested in this URL.
			return DECLINED;
		}

		# Request for an abstract page or full-text
		$access->{referent_id} = $eprintid;

		my $docid = uri_to_docid( $session, $eprintid, $uri );

		if( defined $docid )
		{
			$access->{referent_docid} = $docid;
			$access->{service_type_id} = "?fulltext=yes";
		}
		else
		{
			$access->{service_type_id} = "?abstract=yes";
		}
	}

	if( !$access->{referring_entity_id} or $access->{referring_entity_id} !~ /^https?:/ )
	{
		$access->{referring_entity_id} = '';
	}


	# Check for an internal referrer
	my $eprintid = uri_to_eprintid( 
				$session, 
				URI->new($access->{referring_entity_id}) );

	if( defined $eprintid ) 
	{
		$access->{referring_entity_id} = $eprintid;
	}

	$session->get_repository->get_dataset( "access" )->create_object( $session, $access );
	
	return OK;
}

=item $id = EPrints::Apache::LogHandler::uri_to_eprintid( $session, $uri )

Returns the eprint id that $uri corresponds to, or undef.

=cut

sub uri_to_eprintid
{
	my( $session, $uri ) = @_;

	# uri is something like /xxxxxx/?
	if( $uri->path =~ m#^(?:/archive)?/(\d+)/# )
	{
		return 'info:' . EPrints::OpenArchives::to_oai_identifier( $session->get_repository->get_conf( "oai" )->{v2}->{ "archive_id" }, $1 );
	}
	
	return undef;
}

=item $id = EPrints::Apache::LogHandler::uri_to_docid( $session, $eprintid, $uri )

Returns the docid that $uri corresponds to (given the $eprintid), or undef.

=cut

sub uri_to_docid
{
	my( $session, $eprintid, $uri ) = @_;

	if( $uri->path =~ m#^(?:/archive)?/(\d+)/(\d+)/# )
	{
		return '#' . 1 * $2;
	}

	return undef;
}

sub geoip_open
{
	my( $geoip ) = @_;

	my $class = $geoip->{ "class" } or return;
	eval "use $class";

	if( my $fn = $geoip->{ "country" } )
	{
		eval { $GEOIP_DB = $class->open( $fn ) };
		warn "Apache::LogHandler: Country lookup unavailable: $@" if $@;
	}

	if( my $fn = $geoip->{ "organisation" } )
	{
		eval { $GEOORG_DB = $class->open( $fn ) };
		warn "Apache::LogHandler: Organisation lookup unavailable: $@" if $@;
	}
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj::Access>, L<Geo::IP> or L<Geo::IP::PurePerl>.

Download GeoIP databases from L<http://www.maxmind.com/>.
