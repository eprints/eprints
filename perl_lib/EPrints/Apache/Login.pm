######################################################################
#
# EPrints::Apache::Login
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Apache::Login;

use strict;

use EPrints;
use EPrints::Apache::AnApache;

sub handler
{
	my( $r ) = @_;

	my $session = new EPrints::Session;
	my $problems;
	# ok then we need to get the cgi
	if( $session->param( "login_check" ) )
	{
		my $url = $session->get_url( host=>1 );
		my $login_params = $session->param("login_params");
		if( EPrints::Utils::is_set( $login_params ) ) { $url .= "?".$login_params; }
		if( defined $session->current_user )
		{
			$session->redirect( $url );
			return DONE;
		}

		$problems = $session->html_phrase( "cgi/login:no_cookies" );
	}

	my $username = $session->param( "login_username" );
	my $password = $session->param( "login_password" );
	if( defined $username )
	{
		if( $session->valid_login( $username, $password ) )
		{
			my $user = EPrints::DataObj::User::user_with_username( $session, $username );

			my $url = $session->get_url( host=>1 );
			my $login_params = $session->param("login_params");
			#if( EPrints::Utils::is_set( $login_params ) ) { $url .= "?".$login_params; }
			$url .= "?login_params=".EPrints::Utils::url_escape( $session->param("login_params") );
			$url .= "&login_check=1";

			# always set a new random cookie value when we login
			my @a = ();
			srand;
			my $r = $session->get_request;
			for(1..16) { push @a, sprintf( "%02X",int rand 256 ); }
			my $code = join( "", @a );
			$session->login( $user,$code );
			my $cookie = $session->{query}->cookie(
				-name    => "eprints_session",
				-path    => "/",
				-value   => $code,
				-domain  => $session->get_conf("cookie_domain"),
			);			
			$r->err_headers_out->add('Set-Cookie' => $cookie);
			$session->redirect( $url );
			return DONE;
		}

		$problems = $session->html_phrase( "cgi/login:failed" );
	}

	my $page=$session->make_doc_fragment();
	$page->appendChild( input_form( $session, $problems ) );

	$r->status( 401 );
	$r->custom_response( 401, '' ); # disable the normal error document

	my $title = $session->html_phrase( "cgi/login:title" );
	$session->build_page( $title, $page, "login" );
	$session->send_page();
	$session->terminate;

	return DONE;
}


sub input_form
{
	my( $session, $problems ) = @_;

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
