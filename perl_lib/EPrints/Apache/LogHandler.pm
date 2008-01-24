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

use URI;

use EPrints;
use EPrints::Apache::AnApache;

use constant NOT_MODIFIED => 304;

=item handler REQUEST

Called by mod_perl whenever a request is made to the web server where REQUEST is an Apache Request object.

=cut

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

	my $c = $r->connection;
	my $ip = $c->remote_ip;
	my $uri = URI->new($r->uri);

	my $access = {};
	$access->{datestamp} = EPrints::Time::get_iso_timestamp( $r->request_time );
	$access->{requester_id} = $ip;
	$access->{referent_id} = $r->uri;
	$access->{referent_docid} = undef;
	$access->{referring_entity_id} = $r->headers_in->{ "Referer" };
	$access->{service_type_id} = '';
	$access->{requester_user_agent} = $r->headers_in->{ "User-Agent" };

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
	my $ref_uri = URI->new($access->{referring_entity_id});
	my $eprintid = uri_to_eprintid( $session, $ref_uri );

	if( defined $eprintid ) 
	{
		$access->{referring_entity_id} = $eprintid;

		my $docid = uri_to_docid( $session, $eprintid, $ref_uri );

		# If referring entity and referent are the same, and both are fulltext,
		# then this is likely to be inline content (e.g. an image or
		# javascript). For now, we'll ignore these requests.
		if( $access->{referring_entity_id} eq $access->{referent_id} and
			defined( $docid ) )
		{
			return OK;
		}
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
		return $1;
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
		return $2;
	}

	return undef;
}


1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj::Access>

