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
use EPrints::MetaInfo;
use EPrints::Document;

use strict;


$EPrints::SubmissionForm::action_new        = "New";
$EPrints::SubmissionForm::action_delete     = "Delete";
$EPrints::SubmissionForm::action_edit       = "Edit";
$EPrints::SubmissionForm::action_next       = "Next >";
$EPrints::SubmissionForm::action_prev       = "< Back";
$EPrints::SubmissionForm::action_submit     = "Deposit";
$EPrints::SubmissionForm::action_cancel     = "Cancel";
$EPrints::SubmissionForm::action_confirm    = "Confirm";
$EPrints::SubmissionForm::action_clone      = "Clone";
$EPrints::SubmissionForm::action_uploadedit = "Upload/Edit >";
$EPrints::SubmissionForm::action_finished   = "Finished";
$EPrints::SubmissionForm::action_upload     = "Upload >";
$EPrints::SubmissionForm::action_verify     = "Verify ID's";


# Stages of upload

$EPrints::SubmissionForm::stage_type       = "stage_type";       # EPrint type (e.g. journal article)
$EPrints::SubmissionForm::stage_meta       = "stage_meta";       # Metadata (authors, title, etc)
$EPrints::SubmissionForm::stage_subject    = "stage_subject";    # Subject tag form
$EPrints::SubmissionForm::stage_linking    = "stage_linking";    # Linking to other eprints
$EPrints::SubmissionForm::stage_format     = "stage_format";     # File format selection form
$EPrints::SubmissionForm::stage_fileview   = "stage_fileview";   # View/delete files
$EPrints::SubmissionForm::stage_upload     = "stage_upload";     # Upload file form
$EPrints::SubmissionForm::stage_verify     = "stage_verify";     # Verify and confirm submission
$EPrints::SubmissionForm::stage_done       = "stage_done";       # All done. Congrats.
$EPrints::SubmissionForm::stage_error      = "stage_error";      # Some sort of terminal error.
$EPrints::SubmissionForm::stage_return     = "stage_return";     # Auto. return to author area
$EPrints::SubmissionForm::stage_confirmdel = "stage_confirmdel"; # Confirm deletion

%EPrints::SubmissionForm::stage_titles =
(
	$EPrints::SubmissionForm::stage_type       => "Deposit Type",
	$EPrints::SubmissionForm::stage_meta       => "Bibliographic Information",
	$EPrints::SubmissionForm::stage_subject    => "Subject Categories",
	$EPrints::SubmissionForm::stage_linking    => "Succession/Commentary",
	$EPrints::SubmissionForm::stage_format     => "Document Storage Formats",
	$EPrints::SubmissionForm::stage_fileview   => "Document File Upload",
	$EPrints::SubmissionForm::stage_upload     => "Document File Upload",
	$EPrints::SubmissionForm::stage_verify     => "Deposit Verification",
	$EPrints::SubmissionForm::stage_done       => "Completed Deposit",
	$EPrints::SubmissionForm::stage_error      => "Error",
	$EPrints::SubmissionForm::stage_return     => "Return to Author's Home",
	$EPrints::SubmissionForm::stage_confirmdel => "Confirm Deletion"
);


$EPrints::SubmissionForm::corruption_error =
	"An inconsistency in the posted data was detected. Usually this is caused ".
	"by arriving directly to this page from a bookmark and not from your ".
	"paper depositing page, or through using the browser's back/forwards or ".
	"reload buttons. Always access the depositing mechanism via your author ".
	"area and use the buttons on the form.</P><P>If this has happened in the ".
	"normal course of operation please tell the ".
	"<A HREF=\"mailto:$EPrintSite::SiteInfo::admin\">site administrator</A>";

$EPrints::SubmissionForm::database_error =
	"There's been a problem accessing the site database. ".
	"Please try again later, and contact the ".
	"<A HREF=\"mailto:$EPrintSite::SiteInfo::admin\">site ".
	"administrator</A> if the problem persists.";

$EPrints::SubmissionForm::noselection_error =
	"You hadn't selected a paper to edit, clone, delete or deposit!";


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

sub new
{
	my( $class, $session, $redirect, $staff, $table ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{table} = $table;

	return( $self );
}


######################################################################
#
# process()
#
#  Process everything from the previous form, and render the next.
#
######################################################################

sub process
{
	my( $self ) = @_;
	
	if( !$self->{staff} )
	{
		# Is user authorised?
		
		$self->{user} = EPrints::User::current_user( $self->{session} );
		if( !defined $self->{user} )
		{
			$self->exit_error( "I don't know who you are" );
			return;
		}
	}
	
	$self->{action}    = $self->{session}->{render}->param( "submit" );

	$self->{stage}     = $self->{session}->{render}->param( "stage" );
	$self->{eprint_id} = $self->{session}->{render}->param( "eprint_id" );

	# If we have an EPrint ID, retrieve its entry from the database
	if( defined $self->{eprint_id} )
	{
		$self->{eprint} = EPrints::EPrint->new( $self->{session},
		                                        $self->{table},
		                                        $self->{eprint_id} );

		# Check it was retrieved OK
		if( !defined $self->{eprint} )
		{
			my $db_error = $self->{session}->{database}->error();
			EPrints::Log::log_entry( "SubmissionForm", "DB Error: $db_error" );

			$self->exit_error( $EPrints::SubmissionForm::database_error );
			return;
		}

		# Check it's owned by the current user
		if( !$self->{staff} &&
			$self->{eprint}->{username} ne $self->{user}->{username} )
		{
			$self->exit_error( $EPrints::SubmissionForm::corruption_error );
			return;
		}
	}

	$self->{problems} = [];
	my $ok = 1;

	# Process data from previous stage
	if( !defined $self->{stage} )
	{
		$ok = $self->from_home();
	}
	elsif( defined $EPrints::SubmissionForm::stage_titles{$self->{stage}} )
	{
		# It's a valid stage. Process the results of that stage - done by
		# calling the function &from_<stage>
		my $function_name = "from_$self->{stage}";
		{
			no strict 'refs';
			$ok = $self->$function_name();
		}
	}
	else
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return;
	}

	if( $ok )
	{
		# Render stuff for next stage

		# Clear the form, so there are no residual values
		$self->{session}->{render}->clear();

#EPrints::Log::debug( "SubmissionForm", "To stage: $self->{next_stage}" );

		my $function_name = "do_$self->{next_stage}";

		{
			no strict 'refs';
			$self->$function_name();
		}
	}
	
	return;
}


######################################################################
#
# exit_error( $session, $text )
#
#  Quit with an error message.
#
######################################################################

sub exit_error
{
	my( $self, $text ) = @_;

	$self->{session}->{render}->render_error( $text, $self->{redirect} );

	return;
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

sub from_home
{
	my( $self ) = @_;

	# Create a new EPrint
	if( $self->{action} eq $EPrints::SubmissionForm::action_new )
	{
		if( !$self->{staff} )
		{
			$self->{eprint} = EPrints::EPrint::create(
				$self->{session},
				$self->{table},
				$self->{user}->{username} );

			if( !defined $self->{eprint} )
			{
				my $db_error = $self->{session}->{database}->error();
				EPrints::Log::log_entry( "SubmissionForm",
					                      "DB Error: $db_error" );

				$self->exit_error( $EPrints::SubmissionForm::database_error );
				return( 0 );
			}
			else
			{
#				EPrints::Log::debug(
#					"SubmissionForm",
#					"Created new EPrint with ID $self->{eprint}->{eprintid}" );

				$self->{next_stage} = $EPrints::SubmissionForm::stage_type;
			}
		}
		else
		{
			$self->exit_error( "Use your author area to deposit new documents" );
			return( 0 );
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_edit )
	{
		if( !defined $self->{eprint} )
		{
			$self->exit_error( $EPrints::SubmissionForm::noselection_error );
			return( 0 );
		}
		else
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_type;
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_clone )
	{
		if( !defined $self->{eprint} )
		{
			$self->exit_error( $EPrints::SubmissionForm::noselection_error );
			return( 0 );
		}
		
		my $new_eprint = $self->{eprint}->clone( $self->{table}, 1 );

		if( defined $new_eprint )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
		}
		else
		{
			my $error = $self->{session}->{database}->error();
		
			EPrints::Log::log_entry(
				"SubmissionForm",
				"Error cloning EPrint $self->{eprint}->{eprintid}: $error" );

			$self->exit_error( $EPrints::SubmissionForm::database_error );
			return( 0 );
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_delete )
	{
		if( !defined $self->{eprint} )
		{
			$self->exit_error( $EPrints::SubmissionForm::noselection_error );
			return( 0 );
		}
		$self->{next_stage} = $EPrints::SubmissionForm::stage_confirmdel;
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_submit )
	{
		if( !defined $self->{eprint} )
		{
			$self->exit_error( $EPrints::SubmissionForm::noselection_error );
			return( 0 );
		}
		$self->{next_stage} = $EPrints::SubmissionForm::stage_verify;
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_cancel )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
	}
	else
	{
		# Don't have a valid action!
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}
	
	return( 1 );
}


######################################################################
#
# Come from type form
#
######################################################################

sub from_stage_type
{
	my( $self ) = @_;

	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	# Process uploaded data
	$self->update_from_type_form();
	$self->{eprint}->commit();

	if( $self->{action} eq $EPrints::SubmissionForm::action_next )
	{
		$self->{problems} = $self->{eprint}->validate_type();
		if( $#{$self->{problems}} >= 0 )
		{
			# There were problems with the uploaded type, don't move further
			$self->{next_stage} = $EPrints::SubmissionForm::stage_type;
		}
		else
		{
			# No problems, onto the next stage
			$self->{next_stage} = $EPrints::SubmissionForm::stage_linking;
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_cancel )
	{
		# Cancelled, go back to author area.
		$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
	}
	else
	{
		# Don't have a valid action!
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	return( 1 );
}


######################################################################
#
# Come from metadata entry form
#
######################################################################

sub from_stage_meta
{
	my( $self ) = @_;

	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	# Process uploaded data
	$self->update_from_meta_form();
	$self->{eprint}->commit();

	if( $self->{session}->{render}->internal_button_pressed() )
	{
		# Leave the form as is
		$self->{next_stage} = $EPrints::SubmissionForm::stage_meta;
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_next )
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
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_prev )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_linking;
	}
	else
	{
		# Don't have a valid action!
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	return( 1 );
}


######################################################################
#
# Come from subject form
#
######################################################################

sub from_stage_subject
{
	my( $self ) = @_;

	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	# Process uploaded data
	$self->update_from_subject_form();
	$self->{eprint}->commit();
	
	if( $self->{action} eq $EPrints::SubmissionForm::action_next )
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
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_prev )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_meta;
	}
	else
	{
		# Don't have a valid action!
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	return( 1 );
}


######################################################################
#
#  From sucession/commentary stage
#
######################################################################

sub from_stage_linking
{
	my( $self ) = @_;
	
	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	# Update the values
	my $succeeds_field = EPrints::MetaInfo::find_eprint_field( "succeeds" );
	my $commentary_field = EPrints::MetaInfo::find_eprint_field( "commentary" );

	$self->{eprint}->{succeeds} =
		$self->{session}->{render}->form_value( $succeeds_field );
	$self->{eprint}->{commentary} =
		$self->{session}->{render}->form_value( $commentary_field );
	
	$self->{eprint}->commit();
	
	# What's the next stage?
	if( $self->{action} eq $EPrints::SubmissionForm::action_next )
	{
		$self->{problems} = $self->{eprint}->validate_linking();

		if( $#{$self->{problems}} >= 0 )
		{
			# There were problems with the uploaded type, don't move further
			$self->{next_stage} = $EPrints::SubmissionForm::stage_linking;
		}
		else
		{
			# No problems, onto the next stage
			$self->{next_stage} = $EPrints::SubmissionForm::stage_meta;
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_prev )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_type;
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_verify )
	{
		# Just stick with this... want to verify ID's
		$self->{next_stage} = $EPrints::SubmissionForm::stage_linking;
	}
	else
	{
		# Don't have a valid action!
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}
}	


######################################################################
#
#  From "select doc format" page
#
######################################################################

sub from_stage_format
{
	my( $self ) = @_;
	
	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	my( $format, $button ) = $self->update_from_format_form();

	if( defined $format )
	{
		# Find relevant document object
		$self->{document} = $self->{eprint}->get_document( $format );

		if( $button eq "remove" )
		{
			# Remove the offending document
			if( !defined $self->{document} || !$self->{document}->remove() )
			{
				$self->exit_error( $EPrints::SubmissionForm::corruption_error );
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
					$self->exit_error( $EPrints::SubmissionForm::database_error );
					return( 0 );
				}
			}

			$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
		}
		else
		{
			$self->exit_error( $EPrints::SubmissionForm::corruption_error );
			return( 0 );
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_prev )
	{
		# prev stage depends if we're linking users or not
		$self->{next_stage} = $EPrints::SubmissionForm::stage_subject
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_finished )
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
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}		

	return( 1 );
}


######################################################################
#
#  From fileview page
#
######################################################################

sub from_stage_fileview
{
	my( $self ) = @_;

	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}
	
	# Check the document is OK, and that it is associated with the current
	# eprint
	$self->{document} = EPrints::Document->new(
		$self->{session},
		$self->{session}->{render}->param( "doc_id" ) );

	if( !defined $self->{document} ||
	    $self->{document}->{eprintid} ne $self->{eprint}->{eprintid} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
	}
	
	# Check to see if a fileview button was pressed, process it if necessary
	if( $self->update_from_fileview( $self->{document} ) )
	{
		# Doc object will have updated as appropriate, commit changes
		unless( $self->{document}->commit() )
		{
			$self->exit_error( $EPrints::SubmissionForm::database_error );
			return( 0 );
		}
		
		$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
	}
	else
	{
		# Fileview button wasn't pressed, so it was an action button
		# Update the description if appropriate
		if( $self->{document}->{format} eq $EPrints::Document::other )
		{
			$self->{document}->{formatdesc} =
				$self->{session}->{render}->param( "formatdesc" );
			$self->{document}->commit();
		}

		if( $self->{action} eq $EPrints::SubmissionForm::action_prev )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_format;
		}
		elsif( $self->{action} eq $EPrints::SubmissionForm::action_upload )
		{
			# Set up info for next stage
			$self->{arc_format} =
				$self->{session}->{render}->param( "arc_format" );
			$self->{numfiles} = $self->{session}->{render}->param( "numfiles" );
			$self->{next_stage} = $EPrints::SubmissionForm::stage_upload;
		}
		elsif( $self->{action} eq $EPrints::SubmissionForm::action_finished )
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
			$self->exit_error( $EPrints::SubmissionForm::corruption_error );
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

sub from_stage_upload
{
	my( $self ) = @_;

	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	# Check the document is OK, and that it is associated with the current
	# eprint
	my $doc = EPrints::Document->new(
		$self->{session},
		$self->{session}->{render}->param( "doc_id" ) );
	$self->{document} = $doc;

	if( !defined $doc || $doc->{eprintid} ne $self->{eprint}->{eprintid} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}
	
	# We need to address a common "feature" of browsers here. If a form has
	# only one text field in it, and the user types things into it and presses
	# return, the form gets submitted but without any values for the submit
	# button, so we can't tell whether the "Back" or "Upload" button is
	# appropriate. We have to assume that if the user's pressed return they
	# want to go ahead with the upload, so we default to the upload button:
	$self->{action} = $EPrints::SubmissionForm::action_upload
		unless( defined $self->{action} );


	if( $self->{action} eq $EPrints::SubmissionForm::action_prev )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_fileview;
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_upload )
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
				"There was a problem uploading your file(s). Please try again." ];
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
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	return( 1 );
}	

######################################################################
#
#  Come from verify page
#
######################################################################

sub from_stage_verify
{
	my( $self ) = @_;

	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	# We need to know where we came from, so that the Back < button
	# behaves sensibly. It's in a hidden field.
	my $prev_stage = $self->{session}->{render}->param( "prev_stage" );

	if( $self->{action} eq $EPrints::SubmissionForm::action_prev )
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
			$self->exit_error( $EPrints::SubmissionForm::corruption_error );
			return( 0 );
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_submit )
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
				$self->exit_error( $EPrints::SubmissionForm::database_error );
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
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}
	
	return( 1 );
}



######################################################################
#
#  Come from confirm deletion page
#
######################################################################

sub from_stage_confirmdel
{
	my( $self ) = @_;

	if( !defined $self->{eprint} )
	{
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
		return( 0 );
	}

	if( $self->{action} eq $EPrints::SubmissionForm::action_confirm )
	{
		if( $self->{eprint}->remove() )
		{
			$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
		}
		else
		{
			my $db_error = $self->{session}->{database}->error();

			EPrints::Log::log_entry(
				"SubmissionForm",
				"DB Error removing EPrint $self->{eprint}->{eprintid}: $db_error" );

			$self->exit_error( $EPrints::SubmissionForm::database_error );
			return( 0 );
		}
	}
	elsif( $self->{action} eq $EPrints::SubmissionForm::action_cancel )
	{
		$self->{next_stage} = $EPrints::SubmissionForm::stage_return;
	}
	else
	{
		# Don't have a valid action!
		$self->exit_error( $EPrints::SubmissionForm::corruption_error );
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

sub do_stage_type
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_type} );

	$self->list_problems();
	
	print "<P>Please select the most appropriate type for your ".
		"deposit.</P>\n";

	$self->render_type_form(
		[ $EPrints::SubmissionForm::action_cancel,
			$EPrints::SubmissionForm::action_next ],
		{ stage=>$EPrints::SubmissionForm::stage_type } );

	print $self->{session}->{render}->end_html();
}


######################################################################
#
#  Enter metadata fields form
#
######################################################################

sub do_stage_meta
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_meta} );
	$self->list_problems();

	print "<P>Please enter the bibliographic data about your deposit. ".
		"Fields marked with a * are fields that must be filled out ".
		"before your deposit will be accepted.</P>\n";
	$self->render_meta_form(
		[ $EPrints::SubmissionForm::action_prev,
		  $EPrints::SubmissionForm::action_next ],
		{ stage=>$EPrints::SubmissionForm::stage_meta }  );

	print $self->{session}->{render}->end_html();
}

######################################################################
#
#  Select subject(s) form
#
######################################################################

sub do_stage_subject
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_subject} );
	$self->list_problems();

	$self->render_subject_form(
		[ $EPrints::SubmissionForm::action_prev,
		  $EPrints::SubmissionForm::action_next ],
		{ stage=>$EPrints::SubmissionForm::stage_subject }  );

	print $self->{session}->{render}->end_html();
}	



######################################################################
#
#  Succession/Commentary form
#
######################################################################

sub do_stage_linking
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_linking} );
	
	$self->list_problems();

	my $succeeds_field = EPrints::MetaInfo::find_eprint_field( "succeeds" );
	my $commentary_field = EPrints::MetaInfo::find_eprint_field( "commentary" );

	print $self->{session}->{render}->start_form();
	
	print "<CENTER><P><TABLE BORDER=0>\n";

	# Get the previous version

	print $self->{session}->{render}->input_field_tr(
		$succeeds_field,
		$self->{eprint}->{succeeds},
		1,
		1 );
	
	if( defined $self->{eprint}->{succeeds} &&
		$self->{eprint}->{succeeds} ne "" )
	{
		my $older_eprint = new EPrints::EPrint( $self->{session}, 
		                                        $EPrints::Database::table_archive,
		                                        $self->{eprint}->{succeeds} );
		
		if( defined $older_eprint )
		{
			print "<TR><TD><STRONG>Verify:</STRONG></TD><TD>";
			print $self->{session}->{render}->render_eprint_citation(
				$older_eprint );
			print "</TD></TR>\n";
		}
		else
		{
			print "<TR><TD COLSPAN=2><STRONG>ID $self->{eprint}->{succeeds} is ".
				"not a valid EPrint ID!</STRONG></TD></TR>\n";
		}
	}
			
	# Get the paper commented on

	print $self->{session}->{render}->input_field_tr(
		$commentary_field,
		$self->{eprint}->{commentary},
		1,
		1 );
	
	if( defined $self->{eprint}->{commentary} &&
		$self->{eprint}->{commentary} ne "" )
	{
		my $older_eprint = new EPrints::EPrint( $self->{session}, 
		                                        $EPrints::Database::table_archive,
		                                        $self->{eprint}->{commentary} );
		
		if( defined $older_eprint )
		{
			print "<TR><TD><STRONG>Verify:</STRONG></TD><TD>";
			print $self->{session}->{render}->render_eprint_citation(
				$older_eprint );
			print "</TD></TR>\n";
		}
		else
		{
			print "<TR><TD COLSPAN=2><STRONG>ID $self->{eprint}->{commentary} is ".
				"not a valid EPrint ID!</STRONG></TD></TR>\n";
		}
	}

	print "</TABLE></P></CENTER>\n";

	print $self->{session}->{render}->hidden_field(
		"eprint_id",
		$self->{eprint}->{eprintid} );
	
	print $self->{session}->{render}->hidden_field(
		"stage",
		$EPrints::SubmissionForm::stage_linking );

	print "<CENTER><P>";
	print $self->{session}->{render}->submit_buttons(
		[ $EPrints::SubmissionForm::action_prev,
		  $EPrints::SubmissionForm::action_verify,
		  $EPrints::SubmissionForm::action_next ] );
	print "</P></CENTER>";

	print $self->{session}->{render}->end_form();
	
	print $self->{session}->{render}->end_html();
}
	


######################################################################
#
#  Select an upload format
#
######################################################################

sub do_stage_format
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_format} );
	$self->list_problems();

	# Validate again, so we know what buttons to put up and how to state stuff
	$self->{eprint}->prune_documents();
	my $probs = $self->{eprint}->validate_documents();

	print "<P><CENTER>Here are the available upload formats, and how many ".
		"files you have uploaded for each.";

	if( $#EPrintSite::SiteInfo::required_formats >= 0 )
	{
		print " You must upload at least one of the formats listed in bold.";
	}

	print "</CENTER></P>\n";

	print $self->{session}->{render}->start_form();

	# Render a form
	$self->render_format_form();

	# Write a back button, and a finished button, if the docs are OK
	my @buttons = ( $EPrints::SubmissionForm::action_prev );
	push @buttons, $EPrints::SubmissionForm::action_finished
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

sub do_stage_fileview
{
	my( $self ) = @_;

	my $doc = $self->{document};

	# Make some metadata fields
	my @arc_formats = ( "plain", "graburl" );
	my %arc_labels = (
		"plain"   => "Plain Files",
		"graburl" => "From an Existing Web Site"
	);

	foreach (@EPrintSite::SiteInfo::supported_archive_formats)
	{
		push @arc_formats, $_;
		$arc_labels{$_} = $EPrintSite::SiteInfo::archive_names{$_};
	}

	my $arc_format_field = EPrints::MetaField->make_enum(
		"arc_format",
		undef,
		\@arc_formats,
		\%arc_labels );

	my $num_files_field = EPrints::MetaField->new( "numfiles:int:2::::" );


	# Render the form

	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_fileview} );

	$self->list_problems(
		"The document upload can't be completed because:",
		"Please fix this before continuing." );

	print $self->{session}->{render}->start_form();
	
	# Format description, if appropriate

	if( $doc->{format} eq $EPrints::Document::other )
	{
		my @doc_fields = EPrints::MetaInfo::get_document_fields();
		my $desc_field = EPrints::MetaInfo::find_field( \@doc_fields,
	                                                	"formatdesc" );

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
		print "<P><CENTER><EM>No files have been uploaded for this format.".
			"</EM></CENTER></P>\n";
	}
	else
	{
		print "<P><CENTER>These are the files you have uploaded for this".
			" format.";

		if( !defined $doc->get_main() )
		{
			print " You need to select the file that should be shown first when ".
				"a reader wishes to view your deposit.";
		}

		print "</CENTER></P>\n";
		print $self->render_file_view( $doc );

		print "<P ALIGN=CENTER><A HREF=\"".$doc->url()."\" TARGET=_blank>".
			"Click here to view and verify the uploaded files</A></P>\n";
	}

	# Render upload file options

	print "<P><CENTER>File upload method: ";
	print $self->{session}->{render}->input_field( $arc_format_field, "plain" );

	print "</CENTER></P>\n<P><CENTER><em>(Plain files only)</em> Number of ".
		"files to upload: ";
	print $self->{session}->{render}->input_field( $num_files_field, 1 );
	print "</CENTER></P>\n";

	# Action buttons
	my @buttons = (
		$EPrints::SubmissionForm::action_prev,
		$EPrints::SubmissionForm::action_upload );
	push @buttons, $EPrints::SubmissionForm::action_finished
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

sub do_stage_upload
{
	my( $self ) = @_;

	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_upload} );
	print $self->{session}->{render}->start_form();

	my $num_files;

	if( $self->{arc_format} eq "graburl" )
	{
		print "<P><CENTER>Please enter the URL of the document you wish to ".
			"upload to the archive in the box below.</CENTER></P>\n";
		print "<P><CENTER><EM>Occasionally, uploading this way may ".
			"not produce a totally accurate copy. This is because some ".
			"assumptions about the structure of the HTML must be made, to stop ".
			"the software from trying to upload the whole World-Wide Web!</EM>".
			"</CENTER></P>\n";
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
			print "<P><CENTER>Enter the filename (with full path) of the ".
				"compressed file in the box below.</CENTER></P>\n";
		}
		else
		{
			$num_files = $self->{numfiles};

			if( $self->{numfiles} > 1 )
			{
				print "<P><CENTER>Please enter the filenames (with full paths) of ".
					"the document files in the boxes below.</CENTER></P>\n";
			}
			else
			{
				print "<P><CENTER>Please enter the filename (with full path) of ".
					"the document file in the box below.</CENTER></P>\n";
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
		[ $EPrints::SubmissionForm::action_prev,
		  $EPrints::SubmissionForm::action_upload ] );
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

sub do_stage_verify
{
	my( $self ) = @_;

	$self->{eprint}->prune();
	$self->{eprint}->commit();
	# Validate again, in case we came from home
	$self->{problems} = $self->{eprint}->validate_full();

	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_verify} );

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
		$self->list_problems(
			"Before you deposit this entry to the archive, the following ".
				"problems need to be corrected:",
			"" );

		print "<P><CENTER>";
		print $self->{session}->{render}->submit_buttons(
			[ $EPrints::SubmissionForm::action_prev ] );
		print "</CENTER></P>\n";
	}
	else
	{
		print "<P><CENTER>Please verify that all of the details about your ".
			"deposit are correct, and that all necessary document files ".
			"have been correctly uploaded including any figures.</CENTER></P>\n";
		print "<HR>\n";
		
		print $self->{session}->{render}->render_eprint_full( $self->{eprint} );
	
		print "<HR>\n";

		print $EPrintSite::SiteInfo::deposit_agreement_text."\n"
			if( defined $EPrintSite::SiteInfo::deposit_agreement_text );

		print "<P><CENTER>";
		print $self->{session}->{render}->submit_buttons(
			[ $EPrints::SubmissionForm::action_prev,
			  $EPrints::SubmissionForm::action_submit ] );
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

sub do_stage_done
{
	my( $self ) = @_;
	
	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_done} );
	
	print "<P><CENTER><STRONG>Thank you.</STRONG><CENTER></P>\n";
	
	print "<P><CENTER>Your document is now held in the deposit buffer. ".
		"Provided there are no problems it should appear in the main archive ".
		"within the next few days.</CENTER></P>\n";
	
	print "<P><CENTER><A HREF=\"home\">Click here to return to your deposit ".
		"papers page</A></CENTER></P>\n";

	print $self->{session}->{render}->end_html();
}


######################################################################
#
#  Confirm deletion
#
######################################################################

sub do_stage_confirmdel
{
	my( $self ) = @_;

	print $self->{session}->{render}->start_html(
		$EPrints::SubmissionForm::stage_titles{
			$EPrints::SubmissionForm::stage_confirmdel} );

	print "<P><CENTER><strong>Are you absolutely sure you want to delete this ".
		"entry?</strong></CENTER></P>\n<P><CENTER>";
	
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
		[ $EPrints::SubmissionForm::action_confirm,
		  $EPrints::SubmissionForm::action_cancel ] );
	print $self->{session}->{render}->end_form();

	print "</CENTER></P>\n";

	print $self->{session}->{render}->end_html();
}	


######################################################################
#
#  Automatically return to author's home.
#
######################################################################

sub do_stage_return
{
	my( $self ) = @_;

	$self->{session}->{render}->redirect( $self->{redirect} );
}	



######################################################################
#
#  Miscellaneous Functions
#
######################################################################

######################################################################
#
# list_problems( $before, $after )
#
#  Lists the given problems with the form. If $before and/or $after
#  are given, they are printed before and after the list. If they're
#  undefined, default messages are printed.
#
######################################################################


sub list_problems
{
	my( $self, $before, $after ) = @_;
	
#EPrints::Log::debug( "SubmissionForm", "problems is ".(defined $self->{problems} ? $self->{problems} : "undef" ) );
#	foreach( @{$self->{problems}} )
#	{
#EPrints::Log::debug( "SubmissionForm", "problem: $_" );
#	}

	if( defined $self->{problems} && $#{$self->{problems}} >= 0 )
	{
		# List the problem(s)

		if( defined $before )
		{
			print "<P>$before</P>\n";
		}
		else
		{
			print "<P>The form doesn\'t seem to be filled out correctly:</P>\n";
		}
		
		print "<UL>\n";
		foreach (@{$self->{problems}})
		{
			print "<LI>$_</LI>\n";
		}
		print "</UL>\n";
		
		if( defined $after )
		{
			print "<P>$after</P>\n";
		}
		else
		{
			print "<P>Please complete the form before continuing.</P>\n";
		}
	}
}







######################################################################
#
#  EPRINT forms
#
######################################################################


######################################################################
#
# render_type_form( $submit_buttons, $hidden_fields )
#                     array_ref         hash_ref
#
#  Renders the type form. $submit_buttons should be a reference to
#  an array with the values for submit buttons that should be shown.
#
######################################################################

sub render_type_form
{
	my( $self, $submit_buttons, $hidden_fields ) = @_;
	
	my $field = EPrints::MetaInfo::find_eprint_field( "type" );

	$hidden_fields->{eprint_id} = $self->{eprint}->{eprintid};
	
	$self->{session}->{render}->render_form( [ $field ],
	                                         $self->{eprint},
	                                         0,
	                                         0,
	                                         $submit_buttons,
	                                         $hidden_fields );
}


######################################################################
#
# $success = update_from_type_form()
#
#  Update values from a type form. Doesn't update the database entry -
#  use commit() to make the changes permanent.
#
######################################################################

sub update_from_type_form
{
	my( $self ) = @_;
	
	if( $self->{session}->{render}->param( "eprint_id" ) ne
	    $self->{eprint}->{eprintid} )
	{
		my $form_id = $self->{session}->{render}->param( "eprint_id" );

		EPrints::Log::log_entry(
			"Forms",
			"EPrint ID in form >$form_id< doesn't match object id ".
				">$self->{eprint}->{eprintid}<" );

		return( 0 );
	}
	else
	{
		my $field = EPrints::MetaInfo::find_eprint_field( "type" );

		$self->{eprint}->{type} =
			$self->{session}->{render}->form_value( $field );
	}

	return( 1 );
}

######################################################################
#
# render_meta_form( $submit_buttons, $hidden_fields )
#                      array_ref        hash_ref
#
#  Render a form for the (site-specific) metadata fields.
#
######################################################################

sub render_meta_form
{
	my( $self, $submit_buttons, $hidden_fields ) = @_;
	
	my @edit_fields;
	my $field;
	my @all_fields = EPrints::MetaInfo::get_eprint_fields(
		$self->{eprint}->{type} );
	
	# Get the appropriate fields
	foreach $field (@all_fields)
	{
		push @edit_fields, $field if( $field->{editable} );
	}
	
	$hidden_fields->{eprint_id} = $self->{eprint}->{eprintid};

	$self->{session}->{render}->render_form( \@edit_fields,
	                                         $self->{eprint},
	                                         1,
	                                         1,
	                                         $submit_buttons,
	                                         $hidden_fields );
}


######################################################################
#
# update_from_meta_form()
#
#  Updated metadata from the form.
#
######################################################################

sub update_from_meta_form
{
	my( $self ) = @_;

	my @all_fields = EPrints::MetaInfo::get_all_eprint_fields();
	my $field;
	
	if( $self->{session}->{render}->param( "eprint_id" ) ne
		$self->{eprint}->{eprintid} )
	{
		my $form_id = $self->{session}->{render}->param( "eprint_id" );

		EPrints::Log::log_entry(
			"Forms",
			"EPrint ID in form >$form_id< doesn't match object id ".
				">$self->{eprint}->{eprintid}<" );

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
# render_subject_form(  $submit_buttons, $hidden_fields )
#                           array_ref        hash_ref
#
#  Render a form for the subject(s) field.
#
######################################################################

sub render_subject_form
{
	my( $self, $submit_buttons, $hidden_fields ) = @_;

	my @edit_fields;

	push @edit_fields, EPrints::MetaInfo::find_eprint_field( "subjects" );
	push @edit_fields, EPrints::MetaInfo::find_eprint_field( "additional" );
	push @edit_fields, EPrints::MetaInfo::find_eprint_field( "reasons" );

	$hidden_fields->{eprint_id} = $self->{eprint}->{eprintid};

	$self->{session}->{render}->render_form( \@edit_fields,
	                                         $self->{eprint},
	                                         0,
	                                         1,
	                                         $submit_buttons,
	                                         $hidden_fields );
}



######################################################################
#
# render_users_form(  $submit_buttons, $hidden_fields )
#                           array_ref        hash_ref
#
#  Render a form for the usernames field.
#
######################################################################

sub render_users_form
{
	my( $self, $submit_buttons, $hidden_fields ) = @_;

	my @edit_fields;

	push @edit_fields, EPrints::MetaInfo::find_eprint_field( "usernames" );

	$hidden_fields->{eprint_id} = $self->{eprint}->{eprintid};

	$self->{session}->{render}->render_form( \@edit_fields,
	                                         $self->{eprint},
	                                         0,
	                                         1,
	                                         $submit_buttons,
	                                         $hidden_fields );
}


######################################################################
#
# update_from_subject_form()
#
#  Update subject data from the form
#
######################################################################

sub update_from_subject_form
{
	my( $self ) = @_;
	
	if( $self->{session}->{render}->param( "eprint_id" ) ne
		$self->{eprint}->{eprintid} )
	{
		my $form_id = $self->{session}->{render}->param( "eprint_id" );

		EPrints::Log::log_entry(
			"Forms",
			"EPrint ID in form >$form_id< doesn't match object id ".
				">$self->{eprint}->{eprintid}<" );

		return( 0 );
	}
	else
	{
		my @all_fields = EPrints::MetaInfo::get_eprint_fields(
			$self->{eprint}->{type} );
		my $field;

		foreach $field (@all_fields)
		{
			if( $field->{type} eq "subjects")
			{
				my $param =
					$self->{eprint}->{session}->{render}->form_value( $field );
				$self->{eprint}->{$field->{name}} = $param;
			}
		}

		my $additional_field = 
			EPrints::MetaInfo::find_eprint_field( "additional" );
		my $reason_field = EPrints::MetaInfo::find_eprint_field( "reasons" );

		$self->{eprint}->{$additional_field->{name}} =
			$self->{session}->{render}->form_value( $additional_field );
		$self->{eprint}->{$reason_field->{name}} =
			$self->{session}->{render}->form_value( $reason_field );

		return( 1 );
	}
}


######################################################################
#
# update_from_users_form()
#
#  Update usernames data from the form
#
######################################################################

sub update_from_users_form
{
	my( $self ) = @_;
	
	if( $self->{session}->{render}->param( "eprint_id" ) ne
		$self->{eprint}->{eprintid} )
	{
		my $form_id = $self->{session}->{render}->param( "eprint_id" );

		EPrints::Log::log_entry(
			"Forms",
			"EPrint ID in form >$form_id< doesn't match object id ".
				">$self->{eprint}->{eprintid}<" );

		return( 0 );
	}
	else
	{
		my @all_fields = EPrints::MetaInfo::get_eprint_fields(
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
# $html = render_file_view()
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

sub render_file_view
{
	my( $self, $document ) = @_;
	my $html;
	
	$html = "<CENTER><TABLE BORDER=1 CELLPADDING=3><TR><TH></TH>".
		"<TH>Filename</TH><TH>Size (Bytes)</TH><TH></TH>".
		"<TH></TH></TR>\n";
	
	my %files = $document->files();
	my $main = $document->{main};
	my $filename;
	my $filecount = 0;
	
	foreach $filename (sort keys %files)
	{
		$html .= "<TR><TD>";
		$html .= "<STRONG>Shown First -\&gt;</STRONG>"
			if( defined $main && $main eq $filename );
		
		$html .= "</TD><TD>$filename</TD><TD ALIGN=RIGHT>$files{$filename}</TD>".
			"<TD>";
		if( !defined $main || $main ne $filename )
		{
			$html .= $self->{session}->{render}->named_submit_button(
				"main_$filecount",
				"Show first" );
		}
		$html .= "</TD><TD>";
		$html .= $self->{session}->{render}->named_submit_button(
			"delete_$filecount",
			"Delete" );
		$html .= "</TD></TR>\n";
		$filecount++;
	}

	$html .= "</TABLE></CENTER>\n";
	
	$html .= "<P><CENTER>";
	$html .= $self->{session}->{render}->named_submit_button(
		"deleteall",
		"Delete All Files" );
	$html .= "</CENTER></P>\n";

	return( $html );
}

######################################################################
#
# $consumed = update_from_fileview()
#
#  Update document object according to form. If $consumed, then a
#  button on the fileview form was pressed. $consumed is left as 0
#  if the fileview didn't receive a button press (hence another button
#  must have been pressed.)
#
######################################################################

sub update_from_fileview
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
# render_format_form()
#
#  Render a table showing what formats have been uploaded for the
#  current EPrint. Buttons named "edit_<format>" (e.g. "edit_html")
#  will also be written into the table, and buttons named
#  "remove_<format>"
#
######################################################################

sub render_format_form
{
	my( $self ) = @_;

	print "<CENTER><TABLE BORDER=1 CELLPADDING=3><TR><TH><STRONG>Format</STRONG></TH>".
		"<TH><STRONG>Files Uploaded</STRONG></TH></TR>\n";
	
	my $f;
	foreach $f (@EPrintSite::SiteInfo::supported_formats)
	{
		my $req = EPrints::Document::required_format( $f );
		my $doc = $self->{eprint}->get_document( $f );
		my $numfiles = 0;
		if( defined $doc )
		{
			my %files = $doc->files();
			$numfiles = scalar( keys %files );
		} 

		print "<TR><TD>";
		print "<STRONG>" if $req;
		print $EPrintSite::SiteInfo::supported_format_names{$f};
		print "</STRONG>" if $req;
		print "</TD><TD ALIGN=CENTER>$numfiles</TD><TD>";
		print $self->{session}->{render}->named_submit_button(
			"edit_$f",
			"Upload/Edit" );
		print "</TD><TD>";
		print $self->{session}->{render}->named_submit_button(
			"remove_$f",
			"Remove" ) if( $numfiles > 0 );
		print "</TD></TR>\n";
	}

	if( $EPrintSite::SiteInfo::allow_arbitrary_formats )
	{
		my $other = $self->{eprint}->get_document( $EPrints::Document::other );
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
			"edit_$EPrints::Document::other",
			"Upload/Edit" );
		print "</TD><TD>";
		print $self->{session}->{render}->named_submit_button(
			"remove_$EPrints::Document::other",
			"Remove" ) if( $numfiles > 0 );
		print "</TD></TR>\n";
	}		

	print "</TABLE></CENTER>\n";
}		
	

######################################################################
#
# ( $format, $button ) = update_from_format_form()
#
#  Works out whether a button on the format form rendered by
#  render_format_form was pressed. If it was, the format concerned is
#  returned in $format, and the button type "remove" or "edit" is
#  given in $button.
#
######################################################################

sub update_from_format_form
{
	my( $self ) = @_;
	
	my $f;

	foreach $f (@EPrintSite::SiteInfo::supported_formats)
	{
		return( $f, "edit" )
			if( defined $self->{session}->{render}->param( "edit_$f" ) );
		return( $f, "remove" )
			if( defined $self->{session}->{render}->param( "remove_$f" ) );
	}

	return( $EPrints::Document::other, "edit" )
		if( defined $self->{eprint}->{session}->{render}->param(
			"edit_$EPrints::Document::other" ) );
	return( $EPrints::Document::other, "remove" )
		if( defined $self->{eprint}->{session}->{render}->param(
			"remove_$EPrints::Document::other" ) );
	
	return( undef, undef );
}


1;
