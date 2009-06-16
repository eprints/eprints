package EPrints::Plugin::Screen::Admin::TestEmail;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ test_email /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions_system", 
			position => 1500, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/test_email" );
}

sub allow_test_email
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_test_email
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $email = $session->param( "requester_email" );

	unless( $email )
	{
		$self->{processor}->add_message( "error", $session->html_phrase( "request:no_email" ) );
		return;
	}

	my $mail = $session->make_element( "mail" );
	$mail->appendChild( $self->html_phrase( "test_mail" ));

	my $rc = EPrints::Email::send_mail(
		session => $session,
		langid => $session->get_langid,
		to_email => $email,
		subject => $self->phrase( "test_mail_subject" ),
		message => $mail,
		sig => $session->html_phrase( "mail_sig" )
	);

	if( !$rc )
	{
		$self->{processor}->add_message( "error", $session->html_phrase( "general:email_failed" ) );
	}
	else
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "mail_sent",
				requester => $session->make_text( $email )
			) );
	}
}	

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $session->make_doc_fragment;

	my $form = $session->render_input_form(
		fields => [
			$session->get_repository->get_dataset( "request" )->get_field( "requester_email" ),
		],
		show_names => 1,
		show_help => 1,
		buttons => { test_email => $self->phrase( "send" ) },
	);

	$html->appendChild( $form );
	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );

	return $html;
}


1;
