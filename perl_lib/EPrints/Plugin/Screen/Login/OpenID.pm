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

	return $self;
}

sub action_login
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $openid = $repo->param( "openid_identifier" );
	my $username;

	my $mode = $repo->param( 'openid.mode' );
	$mode = '' if !defined $mode;

	if( $mode eq 'cancel' )
	{
		my $uri = URI->new( $repo->current_url( host => 1 ) );
		$uri->query($repo->param( "login_params" ) );
		$repo->redirect( "$uri" );
		exit(0);
	}
	elsif( defined( $repo->param( 'openid.signed' ) ) )
	{
		$username = $self->_valid_openid();
	}
	elsif( defined $openid )
	{
		$self->_init_openid( $openid );
	}

	if( defined $openid && !defined $username )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "failed" ) );
	}

	$self->{processor}->{username} = $username;

	$self->SUPER::action_login;

	my $user = $self->{processor}->{user};
	return if !defined $user;

	# we require the user to validate their email address via OpenID
	if( !$user->is_set( "email" ) )
	{
		undef $self->{processor}->{user};
	}
}

sub _init_openid
{
	my( $self, $openid_identifier, %ext ) = @_;

	return if $openid_identifier !~ /^https:/; # only HTTP support atm

	my $repo = $self->{repository};
	my $processor = $self->{processor};

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
		_action_login => 1,
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

	my $identity = URI->new( $repo->param( "openid.identity" ) );
	$op_endpoint = URI->new( $op_endpoint );

	if( !$identity->host || $identity->host ne $op_endpoint->host )
	{
		$processor->add_message( 'error', $self->html_phrase( "bad_response",
			error => $repo->xml->create_text_node( "OpenID provided an identity outside of its realm" ) ) );
		return;
	}

	return $repo->param( "openid.identity" );
}

sub resolve_openid_identifier
{
	my( $self, $openid_identifier ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	my $ua = LWP::UserAgent->new;
	my $r = $ua->get( $openid_identifier, Accept => 'application/xrds+xml' );

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
		sort { $b->{priority} <=> $a->{priority} }
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

	my $title = $self->render_title;
	$bits{login_button} = $repo->render_button(
			name => "_action_login",
			value => $repo->xhtml->to_text_dump( $title ),
			class => 'ep_form_action_button', );
	$bits{login_button} = $repo->make_element( "input",
		name => "_action_login",
		type => "image",
		src => $self->icon_url );

	$repo->xml->dispose( $title );

	my $form = $repo->render_form( "POST" );

	$form->appendChild( $self->html_phrase( "input", %bits ) );
	$form->appendChild( $self->render_hidden_bits );

	return $form;
}

sub icon_url
{
	my( $self ) = @_;

	return $self->{repository}->current_url( path => "static", "images/external/openid-logo-wordmark-icon.jpg" );
}

1;
