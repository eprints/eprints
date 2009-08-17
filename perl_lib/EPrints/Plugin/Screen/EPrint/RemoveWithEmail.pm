package EPrints::Plugin::Screen::EPrint::RemoveWithEmail;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_reject.png";
	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 300,
		},
		{
			place => "eprint_actions_editor_buffer", 
			position => 200,
		},
		{
			place => "eprint_review_actions",
			position => 400,
		},
	];

	$self->{actions} = [qw/ send cancel /];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->{processor}->{eprint}->obtain_lock( $self->{handle}->current_user );
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless defined $self->{processor}->{eprint};
	return 0 if( !defined $self->{processor}->{eprint}->get_user );
	return 0 unless $self->could_obtain_eprint_lock;

	return $self->allow( "eprint/remove_with_email" );
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
			"cgi/users/edit_eprint:remove_form_intro" ) );

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
	
	my $edit_link = $self->{handle}->make_element( "a", href=>"#", onclick => "EPJS_blur(event); EPJS_toggle('ep_mail_reason_fixed',true,'block');EPJS_toggle('ep_mail_reason_edit',false,'block');\$('ep_mail_reason_edit').focus(); \$('ep_mail_reason_edit').select(); return false", );
	$reason_static->appendChild( $self->{handle}->html_phrase( "mail_edit_click",
		edit_link => $edit_link ) ); 
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
	
	my $phraseid;
	if( $eprint->get_dataset->id eq "inbox" )
	{
		$phraseid = "mail_delete_body.inbox";
	}
	else
	{
		$phraseid = "mail_delete_body";
	}
	
	my $content = $self->{handle}->html_phrase(
		$phraseid,	
		title => $title,
		reason => $reason );

	my $body = $self->{handle}->html_phrase(
		"mail_body",
		content => $content );

	my $to_user = $eprint->get_user();
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
		"send" => $self->{handle}->phrase( "priv:action/eprint/remove_with_email" ),
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

	$self->{processor}->{screenid} = "Review";

	if( !$eprint->remove )
	{
		my $db_error = $self->{handle}->get_database->error;
		$self->{handle}->get_repository->log( "DB error removing EPrint ".$eprint->get_value( "eprintid" ).": $db_error" );
		$self->{processor}->add_message( "message", $self->html_phrase( "item_not_removed" ) );
		$self->{processor}->{screenid} = "FirstTool";
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) ); 
	
	# Successfully removed, mail the user with the reason

	my $title = $self->{handle}->make_text( 
		EPrints::Utils::tree_to_utf8( 
			$eprint->render_description() ) );
	
	my $content = $self->{handle}->html_phrase( 
		"mail_delete_body",
		title => $title, 
		reason => $self->{handle}->make_text( 
			$self->{handle}->param( "reason" ) ) );

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
