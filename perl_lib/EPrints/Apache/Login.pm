
package EPrints::Apache::Login;

use strict;

use EPrints;
use EPrints::Apache::AnApache;

sub handler
{
	my( $r ) = @_;

	my $handle = new EPrints::Handle;
	my $problems;
	# ok then we need to get the cgi
	my $username = $handle->param( "login_username" );
	my $password = $handle->param( "login_password" );

	if( defined $username )
	{
		if( $handle->valid_login( $username, $password ) )
		{
			my $user = $handle->get_user_with_username( $username );
			$handle->login( $user );

			my $loginparams = $handle->param("loginparams");

			my $c = $r->connection;

			$c->notes->set( loginparams=>$loginparams );

			# Declined to render the HTML, not declined the
			# request.
			return DECLINED;
		}

		$problems = $handle->html_phrase( "cgi/login:failed" );
	}

	my $page=$handle->make_doc_fragment();
	$page->appendChild( input_form( $handle, $problems ) );

        my $cookie = EPrints::Apache::AnApache::cookie( $r, "eprints_session" );
	my %opts = ();

	# always set a new random cookie value when we render the login form.
	my @a = ();
	srand;
	for(1..16) { push @a, sprintf( "%02X",int rand 256 ); }
	$opts{code} = join( "", @a );

	my $title = $handle->html_phrase( "cgi/login:title" );
	$handle->prepare_page( { title=>$title, page=>$page }, page_id=>"login" );
	$handle->send_page( %opts );
	$handle->terminate;

	return DONE;

}


sub input_form
{
	my( $handle, $problems ) = @_;

	my %bits;
	if( defined $problems )
	{
		$bits{problems} = $handle->render_message( "error", $problems );
	}
	else
	{
		$bits{problems} = $handle->make_doc_fragment;
	}

	$bits{input_username} = $handle->render_input_field(
			class => "ep_form_text",
			id => "login_username",
			name => 'login_username' );

	$bits{input_password} = $handle->render_input_field(
			class => "ep_form_text",
			name => 'login_password',
			type => "password" );

	$bits{login_button} = $handle->render_button(
			name => '_action_login',
			value => "Login",
			class => 'ep_form_action_button', );

	my $op1;
	my $op2;

	$bits{log_in_until} = $handle->make_element( "select", name=>"login_log_in_until" );
	$op1 = $handle->make_element( "option", value=>"until_close", selected=>"selected" );
	$op1->appendChild( $handle->html_phrase( "cgi/login:until_close" ) );
	$op2 = $handle->make_element( "option", value=>"forever" );
	$op2->appendChild( $handle->html_phrase( "cgi/login:forever" ) );
	$bits{log_in_until}->appendChild( $op1 );
	$bits{log_in_until}->appendChild( $op2 );
	
	$bits{bind_to_ip} = $handle->make_element( "select", name=>"login_log_in_until" );
	$op1 = $handle->make_element( "option", value=>"bind", selected=>"selected" );
	$op1->appendChild( $handle->html_phrase( "cgi/login:bind" ) );
	$op2 = $handle->make_element( "option", value=>"dont_bind" );
	$op2->appendChild( $handle->html_phrase( "cgi/login:dont_bind" ) );
	$bits{bind_to_ip}->appendChild( $op1 );
	$bits{bind_to_ip}->appendChild( $op2 );

	my $reset_ok =  $handle->get_repository->get_conf(
				"allow_reset_password");
	if( $reset_ok ) 
	{
		$bits{reset_link} = $handle->html_phrase(
					"cgi/login:reset_link" );
	}
	else
	{
		$bits{reset_link} = $handle->make_doc_fragment;
	}
	
	my $form = $handle->render_form( "POST" );
	$form->appendChild( $handle->html_phrase( "cgi/login:page_layout", %bits ) );

	my $loginparams = $handle->param( "loginparams" );

	if( !defined $loginparams )
	{
		my @p = $handle->param;
		my @k = ();
		foreach my $p ( @p )
		{
			my $v = $handle->param( $p );
			$v =~ s/([^A-Z0-9])/sprintf( "%%%02X", ord($1) )/ieg;
			push @k, $p."=".$v;
		}
		$loginparams = join( "&", @k );
	}
	$form->appendChild( $handle->render_hidden_field( "loginparams", $loginparams ));

	my $target = $handle->param( "target" );
	if( defined $target )
	{
		$form->appendChild( $handle->render_hidden_field( "target", $target ));
	}

	my $script = $handle->make_javascript( '$("login_username").focus()' );
	$form->appendChild( $script);

	return $form;
}

1;
