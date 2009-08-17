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

use EPrints;

use strict;

use constant {
	DECLINED => -1,
	OK => 0,
	NOT_MODIFIED => 304
};

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
		return DECLINED();
	}

	my $pnotes = $r->pnotes;

	my $event_type = $pnotes->{ "loghandler" };
	return DECLINED() unless defined $event_type;

	my $c = $r->connection;
	my $ip = $c->remote_ip;

	my $access = {};
	$access->{datestamp} = EPrints::Time::get_iso_timestamp( $r->request_time );
	$access->{requester_id} = $ip;
	$access->{referring_entity_id} = $r->headers_in->{ "Referer" };
	$access->{service_type_id} = $event_type;
	$access->{requester_user_agent} = $r->headers_in->{ "User-Agent" };

	if( $event_type eq "?abstract=yes" )
	{
		$access->{referent_id} = $pnotes->{ "eprintid" };
	}
	elsif( $event_type eq "?fulltext=yes" )
	{
		my $dataobj = $pnotes->{ "dataobj" };
		my $filename = $pnotes->{ "filename" };
		# only count hits to the main file
		if( $filename ne $dataobj->get_main )
		{
			return DECLINED();
		}
		if( $dataobj->has_related_objects( EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) )
		{
			return DECLINED();
		}
		$access->{referent_id} = $dataobj->get_value( "eprintid" );
		$access->{referent_docid} = $dataobj->get_id;
	}
	else
	{
		return DECLINED();
	}

	# Sanity check referring URL (don't store non-HTTP referrals)
	if( !$access->{referring_entity_id} or $access->{referring_entity_id} !~ /^https?:/ )
	{
		$access->{referring_entity_id} = '';
	}

	my $handle = new EPrints::Handle(2);
	$handle->get_repository->get_dataset( "access" )->create_object(
			$handle,
			$access
		);
	$handle->terminate;

	return OK();
}

=item $id = EPrints::Apache::LogHandler::uri_to_eprintid( $handle, $uri )

Returns the eprint id that $uri corresponds to, or undef.

=cut

sub uri_to_eprintid
{
	my( $handle, $uri ) = @_;

	# uri is something like /xxxxxx/?
	if( $uri->path =~ m#^(?:/archive)?/(\d+)/# )
	{
		return $1;
	}
	
	return undef;
}

=item $id = EPrints::Apache::LogHandler::uri_to_docid( $handle, $eprintid, $uri )

Returns the docid that $uri corresponds to (given the $eprintid), or undef.

=cut

sub uri_to_docid
{
	my( $handle, $eprintid, $uri ) = @_;

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

