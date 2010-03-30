package EPrints::Plugin::Screen::EPrint::RequestRemoval;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_actions",
			position => 600,
		},
	];

	$self->{actions} = [qw/ send cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/request_removal" );
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

	my $page = $self->{session}->make_doc_fragment();
	
	$page->appendChild( $self->html_phrase( "intro" ) );

	my $form = $self->render_form;
	
	$page->appendChild( $form );
	
	my $reason = $self->{session}->make_doc_fragment;
	my $reason_static = $self->{session}->make_element( "div", id=>"ep_mail_reason_fixed",class=>"ep_only_js" );
	$reason_static->appendChild( $self->html_phrase( "reason" ) );
	$reason_static->appendChild( $self->{session}->make_text( " " ));	
	
	my $edit_link = $self->{session}->make_element( "a", href=>"#", onclick => "EPJS_blur(event); EPJS_toggle('ep_mail_reason_fixed',true,'block');EPJS_toggle('ep_mail_reason_edit',false,'block');\$('ep_mail_reason_edit').focus(); \$('ep_mail_reason_edit').select(); return false", );
	$reason_static->appendChild( $self->{session}->html_phrase( "mail_edit_click",
		edit_link => $edit_link ) ); 
	$reason->appendChild( $reason_static );
	

	my $div = $self->{session}->make_element( "div", class => "ep_form_field_input" );

	my $textarea = $self->{session}->make_element(
		"textarea",
		id => "ep_mail_reason_edit",
		class => "ep_no_js",
		name => "reason",
		rows => 5,
		cols => 60,
		wrap => "virtual" );
	$textarea->appendChild( $self->html_phrase( "reason" ) ); 
	$reason->appendChild( $textarea );

	# remove any markup:
	my $title = $self->{session}->make_text( 
		EPrints::Utils::tree_to_utf8( 
			$eprint->render_description() ) );
	
	my $from_user =$self->{session}->current_user;
	
	my $content = $self->html_phrase(
		"mail",
		user => $from_user->render_description,
		email => $self->{session}->make_text( $from_user->get_value( "email" )),
		citation => $self->{processor}->{eprint}->render_citation,
		url => $self->{session}->render_link(
				$self->{processor}->{eprint}->get_control_url ),
		reason => $reason );

	my $body = $self->{session}->html_phrase(
		"mail_body",
		content => $content );

	my $subject = $self->html_phrase( "subject" );

	my $view = $self->{session}->html_phrase(
		"mail_view",
		subject => $subject,
		to => $self->{session}->html_phrase( "archive_name" ),
		from => $from_user->render_description,
		body => $body );

	$div->appendChild( $view );
	
	$form->appendChild( $div );

	$form->appendChild( $self->{session}->render_action_buttons(
		_class => "ep_form_button_bar",
		"send" => $self->phrase( "action:send:title" ),
		"cancel" => $self->phrase( "action:cancel:title" ),
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


	# nb. Phrases in language of target not sender.

	my $ed = $eprint->get_editorial_contact;

	my $langid;
	if( defined $ed )
	{
		$langid = $ed->get_value( "lang" );
	}
	else
	{
		$langid = $self->{session}->get_conf( "defaultlanguage" );
	}
	my $lang = $self->{session}->get_language( $langid );

	my %mail;
	$mail{session} = $self->{session};
	$mail{langid} = $langid;
	$mail{subject} = EPrints::Utils::tree_to_utf8( $lang->phrase( 
		"Plugin/Screen/EPrint/RequestRemoval:subject",
		{},
		$self->{session} ) );
	$mail{sig} = $lang->phrase( 
		"mail_sig",
		{},
		$self->{session} );

	if( defined $ed )
	{
 		$mail{to_name} = EPrints::Utils::tree_to_utf8( $ed->render_description ),
 		$mail{to_email} = $ed->get_value( "email" );
	}
	else
	{
 		$mail{to_name} = EPrints::Utils::tree_to_utf8( $lang->phrase( 
			"lib/session:archive_admin",
			{},
			$self->{session} ) );
 		$mail{to_email} = $self->{session}->get_repository->get_conf( "adminemail" );
	}
	
	my $from_user = $self->{session}->current_user;
	$mail{from_name} = EPrints::Utils::tree_to_utf8( $from_user->render_description() );
	$mail{from_email} = $from_user->get_value( "email" );

	my $reason = $self->{session}->make_text( $self->{session}->param( "reason" ) );
	$mail{message} = $self->html_phrase(
		"mail",
		user => $from_user->render_description,
		email => $self->{session}->make_text( $from_user->get_value( "email" )),
		citation => $self->{processor}->{eprint}->render_citation,
		url => $self->{session}->render_link(
				$self->{processor}->{eprint}->get_control_url ),
		reason => $reason );

	my $mail_ok = EPrints::Email::send_mail( %mail );

	if( !$mail_ok ) 
	{
		$self->{processor}->add_message( "warning",
			$self->{session}->html_phrase( 
				"cgi/users/edit_eprint:mail_fail",
				username => $self->{session}->make_text( $mail{to_name} ),
				email => $self->{session}->make_text( $mail{to_email} ) ));
		return;
	}

	$self->{processor}->add_message( "message",
		$self->{session}->html_phrase( 
			"cgi/users/edit_eprint:mail_sent" ) );




	my $history_ds = $self->{session}->get_repository->get_dataset( "history" );

	$history_ds->create_object( 
		$self->{session},
		{
			userid=>$from_user->get_id,
			datasetid=>"eprint",
			objectid=>$eprint->get_id,
			revision=>$eprint->get_value( "rev_number" ),
			action=>"removal_request",
			details=> EPrints::Utils::tree_to_utf8( $mail{message} , 80 ),
		}
	);
}


1;
