######################################################################
#
#  EPrints Submission uploading/editing forms
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

package EPrints::SubmissionForm;

use EPrints::EPrint;
use EPrints::HTMLRender;
use EPrints::Session;
use EPrints::Document;

use strict;


# Stages of upload

my $STAGES = {
	type => 1,
	linking => 1,
	meta => 1,
	subject => 1,
	format => 1,
	fileview => 1,
	upload => 1,
	verify => 1,
	done => 1,
	error => 1,
	return => 1,
	confirmdel => 1 
};


######################################################################
#
# $subform = new( $session, $redirect, $staff, $table )
#
#  Create a submission session. $redirect is where the user should be
#  directed when the submission has finished/failed. $staff indicates
#  whether it's a staff member that's doing the editing. If $staff is
#  1, no authorisation checks are done, but if $staff is 0, and the
#  user is somehow attempting to edit a record they don't have
#  permission to edit, they'll be presented with an error. $table is
#  the table in which the eprint being edited resides.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class, $session, $redirect, $staff, $dataset ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{dataset} = $dataset;

	return( $self );
}


######################################################################
#
# process()
#
#  Process everything from the previous form, and render the next.
#
######################################################################

## WP1: BAD
sub process
{
	my( $self ) = @_;
	
#cjg NOT VERY FAR YET...	
	$self->{action}    = $self->{session}->get_action_button();
	$self->{stage}     = $self->{session}->param( "stage" );
	$self->{eprint_id} = $self->{session}->param( "eprint_id" );
	$self->{user}      = $self->{session}->current_user();

	# If we have an EPrint ID, retrieve its entry from the database
	if( defined $self->{eprint_id} )
	{
		$self->{eprint} = EPrints::EPrint->new( $self->{session},
		                                        $self->{dataset},
		                                        $self->{eprint_id} );

		# Check it was retrieved OK
		if( !defined $self->{eprint} )
		{
			my $db_error = $self->{session}->get_db()->error;
			#cjg LOG..
			$self->{session}->log( "Database Error: $db_error" );
			$self->_database_err;
			return;
		}

		# check that we got the record we wanted - if we didn't
		# then something is heap big bad. ( This is being a bit
		# over paranoid, but what the hell )
		if( $self->{session}->param( "eprint_id" ) ne
	    		$self->{eprint}->get_value( "eprintid" ) )
		{
			my $form_id = $self->{session}->param( "eprint_id" );
			$self->{session}->get_archive()->log( 
				"Form error: EPrint ID in form ".
				$self->{session}->param( "eprint_id" ).
				" doesn't match object id ".
				$self->{eprint}->get_value( "eprintid" ) );
			$self->_corrupt_err;
			return;
		}

		# Check it's owned by the current user
		if( !$self->{staff} &&
			( $self->{eprint}->get_value( "username" ) ne 
			  $self->{user}->get_value( "username" ) ) )
		{
			$self->{session}->get_archive()->log( 
				"Illegal attempt to edit record ".
				$self->{eprint}->get_value( "eprintid" ).
				" by user with id ".
				$self->{user}->get_value( "username" ) );
			$self->_corrupt_err;
			return;
		}
	}

	$self->{problems} = [];
	my $ok = 1;
	# Process data from previous stage
	if( !defined $self->{stage} )
	{
		$ok = $self->_from_home();
	}
	elsif( defined $STAGES->{$self->{stage}} )
	{
		# It's a valid stage. 

		# But if we don't have an eprint then something's
		# gone wrong.
		if( !defined $self->{eprint} )
		{
			$self->_corrupt_err;
			return( 0 );
		}

		# Process the results of that stage - done 
		# by calling the function &_from_stage_<stage>
		my $function_name = "_from_stage_".$self->{stage};
		{
			no strict 'refs';
			$ok = $self->$function_name();
		}
	}
	else
	{
		$self->_corrupt_err;
		return;
	}

print STDERR "SUBMISSION YAY\n";
	if( $ok )
	{
		# Render stuff for next stage

		my $function_name = "_do_stage_".$self->{next_stage};
		{
print STDERR "CALLING $function_name\n";
			no strict 'refs';
			$self->$function_name();
		}
	}
	
	return;
}


## WP1: BAD
sub _corrupt_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->phrase( 
			"lib/submissionform:corrupt_err",
			line_no => (caller())[2] ) );

}

## WP1: BAD
sub _database_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->phrase( 
			"lib/submissionform:database_err",
			line_no => (caller())[2] ) );

}

######################################################################
#
#  Stage from functions:
#
# $self->{eprint} is the EPrint currently being edited, or undef if
# there isn't one. This may change. $self->{next_stage} should be the
# stage to render next. $self->{problems} should contain any problems
# with uploaded data (fieldname => problem). Some stages may also pass
# any miscellaneous extra info to the next stage.
#
######################################################################


######################################################################
#
#  Came from an external page (usually author or staff home,
#  or bookmarked)
#
######################################################################

## WP1: BAD
sub _from_home
{
	my( $self ) = @_;

	# Create a new EPrint
	if( $self->{action} eq "new" )
	{
		if( !$self->{staff} )
		{
			$self->{eprint} = EPrints::EPrint::create(
				$self->{session},
				$self->{dataset},
				$self->{user}->get_value( "username" ) );

			if( !defined $self->{eprint} )
			{
				my $db_error = $self->{session}->{database}->error();
				$self->{session}->get_archive()->log( "Database Error: $db_error" );
				$self->_database_err;
				return( 0 );
			}
			else
			{

				$self->{next_stage} = "type";
			}
		}
		else
		{
			$self->{session}->render_error( $self->{session}->phrase(
			        "lib/submissionform:use_auth_area" ) );
			return( 0 );
		}
	}
	elsif( $self->{action} eq "edit" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->phrase( "lib/submissionform:nosel_err" ) );
			return( 0 );
		}
		else
		{
			$self->{next_stage} = "type";
		}
	}
#cjg NOT DONE REST OF THIS FUNCTION
	elsif( $self->{action} eq $self->{session}->phrase( "lib/submissionform:action_clone" ) )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->phrase( "lib/submissionform:nosel_err" ) );
			return( 0 );
		}
		
		my $new_eprint = $self->{eprint}->clone( $self->{dataset}, 1 );

		if( defined $new_eprint )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
		}
		else
		{
			my $error = $self->{session}->{database}->error();
			$self->{session}->log( "SubmissionForm error: Error cloning EPrint ".$self->{eprint}->{eprintid}.": $error" );	
			$self->_database_err;
			return( 0 );
		}
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_delete") )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->phrase( "lib/submissionform:nosel_err" ) );
			return( 0 );
		}
		$self->{next_stage} = $EPrints::SubmissionForm::stage_confirmdel;
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_submit") )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->phrase( "lib/submissionform:nosel_err" ) );
			return( 0 );
		}
		$self->{next_stage} = $EPrints::SubmissionForm::stage_verify;
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_cancel") )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
	}
	else
	{
		# Don't have a valid action!
		$self->_corrupt_err;
		return( 0 );
	}
	
	return( 1 );
}


######################################################################
#
# Come from type form
#
######################################################################

## WP1: BAD
sub _from_stage_type
{
	my( $self ) = @_;

	## Process uploaded data

	$self->_update_from_form( "type" );
	$self->{eprint}->commit();

	## Process the action

	if( $self->{action} eq "next" )
	{
		$self->{problems} = $self->{eprint}->validate_type();
		if( scalar @{$self->{problems}} > 0 )
		{
			# There were problems with the uploaded type, 
			# don't move further
			$self->{next_stage} = "type";
		}
		else
		{
			# No problems, onto the next stage
			$self->{next_stage} = "linking";
		}
	}
	elsif( $self->{action} eq "cancel" )
	{
		# Cancelled, go back to author area.
		$self->{next_stage} = "return";
	}
	else
	{
		# Don't have a valid action!
		$self->_corrupt_err;
		return( 0 );
	}

	return( 1 );
}

######################################################################
#
#  From sucession/commentary stage
#
######################################################################

## WP1: BAD
sub _from_stage_linking
{
	my( $self ) = @_;
	
	## Process uploaded data

	$self->_update_from_form( "succeeds" );
	$self->_update_from_form( "commentary" );
	$self->{eprint}->commit();

	## What's the next stage?

	if( $self->{action} eq "next" )
	{
		$self->{problems} = $self->{eprint}->validate_linking();

		if( scalar @{$self->{problems}} > 0 )
		{
			# There were problems with the uploaded type, 
			# don't move further
			$self->{next_stage} = "linking";
		}
		else
		{
			# No problems, onto the next stage
			$self->{next_stage} = "meta";
		}
	}
	elsif( $self->{action} eq "prev" )
	{
		$self->{next_stage} = "type";
	}
	elsif( $self->{action} eq "verify" )
	{
		# Just stick with this... want to verify ID's
		$self->{next_stage} = "linking";
	}
	else
	{
		# Don't have a valid action!
		$self->_corrupt_err;
		return( 0 );
	}
}	


######################################################################
#
# Come from metadata entry form
#
######################################################################

## WP1: BAD
sub _from_stage_meta
{
	my( $self ) = @_;

	# Process uploaded data
	$self->_update_from_meta_form();
	$self->{eprint}->commit();

	if( $self->{session}->{render}->internal_button_pressed() )
	{
		# Leave the form as is
		$self->{next_stage} = $EPrints::SubmissionForm::stage_meta;
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_next") )
	{
		# validation checks
		$self->{problems} = $self->{eprint}->validate_meta();

		if( $#{$self->{problems}} >= 0 )
		{
			# There were problems with the uploaded type, don't move further
			$self->{next_stage} = $EPrints::SubmissionForm::stage_meta;
		}
		else
		{
			# No problems, onto the next stage
			$self->{next_stage} = $EPrints::SubmissionForm::stage_subject;
		}
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_prev") )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_linking;
	}
	else
	{
		# Don't have a valid action!
		$self->_corrupt_err;
		return( 0 );
	}

	return( 1 );
}


######################################################################
#
# Come from subject form
#
######################################################################

## WP1: BAD
sub _from_stage_subject
{
	my( $self ) = @_;

	# Process uploaded data
	$self->_update_from_subject_form();
	$self->{eprint}->commit();
	
	if( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_next") )
	{
		$self->{problems} = $self->{eprint}->validate_subject();
		if( $#{$self->{problems}} >= 0 )
		{
			# There were problems with the uploaded type, don't move further
			$self->{next_stage} = $EPrints::SubmissionForm::stage_subject;
		}
		else
		{
			# No problems, onto the next stage
			$self->{next_stage} = $EPrints::SubmissionForm::stage_format;
		}
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_prev") )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_meta;
	}
	else
	{
		# Don't have a valid action!
		$self->_corrupt_err;
		return( 0 );
	}

	return( 1 );
}



######################################################################
#
#  From "select doc format" page
#
######################################################################

## WP1: BAD
sub _from_stage_format
{
	my( $self ) = @_;
	
	my( $format, $button ) = $self->_update_from_format_form();

	if( defined $format )
	{
		# Find relevant document object
		$self->{document} = $self->{eprint}->get_document( $format );

		if( $button eq "remove" )
		{
			# Remove the offending document
			if( !defined $self->{document} || !$self->{document}->remove() )
			{
				$self->_corrupt_err;
				return( 0 );
			}

			$self->{next_stage} = $EPrints::SubmissionForm::stage_format;
		}
		elsif( $button eq "edit" )
		{
			# Edit the document, creating it first if necessary
			if( !defined $self->{document} )
			{
				# Need to create a new doc object
				$self->{document} = EPrints::Document::create( $self->{session},
				                                               $self->{eprint},
				                                               $format );

				if( !defined $self->{document} )
				{
					$self->_database_err;
					return( 0 );
				}
			}

			$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
		}
		else
		{
			$self->_corrupt_err;
			return( 0 );
		}
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_prev") )
	{
		# prev stage depends if we're linking users or not
		$self->{next_stage} = $EPrints::SubmissionForm::stage_subject
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_finished") )
	{
		$self->{problems} = $self->{eprint}->validate_documents();

		if( $#{$self->{problems}} >= 0 )
		{
			# Problems, don't advance a stage
			$self->{next_stage} = $EPrints::SubmissionForm::stage_format;
		}
		else
		{
			# prev stage depends if we're linking users or not
			$self->{prev_stage} = $EPrints::SubmissionForm::stage_subject;
			$self->{next_stage} = $EPrints::SubmissionForm::stage_verify;
		}
	}
	else
	{
		$self->_corrupt_err;
		return( 0 );
	}		

	return( 1 );
}


######################################################################
#
#  From fileview page
#
######################################################################

## WP1: BAD
sub _from_stage_fileview
{
	my( $self ) = @_;

	# Check the document is OK, and that it is associated with the current
	# eprint
	$self->{document} = EPrints::Document->new(
		$self->{session},
		$self->{session}->{render}->param( "doc_id" ) );

	if( !defined $self->{document} ||
	    $self->{document}->{eprintid} ne $self->{eprint}->{eprintid} )
	{
		$self->_corrupt_err;
		return( 0 );
	}
	
	# Check to see if a fileview button was pressed, process it if necessary
	if( $self->_update_from_fileview( $self->{document} ) )
	{
		# Doc object will have updated as appropriate, commit changes
		unless( $self->{document}->commit() )
		{
			$self->_database_err;
			return( 0 );
		}
		
		$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
	}
	else
	{
		# Fileview button wasn't pressed, so it was an action button
		# Update the description if appropriate
		if( $self->{document}->{format} eq $EPrints::Document::OTHER )
		{
			$self->{document}->{formatdesc} =
				$self->{session}->{render}->param( "formatdesc" );
			$self->{document}->commit();
		}

		if( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_prev") )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_format;
		}
		elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_upload") )
		{
			# Set up info for next stage
			$self->{arc_format} =
				$self->{session}->{render}->param( "arc_format" );
			$self->{numfiles} = $self->{session}->{render}->param( "numfiles" );
			$self->{next_stage} = $EPrints::SubmissionForm::stage_upload;
		}
		elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_finished") )
		{
			# Finished uploading apparently. Validate.
			$self->{problems} = $self->{document}->validate();
			
			if( $#{$self->{problems}} >= 0 )
			{
				$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
			}
			else
			{
				$self->{next_stage} = $EPrints::SubmissionForm::stage_format;
			}
		}
		else
		{
			# Erk! Unknown action.
			$self->_corrupt_err;
			return( 0 );
		}
	}

	return( 1 );
}


######################################################################
#
#  Come from upload stage
#
######################################################################

## WP1: BAD
sub _from_stage_upload
{
	my( $self ) = @_;

	# Check the document is OK, and that it is associated with the current
	# eprint
	my $doc = EPrints::Document->new(
		$self->{session},
		$self->{session}->{render}->param( "doc_id" ) );
	$self->{document} = $doc;

	if( !defined $doc || $doc->{eprintid} ne $self->{eprint}->{eprintid} )
	{
		$self->_corrupt_err;
		return( 0 );
	}
	
	# We need to address a common "feature" of browsers here. If a form has
	# only one text field in it, and the user types things into it and presses
	# return, the form gets submitted but without any values for the submit
	# button, so we can't tell whether the "Back" or "Upload" button is
	# appropriate. We have to assume that if the user's pressed return they
	# want to go ahead with the upload, so we default to the upload button:
	$self->{action} = $self->{session}->phrase("lib/submissionform:action_upload")
		unless( defined $self->{action} );


	if( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_prev") )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_upload") )
	{
		my $arc_format = $self->{session}->{render}->param( "arc_format" );
		my $numfiles   = $self->{session}->{render}->param( "numfiles" );
		my( $success, $file );

		if( $arc_format eq "plain" )
		{
			my $i;
			
			for( $i=0; $i<$numfiles; $i++ )
			{
				$file = $self->{session}->{render}->param( "file_$i" );
				
				$success = $doc->upload( $file, $file );
			}
		}
		elsif( $arc_format eq "graburl" )
		{
			$success = $doc->upload_url( $self->{session}->{render}->param( "url" ) );
		}
		else
		{
			$file = $self->{session}->{render}->param( "file_0" );
			$success = $doc->upload_archive( $file, $file, $arc_format );
		}
		
		if( !$success )
		{
			$self->{problems} = [
				$self->{session}->phrase( "lib/submissionform:upload_prob" ) ];
		}
		elsif( !defined $doc->get_main() )
		{
			my %files = $doc->files();
			if( scalar keys %files == 1 )
			{
				# There's a single uploaded file, make it the main one.
				my @filenames = keys %files;
				$doc->set_main( $filenames[0] );
			}
		}

		$doc->commit();
		$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
	}
	else
	{
		$self->_corrupt_err;
		return( 0 );
	}

	return( 1 );
}	

######################################################################
#
#  Come from verify page
#
######################################################################

## WP1: BAD
sub _from_stage_verify
{
	my( $self ) = @_;

	# We need to know where we came from, so that the Back < button
	# behaves sensibly. It's in a hidden field.
	my $prev_stage = $self->{session}->{render}->param( "prev_stage" );

	if( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_prev") )
	{
		# Go back to the relevant page
		if( $prev_stage eq "home" )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
		}
		elsif( $prev_stage eq $EPrints::SubmissionForm::stage_format )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_format;
		}
		else
		{
			# No relevant page! erk!
			$self->_corrupt_err;
			return( 0 );
		}
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_submit") )
	{
		# Do the commit to the archive thang. One last check...
		my $problems = $self->{eprint}->validate_full();
		
		if( $#{$problems} ==-1 )
		{
			# OK, no problems, submit it to the archive
			if( $self->{eprint}->submit() )
			{
				$self->{id} = $self->{eprint}->{eprintid};
				$self->{next_stage} = $EPrints::SubmissionForm::stage_done;
			}
			else
			{
				$self->_database_err;
				return( 0 );
			}
		}
		else
		{
			# Have problems, back to verify
			$self->{next_stage} = $EPrints::SubmissionForm::stage_verify;
			$self->{prev_stage} = $prev_stage;
		}
	}
	else
	{
		$self->_corrupt_err;
		return( 0 );
	}
	
	return( 1 );
}



######################################################################
#
#  Come from confirm deletion page
#
######################################################################

## WP1: BAD
sub _from_stage_confirmdel
{
	my( $self ) = @_;

	if( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_confirm") )
	{
		if( $self->{eprint}->remove() )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
		}
		else
		{
			my $db_error = $self->{session}->{database}->error();
			$self->{session}->get_archive()->log( "DB error removing EPrint ".$self->{eprint}->{eprintid}.": $db_error" );
			$self->_database_err;
			return( 0 );
		}
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_cancel") )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
	}
	else
	{
		# Don't have a valid action!
		$self->_corrupt_err;
		return( 0 )
	}

	return( 1 );
}





######################################################################
#
#  Functions to render the form for each stage.
#
######################################################################


######################################################################
#
#  Select type form
#
######################################################################

## WP1: BAD
sub _do_stage_type
{
	my( $self ) = @_;

	my( $page, $p );

	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	# should this be done with "help?" cjg
	$p = $self->{session}->make_element( "p" );	
	$p->appendChild( 
		$self->{session}->html_phrase( "lib/submissionform:sel_type" ));
	$page->appendChild( $p );

	my $submit_buttons = {
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };

	$page->appendChild( $self->{session}->render_input_form( 
		[ $self->{dataset}->get_field( "type" ) ],
	        $self->{eprint}->get_data(),
	        0,
	        0,
	        $submit_buttons,
	        { stage => "type", 
		  eprint_id => $self->{eprint}->get_value( "eprintid" ) }
	) );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_type" ),
		$page );
	$self->{session}->send_page();
}

######################################################################
#
#  Succession/Commentary form
#
######################################################################

## WP1: BAD
sub _do_stage_linking
{
	my( $self ) = @_;
	
	my( $page, $p );

	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	my $archive_ds =
		$self->{session}->get_archive()->get_data_set( "archive" );
	my $comment = {};
	my $field_id;
	foreach $field_id ( "succeeds", "commentary" )
	{
		next unless( defined $self->{eprint}->get_value( $field_id ) );

		my $older_eprint = new EPrints::EPrint( 
			$self->{session}, 
		        $archive_ds,
		        $self->{eprint}->get_value( $field_id ) );
	
		$comment->{$field_id} = $self->{session}->make_doc_fragment();	

		if( defined $older_eprint )
		{
			my $citation = $older_eprint->render_citation();
			$comment->{$field_id}->appendChild( 
				$self->{session}->html_phrase( 
					"lib/submissionform:verify",
					citation => $citation ) );
		}
		else
		{
			my $idtext = $self->{session}->make_text(
					$self->{eprint}->get_value($field_id));

			$comment->{$field_id}->appendChild( 
				$self->{session}->html_phrase( 
					"lib/submissionform:invalid_eprint",
					eprintid => $idtext ) );
		}
	}
			

	my $submit_buttons = {
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		verify => $self->{session}->phrase(
				"lib/submissionform:action_verify" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };

	$page->appendChild( $self->{session}->render_input_form( 
		[ 
			$self->{dataset}->get_field( "succeeds" ),
			$self->{dataset}->get_field( "commentary" ) 
		],
	        $self->{eprint}->get_data(),
	        1,
	        1,
	        $submit_buttons,
	        { stage => "linking",
		  eprint_id => $self->{eprint}->get_value( "eprintid" ) },
		$comment
	) );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_linking" ),
		$page );
	$self->{session}->send_page();

}
	



######################################################################
#
#  Enter metadata fields form
#
######################################################################

## WP1: BAD
sub _do_stage_meta
{
	my( $self ) = @_;
	
	my( $page, $p );

	$page = $self->{session}->make_doc_fragment();

print STDERR "-1.ok so far...\n";
	$page->appendChild( $self->_render_problems() );

	$p = $self->{session}->make_element( "p" );

	$p->appendChild( 
		$self->{session}->html_phrase( 
			"lib/submissionform:bib_info",
			star => $self->{session}->make_element(
					"span",
					class => "requiredstar" ) ) );	
	$page->appendChild( $p );
	
	my @edit_fields;
	my @all_fields = $self->{dataset}->get_type_fields( $self->{eprint}->get_value( "type" ) );
	
print STDERR "1.ok so far...\n";
	# Get the appropriate fields
	my $field;
	foreach $field (@all_fields)
	{
		push @edit_fields, $field if( $field->get_property( "editable" ) );
	}

print STDERR "2.ok so far...\n";
	my $hidden_fields = {	
		eprint_id => $self->{eprint}->get_value( "eprintid" ),
		stage => "meta" };

	my $submit_buttons = {
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };
print STDERR "ok so far...\n";
	$page->appendChild( 
		$self->{session}->render_input_form( 
			\@edit_fields,
			$self->{eprint}->{data},
			1,
			1,
			$submit_buttons,
			$hidden_fields ) );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_meta" ),
		$page );
	$self->{session}->send_page();
}

######################################################################
#
#  Select subject(s) form
#
######################################################################

## WP1: BAD
sub _do_stage_subject
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$self->{session}->phrase(
			$EPrints::SubmissionForm::stage_titles{
				$EPrints::SubmissionForm::stage_subject} ) );
	$self->_render_problems();

	$self->_render_subject_form(
		[ $self->{session}->phrase("lib/submissionform:action_prev"),
		  $self->{session}->phrase("lib/submissionform:action_next") ],
		{ stage=>$EPrints::SubmissionForm::stage_subject }  );

	print $self->{session}->{render}->end_html();
}	



######################################################################
#
#  Select an upload format
#
######################################################################

## WP1: BAD
sub _do_stage_format
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$self->{session}->phrase(
			$EPrints::SubmissionForm::stage_titles{
				$EPrints::SubmissionForm::stage_format} ) );
	$self->_render_problems();

	# Validate again, so we know what buttons to put up and how to state stuff
	$self->{eprint}->prune_documents();
	my $probs = $self->{eprint}->validate_documents();

	print "<P><CENTER>";
	print $self->{session}->phrase("lib/submissionform:valid_formats");

	if( @{$self->{session}->get_archive()->get_conf( "required_formats" )} >= 0 )
	{
		print $self->{session}->phrase("lib/submissionform:least_one");
	}

	print "</CENTER></P>\n";

	print $self->{session}->{render}->start_form();

	# Render a form
	$self->_render_format_form();

	# Write a back button, and a finished button, if the docs are OK
	my @buttons = ( $self->{session}->phrase("lib/submissionform:action_prev") );
	push @buttons, $self->{session}->phrase("lib/submissionform:action_finished")
		if( $#{$probs} == -1 );
	
	print "<P><CENTER>";
	print $self->{session}->{render}->submit_buttons( \@buttons );
	print "</CENTER></P>\n";
		
	print $self->{session}->{render}->hidden_field(
		"stage",
		$EPrints::SubmissionForm::stage_format );
	print $self->{session}->{render}->hidden_field(
		"eprint_id",
		 $self->{eprint}->{eprintid} );
	
	print $self->{session}->{render}->end_form();

	print $self->{session}->{render}->end_html();
}

######################################################################
#
#  View / Delete files
#
######################################################################

## WP1: BAD
sub _do_stage_fileview
{
	my( $self ) = @_;

	my $doc = $self->{document};

	# Make some metadata fields
	my @arc_formats = ( "plain", "graburl" );
	my %arc_labels = (
		"plain"   => $self->{session}->phrase("lib/submissionform:plain"),
		"graburl" => $self->{session}->phrase("lib/submissionform:grab_url")
	);
	my $format;
	foreach $format (@{$self->{session}->get_archive()->get_conf( "supported_archive_formats" )})
	{
		push @arc_formats, $format;
		$arc_labels{$format} = EPrints::Document::archive_name( 
					$self->{session},
					$format );
	}

	my $arc_format_field = EPrints::MetaField->make_enum(
		"arc_format",
		undef,
		\@arc_formats,
		\%arc_labels );

	my $num_files_field = EPrints::MetaField->new( "numfiles:int:2::::" );


	# Render the form

	print $self->{session}->{render}->start_html(
		$self->{session}->phrase(
			$EPrints::SubmissionForm::stage_titles{
				$EPrints::SubmissionForm::stage_fileview} ) );

	$self->_render_problems(
		$self->{session}->phrase("lib/submissionform:fix_upload"),
		$self->{session}->phrase("lib/submissionform:please_fix") );

	print $self->{session}->{render}->start_form();
	
	# Format description, if appropriate

	if( $doc->{format} eq $EPrints::Document::OTHER )
	{
		my $ds = $self->{session}->get_archive()->get_data_set( "document" );
		my $desc_field = $ds->get_field( "formatdesc" );

		print "<P><CENTER><EM>$desc_field->{help}</EM></CENTER></P>\n";
		print "<P><CENTER>";
		print $self->{session}->{render}->input_field( $desc_field, 
		                                               $doc->{formatdesc} );
		print "</CENTER></P>\n";
	}
	
	# Render info about uploaded files

	my %files = $doc->files();
	
	if( scalar keys %files == 0 )
	{
		print "<P><CENTER><EM>";
		print $self->{session}->phrase("lib/submissionform:no_files");
		print "</EM></CENTER></P>\n";
	}
	else
	{
		print "<P><CENTER>";
		print $self->{session}->phrase("lib/submissionform:files_for_format");

		if( !defined $doc->get_main() )
		{
			print $self->{session}->phrase("lib/submissionform:sel_first");
		}

		print "</CENTER></P>\n";
		print $self->_render_file_view( $doc );

		print "<P ALIGN=CENTER><A HREF=\"".$doc->url()."\" TARGET=_blank>";
		print $self->{session}->phrase("lib/submissionform:here_to_view");
		print "</A></P>\n";
	}

	# Render upload file options
	print "<P><CENTER>";
	print $self->{session}->phrase("lib/submissionform:file_up_method")." ";
	print $self->{session}->{render}->input_field( $arc_format_field, "plain" );

	print "</CENTER></P>\n<P><CENTER><em>";
	print $self->{session}->phrase("lib/submissionform:plain_only")." ";
	print "</em> ";
	print $self->{session}->phrase("lib/submissionform:num_files")." ";
	print $self->{session}->{render}->input_field( $num_files_field, 1 );
	print "</CENTER></P>\n";

	# Action buttons
	my @buttons = (
		$self->{session}->phrase("lib/submissionform:action_prev"),
		$self->{session}->phrase("lib/submissionform:action_upload") );
	push @buttons, $self->{session}->phrase("lib/submissionform:action_finished")
		if( scalar keys %files > 0 );
	print "<P><CENTER>";
	print $self->{session}->{render}->submit_buttons( \@buttons );
	print "</CENTER></P>\n";
		
	print $self->{session}->{render}->hidden_field(
		"stage",
		$EPrints::SubmissionForm::stage_fileview );
	print $self->{session}->{render}->hidden_field(
		"eprint_id",
		$self->{eprint}->{eprintid} );
	print $self->{session}->{render}->hidden_field( "doc_id", $doc->{docid} );

	$self->{session}->{render}->end_form();

	print $self->{session}->{render}->end_html();
}
	

######################################################################
#
#  Actual file upload form
#
######################################################################

## WP1: BAD
sub _do_stage_upload
{
	my( $self ) = @_;

	print $self->{session}->{render}->start_html(
		$self->{session}->phrase(
			$EPrints::SubmissionForm::stage_titles{
				$EPrints::SubmissionForm::stage_upload} ) );
	print $self->{session}->{render}->start_form();

	my $num_files;

	if( $self->{arc_format} eq "graburl" )
	{
		print "<P><CENTER>";
		print $self->{session}->phrase("lib/submissionform:enter_url");
		print "</CENTER></P>\n";
		print "<P><CENTER><EM>";
		print $self->{session}->phrase("lib/submissionform:url_warning");
		print "</EM></CENTER></P>\n";
		my $url_field = EPrints::MetaField->new( "url:text:::::" );
		print "<P><CENTER>";
		print $self->{session}->{render}->input_field( $url_field, "" );
		print "</CENTER></P>\n";
	}
	else
	{
		if( $self->{arc_format} ne "plain" )
		{
			$num_files = 1;
			print "<P><CENTER>";
			print $self->{session}->phrase("lib/submissionform:entercompfile");
			print "</CENTER></P>\n";
		}
		else
		{
			$num_files = $self->{numfiles};

			if( $self->{numfiles} > 1 )
			{
				print "<P><CENTER>";
				print $self->{session}->phrase("lib/submissionform:enter_files");
				print "</CENTER></P>\n";
			}
			else
			{
				print "<P><CENTER>";
				print $self->{session}->phrase("lib/submissionform:enter_file");
				print "</CENTER></P>\n";
			}
		}

		my $i;
		for( $i=0; $i < $num_files; $i++ )
		{
			print "<P><CENTER>";
			print $self->{session}->{render}->upload_field( "file_$i" );
			print "</CENTER></P>\n";
		}
	}
	
	print "<P><CENTER>";
	print $self->{session}->{render}->submit_buttons(
		[ $self->{session}->phrase("lib/submissionform:action_prev"),
		  $self->{session}->phrase("lib/submissionform:action_upload") ] );
	print "</CENTER></P>\n";
	print $self->{session}->{render}->hidden_field(
		"stage",
		$EPrints::SubmissionForm::stage_upload );
	print $self->{session}->{render}->hidden_field(
		"eprint_id",
		$self->{eprint}->{eprintid} );
	print $self->{session}->{render}->hidden_field( "doc_id",
	                                                $self->{document}->{docid} );
	print $self->{session}->{render}->hidden_field( "numfiles",
	                                                $self->{numfiles} );
	print $self->{session}->{render}->hidden_field( "arc_format",
	                                                 $self->{arc_format} );

	print $self->{session}->{render}->end_form();
	print $self->{session}->{render}->end_html();
}


######################################################################
#
#  Confirm submission
#
######################################################################

## WP1: BAD
sub _do_stage_verify
{
	my( $self ) = @_;

	$self->{eprint}->prune();
	$self->{eprint}->commit();
	# Validate again, in case we came from home
	$self->{problems} = $self->{eprint}->validate_full();

	print $self->{session}->{render}->start_html(
		$self->{session}->phrase(
			$EPrints::SubmissionForm::stage_titles{
				$EPrints::SubmissionForm::stage_verify} ) );

	print $self->{session}->{render}->start_form();
	
	# Put in information about where we came from in "prev_stage".
	#   "home" means we came from the author's home
	#   otherwise the previous stage (usually "stage_format")
	my $prev_stage = $self->{prev_stage};
	$prev_stage = "home" if( !defined $prev_stage );
	print $self->{session}->{render}->hidden_field( "prev_stage", $prev_stage );

	print $self->{session}->{render}->hidden_field(
		"stage",
		$EPrints::SubmissionForm::stage_verify );
	print $self->{session}->{render}->hidden_field(
		"eprint_id",
		$self->{eprint}->{eprintid} );

	if( $#{$self->{problems}} >= 0 )
	{
		$self->_render_problems(
			$self->{session}->phrase("lib/submissionform:fix_probs"),
			"" );

		print "<P><CENTER>";
		print $self->{session}->{render}->submit_buttons(
			[ $self->{session}->phrase("lib/submissionform:action_prev") ] );
		print "</CENTER></P>\n";
	}
	else
	{
		print "<P><CENTER>";
		print $self->{session}->phrase("lib/submissionform:please_verify");
		print "</CENTER></P>\n";
		print "<HR>\n";
		
		print $self->{session}->{render}->_render_eprint_full( $self->{eprint} );
	
		print "<HR>\n";

		print $self->{session}->get_archive()->get_conf ("deposit_agreement_text" )."\n"
			if( defined $self->{session}->get_archive()->get_conf( "deposit_agreement_text" ) );

		print "<P><CENTER>";
		print $self->{session}->{render}->submit_buttons(
			[ $self->{session}->phrase("lib/submissionform:action_prev"),
			  $self->{session}->phrase("lib/submissionform:action_submit") ] );
		print "</CENTER></P>\n";
	}
	
	print $self->{session}->{render}->end_form();
	print $self->{session}->{render}->end_html();
}		
		

######################################################################
#
#  All done.
#
######################################################################

## WP1: BAD
sub _do_stage_done
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$self->{session}->phrase(
			$EPrints::SubmissionForm::stage_titles{
				$EPrints::SubmissionForm::stage_done} ) );
	
	print "<P><CENTER><STRONG>";
	print $self->{session}->phrase("lib/submissionform:thanks");
	print "</STRONG><CENTER></P>\n";
	
	print "<P><CENTER>";
	print $self->{session}->phrase("lib/submissionform:in_buffer");
	print "</CENTER></P>\n";
	
	print "<P><CENTER><A HREF=\"home\">";
	print $self->{session}->phrase("lib/submissionform:ret_dep_page");
	print "</A></CENTER></P>\n";

	print $self->{session}->{render}->end_html();
}


######################################################################
#
#  Confirm deletion
#
######################################################################

## WP1: BAD
sub _do_stage_confirmdel
{
	my( $self ) = @_;

	print $self->{session}->{render}->start_html(
		$self->{session}->phrase(
			$EPrints::SubmissionForm::stage_titles{
				$EPrints::SubmissionForm::stage_confirmdel} ) );

	print "<P><CENTER><strong>";
	print $self->{session}->phrase("lib/submissionform:sure_delete");
	print "</strong></CENTER></P>\n<P><CENTER>";
	
	print $self->{eprint}->short_title();
	
	print "</CENTER></P>\n<P><CENTER>\n";

	print $self->{session}->{render}->start_form();
	print $self->{session}->{render}->hidden_field(
		"eprint_id",
		$self->{eprint}->{eprintid} );
	print $self->{session}->{render}->hidden_field(
		"stage",
		$EPrints::SubmissionForm::stage_confirmdel );
	print $self->{session}->{render}->submit_buttons(
		[ $self->{session}->phrase("lib/submissionform:action_confirm"),
		  $self->{session}->phrase("lib/submissionform:action_cancel") ] );
	print $self->{session}->{render}->end_form();

	print "</CENTER></P>\n";

	print $self->{session}->{render}->end_html();
}	


######################################################################
#
#  Automatically return to author's home.
#
######################################################################

## WP1: BAD
sub _do_stage_return
{
	my( $self ) = @_;

	$self->{session}->{render}->redirect( $self->{redirect} );
}	



######################################################################
#
#  Miscellaneous Functions
#
######################################################################

sub _update_from_form
{
	my( $self, $field_id ) = @_;
	
	my $field = $self->{dataset}->get_field( $field_id );

	$self->{eprint}->set_value( 
		$field_id,
		$field->form_value( $self->{session} ) );
}

######################################################################
#
# _render_problems( $before, $after )
#
#  Lists the given problems with the form. If $before and/or $after
#  are given, they are printed before and after the list. If they're
#  undefined, default messages are printed.
#
######################################################################


## WP1: BAD
sub _render_problems
{
	my( $self, $before, $after ) = @_;

	my( $p, $ul, $li, $frag );
	$frag = $self->{session}->make_doc_fragment();

	if( !defined $self->{problems} || scalar @{$self->{problems}} == 0 )
	{
		# No problems - return an empty node.
		return $frag;
	}

	# List the problem(s)

	$p = $self->{session}->make_element( "p" );
	if( defined $before )
	{
		$p->appendChild( $before );
	}
	else
	{
		$p->appendChild( 	
			$self->{session}->html_phrase(
				"lib/submissionform:filled_wrong" ) );
	}
	$frag->appendChild( $p );

	$ul = $self->{session}->make_element( "ul" );	
	foreach (@{$self->{problems}})
	{
		$li = $self->{session}->make_element( "li" );
		$li->appendChild( $_ );
		$ul->appendChild( $li );
	}
	$frag->appendChild( $ul );
	
	$p = $self->{session}->make_element( "p" );
	if( defined $after )
	{
		$p->appendChild( $after );
	}
	else
	{
		$p->appendChild( 	
			$self->{session}->html_phrase(
				"lib/submissionform:please_complete" ) );
	}
	$frag->appendChild( $p );
	
	return $frag;
}










######################################################################
#
# _update_from_meta_form()
#
#  Updated metadata from the form.
#
######################################################################

## WP1: BAD
sub _update_from_meta_form
{
	my( $self ) = @_;

	my @all_fields = $self->{session}->{metainfo}->get_fields( "eprint" );
	my $field;
	
	if( $self->{session}->{render}->param( "eprint_id" ) ne
		$self->{eprint}->{eprintid} )
	{
		my $form_id = $self->{session}->{render}->param( "eprint_id" );
		$self->{session}->get_archive()->log( "EPrint ID in form &gt;".$form_id."&lt; doesn't match object id ".$self->{eprint}->{eprintid} );
		return( 0 );
	}
	else
	{
		foreach $field (@all_fields)
		{
			my $param = $self->{session}->{render}->form_value( $field );

			# Only update if it appeared in the form.
			if( $field->{editable} )
			{
				$self->{eprint}->{$field->{name}} = $param;
			}
		}
		return( 1 );
	}
}

######################################################################
#
# _render_subject_form(  $submit_buttons, $hidden_fields )
#                           array_ref        hash_ref
#
#  Render a form for the subject(s) field.
#
######################################################################

## WP1: BAD
sub _render_subject_form
{
	my( $self, $submit_buttons, $hidden_fields ) = @_;

	my @edit_fields;

	push @edit_fields, $self->{session}->{metainfo}->find_table_field( "eprint", "subjects" );
	push @edit_fields, $self->{session}->{metainfo}->find_table_field( "eprint", "additional" );
	push @edit_fields, $self->{session}->{metainfo}->find_table_field( "eprint", "reasons" );

	$hidden_fields->{eprint_id} = $self->{eprint}->{eprintid};

	$self->{session}->{render}->render_input_form( \@edit_fields,
	                                         $self->{eprint},
	                                         0,
	                                         1,
	                                         $submit_buttons,
	                                         $hidden_fields );
}



######################################################################
#
# _render_users_form(  $submit_buttons, $hidden_fields )
#                           array_ref        hash_ref
#
#  Render a form for the usernames field.
#
######################################################################
# cjg WHAT DOES THIS DO?
## WP1: BAD
sub _render_users_form
{
	my( $self, $submit_buttons, $hidden_fields ) = @_;

	my @edit_fields;

	push @edit_fields, $self->{session}->{metainfo}->find_table_field( "eprint", "usernames" );

	$hidden_fields->{eprint_id} = $self->{eprint}->{eprintid};

	$self->{session}->{render}->render_input_form( \@edit_fields,
	                                         $self->{eprint},
	                                         0,
	                                         1,
	                                         $submit_buttons,
	                                         $hidden_fields );
}


######################################################################
#
# _update_from_subject_form()
#
#  Update subject data from the form
#
######################################################################

## WP1: BAD
sub _update_from_subject_form
{
	my( $self ) = @_;
	
	if( $self->{session}->{render}->param( "eprint_id" ) ne
		$self->{eprint}->{eprintid} )
	{
		my $form_id = $self->{session}->{render}->param( "eprint_id" );
		$self->{session}->get_archive()->log( "EPrint ID in form &gt;".$form_id."&lt; doesn't match object id ".$self->{eprint}->{eprintid} );

		return( 0 );
	}
	else
	{
		my @all_fields = $self->{session}->{metainfo}->get_fields(
			"eprint",
			$self->{eprint}->{type} );
		my $field;

		foreach $field (@all_fields)
		{
			if( $field->{type} eq "subject")
			{
				my $param =
					$self->{eprint}->{session}->{render}->form_value( $field );
				$self->{eprint}->{$field->{name}} = $param;
			}
		}

		my $additional_field = 
			$self->{session}->{metainfo}->find_table_field( "eprint", "additional" );
		my $reason_field = $self->{session}->{metainfo}->find_table_field( "eprint", "reasons" );

		$self->{eprint}->{$additional_field->{name}} =
			$self->{session}->{render}->form_value( $additional_field );
		$self->{eprint}->{$reason_field->{name}} =
			$self->{session}->{render}->form_value( $reason_field );

		return( 1 );
	}
}


######################################################################
#
# _update_from_users_form()
#
#  Update usernames data from the form
#
######################################################################
#cjg what is this for?
## WP1: BAD
sub _update_from_users_form
{
	my( $self ) = @_;
	
	if( $self->{session}->{render}->param( "eprint_id" ) ne
		$self->{eprint}->{eprintid} )
	{
		my $form_id = $self->{session}->{render}->param( "eprint_id" );
		$self->{session}->get_archive()->log( "EPrint ID in form &gt;".$form_id."&lt; doesn't match object id ".$self->{eprint}->{eprintid} );

		return( 0 );
	}
	else
	{
		my @all_fields = $self->{session}->{metainfo}->get_fields(
			"eprint",
			$self->{eprint}->{type} );
		my $field;

		foreach $field (@all_fields)
		{
			if( $field->{type} eq "username")
			{
				my $param =
					$self->{eprint}->{session}->{render}->form_value( $field );
				$self->{eprint}->{$field->{name}} = $param;
			}
		}

		return( 1 );
	}
}



######################################################################
#
#  DOCUMENT forms
#
######################################################################


######################################################################
#
# $html = _render_file_view()
#
#  Renders an HTML table showing the files in this document, together
#  with buttons allowing deletion and setting which one gets shown first.
#
#  The delete buttons are called delete_n
#
#  where n is a number counting up from 0. To get the file this refers to:
#
#  my %files = $doc->get_files();
#  my @sorted_files = sort keys %files;
#  my $filename = $sorted_files[n];
#
######################################################################

## WP1: BAD
sub _render_file_view
{
	my( $self, $document ) = @_;
	my $html;
	
	$html = "<CENTER><TABLE BORDER=1 CELLPADDING=3><TR><TH></TH>".
		"<TH>".$self->{session}->phrase("lib/submissionform:filename")."</TH>".
		"<TH>".$self->{session}->phrase("lib/submissionform:size_bytes")."</TH>".
		"<TH></TH><TH></TH></TR>\n";
	
	my %files = $document->files();
	my $main = $document->{main};
	my $filename;
	my $filecount = 0;
	
	foreach $filename (sort keys %files)
	{
		$html .= "<TR><TD>";
		if( defined $main && $main eq $filename )
		{
			$html .= "<STRONG>";
			$html .= $self->{session}->phrase("lib/submissionform:shown_first");
			$html .= " -\&gt;</STRONG>"
		}
		
		$html .= "</TD><TD>$filename</TD><TD ALIGN=RIGHT>$files{$filename}</TD>".
			"<TD>";
		if( !defined $main || $main ne $filename )
		{
			$html .= $self->{session}->{render}->named_submit_button(
				"main_$filecount",
				$self->{session}->phrase("lib/submissionform:show_first") );
		}
		$html .= "</TD><TD>";
		$html .= $self->{session}->{render}->named_submit_button(
			"delete_$filecount",
			$self->{session}->phrase("lib/submissionform:delete") );
		$html .= "</TD></TR>\n";
		$filecount++;
	}

	$html .= "</TABLE></CENTER>\n";
	
	$html .= "<P><CENTER>";
	$html .= $self->{session}->{render}->named_submit_button(
		"deleteall",
		$self->{session}->phrase("lib/submissionform:delete_all") );
	$html .= "</CENTER></P>\n";

	return( $html );
}

######################################################################
#
# $consumed = _update_from_fileview()
#
#  Update document object according to form. If $consumed, then a
#  button on the fileview form was pressed. $consumed is left as 0
#  if the fileview didn't receive a button press (hence another button
#  must have been pressed.)
#
######################################################################

## WP1: BAD
sub _update_from_fileview
{
	my( $self, $document ) = @_;
	
	my %files_unsorted = $document->files();
	my @files = sort keys %files_unsorted;
	my $i;
	my $consumed = 0;
	
	# Determine which button was pressed
	if( defined $self->{session}->{render}->param( "deleteall" ) )
	{
		# Delete all button
		$document->remove_all_files();
		$consumed = 1;
	}

	for( $i=0; $i <= $#files; $i++ )
	{
		if( defined $self->{session}->{render}->param( "main_$i" ) )
		{
			# Pressed "Show First" button for this file
			$document->set_main( $files[$i] );
			$consumed = 1;
		}
		elsif( defined $self->{session}->{render}->param( "delete_$i" ) )
		{
			# Pressed "delete" button for this file
			$document->remove_file( $files[$i] );
			$document->set_main( undef ) if( $files[$i] eq $document->{main} );
			$consumed = 1;
		}
	}

	return( $consumed );
}



######################################################################
#
# _render_format_form()
#
#  Render a table showing what formats have been uploaded for the
#  current EPrint. Buttons named "edit_<format>" (e.g. "edit_html")
#  will also be written into the table, and buttons named
#  "remove_<format>"
#
######################################################################

## WP1: BAD
sub _render_format_form
{
	my( $self ) = @_;

	print "<CENTER><TABLE BORDER=1 CELLPADDING=3><TR><TH><STRONG>".
		$self->{session}->phrase("lib/submissionform:format").
		"</STRONG></TH>".
		"<TH><STRONG>".
		$self->{session}->phrase("lib/submissionform:files_uploaded").
		"</STRONG></TH></TR>\n";
	
	my $f;
	foreach $f (@{$self->{session}->get_archive()->get_conf( "supported_formats" )})
	{
		my $req = EPrints::Document::required_format( $self->{session} , $f );
		my $doc = $self->{eprint}->get_document( $f );
		my $numfiles = 0;
		if( defined $doc )
		{
			my %files = $doc->files();
			$numfiles = scalar( keys %files );
		} 

		print "<TR><TD>";
		print "<STRONG>" if $req;
		print EPrints::Document::format_name( $self->{session}, $f );
		print "</STRONG>" if $req;
		print "</TD><TD ALIGN=CENTER>$numfiles</TD><TD>";
		print $self->{session}->{render}->named_submit_button(
			"edit_$f",
			$self->{session}->phrase("lib/submissionform:action_uploadedit") );
		print "</TD><TD>";
		if( $numfiles > 0 )
		{
			print $self->{session}->{render}->named_submit_button(
				"remove_$f",
				$self->{session}->phrase("lib/submissionform:remove") );
		}
		print "</TD></TR>\n";
	}

	if( $self->{session}->get_archive()->get_conf( "allow_arbitrary_formats" ) )
	{
		my $other = $self->{eprint}->get_document( $EPrints::Document::OTHER );
		my $othername = "Other";
		my $numfiles = 0;
		
		if( defined $other )
		{
			$othername = $other->{formatdesc} if( $other->{formatdesc} ne "" );
			my %files = $other->files();
			$numfiles = scalar( keys %files );
		} 

		print "<TR><TD>$othername</TD><TD ALIGN=CENTER>$numfiles</TD><TD>";
		print $self->{session}->{render}->named_submit_button(
			"edit_$EPrints::Document::OTHER",
			$self->{session}->phrase("lib/submissionform:uploadedit") );
		print "</TD><TD>";
		if( $numfiles > 0 )
		{
			print $self->{session}->{render}->named_submit_button(
				"remove_$EPrints::Document::OTHER",
				$self->{session}->phrase("lib/submissionform:remove") );
		}
		print "</TD></TR>\n";
	}		

	print "</TABLE></CENTER>\n";
}		
	

######################################################################
#
# ( $format, $button ) = _update_from_format_form()
#
#  Works out whether a button on the format form rendered by
#  _render_format_form was pressed. If it was, the format concerned is
#  returned in $format, and the button type "remove" or "edit" is
#  given in $button.
#
######################################################################

## WP1: BAD
sub _update_from_format_form
{
	my( $self ) = @_;
	
	my $f;

# what about arbitary formats?
	foreach $f (@{$self->{session}->get_archive()->get_conf( "supported_formats" )})
	{
		return( $f, "edit" )
			if( defined $self->{session}->{render}->param( "edit_$f" ) );
		return( $f, "remove" )
			if( defined $self->{session}->{render}->param( "remove_$f" ) );
	}

	return( $EPrints::Document::OTHER, "edit" )
		if( defined $self->{eprint}->{session}->{render}->param(
			"edit_$EPrints::Document::OTHER" ) );
	return( $EPrints::Document::OTHER, "remove" )
		if( defined $self->{eprint}->{session}->{render}->param(
			"remove_$EPrints::DocumentOTHERother" ) );
	
	return( undef, undef );
}

1;
