package EPrints::Plugin::Screen::Public::RequestCopy;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	# submit is a null action
	$self->{actions} = [qw/ submit request /];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{docid} = $self->{session}->param( "docid" );
	$self->{processor}->{document} = new EPrints::DataObj::Document( $self->{session}, $self->{processor}->{docid} );

	# We need a valid docid or an eprintid if the eprint has no documents
	if( !defined $self->{processor}->{document} )
	{

		$self->{processor}->{eprintid} = $self->{session}->param( "eprintid" );
		$self->{processor}->{eprint} = new EPrints::DataObj::EPrint( $self->{session}, $self->{processor}->{eprintid} );

		if( !defined $self->{processor}->{eprint} ||
			$self->{processor}->{eprint}->get_value( "full_text_status" ) ne "none" )
		{
			&_properties_error;
			return;
		}
	}
	else
	{
		$self->{processor}->{eprint} = $self->{processor}->{document}->get_eprint;
		$self->{processor}->{eprintid} = $self->{processor}->{eprint}->get_id;
	}

	# Check requested document is not already OA
	if( defined $self->{processor}->{document} && $self->{processor}->{document}->is_public )
	{
		&_properties_error;
		return;
	}

	# Check that we have a contact email address for this eprint
	if( $self->{session}->get_repository->can_call( "email_for_doc_request" ) ) 
	{
		$self->{processor}->{contact_email} = $self->{session}->get_repository->call( 
			"email_for_doc_request", 
			$self->{session}, 
			$self->{processor}->{eprint} );
	}
	if( !defined $self->{processor}->{contact_email} )
	{
		&_properties_error;
		return;
	}

	$self->{processor}->{request_sent} = $self->{session}->param( "request_sent" );

	$self->SUPER::properties_from;

}

sub _properties_error
{
	my( $self ) = @_;
	
	$self->{processor}->{screenid} = "Error";
	$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
}

# submit is a null action
sub allow_submit { return 1; }
sub action_submit {}

sub allow_request
{
	return 1;
}

sub action_request
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $email = $session->param( "requester_email" );

	unless( defined $email && $email ne "" )
	{
		$self->{processor}->add_message( "error", $session->html_phrase( "request:no_email" ) );
		return;
	}

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};
	my $contact_email = $self->{processor}->{contact_email};

	# Create request object
	my $data = {};
	$data->{eprintid} = $eprint->get_id;
	$data->{docid} = $doc->get_id if defined $doc;
	$data->{requester_email} = $email;
	$data->{email} = $contact_email;

	my $user = EPrints::DataObj::User::user_with_email( $session, $contact_email );
	$data->{userid} = $user->get_id if defined $user;

	my $reason = $session->param( "reason" );
	$data->{reason} = $reason if EPrints::Utils::is_set( $reason );

	my $request = $session->get_repository->get_dataset( "request" )->create_object( $session, $data );

	my $history_data = {
		datasetid=>"request",
		objectid=>$request->get_id,
		action=>"create",
	};
	
	if( defined $self->{processor}->{user} )
	{
		$history_data->{userid} = $self->{processor}->{user}->get_id;
	}
	else
	{
		$history_data->{actor} = $email;
	}

	# Log request creation event
	my $history_ds = $session->get_repository->get_dataset( "history" );
	$history_ds->create_object( $session, $history_data );

	# Send request email
	my $subject = $session->phrase( "request/request_email:subject", eprint => $eprint->get_value( "title" ) );
	my $mail = $session->make_element( "mail" );
	$mail->appendChild( $session->html_phrase(
		"request/request_email:body", 
		eprint => $eprint->render_citation_link_staff,
		document => defined $doc ? $doc->render_value( "main" ) : $session->make_doc_fragment,
		requester => $session->make_text( $email ),
		reason => EPrints::Utils::is_set( $reason ) ? $session->make_text( $reason )
			: $session->html_phrase( "Plugin/Screen/EPrint/RequestRemoval:reason" ) ) );

	my $result;
	if( defined $user && defined $doc )
	{
		# Contact is registered user and EPrints holds requested document
		# Send email to contact with accept/reject links

		my $url =  $session->get_repository->get_conf( "http_cgiurl" ) .
			"/users/home?screen=Request::Respond&requestid=" . $request->get_id;

		$mail->appendChild( $session->html_phrase( "request/request_email:links",
			accept => $session->render_link( "$url&action=accept" ),
			reject => $session->render_link( "$url&action=reject" ) ) );

		$result = EPrints::Email::send_mail(
			session => $session,
			langid => $session->get_langid,
			to_name => EPrints::Utils::tree_to_utf8( $user->render_description ),
			to_email => $contact_email,
			subject => $subject,
			message => $mail,
			sig => $session->html_phrase( "mail_sig" ),
		);
	} 
	else
	{
		# Contact is non-registered user or EPrints holds no documents
		# Send email to contact with 'replyto'
		$result = EPrints::Email::send_mail(
			session => $session,
			langid => $session->get_langid,
			to_name => defined $user ? EPrints::Utils::tree_to_utf8( $user->render_description ) : "",
			to_email => $contact_email,
			subject => $subject,
			message => $mail,
			sig => $session->html_phrase( "mail_sig" ),
			replyto_email => $email,
		);
	}

	if( !$result )
	{
		$self->{processor}->add_message( "error", $session->html_phrase( "general:email_failed" ) );
		return;
	}
		
	# Send acknowledgement to requester
	$mail = $session->make_element( "mail" );
	$mail->appendChild( $session->html_phrase(
		"request/ack_email:body", 
		document => defined $doc ? $doc->render_value( "main" ) : $session->make_doc_fragment,
		eprint	=> $eprint->render_citation_link ) );

	$result = EPrints::Email::send_mail(
		session => $session,
		langid => $session->get_langid,
		to_email => $email,
		subject => $session->phrase( "request/ack_email:subject", eprint=>$eprint->get_value( "title" ) ), 
		message => $mail,
		sig => $session->html_phrase( "mail_sig" )
	);

	if( !$result )
	{
		$self->{processor}->add_message( "error", $session->html_phrase( "general:email_failed" ) );
		return;
	}
	
	$self->{processor}->add_message( "message", $session->html_phrase( "request/ack_page", link => $session->render_link( $eprint->get_url ) ) );
	$self->{processor}->{request_sent} = 1;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $url = $self->SUPER::redirect_to_me_url;
	if( defined $self->{processor}->{eprintid} )
	{
		$url.="&eprintid=".$self->{processor}->{eprintid};
	}
	if( defined $self->{processor}->{docid} )
	{
		$url.="&docid=".$self->{processor}->{docid};
	}
	if( defined $self->{processor}->{request_sent} )
	{
		$url.="&request_sent=".$self->{processor}->{request_sent};
	}
	return $url;
} 


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $page = $session->make_doc_fragment();
	return $page if $self->{processor}->{request_sent};

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};

	my $p = $session->make_element( "p" );
	$p->appendChild( $eprint->render_citation );
	$page->appendChild( $p );

	$page->appendChild( $self->render_document ) if defined $doc;

	my $form = $session->render_input_form(
		fields => [ 
			$session->get_repository->get_dataset( "request" )->get_field( "requester_email" ),
			$session->get_repository->get_dataset( "request" )->get_field( "reason" ),
		],
		show_names => 1,
		show_help => 1,
		buttons => { request => $session->phrase( "request:button" ) },
	);
	$page->appendChild( $form );

	$form->appendChild( $session->render_hidden_field( "eprintid", $eprint->get_id ) );
	$form->appendChild( $session->render_hidden_field( "docid", $doc->get_id ) ) if defined $doc;

	return $page;
}

sub render_document
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $doc = $self->{processor}->{document};

	my( $doctable, $doctr, $doctd );
	$doctable = $session->make_element( "table" );
	$doctr = $session->make_element( "tr" );
	
	$doctd = $session->make_element( "td" );
	$doctr->appendChild( $doctd );
	$doctd->appendChild( $doc->render_icon_link );
	
	$doctd = $session->make_element( "td" );
	$doctr->appendChild( $doctd );
	$doctd->appendChild( $doc->render_citation_link() );
	my %files = $doc->files;
	if( defined $files{$doc->get_main} )
	{
		my $size = $files{$doc->get_main};
		$doctd->appendChild( $session->make_element( 'br' ) );
		$doctd->appendChild( $session->make_text( EPrints::Utils::human_filesize($size) ));
	}

	$doctable->appendChild( $doctr );

	return $doctable;
}

1;
