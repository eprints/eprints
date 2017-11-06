=head1 NAME

EPrints::Plugin::Screen::Public::RequestCopy

=cut

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

	$self->{processor}->{dataset} = $self->{repository}->dataset( "request" );
	$self->{processor}->{dataobj} = $self->{processor}->{dataset}->make_dataobj( {
			eprintid => $self->{processor}->{eprintid},
			docid => $self->{processor}->{docid},
			email => $self->{processor}->{contact_email},
		} );

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

	my $request = $self->{processor}->{dataobj};

	my $rc = $self->workflow->update_from_form( $self->{processor} );
	return if !$rc; # validation failed

	my $email = $request->value( "requester_email" );

	my $use_pin_security = $session->config( 'use_request_copy_pin_security' );

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};
	my $contact_email = $self->{processor}->{contact_email};

	my $user = EPrints::DataObj::User::user_with_email( $session, $contact_email );
	if( defined $user )
	{
		$request->set_value( "userid", $user->id );
	}

	$request = $self->{processor}->{dataset}->create_dataobj( $request->get_data );

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
	my $history_ds = $session->dataset( "history" );
	$history_ds->create_object( $session, $history_data );

	# Send request email
	my $subject = $session->phrase( "request/request_email:subject", eprint => $eprint->get_value( "title" ) );
	my $mail = $session->make_element( "mail" );
	$mail->appendChild( $session->html_phrase(
		"request/request_email:body", 
		eprint => $eprint->render_citation_link_staff,
		document => defined $doc ? $doc->render_value( "main" ) : $session->make_doc_fragment,
		requester => $request->render_citation( "requester" ),
		reason => $request->is_set( "reason" ) ? $request->render_value( "reason" )
			: $session->html_phrase( "Plugin/Screen/EPrint/RequestRemoval:reason" ) ) );

	my $result;
	if( ( defined $user || $use_pin_security ) && defined $doc )
	{
		# Contact is a registered user or it doesn't matter
		# because we're using the pin security model, and
		# EPrints holds the requested document

		# Send email to contact with accept/reject links

		my $url;
		if ( $use_pin_security )
		{
			# Handle the response via a non-authenticated CGI script
			$url = $session->get_url( host => 1, path => "cgi", "respond_to_doc_request" );
			$url->query_form(
					pin => $request->get_value( 'pin' ),
				);
		}
		else
		{
			# Handle the response via cgi/users/home which is authenticated
			$url = $session->get_url( host => 1, path => "cgi", "users/home" );
			$url->query_form(
					screen => "Request::Respond",
					requestid => $request->id,
				);
		}

		$mail->appendChild( $session->html_phrase( "request/request_email:links",
			accept => $session->render_link( "$url&action=accept" ),
			reject => $session->render_link( "$url&action=reject" ) ) );

		my $to_name;
		if ( defined $user )
		{
			$to_name = EPrints::Utils::tree_to_utf8( $user->render_description );
		}
		else
		{
			$to_name = $contact_email;
		}

		$result = EPrints::Email::send_mail(
			session => $session,
			langid => $session->get_langid,
			to_name => $to_name,
			to_email => $contact_email,
			subject => $subject,
			message => $mail,
			sig => $session->html_phrase( "mail_sig" ),
			cc_list => EPrints::Utils::is_set( $session->config( "request_copy_cc" ) ) ? $session->config( "request_copy_cc" ) : [],
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
			cc_list => EPrints::Utils::is_set( $session->config( "request_copy_cc" ) ) ? $session->config( "request_copy_cc" ) : [],
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

sub workflow
{
	my( $self ) = @_;

	return $self->{processor}->{workflow} ||= EPrints::Workflow->new(
			$self->{repository},
			"default",
			item => $self->{processor}->{dataobj},
			eprint => $self->{processor}->{eprint},
			document => $self->{processor}->{document},
		);
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $page = $session->make_doc_fragment();
	return $page if $self->{processor}->{request_sent};

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};

	my $form = $self->render_form;
	$page->appendChild( $form );

	$form->appendChild( $session->render_hidden_field( "eprintid", $eprint->get_id ) );
	$form->appendChild( $session->render_hidden_field( "docid", $doc->get_id ) ) if defined $doc;

	$form->appendChild( $self->workflow->render );

	$form->appendChild( $session->xhtml->action_button(
			request => $session->phrase( "request:button" )
		) );

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

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

