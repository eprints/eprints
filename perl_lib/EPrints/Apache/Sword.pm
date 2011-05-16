=head1 NAME

EPrints::Apache::Sword

=cut

package EPrints::Apache::Sword;

use EPrints::Const qw( :http );
use MIME::Base64;
use HTTP::Headers::Util;
use Digest::MD5;

our $PACKAGING_PREFIX = "sword:";

use strict;

sub handler_servicedocument
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;
	my $xml = $repo->xml;

	my $user = $repo->current_user;
	EPrints->abort( "unprotected" ) if !defined $user; # Rewrite foobar
	my $on_behalf_of = on_behalf_of( $repo, $r, $user );
	if( $on_behalf_of->{status} != OK )
	{
		return sword_error( $repo, $r, %$on_behalf_of );
	}
	$on_behalf_of = $on_behalf_of->{on_behalf_of};

	my $service_conf = $repo->config( "sword", "service_conf" ) || {};

	$service_conf->{title} = $repo->phrase( "archive_name" ) if !defined $service_conf->{title};

# SERVICE and WORKSPACE DEFINITION

	my $service = $xml->create_element( "service", 
			xmlns => "http://www.w3.org/2007/app",
			"xmlns:atom" => "http://www.w3.org/2005/Atom",
			"xmlns:sword" => "http://purl.org/net/sword/",
			"xmlns:dcterms" => "http://purl.org/dc/terms/" );

	my $workspace = $xml->create_data_element( "workspace", [
		[ "atom:title", $service_conf->{title} ],
# SWORD LEVEL
		[ "sword:version", "2.0" ],
# SWORD VERBOSE	(Unsupported)
		[ "sword:verbose", "true" ],
# SWORD NOOP (Unsupported)
		[ "sword:noOp", "true" ],
	]);
	$service->appendChild( $workspace );

	my $treatment = $service_conf->{treatment};
	if( defined $on_behalf_of )
	{
		$treatment .= $repo->phrase( "Sword/ServiceDocument:note_behalf", username=>$on_behalf_of->value( "username" ));
	}

	my $collection = $xml->create_data_element( "collection", [
# COLLECTION TITLE
		[ "atom:title", $repo->dataset( "eprint" )->render_name ],
# COLLECTION POLICY
		[ "sword:collectionPolicy", $service_conf->{sword_policy} ],
# COLLECTION MEDIATED
		[ "sword:mediation", "true" ],
# DCTERMS ABSTRACT
		[ "dcterms:abstract", $service_conf->{dcterms_abstract} ],
# COLLECTION TREATMENT
		[ "sword:treatment", $treatment ],
	], "href" => $repo->current_url( host => 1, path => "static", "sword-app/collection" ),
	);
	$service->appendChild( $collection );

	if( $user->allow( "create_eprint" ) )
	{
		foreach my $plugin (plugins( $repo ))
		{
			foreach my $mime_type (@{$plugin->param( "accept" )})
			{
				if( $mime_type =~ /^$PACKAGING_PREFIX(.+)$/ )
				{
					$collection->appendChild( $xml->create_data_element( "acceptPackaging", $1 ) );
				}
				else
				{
					$collection->appendChild( $xml->create_data_element( "accept", $mime_type ) );
				}
			}
		}

		# we always accept simple files
		$collection->appendChild( $xml->create_data_element( "acceptPackaging", "http://purl.org/net/sword/package/Binary" ) );
		$collection->appendChild( $xml->create_data_element( "accept", "application/octet-stream" ) );
	}
	else
	{
		$collection->application( $xml->create_data_element( "accept" ) );
	}

	my $content = "<?xml version='1.0' encoding='UTF-8'?>\n" .
		$xml->to_string( $service, indent => 1 );

	return send_response( $r,
		OK,
		'application/xtomsvc+xml; charset=UTF-8',
		$content
	);
}

sub handler_records
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;

	my $user = $repo->current_user;
	EPrints->abort( "unprotected" ) if !defined $user;

	my $on_behalf_of = on_behalf_of( $repo, $r, $user );
	if( $on_behalf_of->{status} != OK )
	{
		return sword_error( $repo, $r, %$on_behalf_of );
	}
	$on_behalf_of = $on_behalf_of->{on_behalf_of};

	my $owner = $on_behalf_of || $user;

	my $headers = process_headers( $repo, $r );

	if( $r->method eq "POST" )
	{
		use bytes;

		if( !$user->allow( "create_eprint" ) )
		{
			return HTTP_FORBIDDEN;
		}

		my $mime_type = $headers->{content_type};

		my @plugins;
		if( $headers->{packaging} )
		{
			@plugins = plugins( $repo, can_accept => $headers->{packaging} );
			return sword_error( $repo, $r,
				status => HTTP_BAD_REQUEST,
				href => "http://purl.org/net/sword/error/ErrorContent",
				summary => "No support for packaging '$headers->{packaging}'",
			) if !@plugins;
		}
		else
		{
			@plugins = plugins( $repo, can_accept => $mime_type );
		}

		my $ctx = $headers->{content_md5} ? Digest::MD5->new : undef;

		my $tmpfile = File::Temp->new( SUFFIX => $headers->{extension} );
		binmode($tmpfile);
		my $len = 0;
		while($r->read(my $buffer, 4096)) {
			$len += length($buffer);
			$ctx->add( $buffer ) if defined $ctx;
			print $tmpfile $buffer;
		}
		seek($tmpfile,0,0);

		if( defined $ctx && $ctx->hexdigest ne $headers->{content_md5} )
		{
			return sword_error( $repo, $r,
				status => HTTP_PRECONDITION_FAILED,
				href => "http://purl.org/net/sword/error/ErrorChecksumMismatch",
				summary => "MD5 digest mismatch between headers and content",
			);
		}

		my $dataset = $repo->dataset( "inbox" );
		my $eprint;

		if( !@plugins )
		{
			$eprint = $dataset->create_dataobj({
				eprint_status => "inbox",
				documents => [{
					format => $mime_type,
					main => $headers->{filename},
					files => [{
						filename => $headers->{filename},
						filesize => -s $tmpfile,
						_content => $tmpfile,
						mime_type => $mime_type,
					}],
				}],
			});
		}
		else
		{
			my $list = eval { $plugins[0]->input_fh(
				dataset => $dataset,
				fh => $tmpfile,
				filename => $headers->{filename},
			) };
			if( $@ )
			{
				return sword_error( $repo, $r,
					summary => $@
				);
			}

			$eprint = $list->item( 0 );
		}

		if( !defined $eprint )
		{
			return sword_error( $repo, $r,
				summary => "No data found"
			);
		}

		$eprint->set_value( "userid", $owner->id );
		if( defined $on_behalf_of )
		{
			$eprint->set_value( "sword_depositor", $user->id );
		}
		$eprint->commit;

		if(
			!$headers->{in_progress} &&
			$user->allow( "eprint/inbox/deposit", $eprint )
		  )
		{
			$eprint->move_to_buffer;
		}

		$r->err_headers_out->{'Location'} = $eprint->uri;

		my $plugin = $repo->plugin( "Export::Atom" );
		$r->content_type( $plugin->param( "mimetype" ) );
		$plugin->initialise_fh( \*STDOUT );
		print $plugin->output_dataobj( $eprint );

		return HTTP_CREATED;
	}
	else
	{
		my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
		$accept = "" if !defined $accept;
		my $plugin = EPrints::Apache::Rewrite::content_negotiate_best_plugin( 
			$repo, 
			accept_header => $accept,
			consider_summary_page => 0,
			plugins => [$repo->get_plugins(
				type => "Export",
				is_visible => "all",
				can_accept => "list/eprint" )]
		);
		return HTTP_NOT_FOUND if !defined $plugin;
	
		my $indexOffset = $repo->param( "indexOffset" ) || 0;
		my $page_size = 20;

		my $base = $repo->current_url( host => 1 );
		my $next = $base->clone;
		$next->query_form( indexOffset => $indexOffset + $page_size );
		my $previous = $base->clone;
		$previous->query_form( indexOffset => $indexOffset - $page_size );

		my $list = $owner->owned_eprints_list(
			limit => $indexOffset + $page_size,
		);
		$list->{ids} = $list->ids( $indexOffset, $page_size );

		$r->content_type( $plugin->param( "mime_type" ) );
		$plugin->initialise_fh( \*STDOUT );
		$plugin->output_list(
			startIndex => $indexOffset,
			list => $list,
			fh => \*STDOUT,
			offsets => {
				self => $repo->current_url( host => 1, query => 1 ),
				first => $base,
				next => $next,
				($indexOffset >= $page_size ? (previous => $previous) : ()),
			},
		);
		return OK;
	}
}

### Utility methods below

sub on_behalf_of
{
	my( $repo, $r, $depositor ) = @_;

	my $err = {
		status => HTTP_FORBIDDEN,
		href => "http://purl.org/net/sword/error/TargetOwnerUnknown",
		summary => "Target user unknown or no permission to act on-behalf-of",
	};

	my $on_behalf_of =
		$r->headers_in->{'On-Behalf-Of'} || # SWORD 2.0
		$r->headers_in->{'X-On-Behalf-Of'}; # SWORD 1.3

	return { status => OK } if !$on_behalf_of;

	$on_behalf_of = $repo->user_by_username( $on_behalf_of );
	return $err if !defined $on_behalf_of;

	return $err if !$depositor->allow( "user/mediate", $on_behalf_of );

	return {
		status => OK,
		on_behalf_of => $on_behalf_of,
	};
}

sub authenticate
{
	my ( $repo, $r ) = @_;

	my $authen = $r->headers_in->{'Authorization'};

	if(!defined $authen)
	{
		return {
			status => HTTP_UNAUTHORIZED, 
			no_auth => 1, 
		};
	}

# Check we have Basic authentication sent in the headers, and decode the Base64 string:
	if($authen =~ /^Basic\ (.*)$/)
	{
		$authen = $1;
	}
	my $decode_authen = MIME::Base64::decode_base64( $authen );
	if(!defined $decode_authen)
	{
		return {
			status => HTTP_UNAUTHORIZED, 
		};
	}

	my( $username, $password ) = split ':', $decode_authen, 2;
	$username = $repo->valid_login( $username, $password );
	my $user = $repo->user_by_username( $username );

	if( !defined( $user ) )
	{
		return {
			status => HTTP_UNAUTHORIZED, 
		};
	}

# Now check we have a behalf user set, and whether the mediated deposit is allowed
	my $owner =
		$r->headers_in->{'On-Behalf-Of'} || # SWORD 2.0
		$r->headers_in->{'X-On-Behalf-Of'}; # SWORD 1.3
	if( !defined $owner )
	{
		return {
			status => OK,
			owner => $user,
		};
	}

	$owner = $repo->user_by_username( $owner );
	if( !defined $owner )
	{
		return {
			status => HTTP_UNAUTHORIZED, 
			href => "http://purl.org/net/sword/error/TargetOwnerUnknown",
		};
	}

	if( !$user->allow( "user/mediate", $owner ) )
	{
		return {
			status => HTTP_FORBIDDEN, 
			href => "http://eprints.org/sword/error/MediationForbidden",
		};
	}

	return {
		status => OK,
		depositor => $user,
		owner => $owner,
	};
}

sub is_true
{
	return defined($_[0]) && lc($_[0]) eq "true";
}

sub is_false
{
	return defined($_[0]) && lc($_[0]) eq "false";
}

sub process_headers
{
	my ( $repo, $r ) = @_;

	my %response;

# In-Progress
	$response{in_progress} = is_true( $r->headers_in->{'In-Progress'} );

# X-Verbose
	$response{verbose} = is_true( $r->headers_in->{'X-Verbose'} );

# Content-Type	
	$response{content_type} = $r->headers_in->{'Content-Type'};
	$response{content_type} = "application/octet-stream"
		if !EPrints::Utils::is_set( $response{content_type} );

# Content-Length
	$response{content_length} = $r->headers_in->{'Content-Length'};

# Content-MD5	
	$response{content_md5} = $r->headers_in->{'Content-MD5'};

# Content-Disposition
	my @values = HTTP::Headers::Util::split_header_words( $r->headers_in->{'Content-Disposition'} || '' );
	for(my $i = 0; $i < @values; $i += 2)
	{
		if( $values[$_] eq "filename" )
		{
			$response{filename} = $values[$_+1];
		}
	}
	$response{filename} = "main.bin"
		if !EPrints::Utils::is_set( $response{filename} );
	($response{extension}) = $response{filename} =~ /((?:\.[^\.]+){1,2})$/;

# X-No-Op
	$response{no_op} = is_true( $r->headers_in->{'X-No-Op'} );

# X-Packaging
	$response{packaging} = 
		$r->headers_in->{'Packaging'} || # SWORD 2.0
		$r->headers_in->{'X-Packaging'} || # SWORD 1.3
		$r->headers_in->{'X-Format-Namespace'}; # SWORD 1.2

# Slug
	$response{slug} = $r->headers_in->{'Slug'};

# userAgent
	$response{user_agent} = $r->headers_in->{'User-Agent'};

	return \%response;
}

sub sword_error
{
	my( $repo, $r, %opts ) = @_;

	my $xml = generate_error_document( $repo, %opts );

	$opts{status} = HTTP_BAD_REQUEST if !defined $opts{status};

	$r->status( $opts{status} );

	return send_response( $r,
		$opts{status},
		'application/xml; charset=UTF-8',
		$xml
	);
}

# other helper functions:
sub generate_error_document
{
	my ( $repo, %opts ) = @_;

	my $xml = $repo->xml;

	$opts{href} = "http://eprints.org/sword/error/UnknownError"
		if !defined $opts{href};

	my $error = $xml->create_data_element( "sword:error", [
		[ "title", "ERROR" ],
		[ "updated", EPrints::Time::get_iso_timestamp() ],
		[ "generator", $repo->phrase( "archive_name" ),
			uri => "http://www.eprints.org/",
			version => EPrints->human_version,
		],
		[ "summary", $opts{summary} ],
		[ "sword:userAgent", $opts{user_agent} ],
	],
		"xmlns" => "http://www.w3.org/2005/Atom",
		"xmlns:sword" => "http://purl.org/net/sword/",
		href => $opts{href},
	);

	return "<?xml version='1.0' encoding='UTF-8'?>\n" .
		$xml->to_string( $error, indent => 1 );
}

sub plugins
{
	my( $repo, %constraints ) = @_;

	return $repo->get_plugins(
		type => "Import",
		can_produce => "dataobj/eprint",
		is_visible => "all",
		is_advertised => 1,
		%constraints
	);
}

sub send_response
{
	my( $r, $status, $content_type, $content ) = @_;

	use bytes;

	$r->status( $status );
	$r->content_type( $content_type );
	if( defined $content )
	{
		$r->err_headers_out->{'Content-Length'} = length $content;
		binmode(STDOUT, ":utf8");
		print $content;
	}

	return $status;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

