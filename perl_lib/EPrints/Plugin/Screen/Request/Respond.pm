
package EPrints::Plugin::Screen::Request::Respond;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ confirm /];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	# Need valid requestid
	$self->{processor}->{requestid} = $self->{handle}->param( "requestid" );
	$self->{processor}->{request} = new EPrints::DataObj::Request( $self->{handle}, $self->{processor}->{requestid} );
	if( !defined $self->{processor}->{request} )
	{
		&_properties_error;
		return;
	}

	$self->{processor}->{document} = EPrints::DataObj::Document->new(
				$self->{handle}, $self->{processor}->{request}->get_value( "docid" ) );

	$self->{processor}->{eprint} = EPrints::DataObj::EPrint->new(
				$self->{handle}, $self->{processor}->{request}->get_value( "eprintid" ) );

	$self->{processor}->{contact} = EPrints::DataObj::User->new(
				$self->{handle}, $self->{processor}->{request}->get_value( "userid" ) );

	# Need valid document, eprint and contact
	if( !defined $self->{processor}->{document} ||
		!defined $self->{processor}->{eprint} ||
		!defined $self->{processor}->{contact} )
	{
		&_properties_error;
		return;
	}

	$self->{processor}->{response_sent} = $self->{handle}->param( "response_sent" );
	$self->{processor}->{actionid} = $self->{handle}->param( "action" );

	$self->SUPER::properties_from;

}

sub _properties_error
{
	my( $self ) = @_;
	
	$self->{processor}->{screenid} = "Error";
	$self->{processor}->add_message( "error", $self->{handle}->html_phrase( "general:bad_param" ) );
}

sub can_be_viewed
{
	my( $self ) = @_;

	# Only the contact user (ie. user listed as contact email at time of request) can process it
	return $self->{processor}->{contact}->get_id == $self->{processor}->{user}->get_id;
}

sub allow_confirm
{
	return 1;
}

sub action_confirm
{
	my( $self ) = @_;

	my $handle = $self->{handle};

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};

	my $email = $self->{processor}->{request}->get_value( "requester_email" );

	my $action = $handle->param("action");
	$action = "reject" if !defined $action || $action ne "accept";
	# Requested document has been made OA in the meantime
	$action = "oa" if $self->{processor}->{document}->is_public;

	my $subject = $handle->phrase( 
		"request/response_email:subject", 
		eprint => $eprint->get_value( "title" ) );

	my $mail = $handle->make_element( "mail" );
	my $reason = $handle->param( "reason" );
	$mail->appendChild( $handle->html_phrase(
		"request/response_email:body_$action",
		eprint => $eprint->render_citation_link,
		document => $doc->render_value( "main" ),
		reason => EPrints::Utils::is_set( $reason ) ? $handle->make_text( $reason )
			: $handle->html_phrase( "Plugin/Screen/EPrint/RequestRemoval:reason" ) ) );

	my $result;
	if( $action eq "accept")
	{
		# Send acceptance notice with requested document attached
		my @paths;
		my %files = $doc->files;
		for( keys %files )
		{
			push @paths, $doc->local_path . "/" . $_;
		}
	
		# Make document OA if flag set
		if( defined $handle->param( "oa" ) && $handle->param( "oa" ) eq "on" )
		{
			$doc->set_value( "security", "public" );
			$doc->commit;
			$eprint->commit;
			$eprint->generate_static;
		}

		$result = EPrints::Email::send_mail(
			handle => $handle,
			langid => $handle->get_langid,
			to_email => $email,
			subject => $subject,
			message => $mail,
			sig => $handle->html_phrase( "mail_sig" ),
			attach => \@paths,
		);
	}
	else
	{
		# Send rejection notice
		$result = EPrints::Email::send_mail(
			handle => $handle,
			langid => $handle->get_langid,
			to_email => $email,
			subject => $subject,
			message => $mail,
			sig => $handle->html_phrase( "mail_sig" ),
		);
	}
	
	# Log response event
	my $history_ds = $handle->get_repository->get_dataset( "history" );
	my $user = $self->{processor}->{contact};
	$history_ds->create_object(
		$handle,
		{
			userid =>$user->get_id,
			actor=>EPrints::Utils::tree_to_utf8( $user->render_description ),
			datasetid=>"request",
			objectid=>$self->{processor}->{request}->get_id,
			action=> "$action\_request",
			details=>EPrints::Utils::is_set( $reason ) ? $reason : undef,
		}
	);

	if( !$result )
	{
		$self->{processor}->add_message( "error", $self->{handle}->html_phrase(
			"general:email_failed" ) );
		return;
	}

	$self->{processor}->add_message( "message", $self->{handle}->html_phrase( "request/response:ack_page" ) );
	$self->{processor}->{response_sent} = 1;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $url = $self->SUPER::redirect_to_me_url;
	if( defined $self->{processor}->{requestid} )
	{
		$url.="&requestid=".$self->{processor}->{requestid};
	}
	if( defined $self->{processor}->{actionid} )
	{
		$url.="&action=".$self->{processor}->{actionid};
	}
	if( defined $self->{processor}->{response_sent} )
	{
		$url.="&response_sent=".$self->{processor}->{response_sent};
	}
	return $url;
}

sub render
{
	my( $self ) = @_;

	my $handle = $self->{handle};

	my $page = $handle->make_doc_fragment();
	return $page if $self->{processor}->{response_sent};

	my $email = $self->{processor}->{request}->get_value( "email" );

	my $action = $handle->param("action");
	$action = "reject" if !defined $action || $action ne "accept";
	# Requested document has been made OA in the meantime
	$action = "oa" if $self->{processor}->{document}->is_public;

	$page->appendChild( $handle->html_phrase(
		"request/respond_page:$action",
		eprint => $self->{processor}->{eprint}->render_citation_link,
		document => $self->render_document,
	) );

	my $form =  $handle->render_form( "post" );
	$page->appendChild( $form );
	
	if( $action eq "reject" )
	{
		my $textarea = $handle->make_element( "textarea", 
			name => "reason",
			rows => 5,
			cols => 60,
			wrap => "virtual",
		);
		$form->appendChild( $textarea );
	}

	if( $action eq "accept" )
	{
		my $p = $handle->make_element( "p" );
		$form->appendChild( $p );
		my $label = $handle->make_element( "label" );
		my $cb = $handle->make_element( "input", type => "checkbox", name => "oa" );
		$label->appendChild( $cb );
		$label->appendChild( $handle->make_text( " " ));
		$label->appendChild( $handle->html_phrase(
			"request/respond_page:fieldname_oa" ) );
		$p->appendChild( $label );
	}

	$form->appendChild( $handle->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$form->appendChild( $handle->render_hidden_field( "requestid", $self->{processor}->{request}->get_id ) );
	$form->appendChild( $handle->render_hidden_field( "action", $action ) );

	$form->appendChild( $handle->make_element( "br" ) );
	$form->appendChild( $handle->render_action_buttons( confirm => $handle->phrase( "request/respond_page:action_respond" ) ) );

	return $page;

}

sub render_document
{
	my( $self ) = @_;

	my $handle = $self->{handle};
	my $doc = $self->{processor}->{document};

	my( $doctable, $doctr, $doctd );
	$doctable = $handle->make_element( "table" );
	$doctr = $handle->make_element( "tr" );
	
	$doctd = $handle->make_element( "td" );
	$doctr->appendChild( $doctd );
	$doctd->appendChild( $doc->render_icon_link );
	
	$doctd = $handle->make_element( "td" );
	$doctr->appendChild( $doctd );
	$doctd->appendChild( $doc->render_citation_link() );
	my %files = $doc->files;
	if( defined $files{$doc->get_main} )
	{
		my $size = $files{$doc->get_main};
		$doctd->appendChild( $handle->make_element( 'br' ) );
		$doctd->appendChild( $handle->make_text( EPrints::Utils::human_filesize($size) ));
	}

	$doctable->appendChild( $doctr );

	return $doctable;
}

1;
