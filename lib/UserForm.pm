######################################################################
#
#  EPrints User Record Forms
#
######################################################################
#
#  16/02/2000 - Created by Robert Tansley
#  $Id$
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

sub process
{
	my( $self ) = @_;
	
	$self->{user} = EPrints::User->current_user( $self->{session} )
		unless( defined $self->{user} );

	if( !defined $self->{user} )
	{
		# Can't find the user
		$self->{session}->{render}->render_error( "I don't know who you are",
		                                  $self->{redirect} );
		return;
	}

	my $full_name = $self->{user}->full_name();

	if( $self->{session}->{render}->seen_form() == 0 ||
	    $self->{session}->{render}->internal_button_pressed() )
	{
		print $self->{session}->{render}->start_html( "Record for $full_name" );

		# Blurb
		print "<P>Please enter correct information about yourself for our ".
			"records. This	information will be useful to us and readers of your ".
			"papers. You don't have to	supply all this information if you don\'t ".
			"want to; you need only fill out those	fields marked with a * to ".
			"start using the archive.</P>\n";

		$self->render_form();

		print $self->{session}->{render}->end_html();
	}
	else
	{
		# Update the user values
		if( $self->update_from_form() )
		{
			# Validate the changes
			my $problems = $self->{user}->validate();

			if( $#{$problems} == -1 )
			{
				# User has entered everything OK
				$self->{user}->commit();
				$self->{session}->{render}->redirect( $self->{redirect} );
			}
			else
			{
				print $self->{session}->{render}->start_html(
					"Record for $full_name" );

				print "<P>The form doesn\'t seem to be filled out correctly:</P>\n".
					"<UL>\n";

				foreach (@$problems)
				{
					print "<LI>$_</LI>\n";
				}

				print "</UL>\n<P>Please complete the form before continuing.</P>\n";

				$self->render_form();

				print $self->{session}->{render}->end_html();
			}
		}
		else
		{
			$self->{session}->{render}->render_error(
				"There was a problem reading the posted data and updating the ".
					"database. Please try again later",
				$self->{redirect} );
		}
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

sub render_form
{
	my( $self ) = @_;
	
	my @edit_fields;
	my $field;
	my @all_fields = EPrints::MetaInfo->get_user_fields();
	
	# Get the appropriate fields
	foreach $field (@all_fields)
	{
		push @edit_fields, $field if( $self->{staff} || $field->{editable} );
	}
	
	my %hidden = ( "username"=>$self->{user}->{username} );
	
	$self->{session}->{render}->render_form( \@edit_fields,
	                                         $self->{user},
	                                         1,
	                                         0,
	                                         [ "Update Record" ],
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

sub update_from_form
{
	my( $self ) = @_;
	
	my @all_fields = EPrints::MetaInfo->get_user_fields();
	my $field;

	# Ensure correct user
	if( $self->{session}->{render}->param( "username" ) eq
		$self->{user}->{username} )
	{
		foreach $field (@all_fields)
		{
			my $param = $self->{session}->{render}->form_value( $field );
			$param = undef if( $param eq "" );

			# Only update if a value for the field was entered in the form.
			if( $self->{staff} || $field->{editable} )
			{
				$self->{user}->{$field->{name}} = $param;
			}
		}
		return( 1 );
	}
	else
	{
		my $form_id = $self->{session}->{render}->param( "username" );
		EPrints::Log->log_entry(
			"User",
			"Username in form $form_id doesn't match object username ".
				"$self->{username}" );

		return( 0 );
	}
}


1;
