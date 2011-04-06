=head1 NAME

EPrints::Plugin::Screen::EPrint::UploadMethod::Google

=cut

package EPrints::Plugin::Screen::EPrint::UploadMethod::Google;

use URI::Escape;
use LWP::Authen::OAuth;
use EPrints::Plugin::Screen::EPrint::UploadMethod::File;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod::File );

use strict;

our $OAuthGetRequestToken = "https://www.google.com/accounts/OAuthGetRequestToken";
our $OAuthAuthorizeToken = "https://www.google.com/accounts/OAuthAuthorizeToken";
our $OAuthGetAccessToken = "https://www.google.com/accounts/OAuthGetAccessToken";
our $GOOGLE_SCOPE = "https://docs.google.com/feeds/ https://spreadsheets.google.com/feeds/ https://docs.googleusercontent.com/";
our $GOOGLE_SERVICE = "https://docs.google.com/feeds/default/private/full";
our %GOOGLE_FORMATS = (
	doc => "application/msword",
	html => "text/html",
	jpeg => "image/jpeg",
	odt => "application/vnd.oasis.opendocument.text",
	pdf => "application/pdf",
	png => "image/png",
	rtf => "application/rtf",
	svg => "image/svg",
	txt => "text/plain",
	zip => "application/zip",
	ppt => "application/vnd.ms-powerpoint",
	swf => "application/x-shockwave-flash",
	xls => "application/vnd.ms-excel",
	csv => "text/comma-separated-values",
	ods => "application/vnd.oasis.opendocument.spreadsheet",
	tsv => "text/tab-separated-values",
);

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{appears} = [
			{ place => "upload_methods", position => 1000 },
	];
	$self->{actions} = [qw( login logout verify search upload )];

	return $self;
}

sub allow_login { shift->can_be_viewed }
sub allow_logout { shift->can_be_viewed }
sub allow_verify { shift->can_be_viewed }
sub allow_search { shift->can_be_viewed }
sub allow_upload { shift->can_be_viewed }

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->{processor}->screen->hidden_bits,
		stage => $self->{session}->param( "stage" ),
		($self->{parent}->{prefix}."_tab") => $self->get_id,
	);
}

sub from
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::from();
}

sub get_state_params
{
	my( $self ) = @_;

	my $uri = URI->new( 'http:' );
	$uri->query_form(
		$self->{prefix}.'_q' => scalar($self->{session}->param( $self->{prefix}.'_q' )),
	);

	return $uri->query ? '&'.$uri->query : '';
}

sub action_login
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $oauth = $self->oauth;

	$oauth->remove if defined $oauth;

	my $callback = URI->new( $repo->current_url( host => 1 ) );
	$callback->query_form(
		$self->hidden_bits,
		('_internal_'.$self->{prefix}.'_verify') => 1,
	);

	# get a request token
	my $ua = LWP::Authen::OAuth->new(
		oauth_consumer_secret => "anonymous",
	);
	my $r = $ua->post($OAuthGetRequestToken, [
		oauth_consumer_key => "anonymous",
		scope => $GOOGLE_SCOPE,
		oauth_callback => $callback,
		xoauth_displayname => $repo->phrase( "archive_name" ),
	]);
	if( !$r->is_success )
	{
		EPrints->abort( "Error talking to OAuthGetRequestToken endpoint: " . $r->as_string );
	}

	$ua->oauth_update_from_response( $r );

	$repo->dataset( "oauth" )->create_dataobj({
		service => $GOOGLE_SERVICE,
		userid => $repo->current_user->id,
		expires => time()+86400, # 1 day
		oauth_token => $ua->oauth_token,
		oauth_request_secret => $ua->oauth_token_secret,
	});

	my $verify = URI->new( $OAuthAuthorizeToken );
	$verify->query_form(
		oauth_token => $ua->oauth_token
	);

	$self->{processor}->{redirect} = "$verify";
}

sub action_logout
{
	my( $self ) = @_;

	my $oauth = $self->oauth;
	$oauth->remove if $oauth;
}

sub action_verify
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $oauth = $self->oauth;

	# something odd happened
	return if $oauth->is_set( "oauth_token_secret" );

	# upgrade to access token
	my $ua = LWP::Authen::OAuth->new(
		oauth_consumer_key => "anonymous",
		oauth_consumer_secret => "anonymous",
		oauth_token => $oauth->value( "oauth_token" ),
		oauth_token_secret => $oauth->value( "oauth_request_secret" ),
	);
	my $r = $ua->post($OAuthGetAccessToken, [
		oauth_verifier => $repo->param( "oauth_verifier" ),
	]);
	if( $r->is_success )
	{
		$ua->oauth_update_from_response( $r );

		$oauth->set_value( "oauth_token", $ua->oauth_token );
		$oauth->set_value( "oauth_request_secret", undef );
		$oauth->set_value( "oauth_token_secret", $ua->oauth_token_secret );

		$oauth->commit;
	}
	else
	{
		$oauth->remove;
		$repo->log( "Error talking to OAuthGetRequestToken endpoint" );
	}

	my $uri = URI->new( $repo->current_url( host => 1 ) );
	$uri->query_form(
		$self->hidden_bits,
	);

	$self->{processor}->{redirect} = "$uri";
}

sub action_search
{
	my( $self ) = @_;
}

sub action_upload
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $xml = $repo->xml;
	my $oauth = $self->oauth;
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	return if !$oauth;

	my $ua = $self->user_agent( $oauth );

	my $format = $repo->param( $self->{prefix}."_format" );
	my $resourceId = $repo->param( $self->{prefix}."_resourceId" );

	return if !$format || !$resourceId;

	my $r = $ua->get( "$GOOGLE_SERVICE/".URI::Escape::uri_escape($resourceId) );

	my $doc = eval { $repo->xml->parse_string( $r->content ) };

	if( $r->is_error || !$doc )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "remote_error",
			request => $repo->xml->create_text_node( $r->request->uri ),
			response => $repo->xml->create_text_node( $r->as_string ) ) );
		return;
	}

	my( $content ) = $doc->documentElement->getElementsByTagName( "content" );
	my $export_uri = URI->new( $content->getAttribute( "src" ) );
	if( $format ne "other" )
	{
		$export_uri->query_form(
			$export_uri->query_form,
			export => $format,
			exportFormat => $format
		);
	}

	my( $title ) = $doc->documentElement->getElementsByTagName( "title" );
	$title = $repo->xml->text_contents_of( $title ) if defined $title;

	my $tmpfile = File::Temp->new;
	$r = $ua->get( $export_uri, ':content_file' => "$tmpfile" );
	seek($tmpfile,0,0);

	if( $r->is_error )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "remote_error",
			request => $repo->xml->create_text_node( $r->request->uri ),
			response => $repo->xml->create_text_node( $r->as_string ) ) );
		return;
	}

	my $mime_type = $r->header( "Content-Type" );
	$mime_type =~ s/;.*$//;

	my $filename;
	{
		my $content_disposition = $r->header( "Content-Disposition" );
		my @parts = split /\s*;\s*/, $content_disposition;
		my %parts = map { m/=/ ? split('=', $_, 2) : $_ => 1 } @parts;
		s/"(.+)"/$1/ for values %parts;
		$filename = URI::Escape::uri_unescape( $parts{filename} );
	}
	$filename = "main.$format" if !$filename;

	my $document = $eprint->create_subdataobj( "documents", {
		main => $filename,
		format => $mime_type,
		files => [{
			filename => $filename,
			filesize => -s $tmpfile,
			mime_type => $mime_type,
			_content => $tmpfile,
		}],
	});

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->id} = 1;
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $xml = $repo->xml;
	my $oauth = $self->oauth;

	if( !$oauth )
	{
		return $self->render_login();
	}

	my $ua = $self->user_agent( $oauth );
	my $quri = URI->new( "https://docs.google.com/feeds/default/private/full" );
	$quri->query_form(
		q => scalar($repo->param( $self->{prefix} . "_q" )),
	);
	my $r = $ua->get( $quri );
	if( !$r->is_success )
	{
		$oauth->remove;
		$self->{processor}->add_message( "error", $self->html_phrase( "remote_error",
			request => $repo->xml->create_text_node( $r->request->as_string ),
			response => $repo->xml->create_text_node( $r->as_string ) ) );
		return $self->render_login();
	}

	my $f = $repo->make_doc_fragment;

	my $doc = eval { $repo->xml->parse_string( $r->content ) };
	if( !defined $doc )
	{
		EPrints->abort( "Unexpected response: " . $r->content );
	}

	$f->appendChild( $repo->xhtml->input_field(
		$self->{prefix} . "_q",
		scalar($repo->param( $self->{prefix} . "_q" )),
		type => "text" ) );
	$f->appendChild( $repo->render_button(
		value => $repo->phrase( "lib/searchexpression:action_search" ),
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_search" ) );
	$f->appendChild( $repo->render_button(
		value => $repo->phrase( "Plugin/Screen/Logout:title" ),
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_logout" ) );

	my $table = $xml->create_element( "table" );
	$f->appendChild( $table );
	my $i = 0;
	foreach my $entry ($doc->documentElement->getElementsByTagName( "entry" ))
	{
		my $tr = $table->appendChild( $xml->create_element( "tr" ) );

		my( $resourceId ) = $entry->getElementsByTagName( "resourceId" );
		$resourceId = $xml->text_contents_of( $resourceId );

		my $label_key = join "_", $self->{prefix}, $i++;

		my( $title ) = $entry->getElementsByTagName( "title" );
		$title = $xml->text_contents_of( $title );
		my $td = $tr->appendChild( $xml->create_element( "td" ) );
		my $label = $td->appendChild( $xml->create_element( "label",
				for => $label_key,
			) );
		$label->appendChild( $xml->create_text_node( $title ) );

		my $checkbox = $xml->create_element( "input",
			type => "radio",
			name => $self->{prefix}.'_resourceId',
			id => $label_key,
			value => $resourceId,
		);
		$td = $tr->appendChild( $xml->create_element( "td" ) );
		$td->appendChild( $checkbox );
	}
	
	$f->appendChild( $repo->html_phrase( "lib/submissionform:format" ) );
	$f->appendChild( $repo->xml->create_text_node( ": " ) );

	my $select = $f->appendChild( $repo->xml->create_element( "select",
		name => $self->{prefix}.'_format'
	) );
	$select->appendChild( $repo->xml->create_element( "option",
		value => "other"
	) )->appendChild( $repo->html_phrase( "document_typename_other" ) );
	for(sort { $GOOGLE_FORMATS{$a} cmp $GOOGLE_FORMATS{$b} } keys %GOOGLE_FORMATS)
	{
		my $phraseid = "document_typename_".$GOOGLE_FORMATS{$_};
		if( $repo->get_lang->has_phrase( $phraseid ) )
		{
			$select->appendChild( $repo->xml->create_element( "option",
				value => $_
			) )->appendChild( $repo->html_phrase( $phraseid ) );
		}
		else
		{
			$select->appendChild( $repo->xml->create_element( "option",
				value => $_
			) )->appendChild( $repo->xml->create_text_node( $GOOGLE_FORMATS{$_} ) );
		}
	}

	$f->appendChild( $repo->render_button(
		value => $repo->phrase( "Plugin/InputForm/Component/Upload:add_format" ),
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_upload" ) );

	return $f; 
}

sub render_login
{
	my( $self ) = @_;

	my $repo = $self->{session};

	return $repo->render_button(
		value => $repo->phrase( "cgi/login:title" ),
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_login" );
}

sub oauth
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $user = $repo->current_user;
	my $dataset = $repo->dataset( "oauth" );

	return $dataset->dataobj_class->new_by_service_userid(
		$repo,
		$GOOGLE_SERVICE,
		$user->id );
}

sub user_agent
{
	my( $self, $oauth ) = @_;

	my $ua = LWP::Authen::OAuth->new(
		oauth_consumer_key => "anonymous",
		oauth_consumer_secret => "anonymous",
		oauth_token => $oauth->value( "oauth_token" ),
		oauth_token_secret => $oauth->value( "oauth_token_secret" ),
	);
	$ua->default_headers->header( 'GData-Version' => '3.0' );

	return $ua;
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

