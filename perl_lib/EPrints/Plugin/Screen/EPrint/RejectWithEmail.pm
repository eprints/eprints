package EPrints::Plugin::Screen::EPrint::RejectWithEmail;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_bounce.png";
	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 200,
		},
		{
			place => "eprint_actions_editor_buffer", 
			position => 200,
		},
		{
			place => "eprint_review_actions",
			position => 300,
		},
	];

	$self->{actions} = [qw/ send cancel /];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->obtain_eprint_lock;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};
	return 0 unless $self->could_obtain_eprint_lock;
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

	my $eprint = $self->{processor}->{eprint};
	my $user = $eprint->get_user();
	# We can't bounce it if there's no user associated 

	if( !defined $user )
	{
		$self->{handle}->render_error( 
			$self->{handle}->html_phrase( 
				"cgi/users/edit_eprint:no_user" ),
			"error" );
		return;
	}

	my $page = $self->{handle}->make_doc_fragment();

	$page->appendChild( 
		$self->{handle}->html_phrase( 
			"cgi/users/edit_eprint:reject_form_intro" ) );
		
	if( $user->is_set( "lang" ) )
	{
		$page->appendChild( 
			$self->{handle}->html_phrase(
				"cgi/users/edit_eprint:author_lang_pref", 
				langpref => $user->render_value( "lang" ) ) );
	}

	my $form = $self->render_form;
	
	$page->appendChild( $form );

	my $reason = $self->{handle}->make_doc_fragment;
	my $reason_static = $self->{handle}->make_element( "div", id=>"ep_mail_reason_fixed",class=>"ep_only_js" );
	$reason_static->appendChild( $self->{handle}->html_phrase( "mail_bounce_reason" ) );
	$reason_static->appendChild( $self->{handle}->make_text( " " ));	
	
	my $edit_link_a = $self->{handle}->make_element( "a", href=>"#", onclick => "EPJS_blur(event); EPJS_toggle('ep_mail_reason_fixed',true,'block');EPJS_toggle('ep_mail_reason_edit',false,'block');\$('ep_mail_reason_edit').focus(); \$('ep_mail_reason_edit').select(); return false", );
	$reason_static->appendChild( $self->{handle}->html_phrase( "mail_edit_click",
		edit_link => $edit_link_a ) ); 
	$reason->appendChild( $reason_static );
	
	my $div = $self->{handle}->make_element( "div", class => "ep_form_field_input" );

	my $textarea = $self->{handle}->make_element(
		"textarea",
		id => "ep_mail_reason_edit",
		class => "ep_no_js",
		name => "reason",
		rows => 5,
		cols => 60,
		wrap => "virtual" );
	$textarea->appendChild( $self->{handle}->html_phrase( "mail_bounce_reason" ) ); 
	$reason->appendChild( $textarea );


	# remove any markup:
	my $title = $self->{handle}->make_text( 
		EPrints::Utils::tree_to_utf8( 
			$eprint->render_description() ) );

	my $eprintid = $eprint->get_id;
	my $home = $self->{handle}->get_repository->get_conf( "userhome" );
	my $target = $home."?eprintid=$eprintid&screen=EPrint::View::Owner";	
	my $edit_link = $self->{handle}->render_link( $target );

	my $content = $self->{handle}->html_phrase(
		"mail_bounce_body",
		title => $title,
		reason => $reason,
		edit_link => $edit_link );

	my $body = $self->{handle}->html_phrase(
		"mail_body",
		content => $content );

	my $to_user = $user;
	my $from_user =$self->{handle}->current_user;

	my $subject = $self->{handle}->html_phrase( "cgi/users/edit_eprint:subject_bounce" );

	my $view = $self->{handle}->html_phrase(
		"mail_view",
		subject => $subject,
		to => $to_user->render_description,
		from => $from_user->render_description,
		body => $body );

	$div->appendChild( $view );
	
	$form->appendChild( $div );

	$form->appendChild( $self->{handle}->render_action_buttons(
		_class => "ep_form_button_bar",
		"send" => $self->{handle}->phrase( "priv:action/eprint/reject_with_email" ),
		"cancel" => $self->{handle}->phrase( "cgi/users/edit_eprint:action_cancel" ),
 	) );

	return( $page );
}	


sub action_send
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $user = $eprint->get_user();
	# We can't bounce it if there's no user associated 

	$self->{processor}->{screenid} = "EPrint::View";

	if( !$eprint->move_to_inbox )
	{
		$self->{processor}->add_message( 
			"error",
			$self->{handle}->html_phrase( 
				"cgi/users/edit_eprint:bord_fail" ) );
	}

	$self->{processor}->add_message( "message",
		$self->{handle}->html_phrase( 
			"cgi/users/edit_eprint:status_changed" ) );

	# Successfully transferred, mail the user with the reason

	my $title = $self->{handle}->make_text( 
		EPrints::Utils::tree_to_utf8( 
			$eprint->render_description() ) );
	
	my $eprintid = $eprint->get_id;
	my $home = $self->{handle}->get_repository->get_conf( "userhome" );
	my $target = $home."?eprintid=$eprintid&screen=EPrint::View::Owner";	
	my $edit_link = $self->{handle}->render_link( $target );

	my $content = $self->{handle}->html_phrase(
		"mail_bounce_body",
		title => $title,
		reason => $self->{handle}->make_text( 
			$self->{handle}->param( "reason" ) ),
		edit_link => $edit_link );

	my $mail_ok = $user->mail(
		"cgi/users/edit_eprint:subject_bounce",
		$content,
		$self->{handle}->current_user );
	
	if( !$mail_ok ) 
	{
		$self->{processor}->add_message( "warning",
			$self->{handle}->html_phrase( 
				"cgi/users/edit_eprint:mail_fail",
				username => $user->render_value( "username" ),
				email => $user->render_value( "email" ) ) );
		return;
	}

	$self->{processor}->add_message( "message",
		$self->{handle}->html_phrase( 
			"cgi/users/edit_eprint:mail_sent" ) );
	$eprint->log_mail_owner( $content );
}


1;
