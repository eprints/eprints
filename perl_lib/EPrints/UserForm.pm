######################################################################
#
# EPrints::UserForm
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

=pod

=head1 NAME

B<EPrints::UserForm> - The HTML form for editing user records.

=head1 DESCRIPTION

Object which handles rendering a form to edit EPrints::User objects
and also processing the results of that form.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
# $self->{session}
#     The current EPrints::Session object.
#
# $self->{redirect}
#     The URL to redirect to when we're done.
#
# $self->{staff}
#     If staff mode is set to true then staffonly fields are included
#     in the form.
#
# $self->{user}
#     The EPrints::User object being modified.
#
# $self->{dest}
#     The URL for the form to submit to.
#
######################################################################

package EPrints::UserForm;

use strict;

######################################################################
=pod

=item $userform = EPrints::UserForm->new( $session, $redirect, $staff, $user )

Create a new user form session. If $user is unspecified, the current
user (from Apache cookies) is used.

$session is the current EPrints::Session object.

$redirect is the URL to go to after the form is complete.

If $staff is true then fields marked "staffonly" are included in
the form.

$user is the EPrints::User record to edit.

=cut
######################################################################

sub new
{
	my( $class, $session, $redirect, $staff, $user, $dest ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{user} = $user;
	$self->{dest} = $dest;

	if( !defined $self->{user} ) 
	{
		$self->{user} = $self->{session}->current_user();
	}
	
	return( $self );
}

######################################################################
=pod

=item $userform->process

Handle results from the form and render the form.

=cut
######################################################################

sub process
{
	my( $self ) = @_;
	
	my $full_name = $self->{user}->render_description();

	if( $self->{session}->seen_form() == 0 ||
	    $self->{session}->internal_button_pressed() ||
	    $self->{session}->get_action_button() eq "edit" )
	{
		if( $self->{session}->internal_button_pressed() )
		{
			$self->_update_from_form();
		}

		my( $page, $p, $a );

		$page = $self->{session}->make_doc_fragment();
		if( $self->{staff} )
		{
			$page->appendChild( $self->{session}->html_phrase( 
				"lib/userform:staff_blurb" ) );
		}
		else
		{
			$page->appendChild( $self->{session}->html_phrase( 
				"lib/userform:blurb" ) );
		}

		$page->appendChild( $self->_render_user_form() );
		$self->{session}->build_page(
			$self->{session}->html_phrase( 
				"lib/userform:record_for", 
				name => $full_name ),
			$page,
			"user_form" );
		$self->{session}->send_page();

	}
	elsif( $self->_update_from_form() )
	{
		# Update the user values

		# Validate the changes
		$self->{user}->commit();
		$self->{user} = EPrints::User->new( 
			$self->{session}, 
			$self->{user}->get_value( "userid" ) );
		my $problems = $self->{user}->validate();

		if( scalar @{$problems} == 0 )
		{
			# User has entered everything OK
			$self->{session}->redirect( $self->{redirect} );
			return;
		}

		my( $page, $p, $ul, $li );

		$page = $self->{session}->make_doc_fragment();

		my $problem_box = $self->{session}->make_element( 
					"div",
					class=>"problems" );
		$page->appendChild( $problem_box );
		$problem_box->appendChild( $self->{session}->html_phrase( 
			"lib/userform:form_incorrect" ) );

		$ul = $self->{session}->make_element( "ul" );
		my( $problem );
		foreach $problem (@$problems)
		{
			$li = $self->{session}->make_element( "li" );
			$li->appendChild( $problem );
			$ul->appendChild( $li );
		}
		$problem_box->appendChild( $ul );

		$problem_box->appendChild( $self->{session}->html_phrase( 
			"lib/userform:complete_form" ) );
	
		$page->appendChild( $self->_render_user_form() );

		$self->{session}->build_page(
			$self->{session}->html_phrase( 
				"lib/userform:record_for", 
				name => $full_name ), 
			$page,
			"user_form" );
		$self->{session}->send_page();
	}
	else 
	{
		$self->{session}->render_error( 
			$self->{session}->html_phrase( 
				"lib/userform:problem_updating" ),
			$self->{redirect} );
	}
}

######################################################################
# 
# $form = $userform->_render_user_form
#
#  Render the current user as an HTML DOM form for editing. If
#  $self->{staff} is 1, the staff-only fields will be available for
#  editing, otherwise they won't.
#
######################################################################

sub _render_user_form
{
	my( $self ) = @_;
	
	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );

	my @fields = $user_ds->get_type_fields( $self->{user}->get_value( "usertype" ), $self->{staff} );

	my %hidden = ( "userid"=>$self->{user}->get_value( "userid" ) );
	my $buttons = { update => $self->{session}->phrase( "lib/userform:update_record" ) };
	my $form = $self->{session}->render_input_form( 
					staff=>$self->{staff},
					dataset=>$user_ds,
					type=>$self->{user}->get_value( "usertype" ),
					fields=>\@fields,
					values=>$self->{user}->get_data(),
					show_names=>1,
					show_help=>1,
					buttons=>$buttons,
					default_action => "update",
					dest => $self->{dest}.'#t',
					hidden_fields=>\%hidden );
	return $form;
}

######################################################################
# 
# $success = $userform->_update_from_form()
#
#  Updates the user object from POSTed form data. Note that this
#  methods does NOT update the database - for that use commit().
#
######################################################################

sub _update_from_form
{
	my( $self ) = @_;

	# Ensure correct user
	if( $self->{session}->param( "userid" ) ne
		$self->{user}->get_value( "userid" ) )
	{
		my $form_id = $self->{session}->param( "username" );
		$self->{session}->get_repository->log( 
			"Username in $form_id doesn't match object username ".
			 $self->{username} );
	
		return( 0 );
	}
	
	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );

	my $usertype;
	if( $self->{staff} )
	{
		# In a search type the usertype can change!
 		$usertype = $self->{session}->param( "usertype" );   
	}
	if( !defined $usertype )
	{
		$usertype = $self->{user}->get_value( "usertype" )       
	}   
	my @fields = $user_ds->get_type_fields( $usertype, $self->{staff} );

	my $field;
	foreach $field ( @fields )
	{
		my $param = $field->form_value( $self->{session} );

		$self->{user}->set_value( $field->{name} , $param );
	}
	return( 1 );
}


######################################################################
#=pod
#
#=item $foo = $thing->DESTROY
#
#undocumented
#
#=cut
######################################################################

#sub DESTROY
#{
#	my( $self ) = @_;
#
#	EPrints::Utils::destroy( $self );
#}

1;

######################################################################
=pod

=back

=cut

