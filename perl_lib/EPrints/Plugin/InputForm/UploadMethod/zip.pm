
package EPrints::Plugin::InputForm::UploadMethod::zip;

use EPrints;
use EPrints::Plugin::InputForm::UploadMethod;

@ISA = ( "EPrints::Plugin::InputForm::UploadMethod" );

use strict;


sub render_tab_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:from_zip" );
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	my $repo = $self->{session};

	my $doc = $self->{dataobj}->create_subdataobj( "documents", {
		format => "other",
	} );
	if( !defined $doc )
	{
		$processor->add_message( "error", $repo->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}

	my $success = EPrints::Apache::AnApache::upload_doc_archive( 
		$repo,
		$doc,
		$self->{prefix}."_first_file_zip",
		"zip" );

	if( !$success )
	{
		$doc->remove();
		$processor->add_message( "error", $repo->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );
		return;
	}

	if( !$doc->set_main( "index.html" ) && !$doc->set_main( "index.htm" ) )
	{
		my $files = $doc->value( "files" );
		if( @$files )
		{
			my $file = $files->[0];
			$doc->set_value( "main", $file->value( "filename" ) );
		}
	}

	if( $doc->is_set( "main" ) )
	{
		my $file = $doc->get_stored_file( $doc->value( "main" ) );
		$doc->set_value( "format", $repo->call( 'guess_doc_type',
			$repo,
			$file->value( "filename" ) ) );
	}

	$doc->commit;

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$doc->id} = 1;
}

sub render_add_document
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:new_from_zip" ) );

	my $ffname = $self->{prefix}."_first_file_zip";	
	my $file_button = $self->{session}->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $add_format_button = $self->{session}->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format_".$self->get_id );
	$f->appendChild( $file_button );
	$f->appendChild( $self->{session}->make_text( " " ) );
	$f->appendChild( $add_format_button );

	my $script = $self->{session}->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->{session}->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
	$f->appendChild( $script);

	return $f;
}

