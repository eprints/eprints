package EPrints::Plugin::Screen::EPrint::RejectWithEmail;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 200,
		}
	];

	$self->{actions} = [qw/ send cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};
	return 0 if( $self->{processor}->{eprint}->get_value( "eprint_status" ) eq "inbox" );
	return 0 if( !defined $self->{processor}->{eprint}->get_user );

	return $self->allow( "eprint/reject_with_email" );
}

sub allow_send
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";
}

sub render
{
	my( $self ) = @_;

	my $user = $self->{processor}->{eprint}->get_user();
	# We can't bounce it if there's no user associated 

	if( !defined $user )
	{
		$self->{session}->render_error( 
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:no_user" ),
			"error" );
		return;
	}

	my $page = $self->{session}->make_doc_fragment();

	$page->appendChild( 
		$self->{session}->html_phrase( 
			"cgi/users/edit_eprint:bounce_form_intro", 
			langpref => $user->render_value( "lang" ) ) );

	my $form = $self->render_form;
	
	$page->appendChild( $form );
	
	my $div = $self->{session}->make_element( "div", class => "ep_form_field_input" );

	my $textarea = $self->{session}->make_element(
		"textarea",
		name => "reason",
		rows => 20,
		cols => 60,
		wrap => "virtual" );

	# remove any markup:
	my $title = $self->{session}->make_text( 
		EPrints::Utils::tree_to_utf8( 
			$self->{processor}->{eprint}->render_description() ) );

	$textarea->appendChild( 
		$self->{session}->html_phrase( 
			"mail_bounce_reason", 
			title => $title ) );

	$div->appendChild( $textarea );

	$form->appendChild( $div );

	$form->appendChild( $self->{session}->render_action_buttons(
		"send" => $self->{session}->phrase( "priv:action/eprint/reject_with_email" ),
		"cancel" => $self->{session}->phrase( "cgi/users/edit_eprint:action_cancel" ),
 	) );

	return( $page );
}	


sub action_send
{
	my( $self ) = @_;

	my $user = $self->{processor}->{eprint}->get_user();
	# We can't bounce it if there's no user associated 

	$self->{processor}->{screenid} = "EPrint::View";

	if( !$self->{processor}->{eprint}->move_to_inbox )
	{
		$self->{processor}->add_message( 
			"error",
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:bord_fail" ) );
	}

	$self->{processor}->add_message( "message",
		$self->{session}->html_phrase( 
			"cgi/users/edit_eprint:status_changed" ) );

	# Successfully transferred, mail the user with the reason

	my $mail = $self->{session}->make_element( "mail" );
	$mail->appendChild( 
		$self->{session}->make_text( 
			$self->{session}->param( "reason" ) ) );

	my $mail_ok = $user->mail(
		"cgi/users/edit_eprint:subject_bounce",
		$mail,
		$self->{session}->current_user );
	
	if( !$mail_ok ) 
	{
		$self->{processor}->add_message( "warning",
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:mail_fail",
				username => $user->render_value( "username" ),
				email => $user->render_value( "email" ) ) );
		return;
	}

	$self->{processor}->add_message( "message",
		$self->{session}->html_phrase( 
			"cgi/users/edit_eprint:mail_sent" ) );
	$self->{processor}->{eprint}->log_mail_owner( $mail );
}


1;
