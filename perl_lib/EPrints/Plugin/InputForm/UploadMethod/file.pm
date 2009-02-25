
package EPrints::Plugin::InputForm::UploadMethod::file;

use EPrints;
use EPrints::Plugin::InputForm::UploadMethod;

@ISA = ( "EPrints::Plugin::InputForm::UploadMethod" );

use strict;

sub render_tab_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:from_file" );
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	my $doc_data = { eprintid => $self->{dataobj}->get_id };

	my $repository = $self->{session}->get_repository;
	$doc_data->{format} = $repository->call( 'guess_doc_type', 
		$self->{session},
		$self->{session}->param( $self->{prefix}."_first_file" ) );

	my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
	my $document = $doc_ds->create_object( $self->{session}, $doc_data );
	if( !defined $document )
	{
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}
	my $success = EPrints::Apache::AnApache::upload_doc_file( 
		$self->{session},
		$document,
		$self->{prefix}."_first_file" );
	if( !$success )
	{
		$document->remove();
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );
		return;
	}

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}

sub render_add_document
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:new_document" ) );

	my $ffname = $self->{prefix}."_first_file";	
	my $file_button = $self->{session}->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $upload_progress_url = $session->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $add_format_button = $self->{session}->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format",
		onclick => $onclick );
	$f->appendChild( $file_button );
	$f->appendChild( $session->make_text( " " ) );
	$f->appendChild( $self->{session}->make_text( " " ) );
	$f->appendChild( $add_format_button );
	my $progress_bar = $session->make_element( "div", id => "progress" );
	$f->appendChild( $progress_bar );

	my $script = $self->{session}->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->{session}->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
	$f->appendChild( $script);
	
	return $f;
}



1;
