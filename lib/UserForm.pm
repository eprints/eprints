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
	$self->{staff} = $user;
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

		$page = $self->{session}->makeDocFragment;

		$p = $self->{session}->make_element( "p" );		
		$p->appendChild( $self->{session}->html_phrase( "blurb" ) );	
		$page->appendChild( $p );

		$a = $self->{session}->make_element( 
			"a", 
			href => $self->{session}->getSite()->
				  getConf( "server_static" ).
				"/register.html"  );
		$p = $self->{session}->make_element( "p" );		
		$p->appendChild( $self->{session}->html_phrase( 
				"changeemail",
				registerlink => $a ) );	
		$page->appendChild( $p );

		#$self->_render_form();

		$self->{session}->buildPage(
			$self->{session}->
				phrase( "recfor", name => $full_name ),
			$page );
		$self->{session}->sendPage();

		return;
	}

	# Update the user values
	if( $self->_update_from_form() )
	{
		# Validate the changes
		my $problems = $self->{user}->validate();

		if( $#{$problems} == -1 )
		{
			# User has entered everything OK
			$self->{user}->commit();
			$self->{session}->{render}->redirect( $self->{redirect} );
			return;
		}

		print $self->{session}->{render}->start_html( 
			$self->{session}->phrase( "H:recfor", name=>$full_name ) );

			print "<P>".$self->{session}->phrase( "H:formincorrect" )."</P>\n";
		print "<UL>\n";

		foreach (@$problems)
		{
			print "<LI>$_</LI>\n";
		}

		print "</UL>\n";
		print "<P>".$self->{session}->phrase( "H:completeform" )."</P>\n";

		$self->_render_form();

		print $self->{session}->{render}->end_html();
		return;
	}

	$self->{session}->render_error(
		$self->{session}->phrase( "problemupdating" ),
		$self->{redirect} );
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
sub _render_form
{
	my( $self ) = @_;
	
	my @edit_fields;
	my $field;
	my $user_ds = $self->{session}->getSite()->getDataSet( "user" );
	my @all_fields = $user_ds->get_fields;
	
	# Get the appropriate fields
	foreach $field (@all_fields)
	{
		if( $self->{staff} || $field->isEditable() ) {
			push @edit_fields, $field;
		}
	}
	
	my %hidden = ( "username"=>$self->{user}->getValue( "username" ) );

###cjg UPTOHERRE!!!	
	$self->{session}->{render}->render_form( \@edit_fields,
	                                         $self->{user},
	                                         1,
	                                         1,
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

## WP1: BAD
sub _update_from_form
{
	my( $self ) = @_;
	
	my @all_fields = $self->{session}->{metainfo}->get_fields( "user" );
	my $field;

	# Ensure correct user
	if( $self->{session}->{render}->param( "username" ) eq
		$self->{user}->{username} )
	{
		foreach $field (@all_fields)
		{
			my $param = $self->{session}->{render}->form_value( $field );
			$param = undef if( defined $param && $param eq "" );

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
		EPrints::Log::log_entry(
			"usernotmatch",
			      {formid=>$form_id,
			        username=>$self->{username}} );

		return( 0 );
	}
}


1;
