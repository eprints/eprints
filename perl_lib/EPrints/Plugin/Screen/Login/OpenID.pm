package EPrints::Plugin::Screen::Login::OpenID;

use LWP::UserAgent;

@ISA = qw( EPrints::Plugin::Screen::Login );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "login_tools",
			position => 1000,
		},
	];
	$self->{endpoints} = [{
			# No permission to re-use Google's logo:
			# http://www.google.com/support/forum/p/apps-apis/thread?tid=37119cb988edbb78&hl=en
			url => "https://www.google.com/accounts/o8/id",
			title => "Google",
		},{
			# http://developer.yahoo.com/openid/faq.html
			url => "https://me.yahoo.com/",
			icon_url => "images/external/openid-yahoo.png",
			title => "Yahoo",
		}];
	push @{$self->{actions}}, "return";

	return $self;
}

sub allow_return { shift->allow_login }

sub action_login
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	$processor->{screenid} = 'Login';

	my $openid = $repo->param( "openid_identifier" );
	$self->finished if !$openid;

	$self->_init_openid( $openid );
}

sub action_return
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	$processor->{screenid} = 'Login';

	my $mode = $repo->param( 'openid.mode' );
	$mode = '' if !defined $mode;

	if( $mode eq 'cancel' )
	{
		return $self->finished;
	}

	my $username = $self->_valid_openid();
	if( !defined $username )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "failed" ) );
		return;
	}

	$self->{processor}->{username} = $username;

	my $user = $repo->user_by_username( $username );
	if( !defined $user )
	{
		my $plugin = $repo->plugin( "Screen::Register::OpenID",
				processor => $processor,
			);
		if( $plugin && $plugin->can_be_viewed )
		{
			my $uri = URI->new( $repo->current_url( host => 1, path => "cgi", "register" ) );
			$uri->query_form(
				screen => $plugin->get_subtype,
				openid_identifier => $repo->param( "openid_identifier" ),
				_action_register => 1,
				);
			$self->finished( $uri );
		}
	}

	$self->{processor}->{user} = $user;

	$self->finished;
}

sub _init_openid
{
	my( $self, $openid_identifier, %ext ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	if( $openid_identifier !~ /^https:/ )
	{
		$processor->add_message( "error", $self->html_phrase( "invalid_openid" ) );
		return;
	}

	EPrints::DataObj::OpenID->cleanup( $repo );

	my $op_endpoint = $self->resolve_openid_identifier( $openid_identifier );
	return if !defined $op_endpoint;

	# get the association handle
	my $openid = EPrints::DataObj::OpenID->new_by_op_endpoint(
		$repo,
		$op_endpoint
		);

	if( !defined $openid )
	{
		$openid = eval { EPrints::DataObj::OpenID->create_by_op_endpoint(
			$repo,
			$op_endpoint,
		) };
		if( $@ )
		{
			$processor->add_message( "error", $self->html_phrase( "bad_response",
					status => $repo->xml->create_text_node( '' ),
					content => $repo->xml->create_text_node( $@ ),
				) );
			return;
		}
	}

	# return address must match realm
	my $return_to = URI->new( $repo->current_url( scheme => "http", host => 1 ) );
	$return_to->query_form(
		$self->hidden_bits,
		openid_identifier => $openid_identifier,
		_action_return => 1,
	);
	$ext{'openid.return_to'} ||= $return_to;
	$ext{'openid.return_to'} .= ""; # URI breaks with objects
	my $realm = URI->new( $repo->config( "http_url" ) )->canonical;
	my $url = $openid->auth_uri( %ext,
			'openid.realm' => "$realm",
		);
	$repo->redirect( "$url" );
	exit(0);

	return undef;
}

sub _valid_openid
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	my $op_endpoint = $repo->param( "openid.op_endpoint" );
	my $assoc_handle = $repo->param( "openid.assoc_handle" );

	my $openid = EPrints::DataObj::OpenID->new_by_assoc_handle(
		$repo,
		$op_endpoint,
		$assoc_handle );

	if( !defined $openid )
	{
		$processor->add_message( 'error', $self->html_phrase( "bad_response",
			error => $repo->xml->create_text_node( "Invalid or expired association" ) ) );
		return;
	}

	if( !$openid->verify )
	{
		$processor->add_message( 'error', $self->html_phrase( "bad_response",
			error => $repo->xml->create_text_node( "Checksum failed" ) ) );
		return;
	}

	my $nonce = $repo->param( "openid.response_nonce" );
	my $nonce_object = EPrints::DataObj::OpenID->new_by_response_nonce(
		$repo,
		$op_endpoint,
		$nonce );
	if( !defined $nonce || defined $nonce_object )
	{
		$processor->add_message( 'error', $self->html_phrase( "bad_response",
			error => $repo->xml->create_text_node( "NONCE replay" ) ) );
		return;
	}

	$repo->dataset( "openid" )->create_dataobj({
		op_endpoint => $op_endpoint,
		response_nonce => $nonce,
		expires => $openid->value( "expires" ),
	});

	my $return_to = URI->new( $repo->param( "openid.return_to" ) );
	my $openid_identifier = {$return_to->query_form}->{"openid_identifier"};
	return if !$openid_identifier; # bad return_to

	my $username;

	my $identity = $repo->param( "openid.identity" );
	if( $identity && $identity ne $openid_identifier )
	{
		$identity = URI->new( $identity );
		$openid_identifier = URI->new( $openid_identifier );

		if( !$identity->host || $identity->host ne $openid_identifier->host )
		{
			$processor->add_message( 'error', $self->html_phrase( "bad_response",
				error => $repo->xml->create_text_node( "OpenID provided an identity outside of its realm: ".$identity ) ) );
			return;
		}

		$username = $identity;
	}
	else
	{
		$username = $openid_identifier;
	}

	return $username;
}

sub resolve_openid_identifier
{
	my( $self, $openid_identifier ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	my $ua = LWP::UserAgent->new;
	my $r = $ua->get( $openid_identifier, Accept => 'application/xrds+xml' );

	if( $r->header( 'X-XRDS-Location' ) )
	{
		$r = $ua->get( $r->header( 'X-XRDS-Location' ), Accept => 'application/xrds+xml' );
	}

	if(
		$r->is_error ||
		$r->header('Content-Type') !~ m#application/xrds\+xml\b# ||
		length($r->content) > 10000
	  )
	{
		$processor->{problems} = $self->html_phrase( "bad_response",
			error => $repo->xml->create_text_node( $r->content ) );
		return;
	}

	my $doc = eval { $repo->xml->parse_string( $r->content ) };
	if( $@ )
	{
		$processor->{problems} = $self->html_phrase( "bad_response",
			error => $@ );
		return;
	}

	my @services;
	my $xrds = $doc->documentElement;
	foreach my $Service ($xrds->getElementsByTagName( "Service" ) )
	{
		my $service = {
			priority => ($Service->getAttribute( "priority" ) || 0),
			type => {},
		};
		foreach my $node ($Service->childNodes)
		{
			next if !$node->hasChildNodes;
			my $type = $node->nodeName;
			my $value = $node->firstChild->toString;
			if( $type eq 'URI' )
			{
				$service->{'uri'} = $value;
			}
			elsif( $type eq 'Type' )
			{
				$service->{'type'}->{$value} = 1;
			}
			else
			{
				push @{$service->{lc($type)}}, $value;
			}
		}
		push @services, $service;
	}
	@services =
		sort { $a->{priority} <=> $b->{priority} }
		grep { $_->{type}->{'http://specs.openid.net/auth/2.0/server'} }
		@services;

	if( !@services )
	{
		$processor->{problems} = $self->html_phrase( "bad_response",
			error => $repo->xml->create_text_node( "Requires OpenID 2.0 endpoint" ) );
		return;
	}

	my $op_endpoint = $services[0]->{uri};

	return $op_endpoint;
}

sub render_action_link
{
	my( $self, %bits ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	my $endpoints = $self->param( "endpoints" );
	my $base_url = URI->new( $repo->current_url() );
	$base_url->query_form(
		$self->hidden_bits,
		_action_login => 1,
		);
	foreach my $endpoint( @$endpoints )
	{
		my $url = $base_url->clone;
		$url->query_form(
			$url->query_form,
			openid_identifier => $endpoint->{url},
			);
		my $link = $xml->create_element( "a", href => "$url" );
		$frag->appendChild( $link );
		if( $endpoint->{icon_url} )
		{
			$link->appendChild( $xml->create_element( "img",
				src => $repo->current_url( path => "static", $endpoint->{icon_url} ),
				alt => $endpoint->{title},
				title => $endpoint->{title},
				border => 0,
				) );
		}
		else
		{
			$link->appendChild( $xml->create_text_node( $endpoint->{title} ) );
		}
	}

	my $form = $repo->render_form( "POST" );
	$frag->appendChild( $form );

	$form->appendChild( $self->render_hidden_bits );
	$form->appendChild( $xhtml->input_field(
		"openid_identifier",
		"",
		type => "text",
		style => "background-image: url('".$self->icon_url."'); background-repeat: no-repeat; padding-left: 20px;",
		) );

	my $title = $self->render_title;
	$form->appendChild( $repo->render_button(
			name => "_action_login",
			value => $xhtml->to_text_dump( $title ),
			class => 'ep_form_action_button' ) );
	$xml->dispose( $title );

	return $frag;
}

sub icon_url
{
	my( $self ) = @_;

	return $self->{repository}->current_url( path => "static", "images/external/openid-logo-icon.png" );
}

1;
