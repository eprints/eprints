######################################################################
#
#  EPrints User Record Forms
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::UserForm;

use EPrints::User;
use EPrints::HTMLRender;
use EPrints::Session;
use EPrints::Database;

use strict;

######################################################################
#
# $userform = new( $session, $redirect, $staff, $user )
#
#  Create a new user form session. If $user is unspecified, the current
#  user (from Apache cookies) is used.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class, $session, $redirect, $staff, $user ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{user} = $user;
	
	return( $self );
}


######################################################################
#
# process()
#
#  Render and respond to the form
#
######################################################################

## WP1: BAD
sub process
{
	my( $self ) = @_;
	
	if( !defined $self->{user} ) 
	{
		$self->{user} = $self->{session}->current_user();
	}
	my $full_name = $self->{user}->full_name();

	if( $self->{session}->seen_form() == 0 ||
	    $self->{session}->internal_button_pressed() )
	{
		my( $page, $p, $a );

		$page = $self->{session}->make_doc_fragment();

		$page->appendChild( $self->{session}->html_phrase( "lib/userform:blurb" ) );

		$page->appendChild( $self->_render_user_form() );

		$self->{session}->build_page(
			$self->{session}->
				phrase( "lib/userform:record_for", name => $full_name ),
			$page );
		$self->{session}->send_page();

	}
	elsif( $self->_update_from_form() )
	{
		# Update the user values

		# Validate the changes
		my $problems = $self->{user}->validate();

		if( scalar @{$problems} == 0 )
		{
			# User has entered everything OK
			$self->{user}->commit();
			$self->{session}->redirect( $self->{redirect} );
			return;
		}

		my( $page, $p, $ul, $li );

		$page = $self->{session}->make_doc_fragment();

		$page->appendChild( 
			$self->{session}->html_phrase( "lib/userform:form_incorrect" ) );

		$ul = $self->{session}->make_element( "ul" );
		my( $problem );
		foreach $problem (@$problems)
		{
			$li = $self->{session}->make_element( "li" );
			$li->appendChild( 
				$self->{session}->make_text( $problem ) );
			$ul->appendChild( $li );
		}
		$page->appendChild( $ul );

		$page->appendChild( 
			$self->{session}->html_phrase( "lib/userform:complete_form" ) );
	
		$page->appendChild( $self->_render_user_form() );

		$self->{session}->build_page(
			$self->{session}->
				phrase( "lib/userform:record_for", name => $full_name ),
			$page );
		$self->{session}->send_page();
	}
	else 
	{
		$self->{session}->render_error(
			$self->{session}->html_phrase( "lib/userform:problem_updating" ),
			$self->{redirect} );
	}
}


######################################################################
#
# render_form()
#
#  Render the current user as an HTML form for editing. If
# $self->{staff} is 1, the staff-only fields will be available for
#  editing, otherwise they won't.
#
######################################################################

## WP1: BAD
sub _render_user_form
{
	my( $self ) = @_;
	
	my $user_ds = $self->{session}->get_archive()->get_dataset( "user" );

	my @fields;
	if( $self->{staff} )
	{
 		@fields = $user_ds->get_fields();
	}
	else
	{
		@fields = $user_ds->get_type_fields( $self->{user}->get_value( "usertype" ) );
	}
	
	my %hidden = ( "username"=>$self->{user}->get_value( "username" ) );

	my $buttons = { update => $self->{session}->phrase( "lib/userform:update_record" ) };

	return $self->{session}->render_input_form( 
					\@fields,
					$self->{user}->get_values(),
					1,
					1,
					$buttons,
					\%hidden );
}

######################################################################
#
# $success = update_from_form()
#
#  Updates the user object from POSTed form data. Note that this
#  methods does NOT update the database - for that use commit().
#
######################################################################


sub _update_from_form
{
	my( $self ) = @_;

	# Ensure correct user
	if( $self->{session}->param( "username" ) ne
		$self->{user}->get_value( "username" ) )
	{
		my $form_id = $self->{session}->param( "username" );
		$self->{session}->get_archive()->log( 
			"Username in $form_id doesn't match object username ".
			 $self->{username} );
	
		return( 0 );
	}
	
	my $user_ds = $self->{session}->get_archive()->get_dataset( "user" );
	my @fields;
	if( $self->{staff} )
	{
 		@fields = $user_ds->get_fields();
	}
	else
	{
		@fields = $user_ds->get_type_fields( $self->{user}->get_value( "usertype" ) );
	}
	

	my $field;
	foreach $field ( @fields )
	{
		my $param = $field->form_value( $self->{session} );

		$self->{user}->set_value( $field->{name} , $param );
	}
	return( 1 );
}


1;
