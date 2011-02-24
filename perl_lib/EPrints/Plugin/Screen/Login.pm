package EPrints::Plugin::Screen::Login;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
# See cfg.d/dynamic_template.pl
#		{
#			place => "key_tools",
#			position => 100,
#		},
	];
	$self->{actions} = [qw( login )];

	return $self;
}

sub allow_login { 1 }
sub can_be_viewed { 1 }

sub render_title
{
	my( $self ) = @_;

	if( defined( my $user = $self->{session}->current_user ) )
	{
		return $self->html_phrase( "title:logged_in",
			user => $user->render_description,
		);
	}
	else
	{
		return $self->SUPER::render_title;
	}
}

sub render_action_link
{
	my( $self, %opts ) = @_;

	if( defined $self->{session}->current_user )
	{
		return $self->render_title;
	}
	else
	{
		my $link = $self->SUPER::render_action_link( %opts );
		my $uri = URI->new( $link->getAttribute( "href" ) );
		$uri->query( undef );
		$link->setAttribute( href => $uri );
		return $link;
	}
}

sub action_login
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};
	my $r = $repo->get_request;

	my $username = $self->{processor}->{username};

	return if !defined $username;

	my $user = $repo->user_by_username( $username );
	if( !defined $user )
	{
		$processor->add_message( "error", $repo->html_phrase( "cgi/login:failed" ) );
		return;
	}

	$self->{processor}->{user} = $user;

	my $url = $repo->get_url( host=>1 );
	$url .= "?login_params=".URI::Escape::uri_escape( $repo->param("login_params") );
	$url .= "&login_check=1";
	# always set a new random cookie value when we login
	my @a = ();
	srand;
	for(1..16) { push @a, sprintf( "%02X",int rand 256 ); }
	my $code = join( "", @a );
	$repo->login( $user,$code );
	my $cookie = $repo->{query}->cookie(
		-name    => "eprints_session",
		-path    => "/",
		-value   => $code,
		-domain  => $repo->get_conf("cookie_domain"),
	);			
	$r->err_headers_out->add('Set-Cookie' => $cookie);
	$repo->redirect( $url );
	exit(0);
}

sub render
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};
	my $r = $repo->get_request;

	$r->status( 401 );
	$r->custom_response( 401, '' ); # disable the normal error document

	my $page = $repo->make_doc_fragment;

	my @tabs = map { $_->{screen} } $self->list_items( "login_tabs" );

	my $show = $self->{processor}->{show};
	$show = '' if !defined $show;
	my $current = 0;
	for($current = 0; $current < @tabs; ++$current)
	{
		last if $tabs[$current]->get_subtype eq $show;
	}
	$current = 0 if $current == @tabs;

	if( @tabs == 1 )
	{
		$page->appendChild( $tabs[0]->render_login_form );
	}
	elsif( @tabs )
	{
		$page->appendChild( $repo->xhtml->tabs(
			[map { $_->render_title } @tabs],
			[map { $_->render_login_form } @tabs],
			current => $current
			) );
	}


	my @tools = map { $_->{screen} } $self->list_items( "login_tools" );

	my $div = $repo->make_element( "div", class => "ep_block" );

	my $internal;
	foreach my $tool ( @tools )
	{
		$div->appendChild( $tool->render_action_link );
	}
	$page->appendChild( $div );


	return $page;
}

=item $xhtml = $login->render_login()

Render the form components to log in via this method e.g. username and password.

=cut

sub render_login_form
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	return $repo->make_doc_fragment;
}

sub hidden_bits
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my @params;

	push @params, screen => $self->get_subtype;

	my $login_params = $repo->param( "login_params" );
	if( !defined $login_params )
	{
		$login_params = $repo->get_request->args;
	}
	if( $login_params )
	{
		push @params, login_params => $login_params;
	}

	my $target = $repo->param( "target" );
	if( $target )
	{
		push @params, target => $target;
	}

	return @params;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $frag = $repo->make_doc_fragment;

	my @params = $self->hidden_bits;
	while(@params)
	{
		$frag->appendChild( $repo->render_hidden_field( splice(@params,0,2) ) );
	}

	return $frag;
}

1;
