
package EPrints::Plugin::InputForm::UploadMethod::file;

use EPrints;
use EPrints::Plugin::InputForm::UploadMethod;

@ISA = ( "EPrints::Plugin::InputForm::UploadMethod" );

use strict;

sub render_tab_title
{
	my( $self ) = @_;

	return $self->{handle}->html_phrase( "Plugin/InputForm/Component/Upload:from_file" );
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	my $doc_data = {
		_parent => $self->{dataobj},
		eprintid => $self->{dataobj}->get_id,
		};

	my $repository = $self->{handle}->get_repository;
	$doc_data->{format} = $repository->call( 'guess_doc_type', 
		$self->{handle},
		$self->{handle}->param( $self->{prefix}."_first_file" ) );

	my $doc_ds = $self->{handle}->get_repository->get_dataset( 'document' );
	my $document = $doc_ds->create_object( $self->{handle}, $doc_data );
	if( !defined $document )
	{
		$processor->add_message( "error", $self->{handle}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}
	my $success = EPrints::Apache::AnApache::upload_doc_file( 
		$self->{handle},
		$document,
		$self->{prefix}."_first_file" );
	if( !$success )
	{
		$document->remove();
		$processor->add_message( "error", $self->{handle}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );
		return;
	}

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}

sub render_add_document
{
	my( $self ) = @_;

	my $handle = $self->{handle};

	my $f = $self->{handle}->make_doc_fragment;

	$f->appendChild( $self->{handle}->html_phrase( "Plugin/InputForm/Component/Upload:new_document" ) );

	my $ffname = $self->{prefix}."_first_file";	
	my $file_button = $self->{handle}->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $upload_progress_url = $handle->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $add_format_button = $self->{handle}->render_button(
		value => $self->{handle}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format",
		onclick => $onclick );
	$f->appendChild( $file_button );
	$f->appendChild( $handle->make_text( " " ) );
	$f->appendChild( $self->{handle}->make_text( " " ) );
	$f->appendChild( $add_format_button );
	my $progress_bar = $handle->make_element( "div", id => "progress" );
	$f->appendChild( $progress_bar );

	my $script = $self->{handle}->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->{handle}->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
	$f->appendChild( $script);
	
	return $f;
}



1;
