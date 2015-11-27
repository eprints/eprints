=head1 NAME

EPrints::Plugin::Screen::Register

=cut

package EPrints::Plugin::Screen::Register;

# User registration

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
# See cfg.d/dynamic_template.pl
#		{
#			place => "key_tools",
#			position => 100,
#		},
	];
	$self->{actions} = [qw( register confirm )];

	return $self;
}

sub allow_register { shift->{session}->config( "allow_web_signup" ) }

sub allow_confirm { shift->{session}->config( "allow_reset_password" ) }

sub can_be_viewed
{
	my( $self ) = @_;

	return
		( $self->{session}->config( 'allow_reset_password' ) || $self->{session}->config( "allow_web_signup" ) ) &&
		!defined $self->{session}->current_user;
}

sub from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};

	# dummy item used to produce a workflow
	$processor->{item} = $repo->dataset( "user" )->make_dataobj( {} );

	$processor->{dataset} = $repo->dataset( "user" );

	# default to showing whatever the previous attempted registration method
	# was
	$processor->{show} = $self->get_subtype;

	my $signup_style = $repo->config( "signup_style" );
	$processor->{min} = defined $signup_style && $signup_style eq "minimal";

	$self->SUPER::from();
}

sub render_action_link
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $link = $repo->xml->create_element( "a",
		href => $repo->config( "http_cgiroot" ) . "/register"
	);
	$link->appendChild( $self->render_title );

	return $link;
}

sub action_register
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	$processor->{screenid} = 'Register';

	my $workflow = $self->workflow;

	$workflow->update_from_form( $processor, $workflow->get_stage_id, 1 );

	my @problems = $workflow->validate;
	if( @problems )
	{
		$processor->add_message( "error", $self->render_problems( @problems ) );
		return;
	}

	return 1;
}

sub action_confirm
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	my $user_ds = $repo->get_dataset( "user" );

	# Process the form.
	my $userid = $repo->param( "userid" )+0;
	my $pin = $repo->param( "pin" );

	my $user = new EPrints::DataObj::User( $repo, $userid );

	if( !defined $user )
	{
		$processor->add_message( "error", $repo->html_phrase( "cgi/confirm:bad_user" ) );
		$processor->{screenid} = "Error";
		return;
	}

	my $userpin = $user->get_value( "pin" );
	my $pinsettime = $user->get_value( "pinsettime" );
	my $delta = (time - $pinsettime);

	if( !defined $userpin )
	{
		$processor->add_message( "error", $repo->html_phrase( "cgi/confirm:no_pin" ) );
		$processor->{screenid} = "Error";
		return;
	}
	if( $userpin ne $pin)
	{
		$processor->add_message( "error", $repo->html_phrase( "cgi/confirm:pin_mismatch" ) );
		$processor->{screenid} = "Error";
		return;
	}
	my $maxdelta = $repo->config( "pin_timeout" );
	if( ( $maxdelta != 0 ) && ( $maxdelta * 60 * 60 < $delta ) )
	{
		$processor->add_message( "error", $repo->html_phrase( "cgi/confirm:pin_timeout" ) );
		$processor->{screenid} = "Error";
		return;
	}

	$processor->{user} = $user;

	# Only ONE of these should be set, as the two set_* scripts should zero the
	# other value when they set theirs.

	# This script hacks the SQL directly, as normally "secret" fields are not
	# accessible to eprints.
	
	if( $user->is_set( "newemail" ) )
	{
		$processor->{newemail} = $user->value( "newemail" );
		# check no one else has this email! cjg
		$user->set_value( "email", $user->get_value( "newemail" ) );
		$user->set_value( "newemail", undef );
		$user->set_value( "pin", undef );
		if( $user->has_priv( "lock-username-to-email" ) )# cjg change to new system
		{
			# shim the username in the current user object
			$user->set_value( "username", $user->get_value( "email" ) );
		}
		# write the changes
		$user->commit();
	} 
	else
	{
		# Must be password then. Can't see it 'cus it's a "secret".
		$repo->get_database->_update_quoted(
			$user_ds->get_sql_table_name,
			["userid"],
			[$repo->get_database->quote_value($userid)],
			["password","newpassword","pin"],
			[$repo->get_database->quote_identifier("newpassword"),"NULL","NULL"],
		);
		# Create a login ticket and log the user in
		EPrints::DataObj::LoginTicket->expire_all( $repo );
		$repo->dataset( "loginticket" )->create_dataobj({
			userid => $user->id,
		})->set_cookies();
	}
}

sub workflow
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	return EPrints::Workflow->new( $repo, "register",
		processor => $processor,
		item => $processor->{item},
		method => [ $self->get_subtype, "STRING" ],
	);
}

# this method is just a utility for sub-classes
sub render_workflow
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};

	my $form = $repo->render_form( "POST" );
	$form->appendChild( $self->render_hidden_bits );

	# avoid getting the 'stage' hidden input
	my $workflow = $self->workflow;
	my $stage = $workflow->get_stage( $workflow->get_first_stage_id );

	$form->appendChild( $stage->render( $repo, $workflow ) );

	$form->appendChild( $repo->render_hidden_field( "_default_action", "register" ) );
	$form->appendChild( $repo->render_action_buttons(
		register => $repo->phrase( "cgi/register:action_submit" )
		) );

	return $form;
}

sub render
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};
	my $xml = $repo->xml;

	# catch infinite recursion on tab rendering
	return $xml->create_document_fragment if ref($self) ne __PACKAGE__;

	my $page = $xml->create_document_fragment;
	
	my $user = $processor->{user};

	my $action = $processor->{action};
	$action = "" if !defined $action;

	# Reset password

	if( $repo->config( "allow_reset_password" ) && $action eq "confirm" )
	{
		return $page unless( defined $user );
		
		if( $processor->{newemail} )
		{
			$page->appendChild( $repo->html_phrase( 
				"cgi/confirm:set_email",
				newemail=>$repo->make_text( $processor->{newemail} ) ) );
		}
		else
		{
			$page->appendChild( $repo->html_phrase( "cgi/confirm:set_password" ) );
		}

		$page->appendChild( $repo->html_phrase( "cgi/confirm:username",
			username => $user->render_value( "username" ) ) );

		$page->appendChild( $repo->html_phrase( "cgi/confirm:go_login" ) );

		return $page;
	}

	# Registration

	if( !$repo->config("allow_web_signup") )
	{
		return $repo->render_message( "error", $repo->html_phrase( "cgi/register:no_web_signup" ) );
	}

	if( $action eq "register" && defined $user )
	{
		if( $user->is_set( "newpassword" ) || $user->is_set( "newemail" ) )
		{
			$page->appendChild( $repo->html_phrase( 
				"cgi/register:created_new_user",
					email=>$user->render_value( "email" ),
					username=>$user->render_value( "username" ) ) );
		}
		else
		{
			$self->EPrints::Plugin::Screen::Login::finished(
				$repo->current_url( host => 1, path => "cgi", "users/home" )
				);
		}
	}
	else
	{
		if( $processor->{min} )
		{
			$page->appendChild( $repo->html_phrase( "cgi/register:intro_minimal" ) );
		}
		else
		{
			$page->appendChild( $repo->html_phrase( "cgi/register:intro" ) );
		}

		$page->appendChild( $self->make_reg_form() );
	}
		
	return $page;
}

sub make_reg_form
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $page = $repo->make_doc_fragment;

	my @tools = map { $_->{screen} } $self->list_items( 'register_tools' );

	my $div = $repo->make_element( "div", class => "ep_login_tools", style => "text-align: right" );

	my $internal;
	foreach my $tool ( @tools )
	{
		$div->appendChild( $tool->render_action_link );
	}
	$page->appendChild( $div );


	my @tabs = map { $_->{screen} } $self->list_items( 'register_tabs' );

	my $show = $self->{processor}->{show};
	$show = '' if !defined $show;
	my $current = 0;
	for($current = 0; $current < @tabs; ++$current)
	{
		last if $tabs[$current]->get_subtype eq $show;
	}
	$current = 0 if $current == @tabs;

	return $tabs[0]->render if @tabs == 1;
	if( @tabs == 1 )
	{
		$page->appendChild( $tabs[0]->render );
	}
	elsif( @tabs )
	{
		$page->appendChild( $repo->xhtml->tabs(
			[map { $_->render_title } @tabs],
			[map { $_->render } @tabs],
			current => $current
			) );
	}

	return $page;
}

=item $user = $register->register_user( $epdata )

Create a user account using $epdata augmented with any form field values defined by this module.

Sends a confirmation email for either the new password or new email address.

If the email can't be sent returns undef.

=cut

sub register_user
{
	my( $self, $epdata ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{repository};
	my $dataset = $repo->dataset( "user" );

	my $pin = sprintf( "%04X%04X%04X%04X",int rand 0xffff,int rand 0xffff,int rand 0xffff,int rand 0xffff );
	$epdata->{usertype} ||= $repo->config( "default_user_type" );
	$epdata->{pin} = $pin;
	$epdata->{pinsettime} = time();

	my $user = $dataset->create_object( $repo, $epdata );

	my $maxdelta = EPrints::Time::human_delay( $repo->config( "pin_timeout" ) );

	# If email fails then we should abort
	my $rc;
	
	if( $user->is_set( "newpassword" ) )
	{
		$rc = $user->mail( 
			"cgi/register:account",
			$repo->html_phrase( 
				"mail_password_pin", 
				confirmurl => $repo->render_link( $repo->config( "perl_url" )."/confirm?userid=".$user->value( "userid" )."&pin=".$user->value( "pin" ) ),
				username => $user->render_value( "username" ),
				maxdelta => $repo->make_text( $maxdelta ) ) );
	}
	elsif( $user->is_set( "newemail" ) )
	{
		$rc = $user->mail( 
			"cgi/register:account",
			$repo->html_phrase( 
				"mail_email_pin", 
				confirmurl => $repo->render_link( $repo->config( "perl_url" )."/confirm?userid=".$user->value( "userid" )."&pin=".$user->value( "pin" ) ),
				newemail => $repo->make_text( $user->value( "newemail" ) ),
				username => $user->render_value( "username" ),
				maxdelta => $repo->make_text( $maxdelta ) ),
			undef,
			$user->value( "newemail" ) );
	}
	else
	{
		$rc = 1;
	}

	if( !$rc )
	{
		# couldn't send email, so remove the user object again
		# and apologise
		$user->remove();
		$self->{processor}->add_message( "error", $repo->html_phrase(
			"general:email_failed",
			) );
		return;
	}

	return $user;
}

sub render_problems
{
	my( $self, @problems ) = @_;

	my $repo = $self->{repository};

	my $error = $repo->xml->create_element( "ul" );
	foreach my $problem (@problems)
	{
		$error->appendChild( $repo->xml->create_element( "li" ))
			->appendChild( $problem );
	}
	return $error;
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

