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

use Unicode::String qw(utf8 latin1);
use strict;

#cjg CLONE still does not work.

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
		next => "format"
	},
	format => {
		prev => "meta",
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
	my( $class, $session, $redirect, $staff, $dataset, $formtarget ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{redirect} = $redirect;
	$self->{staff} = $staff;
	$self->{dataset} = $dataset;
	$self->{formtarget} = $formtarget;

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
			( $self->{eprint}->get_value( "userid" ) ne 
			  $self->{user}->get_value( "userid" ) ) )
		{
			$self->{session}->get_archive()->log( 
				"Illegal attempt to edit record ".
				$self->{eprint}->get_value( "eprintid" ).
				" by user with id ".
				$self->{user}->get_value( "userid" ) );
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
	else
	{
		# For stages other than home, 
		# if we don't have an eprint then something's
		# gone wrong.
		if( !defined $self->{eprint} )
		{
			$self->_corrupt_err;
			return( 0 );
		}
	}

	if( !defined $STAGES->{$self->{stage}} )
	{
		# It's not a valid stage. 
		if( !defined $self->{eprint} )
		{
			$self->_corrupt_err;
			return( 0 );
		}
	}

	# Process the results of that stage - done 
	# by calling the function &_from_stage_<stage>
	my $function_name = "_from_stage_".$self->{stage};
	{
		no strict 'refs';
		$ok = $self->$function_name();
	}

print STDERR "------------------FROM done $function_name\n";

	if( $ok )
	{
		# Render stuff for next stage

		my $function_name = "_do_stage_".$self->{new_stage};
		{
print STDERR "CALLING $function_name\n";
			no strict 'refs';
			$self->$function_name();
		}
print STDERR "------------------DO done $function_name\n";
	}
	
	return( 1 );
}


## WP1: BAD
sub _corrupt_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:corrupt_err",
			line_no => $self->{session}->make_text( (caller())[2] ) ) );

}

## WP1: BAD
sub _database_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:database_err",
			line_no => $self->{session}->make_text( (caller())[2] ) ) );

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
		if( $self->{staff} )
		{
			$self->{session}->render_error( 
				$self->{session}->html_phrase(
		        		"lib/submissionform:use_auth_area" ) );
			return( 0 );
		}
		$self->{eprint} = EPrints::EPrint::create(
			$self->{session},
			$self->{dataset},
			$self->{user}->get_value( "userid" ) );

		if( !defined $self->{eprint} )
		{
			my $db_error = $self->{session}->{database}->error();
			$self->{session}->get_archive()->log( "Database Error: $db_error" );
			$self->_database_err;
			return( 0 );
		}

		$self->_set_stage_next();
		return( 1 );
	}

	if( $self->{action} eq "edit" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( 
				$self->{session}->html_phrase( 
					"lib/submissionform:nosel_err" ) );
			return( 0 );
		}

		$self->_set_stage_next;
		return( 1 );
	}


	if( $self->{action} eq $self->{session}->phrase( "lib/submissionform:action_clone" ) )
	{
		die;
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->html_phrase( "lib/submissionform:nosel_err" ) );
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

	if( $self->{action} eq "delete" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->html_phrase( "lib/submissionform:nosel_err" ) );
			return( 0 );
		}
		$self->{new_stage} = "confirmdel";
		return( 1 );
	}

	if( $self->{action} eq "submit" )
	{
		if( !defined $self->{eprint} )
		{
			$self->{session}->render_error( $self->{session}->html_phrase( "lib/submissionform:nosel_err" ) );
			return( 0 );
		}
		$self->{new_stage} = "quickverify";
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

	if( $self->{action} eq "finished" )
	{
		$self->{problems} = $self->{eprint}->validate_documents();

		if( $#{$self->{problems}} >= 0 )
		{
			# Problems, don't advance a stage
			$self->_set_stage_this;
			return( 1 )
		}

		$self->_set_stage_next;
		return( 1 );
	}

	#### The other actions ( edit & remove ) have a doc
	#### Attached to their action id.

print STDERR "=====================================\n";	
print STDERR $self->{action}."!";

	unless( $self->{action} =~ m/^([a-z]+)_(.*)$/ )
	{
		$self->_corrupt_err;
		return( 0 );
	}
	my( $doc_action, $docid ) = ( $1, $2 );
		
	# Find relevant document object
	$self->{document} = EPrints::Document->new( $self->{session}, $docid );

	if( !defined $self->{document} )
	{
		$self->_corrupt_err;
		return( 0 );
	}

	if( $doc_action eq "remove" )
	{
		# Remove the offending document
		if( !$self->{document}->remove() )
		{
			$self->_corrupt_err;
			return( 0 );
		}

		$self->{new_stage} = "format";
		return( 1 );
	}

	if( $doc_action eq "edit" )
	{
		$self->{new_stage} = "fileview";
		return( 1 );
	}

	$self->_corrupt_err;
	return( 0 );
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
		$self->{session}->param( "docid" ) );

	if( !defined $self->{document} ||
	    $self->{document}->get_value( "eprintid" ) ne $self->{eprint}->get_value( "eprintid" ) )
	{
		$self->_corrupt_err;
		return( 0 );
	}

	my %files_unsorted = $self->{document}->files();
	my @files = sort keys %files_unsorted;
	my $i;
	my $consumed = 0;
	
	print STDERR "ACTION=".$self->{action}."\n";

	# Determine which button was pressed
	if( $self->{action} eq "deleteall" )
	{
		# Delete all button
		$self->{document}->remove_all_files();
		$consumed = 1;
	}

	if( $self->{action} =~ m/^main_(\d+)/ )
	{
		if( !defined $files[$1] )
		{
			# Not a valid filenumber
			$self->_corrupt_err;
			return( 0 );
		}
		# Pressed "Show First" button for this file
		$self->{document}->set_main( $files[$1] );
		$consumed = 1;
	}

	if( $self->{action} =~ m/^delete_(\d+)/ )
	{
		if( !defined $files[$1] )
		{
			# Not a valid filenumber
			$self->_corrupt_err;
			return( 0 );
		}
		# Pressed "Delete" button for this file
		$self->{document}->remove_file( $files[$1] );
		$consumed = 1;
	}

	
	# Check to see if a fileview button was pressed, process it if necessary
	if( $consumed )
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

	if( $self->{action} eq "prev" )
	{
		$self->{new_stage} = "format";
		return( 1 );
	}

	if( $self->{action} eq "upload" )
	{
		# Set up info for next stage
		$self->{arc_format} = $self->{session}->param( "arc_format" );
		$self->{num_files} = $self->{session}->param( "num_files" );
		$self->{new_stage} = "upload";
		return( 1 );
	}

	# Fileview button wasn't pressed, and neiter was "prev" or "upload"
	# so it must (should) be "finished" -
	# Update the description if appropriate
	$self->{document}->set_value( "formatdesc",
		$self->{session}->param( "formatdesc" ) );
	$self->{document}->set_value( "format",
		$self->{session}->param( "format" ) );
	$self->{document}->set_value( "language",
		$self->{session}->param( "language" ) );
	$self->{document}->set_value( "security",
		$self->{session}->param( "security" ) );
use Data::Dumper;
print STDERR "\n-----------------\naboot to commit.\n";
print STDERR Dumper($self->{document}->{data});
	$self->{document}->commit();

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
	$self->{document} = EPrints::Document->new(
		$self->{session},
		$self->{session}->param( "docid" ) );

	if( !defined $self->{document} ||
	    $self->{document}->get_value( "eprintid" ) ne $self->{eprint}->get_value( "eprintid" ) )
	{
		$self->_corrupt_err;
		return( 0 );
	}
	
	# We need to address a common "feature" of browsers here. If a form has
	# only one text field in it, and the user types things into it and 
	# presses "return" it submits the form without setting the submit
	# button, so we can't tell whether the "Back" or "Upload" button is
	# appropriate. We have to assume that if the user's pressed return they
	# want to go ahead with the upload, so we default to the upload button:

	$self->{action} = "upload" unless( defined $self->{action} );

	if( $self->{action} eq "prev" )
	{
		$self->{new_stage} = "fileview";
		return( 1 );
	}

	if( $self->{action} eq "upload" )
	{
		my $arc_format = $self->{session}->param( "arc_format" );
		my $num_files = $self->{session}->param( "num_files" );
		# Establish a sensible max and minimum number of files.
		# (The same ones as we used to render the upload form)
		$num_files = 1 if( $num_files < 1 );
		$num_files = 1 if( $num_files > 99 ); 
		my( $success, $file );

		if( $arc_format eq "plain" )
		{
			my $i;
			for( $i=0; $i<$num_files; $i++ )
			{
				$file = $self->{session}->param( "file_$i" );
				
				$success = $self->{document}->upload( $file, $file );
			}
		}
		elsif( $arc_format eq "graburl" )
		{
			my $url = $self->{session}->param( "url" );
			$success = $self->{document}->upload_url( $url );
		}
		else
		{
			$file = $self->{session}->param( "file_0" );
			$success = $self->{document}->upload_archive( $file, $file, $arc_format );
		}
		
		if( !$success )
		{
			$self->{problems} = [
				$self->{session}->html_phrase( "lib/submissionform:upload_prob" ) ];
		}
		elsif( !defined $self->{document}->get_main() )
		{
			my %files = $self->{document}->files();
			if( scalar keys %files == 1 )
			{
				# There's a single uploaded file, make it the main one.
				my @filenames = keys %files;
				$self->{document}->set_main( $filenames[0] );
			}
		}

		$self->{document}->commit();
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
		
		if( scalar @{$problems} == 0 )
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
			my $db_error = $self->{session}->get_db()->error();
			$self->{session}->get_archive()->log( "DB error removing EPrint ".$self->{eprint}->get_value( "eprintid" ).": $db_error" );
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

	my $submit_buttons = {
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		next => $self->{session}->phrase( 
				"lib/submissionform:action_next" ) };

	$page->appendChild( $self->{session}->render_input_form( 
		[ $self->{dataset}->get_field( "type" ) ],
	        $self->{eprint}->get_data(),
	        1,
	        1,
	        $submit_buttons,
	        { stage => "type", 
		  eprintid => $self->{eprint}->get_value( "eprintid" ) },
		{},
		$self->{formtarget}."#t"
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
		$self->{formtarget}."#t"
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

	$page->appendChild( $self->{session}->html_phrase( "lib/submissionform:bib_info" ) );
	
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
			$self->{formtarget}."#t" ) );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_meta" ),
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

	# Validate again, so we know what buttons to put up and how 
	# to state stuff
	$self->{eprint}->prune_documents(); 
	my $probs = $self->{eprint}->validate_documents();

	if( @{$self->{session}->get_archive()->get_conf( "required_formats" )} >= 0 )
	{
		$page->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:least_one") );
	}

	$page->appendChild(
		$self->{session}->html_phrase(
			"lib/submissionform:valid_formats") );

	$form = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
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
	
	my $docds = $self->{session}->get_archive()->get_dataset( "document" );
	my $doc;
	foreach $doc ( $self->{eprint}->get_all_documents() )
	{
		$tr = $self->{session}->make_element( "tr" );
		$table->appendChild( $tr );
		$td = $self->{session}->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $doc->render_desc() );
		$td = $self->{session}->make_element( "td" );
		$tr->appendChild( $td );
		my %files = $doc->files();
		my $nfiles = scalar(keys %files);
		$td->appendChild( $self->{session}->make_text( $nfiles ) );
		$td = $self->{session}->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( $self->{session}->render_action_buttons(
			"edit_".$doc->get_value( "docid" ) => 
				$self->{session}->phrase( 
					"lib/submissionform:action_edit" ) ,
			"remove_".$doc->get_value( "docid" ) => 
				$self->{session}->phrase( 
					"lib/submissionform:action_remove" ) 
		) );
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
	if( scalar @{$probs} == 0 )
	{
		# docs validated ok
		$buttons{finished} = $self->{session}->phrase( "lib/submissionform:action_finished" ); 
	}
	
	$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );

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

	$page->appendChild( $self->_render_problems(
		$self->{session}->html_phrase("lib/submissionform:fix_upload"),
		$self->{session}->html_phrase("lib/submissionform:please_fix") ) );


	# The hidden fields, used by all forms.
	my $hidden_fields = {	
		docid => $self->{document}->get_value( "docid" ),
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		stage => "fileview" };

	############################

#cjg Need to make "graburl" dependent on the setted-ness of "wget"

	my $arc_format_field = EPrints::MetaField->new(
		confid=>'format',
		name=>'arc_format',
		type=>'set',
		options => [ 
				"plain", 
				"graburl", 
				@{$self->{session}->get_archive()->get_conf( 
					"archive_formats" )}
			] );		

	my $num_files_field = EPrints::MetaField->new(
		confid=>'format',
		name=>'num_files',
		type=>'int',
		digits=>2 );

	my $submit_buttons;
	$submit_buttons = {
		upload => $self->{session}->phrase( 
				"lib/submissionform:action_upload" ) };

	$page->appendChild( 
		$self->{session}->render_input_form( 
			[ 
				$arc_format_field, 
				$num_files_field 
			],
			{
				num_files => 1 
			},
			0,
			1,
			$submit_buttons,
			$hidden_fields,
			{},
			$self->{formtarget}."#t" ) );


	##################################
	#
	# Render info about uploaded files

	my %files = $self->{document}->files();

	my( $p, $table, $tr, $th, $td, $form );

	
	if( scalar keys %files == 0 )
	{
		$page->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:no_files") );
	}
	else
	{
		$form = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
		$page->appendChild( $form );

		foreach( keys %{$hidden_fields} )
		{
			$form->appendChild( $self->{session}->render_hidden_field(
				$_, $hidden_fields->{$_} ) );
		}	

		$p = $self->{session}->make_element( "p" );
		$form->appendChild( $p );
		$p->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:files_for_format") );

		if( !defined $self->{document}->get_main() )
		{
			$p->appendChild(
				$self->{session}->html_phrase(
					"lib/submissionform:sel_first") );
		}

		$table = $self->{session}->make_element( 
				"table",
				border=>"1" );
		$form->appendChild( $table );
		$tr = $self->{session}->make_element( "tr" );
		$table->appendChild( $tr );

		$th = $self->{session}->make_element( "th" );
		$tr->appendChild( $th );

		$th = $self->{session}->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:filename") );

		$th = $self->{session}->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:size_bytes") );
	
		$th = $self->{session}->make_element( "th" );
		$tr->appendChild( $th );
	
		$th = $self->{session}->make_element( "th" );
		$tr->appendChild( $th );
		
		my $main = $self->{document}->get_main();
		my $filename;
		my $filecount = 0;
		
		foreach $filename (sort keys %files)
		{
			$tr = $self->{session}->make_element( "tr" );
			$table->appendChild( $tr );

			$td = $self->{session}->make_element( "td" );
			$tr->appendChild( $td );
			if( defined $main && $main eq $filename )
			{
				#cjg Style Mee
				$td->appendChild( $self->{session}->html_phrase(
					"lib/submissionform:shown_first" ) );
				$td->appendChild( $self->{session}->make_text( latin1(" ->") ) );
			}

			$td = $self->{session}->make_element( "td" );
			$tr->appendChild( $td );
			# Iffy. Non 8bit filenames could cause a render bug. cjg
			$td->appendChild( $self->{session}->make_text( $filename ) );

			$td = $self->{session}->make_element( "td", align=>"right" );
			$tr->appendChild( $td );
			$td->appendChild( $self->{session}->make_text( $files{$filename} ) );

			$td = $self->{session}->make_element( "td" );
			$tr->appendChild( $td );
			if( !defined $main || $main ne $filename )
			{
				$td->appendChild( $self->{session}->render_action_buttons(
					"main_".$filecount => 
						$self->{session}->phrase( 
							"lib/submissionform:show_first" ) ) );
			}

			$td = $self->{session}->make_element( "td" );
			$tr->appendChild( $td );
			$td->appendChild( $self->{session}->render_action_buttons(
				"delete_".$filecount => 
					$self->{session}->phrase( 
						"lib/submissionform:delete" ) ) );

			$filecount++;
		}

		$form->appendChild( $self->{session}->render_action_buttons(
			deleteall =>
				$self->{session}->phrase( 
					"lib/submissionform:delete_all" ) ) );

		$a = $self->{session}->make_element( 
			"a", 
			href => $self->{document}->url(),
			target => "_blank" );
		$form->appendChild(
			$self->{session}->html_phrase(
				"lib/submissionform:here_to_view"),
				link=>$a );

	}

	##################################

	my $docds = $self->{session}->get_archive()->get_dataset( "document" );


	$submit_buttons = {
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ) };

	if( scalar keys %files > 0 ) {
		$submit_buttons->{finished} = $self->{session}->phrase( "lib/submissionform:action_finished" );
	}

	$page->appendChild( 
		$self->{session}->render_input_form( 
			[ 
				$docds->get_field( "format" ),
				$docds->get_field( "formatdesc" ),
				$docds->get_field( "language" ),
				$docds->get_field( "security" )
			],
			$self->{document}->get_data(),
			0,
			1,
			$submit_buttons,
			$hidden_fields,
			{},
			$self->{formtarget}."#t" ) );


# cjg Deprecate/rename these.
#	print $self->{session}->phrase("lib/submissionform:file_up_method")." ";
#	print $self->{session}->phrase("lib/submissionform:plain_only")." ";
#	print $self->{session}->phrase("lib/submissionform:num_files")." ";
#

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

	my( $page, $form, $p );

	$page = $self->{session}->make_doc_fragment();
	$form = $self->{session}->render_form( "post", $self->{formtarget}."#t" );
	$page->appendChild( $form );

	if( $self->{arc_format} eq "graburl" )
	{
		$form->appendChild( $self->{session}->html_phrase( "lib/submissionform:enter_url" ) );
		my $field = EPrints::MetaField->new( 
			name => "url",
			type => "text" );
		$form->appendChild( $field->render_input_field( $self->{session} ) );
	}
	else
	{
		$form->appendChild( $p );
		if( $self->{arc_format} eq "plain" )
		{
			if( $self->{num_files} > 1 )
			{
				$form->appendChild( $self->{session}->html_phrase("lib/submissionform:enter_files") );
			}
			else
			{
				$form->appendChild( $self->{session}->html_phrase("lib/submissionform:enter_file") );
			}
		}
		else
		{
			$self->{num_files} = 1;
			$form->appendChild( $self->{session}->html_phrase("lib/submissionform:enter_compfile") );
		}
		my $i;
		# Establish a sensible max and minimum number of files.
		$self->{num_files} = 1 if( $self->{num_files} < 1 );
		$self->{num_files} = 1 if( $self->{num_files} > 99 ); 
		for( $i=0; $i < $self->{num_files}; $i++ )
		{
			$form->appendChild( $self->{session}->render_upload_field( "file_$i" ) );
		}
	}
	
	my %hidden_fields = (
		stage => "upload",
		eprintid => $self->{eprint}->get_value( "eprintid" ),
		docid => $self->{document}->get_value( "docid" ),
		num_files => $self->{num_files},
		arc_format => $self->{arc_format} 
	);
	foreach( keys %hidden_fields )
	{
		$form->appendChild( $self->{session}->render_hidden_field(
			$_, $hidden_fields{$_} ) );
	}	

	$form->appendChild( $self->{session}->render_action_buttons(
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" ),
		upload => $self->{session}->phrase( 
				"lib/submissionform:action_upload" ) ) );


	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_upload" ),
		$page );
	$self->{session}->send_page();
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

	my( $page, $p );
	$page = $self->{session}->make_doc_fragment();

	# stage could be either verify or quickverify
	my $hidden_fields = {
		stage => $self->{new_stage},
		eprintid => $self->{eprint}->get_value( "eprintid" )
	};
	my $submit_buttons = {
		prev => $self->{session}->phrase(
				"lib/submissionform:action_prev" )
	};
	

	if( scalar @{$self->{problems}} > 0 )
	{
		# Null doc fragment past because 'undef' would cause the
		# default to appear.
		$page->appendChild( $self->_render_problems(
			$self->{session}->html_phrase("lib/submissionform:fix_probs"),
			$self->{session}->make_doc_fragment() ) );
	}
	else
	{
		$page->appendChild( $self->{session}->html_phrase("lib/submissionform:please_verify") );

		$page->appendChild( $self->{session}->render_ruler() );	
		$page->appendChild( $self->{eprint}->render_full_details() );
		$page->appendChild( $self->{session}->render_ruler() );	

		# cjg Should be from an XML-lang file NOT the main config.
		$page->appendChild( $self->{session}->html_phrase( "deposit_agreement_text" ) );

		$submit_buttons->{submit} = $self->{session}->phrase( "lib/submissionform:action_submit" );
	}

	$page->appendChild( 
		$self->{session}->render_input_form( 
			[],
			{},
			0,
			1,
			$submit_buttons,
			$hidden_fields,
			{},
			$self->{formtarget}."#t" ) );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_verify" ),
		$page );
	$self->{session}->send_page();
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
	
	my( $page );
	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->{session}->html_phrase("lib/submissionform:thanks") );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_done" ),
		$page );
	$self->{session}->send_page();
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
	
	my( $page, $p );
	$page = $self->{session}->make_doc_fragment();

	$page->appendChild( $self->{session}->html_phrase("lib/submissionform:sure_delete",
		title=>$self->{eprint}->render_short_title() ) );

	my $hidden_fields = {
		stage => "confirmdel",
		eprintid => $self->{eprint}->get_value( "eprintid" )
	};

	my $submit_buttons = {
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		confirm => $self->{session}->phrase(
				"lib/submissionform:action_confirm" )
	};

	$page->appendChild( 
		$self->{session}->render_input_form( 
			[],
			{},
			0,
			1,
			$submit_buttons,
			$hidden_fields,
			{},
			$self->{formtarget}."#t" ) );

	$self->{session}->build_page(
		$self->{session}->phrase( "lib/submissionform:title_confirmdel" ),
		$page );
	$self->{session}->send_page();
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
