package EPrints::Plugin::Screen::Admin::Restore;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ restore_repository /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1245, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "repository/backup" );
}

sub allow_restore_repository
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_restore_repository
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $rc = 1;

	my $fname = $self->{prefix}."_first_file";

	my $fh = $session->get_query->upload( $fname );
	if( defined( $fh ) )
	{
		binmode($fh);
		my $tmpfile = File::Temp->new( SUFFIX => ".tgz" );
		binmode($tmpfile);

		use bytes;
		while(sysread($fh,my $buffer,4096)) {
			syswrite($tmpfile,$buffer);
		}

		seek($tmpfile, 0, 0);
	
		my $database_name = $self->{session}->get_repository->get_conf('dbname');
		my $database_password = $self->{session}->get_repository->get_conf('dbpass');
		my $database_user = $self->{session}->get_repository->get_conf('dbuser');
		my $repository_id = $self->{session}->get_repository->get_id;
		my $eprints_base_path = $self->{session}->get_repository->get_conf('base_path');
		#my $eprints_base_path = "/tmp/test";
		my $check_path = "/tmp/test";

		my $tar_executable = $self->{session}->get_repository->get_conf('executables','tar');
		my $mysql_executable = 'mysql';
	
		`$tar_executable -zxf $tmpfile -C $check_path . `; 

		my $import_base_path;

		{
		local $EPrints::SystemSettings::conf;

		do "$check_path/perl_lib/EPrints/SystemSettings.pm";

		$import_base_path = $EPrints::SystemSettings::conf->{"base_path"};
		
		}

		my $import_archive_id = trim(`ls /tmp/test/archives/`);

		if ($import_base_path eq $eprints_base_path) {
			if ($import_archive_id eq $repository_id) {
			
				my $ret = `diff /home/dct05r/eprints/archives/preserv2/cfg/cfg.d/database.pl /tmp/test/archives/preserv2/cfg/cfg.d/database.pl`;
				if ($ret eq "") {
				
					`mv $check_path/* $eprints_base_path/`;
					$self->{processor}->add_message( "message", $session->make_text( "Repsotory Restored" ) );
					
				} else {
					$self->{processor}->add_message( "error", $session->make_text( "Unable to import this archive: Database configuration mismatch, will probably fix this is a later version." ) );
				}
				
			} else {
				$self->{processor}->add_message( "error", $session->make_text( "Unable to import this archive as it's ID does not match the one you are currently logged into. <$import_archive_id> != <$repository_id>" ) );
			}
		} else {
			$self->{processor}->add_message( "error", $session->make_text( "EPrints base paths did not match...this next version of this script will correct this for you...see how nice we are as everything could have broken!" ) );
		}

	}
	else
	{
		$self->{processor}->add_message( "error", $session->make_text( "made a boo-boo [".$session->get_query->param( $fname )."]" ) );
	}

	$self->{processor}->{screenid} = "Admin";
}	

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $session->make_doc_fragment;

	my $form = $self->{session}->render_form( "POST" );

	my $inner_panel = $self->{session}->make_element( 
			"div", 
			id => $self->{prefix}."_upload_panel_file" );

	$inner_panel->appendChild( $self->html_phrase( "backup_archive" ) );

	my $ffname = $self->{prefix}."_first_file";	
	my $file_button = $session->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $upload_progress_url = $session->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $upload_button = $session->render_button(
		value => $self->phrase( "upload" ), 
		class => "ep_form_internal_button",
		name => "_action_restore_repository",
		onclick => $onclick );
	$inner_panel->appendChild( $file_button );
	$inner_panel->appendChild( $session->make_text( " " ) );
	$inner_panel->appendChild( $upload_button );
	my $progress_bar = $session->make_element( "div", id => "progress" );
	$inner_panel->appendChild( $progress_bar );

	my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->phrase("really_next"))." ); } return true; } );" );
	$inner_panel->appendChild( $script);
	
	$inner_panel->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$form->appendChild( $inner_panel );
	$form->appendChild( $session->render_hidden_field( "_action_restore_repository", "Upload" ) );
	$html->appendChild( $form );
	
	return $html;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;
