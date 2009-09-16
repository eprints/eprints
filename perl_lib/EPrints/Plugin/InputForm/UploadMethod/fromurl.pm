
package EPrints::Plugin::InputForm::UploadMethod::fromurl;

use EPrints;
use EPrints::Plugin::InputForm::UploadMethod;

@ISA = ( "EPrints::Plugin::InputForm::UploadMethod" );

use strict;

sub render_tab_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:from_url" );
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	my $doc_data = {
		_parent => $self->{dataobj},
		eprintid => $self->{dataobj}->get_id,
		format=>"other"
		};

	my $repository = $self->{session}->get_repository;

	my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
	my $document = $doc_ds->create_object( $self->{session}, $doc_data );
	if( !defined $document )
	{
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}
	my $success = $document->upload_url( $self->{session}->param( $self->{prefix}."_first_file_fromurl" ) );
	if( !$success )
	{
		$document->remove();
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );
		return;
	}

	$document->set_value( "format", $repository->call( 'guess_doc_type', 
		$self->{session},
		$document->get_value( "main" ) ) );
	$document->commit;

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}


sub render_add_document
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:new_from_url" ) );

	my $ffname = $self->{prefix}."_first_file_fromurl";	
	my $file_button = $self->{session}->make_element( "input",
		name => $ffname,
		size => "30",
		id => $ffname,
		);
	my $add_format_button = $self->{session}->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format_fromurl" );
	$f->appendChild( $file_button );
	$f->appendChild( $self->{session}->make_text( " " ) );
	$f->appendChild( $add_format_button );
	
	return $f; 
}

	
