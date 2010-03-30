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

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

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

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	# problems is set by Apache::Login
	my $problems = $self->{processor}->{problems};

	my %bits;
	if( defined $problems )
	{
		$bits{problems} = $session->render_message( "error", $problems );
	}
	else
	{
		$bits{problems} = $session->make_doc_fragment;
	}

	$bits{input_username} = $session->render_input_field(
			class => "ep_form_text",
			id => "login_username",
			name => 'login_username' );

	$bits{input_password} = $session->render_input_field(
			class => "ep_form_text",
			name => 'login_password',
			type => "password" );

	$bits{login_button} = $session->render_button(
			name => '_action_login',
			value => "Login",
			class => 'ep_form_action_button', );

	my $op1;
	my $op2;

	$bits{log_in_until} = $session->make_element( "select", name=>"login_log_in_until" );
	$op1 = $session->make_element( "option", value=>"until_close", selected=>"selected" );
	$op1->appendChild( $session->html_phrase( "cgi/login:until_close" ) );
	$op2 = $session->make_element( "option", value=>"forever" );
	$op2->appendChild( $session->html_phrase( "cgi/login:forever" ) );
	$bits{log_in_until}->appendChild( $op1 );
	$bits{log_in_until}->appendChild( $op2 );
	
	$bits{bind_to_ip} = $session->make_element( "select", name=>"login_log_in_until" );
	$op1 = $session->make_element( "option", value=>"bind", selected=>"selected" );
	$op1->appendChild( $session->html_phrase( "cgi/login:bind" ) );
	$op2 = $session->make_element( "option", value=>"dont_bind" );
	$op2->appendChild( $session->html_phrase( "cgi/login:dont_bind" ) );
	$bits{bind_to_ip}->appendChild( $op1 );
	$bits{bind_to_ip}->appendChild( $op2 );

	my $reset_ok =  $session->get_repository->get_conf(
				"allow_reset_password");
	if( $reset_ok ) 
	{
		$bits{reset_link} = $session->html_phrase(
					"cgi/login:reset_link" );
	}
	else
	{
		$bits{reset_link} = $session->make_doc_fragment;
	}
	
	my $form = $session->render_form( "POST" );
	$form->appendChild( $session->html_phrase( "cgi/login:page_layout", %bits ) );

	my $login_params = $session->param( "login_params" );

	if( !defined $login_params )
	{
		my @p = $session->param;
		my @k = ();
		foreach my $p ( @p )
		{
			my $v = $session->param( $p );
			$v =~ s/([^A-Z0-9])/sprintf( "%%%02X", ord($1) )/ieg;
			push @k, $p."=".$v;
		}
		$login_params = join( "&", @k );
	}
	$form->appendChild( $session->render_hidden_field( "login_params", $login_params ));

	my $target = $session->param( "target" );
	if( defined $target )
	{
		$form->appendChild( $session->render_hidden_field( "target", $target ));
	}

	my $script = $session->make_javascript( '$("login_username").focus()' );
	$form->appendChild( $script);

	return $form;
}

1;
