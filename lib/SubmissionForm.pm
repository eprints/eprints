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
	home => {
		next => "type"
	},
	type => {
		prev => "return",
		next => "linking"
	},
	linking => {
		prev => "type",
		next => "meta"
	},
	meta => {
		prev => "linking",
		next => "subject"
	},
	subject => {
		prev => "meta",
		next => "format"
	},
	format => {
		prev => "subject",
		next => "verify"
	},
	fileview => {},
	upload => {},
	verify => {
		prev => "format",
		next => "done"
	},
	quickverify => {
		prev => "return",
		next => "done"
	},
	done => {},
	return => {},
	confirmdel => {
		prev => "return",
		next => "return"
	}
};

#cjg SKIP STAGES???
#cjg "NEW" sets defaults?

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
	
	$self->{action}    = $self->{session}->get_action_button();
	$self->{stage}     = $self->{session}->param( "stage" );
	$self->{eprintid}  = $self->{session}->param( "eprintid" );
	$self->{user}      = $self->{session}->current_user();

	# If we have an EPrint ID, retrieve its entry from the database
	if( defined $self->{eprintid} )
	{
		$self->{eprint} = EPrints::EPrint->new( $self->{session},
		                                        $self->{dataset},
		                                        $self->{eprintid} );

		# Check it was retrieved OK
		if( !defined $self->{eprint} )
		{
			my $db_error = $self->{session}->get_db()->error;
			#cjg LOG..
			$self->{session}->log( "Database Error: $db_error" );
			$self->_database_err;
			return( 0 );
		}

		# check that we got the record we wanted - if we didn't
		# then something is heap big bad. ( This is being a bit
		# over paranoid, but what the hell )
		if( $self->{session}->param( "eprintid" ) ne
	    		$self->{eprint}->get_value( "eprintid" ) )
		{
			my $form_id = $self->{session}->param( "eprintid" );
			$self->{session}->get_archive()->log( 
				"Form error: EPrint ID in form ".
				$self->{session}->param( "eprintid" ).
				" doesn't match object id ".
				$self->{eprint}->get_value( "eprintid" ) );
			$self->_corrupt_err;
			return( 0 );
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
			return( 0 );
		}
	}

	$self->{problems} = [];
	my $ok = 1;
	# Process data from previous stage

	if( !defined $self->{stage} )
	{
		$self->{stage} = "home";
	}

	if( defined $STAGES->{$self->{stage}} )
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
print STDERR "SUBMISSION done $function_name\n";
	}
	else
	{
		$self->_corrupt_err;
		return( 0 );
	}
print STDERR "xxxxxxxxxxxxxxxxxxxxxxxx\n";

	if( $ok )
	{
		# Render stuff for next stage

		my $function_name = "_do_stage_".$self->{new_stage};
		{
print STDERR "CALLING $function_name\n";
			no strict 'refs';
			$self->$function_name();
		}
	}
	
	return( 1 );
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
# there isn't one. This may change. $self->{new_stage} should be the
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
sub _from_stage_home
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

				$self->_set_stage_next();
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
			$self->_set_stage_next;
			return( 1 );
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
			$self->{new_stage} = "return";
		}
		else
		{
			my $error = $self->{session}->{database}->error();
			$self->{session}->log( "SubmissionForm error: Error cloning EPrint ".$self->{eprint}->{eprintid}.": $error" );	#cjg!!
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
		$self->{new_stage} = $EPrints::SubmissionForm::stage_confirmdel;
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_submit") )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->phrase( "lib/submissionform:nosel_err" ) );
			return( 0 );
		}
		$self->{new_stage} = $EPrints::SubmissionForm::stage_quickverify;
	}
	elsif( $self->{action} eq $self->{session}->phrase("lib/submissionform:action_cancel") )
	{
		$self->_set_stage_prev;
	}

	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
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
			$self->_set_stage_this();
			return( 1 );
		}

		# No problems, onto the next stage
		$self->_set_stage_next();
		return( 1 );
	}

	if( $self->{action} eq "cancel" )
	{
		# Cancelled, go back to author area.
		$self->_set_stage_prev();
		return( 1 );
	}

	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
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
			$self->_set_stage_this;
			return( 1 );
		}

		# No problems, onto the next stage
		$self->_set_stage_next;
		return( 1 );
	}

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}

	if( $self->{action} eq "verify" )
	{
		# Just stick with this... want to verify ID's
		$self->_set_stage_this;
		return( 1 );
	}
	
	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
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

	my @fields = $self->{dataset}->get_type_fields( $self->{eprint}->get_value( "type" ) );

	my $field;
	foreach $field (@fields)
	{
		$self->_update_from_form( $field->get_name() );
	}
	$self->{eprint}->commit();

	# What stage now?

	if( $self->{session}->internal_button_pressed() )
	{
		# Leave the form as is
		$self->_set_stage_this;
		return( 1 );
	}

	if( $self->{action} eq "next" )
	{
		# validation checks
		$self->{problems} = $self->{eprint}->validate_meta();

		if( scalar @{$self->{problems}} > 0 )
		{
			# There were problems with the uploaded type, don't move further
			$self->_set_stage_this;
			return( 1 );
		}

		# No problems, onto the next stage
		$self->_set_stage_next;
		return( 1 );
	}

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}
	
	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
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
print STDERR "sigh?\n";
	# Process uploaded data
	$self->_update_from_form( "subjects" );
	$self->_update_from_form( "additional" );
	$self->_update_from_form( "reasons" );
	$self->{eprint}->commit();
	
	if( $self->{action} eq "next" )
	{
		$self->{problems} = $self->{eprint}->validate_subject();
		if( scalar @{$self->{problems}} > 0 )
		{
			# There were problems with the uploaded type, don't move further
			$self->_set_stage_this;
			return( 1 );
		}

		# No problems, onto the next stage
		$self->_set_stage_next;
		return( 1 );
	}

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}

	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
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

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}
		
	if( $self->{action} eq "upload" )
	{
		$self->{document} = EPrints::Document::create( 
			$self->{session},
			$self->{eprint} );
		if( !defined $self->{document} )
		{
			$self->_database_err;
			return( 0 );
		}

		$self->{new_stage} = "fileview";
		return( 1 );
	}

	# edit
	# finished	
	# remove

####	x17
#	my( $format, $button ) = $self->_update_from_format_form();
#
#	if( defined $format )
#	{
#		# Find relevant document object
#		$self->{document} = $self->{eprint}->get_document( $format );
#
#		if( $button eq "remove" )
#		{
#			# Remove the offending document
#			if( !defined $self->{document} || !$self->{document}->remove() )
#			{
#				$self->_corrupt_err;
#				return( 0 );
#			}
#
#			$self->{new_stage} = $EPrints::SubmissionForm::stage_format;
#			return( 1 );
#		}

#		if( $button eq "edit" )
#		{
#			# Edit the document, creating it first if necessary
#			if( !defined $self->{document} )
#			{
#				# Need to create a new doc object
#				$self->{document} = EPrints::Document::create( $self->{session},
#				                                               $self->{eprint},
#				                                               $format );
#
#				if( !defined $self->{document} )
#				{
#					$self->_database_err;
#					return( 0 );
#				}
#			}
#
#			$self->{new_stage} = $EPrints::SubmissionForm::stage_fileview;
#			return( 1 );
#		}
#
#		$self->_corrupt_err;
#		return( 0 );
#	}

#	if( $self->{action} eq "prev" )
#	{
#		# prev stage depends if we're linking users or not
#		$self->_set_stage_prev;
#		return( 1 );
#	}

#	if( $self->{action} eq "finished" )
#	{
#		$self->{problems} = $self->{eprint}->validate_documents();
#
#		if( $#{$self->{problems}} >= 0 )
#		{
#			# Problems, don't advance a stage
#			$self->_set_stage_this;
#			return( 1 )
#		}
#
#		$self->_set_stage_next;
#		return( 1 );
#	}
#
#
#	$self->_corrupt_err;
#	return( 0 );
#		
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
	    $self->{document}->{eprintid} ne $self->{eprint}->{eprintid} )#cjg!!
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
		
		$self->{new_stage} = "fileview";
		return( 1 );
	}
	

	# Fileview button wasn't pressed, so it was an action button
	# Update the description if appropriate
	if( $self->{document}->{format} eq $EPrints::Document::OTHER )
	{
		$self->{document}->{formatdesc} =
			$self->{session}->{render}->param( "formatdesc" );
		$self->{document}->commit();
	}

	if( $self->{action} eq "prev" )
	{
		$self->{new_stage} = "fileview";
		return( 1 );
	}

	if( $self->{action} eq "upload" )
	{
		# Set up info for next stage
		$self->{arc_format} =
			$self->{session}->{render}->param( "arc_format" );
		$self->{numfiles} = $self->{session}->{render}->param( "numfiles" );
		$self->{new_stage} = "upload";
		return( 1 );
	}
	
	if( $self->{action} eq "finished" )
	{
		# Finished uploading apparently. Validate.
		$self->{problems} = $self->{document}->validate();
			
		if( $#{$self->{problems}} >= 0 )
		{
			$self->{new_stage} = "fileview";
			return( 1 );
		}

		$self->{new_stage} = "format";
		return( 1 );
	}
	
	# Erk! Unknown action.
	$self->_corrupt_err;
	return( 0 );
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

	if( !defined $doc || $doc->{eprintid} ne $self->{eprint}->{eprintid} )#cjg!!
	{
		$self->_corrupt_err;
		return( 0 );
	}
	
	# We need to address a common "feature" of browsers here. If a form has
	# only one text field in it, and the user types things into it and presses
	# button, so we can't tell whether the "Back" or "Upload" button is
	# appropriate. We have to assume that if the user's pressed return they
	# want to go ahead with the upload, so we default to the upload button:

	$self->{action} = "upload" unless( defined $self->{action} );

	if( $self->{action} eq "prev" )
	{
		$self->{new_stage} = "fielview";
		return( 1 );
	}

	if( $self->{action} eq "upload" )
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
		$self->{new_stage} = "fileview";
		return( 1 );
	}
	
	$self->_corrupt_err;
	return( 0 );
}	

######################################################################
#
#  Come from verify page
#
######################################################################

## WP1: BAD
sub _from_stage_quickverify { return $_[0]->_from_stage_verify; }

sub _from_stage_verify
{
	my( $self ) = @_;

	if( $self->{action} eq "prev" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}

	if( $self->{action} eq "submit" )
	{
		# Do the commit to the archive thang. One last check...
		my $problems = $self->{eprint}->validate_full();
		
		if( $#{$problems} ==-1 )
		{
			# OK, no problems, submit it to the archive
			if( $self->{eprint}->submit() )
			{
				$self->_set_stage_next;
				return( 1 );
			}
	
			$self->_database_err;
			return( 0 );
		}
		
		# Have problems, back to verify
		$self->_set_stage_this;
		return( 1 );
	}

	$self->_corrupt_err;
	return( 0 );
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

	if( $self->{action} eq "confirm" )
	{
		if( !$self->{eprint}->remove() )
		{
			my $db_error = $self->{session}->{database}->error();
			$self->{session}->get_archive()->log( "DB error removing EPrint ".$self->{eprint}->{eprintid}.": $db_error" );#cjg!!
			$self->_database_err;
			return( 0 );
		}

		$self->_set_stage_next;
		return( 1 );
	}

	if( $self->{action} eq "cancel" )
	{
		$self->_set_stage_prev;
		return( 1 );
	}
	
	# Don't have a valid action!
	$self->_corrupt_err;
	return( 0 );
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
		  eprintid => $self->{eprint}->get_value( "eprintid" ) },
		{},
		"submit#t"
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
		$self->{session}->get_archive()->get_dataset( "archive" );
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
		  eprintid => $self->{eprint}->get_value( "eprintid" ) },
		$comment,
		"submit#t"
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

	$page->appendChild( $self->_render_problems() );

	$p = $self->{session}->make_element( "p" );

	my $intro = $self->{session}->html_phrase( 
			"lib/submissionform:bib_info",
			star => $self->{session}->make_element(
					"span",
					class => "requiredstar" ) );	
	$p->appendChild( $intro );
	$page->appendChild( $p );
	
	my @edit_fields = $self->{dataset}->get_type_fields( $self->{eprint}->get_value( "type" ) );

	my $hidden_fields = {	
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		stage => "meta" };

	my $submit_buttons = {
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };

	$page->appendChild( 
		$self->{session}->render_input_form( 
			\@edit_fields,
			$self->{eprint}->get_data(),
			1,
			1,
			$submit_buttons,
			$hidden_fields,
			{},
			"submit#t" ) );

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

	my( $page );

	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	my $hidden_fields = {	
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		stage => "subject" };

	my $submit_buttons = {
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };


	my @edit_fields;
	push @edit_fields, $self->{dataset}->get_field( "subjects" );
	push @edit_fields, $self->{dataset}->get_field( "additional" );
	push @edit_fields, $self->{dataset}->get_field( "reasons" );

	$page->appendChild( 
		$self->{session}->render_input_form( 
			\@edit_fields,
			$self->{eprint}->get_data(),
			0,
			1,
			$submit_buttons,
			$hidden_fields,
			{},
			"submit#t" ) );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_subject" ),
		$page );
	$self->{session}->send_page();
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

	my( $page, $p, $form, $table, $tr, $td, $th  );

	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->_render_problems() );

	##########################
	# Validate again, so we know what buttons to put up and how 
	# to state stuff
	# $self->{eprint}->prune_documents(); cjg
	# my $probs = $self->{eprint}->validate_documents();

	if( @{$self->{session}->get_archive()->get_conf( "required_formats" )} >= 0 )
	{
		$p = $self->{session}->make_element( "p" );
		$p->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:least_one") );
		$page->appendChild( $p );
	}

	$p = $self->{session}->make_element( "p" );
	$p->appendChild(
		$self->{session}->html_phrase(
			"lib/submissionform:valid_formats") );
	$page->appendChild( $p );

	$form = $self->{session}->render_form( "post" );
	$page->appendChild( $form );

	$table = $self->{session}->make_element( "table", border=>1 );
	$form->appendChild( $table );
	$tr = $self->{session}->make_element( "tr" );
	$table->appendChild( $tr );
	$th = $self->{session}->make_element( "th" );
	$tr->appendChild( $th );
	$th->appendChild( 
		$self->{session}->html_phrase("lib/submissionform:format") );
	$th = $self->{session}->make_element( "th" );
	$tr->appendChild( $th );
	$th->appendChild( 
		$self->{session}->html_phrase("lib/submissionform:files_uploaded") );

	
	my $doc;
	foreach $doc ( $self->{eprint}->get_all_documents() )
	{
		$tr = $self->{session}->make_element( "tr" );
		$table->appendChild( $tr );
		my $nfiles = "???";
		$td = $self->{session}->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $self->{session}->make_text("cjg:format(".$doc->get_value( "format" ).")") );
		my $desc = $doc->get_value( "formatdesc" ); 
		# not calling proper render function here. cjg
		if( defined $desc )
		{
			$td->appendChild( $self->{session}->make_text( " ( $desc )" ) );
		}
		$td = $self->{session}->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $self->{session}->make_text( $nfiles ) );
		$td = $self->{session}->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $self->{session}->render_action_buttons(
			"edit_".$doc->get_value( "docid" ) => 
				$self->{session}->phrase( 
					"lib/submissionform:action_edit" ) ) );
	}

	$form->appendChild( $self->{session}->render_action_buttons(
		upload => $self->{session}->phrase( 
				"lib/submissionform:action_upload" ) ) );
		
	$form->appendChild( $self->{session}->render_hidden_field(
		"stage",
		"format" ) );
	$form->appendChild( $self->{session}->render_hidden_field(
		"eprintid",
		$self->{eprint}->get_value( "eprintid" ) ) );

	my %buttons;
	$buttons{prev} = $self->{session}->phrase( "lib/submissionform:action_prev" );
	$buttons{finished} = $self->{session}->phrase( "lib/submissionform:action_finished" ) ; #cjg IF NO PROBS...
	
	$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );

#	my $f;
#	foreach $f (@{$self->{session}->get_archive()->get_conf( "supported_formats" )})
#	{
#		my $req = EPrints::Document::required_format( $self->{session} , $f );
#		my $doc = $self->{eprint}->get_document( $f );
#		my $numfiles = 0;
#		if( defined $doc )
#		{
#			my %files = $doc->files();
#			$numfiles = scalar( keys %files );
#		} 
#
#		print "<TR><TD>";
#		print "<STRONG>" if $req;
#		print EPrints::Document::format_name( $self->{session}, $f );
#		print "</STRONG>" if $req;
#		print "</TD><TD ALIGN=CENTER>$numfiles</TD><TD>";
#		print $self->{session}->{render}->named_submit_button(
#			"edit_$f",
#			$self->{session}->phrase("lib/submissionform:action_uploadedit") );
#		print "</TD><TD>";
#		if( $numfiles > 0 )
##		{
#			print $self->{session}->{render}->named_submit_button(
#				"remove_$f",
#				$self->{session}->phrase("lib/submissionform:remove") );
#		}
#		print "</TD></TR>\n";
#	}
#
#	if( $self->{session}->get_archive()->get_conf( "allow_arbitrary_formats" ) )
#	{
#		my $other = $self->{eprint}->get_document( $EPrints::Document::OTHER );
#		my $othername = "Other";
#		my $numfiles = 0;
#		
#		if( defined $other )
#		{
#			$othername = $other->{formatdesc} if( $other->{formatdesc} ne "" );
#			my %files = $other->files();
#			$numfiles = scalar( keys %files );
#		} 
#
#		print "<TR><TD>$othername</TD><TD ALIGN=CENTER>$numfiles</TD><TD>";
#		print $self->{session}->{render}->named_submit_button(
#			"edit_$EPrints::Document::OTHER",
#			$self->{session}->phrase("lib/submissionform:uploadedit") );
#		print "</TD><TD>";
#		if( $numfiles > 0 )
#		{
#			print $self->{session}->{render}->named_submit_button(
#				"remove_$EPrints::Document::OTHER",
#				$self->{session}->phrase("lib/submissionform:remove") );
#		}
#		print "</TD></TR>\n";
#	}		
#
#	print "</TABLE></CENTER>\n";
#


	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_format" ),
		$page );
	$self->{session}->send_page();

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

	my $page = $self->{session}->make_doc_fragment();

	my $doc = $self->{document};

	my $arc_format_field = EPrints::MetaField->new(
		config=>'format',
		name=>'arcformat',
		type=>'set',
		options => [ 
				"plain", 
				"graburl", 
				@{$self->{session}->get_archive()->get_conf( "supported_archive_formats" )}
			] );		

	my $num_files_field = EPrints::MetaField->new(
		config=>'format',
		name=>'nfields',
		type=>'int',
		digits=>2 );

	my $hidden_fields = {	
		docid => $doc->get_value( "docid" ),
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		stage => "subject" };

	my $submit_buttons = {
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		upload => $self->{session}->phrase( 
				"lib/submissionform:action_upload" ) };

	#if( scalar keys %files > 0 ) {
		$submit_buttons->{finished} = $self->{session}->phrase("lib/submissionform:action_finished");
	#}
	$page->appendChild( $self->_render_problems(
		$self->{session}->phrase("lib/submissionform:fix_upload"),
		$self->{session}->phrase("lib/submissionform:please_fix") ) );


	$page->appendChild( 
		$self->{session}->render_input_form( 
			[ $arc_format_field, $num_files_field ],
			{},
			0,
			1,
			$submit_buttons,
			$hidden_fields,
			{},
			"submit#t" ) );

	
#
#
#	# Render the form
#
#	print $self->{session}->{render}->start_html(
#		$self->{session}->phrase(
#			$EPrints::SubmissionForm::stage_titles{
#				$EPrints::SubmissionForm::stage_fileview} ) );
#
#	print $self->{session}->{render}->start_form();
#	
#	# Format description, if appropriate
#
#	if( $doc->{format} eq $EPrints::Document::OTHER )
#	{
#		my $ds = $self->{session}->get_archive()->get_dataset( "document" );
#		my $desc_field = $ds->get_field( "formatdesc" );
#
#		print "<P><CENTER><EM>$desc_field->{help}</EM></CENTER></P>\n";
#		print "<P><CENTER>";
#		print $self->{session}->{render}->input_field( $desc_field, 
#		                                               $doc->{formatdesc} );
#		print "</CENTER></P>\n";
#	}
#	
#	# Render info about uploaded files
#
#	my %files = $doc->files();
#	
#	if( scalar keys %files == 0 )
#	{
#		print "<P><CENTER><EM>";
#		print $self->{session}->phrase("lib/submissionform:no_files");
#		print "</EM></CENTER></P>\n";
#	}
#	else
#	{
#		print "<P><CENTER>";
#		print $self->{session}->phrase("lib/submissionform:files_for_format");
#
#		if( !defined $doc->get_main() )
#		{
#			print $self->{session}->phrase("lib/submissionform:sel_first");
#		}
#
#		print "</CENTER></P>\n";
#		print $self->_render_file_view( $doc );
#
#		print "<P ALIGN=CENTER><A HREF=\"".$doc->url()."\" TARGET=_blank>";
#		print $self->{session}->phrase("lib/submissionform:here_to_view");
#		print "</A></P>\n";
#	}
#
#	# Render upload file options
#	print "<P><CENTER>";
#	print $self->{session}->phrase("lib/submissionform:file_up_method")." ";
#	print $self->{session}->{render}->input_field( $arc_format_field, "plain" );
#
#	print "</CENTER></P>\n<P><CENTER><em>";
#	print $self->{session}->phrase("lib/submissionform:plain_only")." ";
#	print "</em> ";
#	print $self->{session}->phrase("lib/submissionform:num_files")." ";
#	print $self->{session}->{render}->input_field( $num_files_field, 1 );
#	print "</CENTER></P>\n";
#
#	# Action buttons
#	print "<P><CENTER>";
#	print $self->{session}->{render}->submit_buttons( \@buttons );
#	print "</CENTER></P>\n";
#		
#	print $self->{session}->{render}->hidden_field(
#		"stage",
#		$EPrints::SubmissionForm::stage_fileview );
#	print $self->{session}->{render}->hidden_field(
#		"eprintid",
#		$self->{eprint}->{eprintid} );
#	print $self->{session}->{render}->hidden_field( "doc_id", $doc->{docid} );
#
#	$self->{session}->{render}->end_form();


	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_fileview" ),
		$page );
	$self->{session}->send_page();
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
		"eprintid",
		$self->{eprint}->{eprintid} );#cjg!!!
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
sub _do_stage_quickverify { return $_[0]->_do_stage_verify; }

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
	
	print $self->{session}->{render}->hidden_field(
		"stage",
		$EPrints::SubmissionForm::stage_verify );
	print $self->{session}->{render}->hidden_field(
		"eprintid",
		$self->{eprint}->{eprintid} );#cjg!!

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
		"eprintid",
		$self->{eprint}->{eprintid} );#cjg!!
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

	$self->{session}->redirect( $self->{redirect} );
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


sub _set_stage_next
{
	my( $self ) = @_;

	$self->{new_stage} = $STAGES->{$self->{stage}}->{next};
}

sub _set_stage_prev
{
	my( $self ) = @_;

	$self->{new_stage} = $STAGES->{$self->{stage}}->{prev};
}

sub _set_stage_this
{
	my( $self ) = @_;

	$self->{new_stage} = $self->{stage};
}

1;
