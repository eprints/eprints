
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
	my $username = $session->param( "login_username" );
	my $password = $session->param( "login_password" );

	if( defined $username )
	{
		if( $session->valid_login( $username, $password ) )
		{
			my $user = EPrints::DataObj::User::user_with_username( $session, $username );
			$session->login( $user );

			my $loginparams = $session->param("loginparams");

			my $c = $r->connection;

			$c->notes->set( loginparams=>$loginparams );

			# Declined to render the HTML, not declined the
			# request.
			return DECLINED;
		}

		$problems = $session->html_phrase( "cgi/login:failed" );
	}

	my $page=$session->make_doc_fragment();
	$page->appendChild( input_form( $session, $problems ) );

        my $cookie = EPrints::Apache::AnApache::cookie( $r, "eprints_session" );
	my %opts = ();

	# always set a new random cookie value when we render the login form.
	my @a = ();
	srand;
	for(1..16) { push @a, sprintf( "%02X",int rand 256 ); }
	$opts{code} = join( "", @a );

	my $title = $session->html_phrase( "cgi/login:title" );
	$session->build_page( $title, $page, "login" );
	$session->send_page( %opts );
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

	my $loginparams = $session->param( "loginparams" );

	if( !defined $loginparams )
	{
		my @p = $session->param;
		my @k = ();
		foreach my $p ( @p )
		{
			my $v = $session->param( $p );
			$v =~ s/([^A-Z0-9])/sprintf( "%%%02X", ord($1) )/ieg;
			push @k, $p."=".$v;
		}
		$loginparams = join( "&", @k );
	}
	$form->appendChild( $session->render_hidden_field( "loginparams", $loginparams ));

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
