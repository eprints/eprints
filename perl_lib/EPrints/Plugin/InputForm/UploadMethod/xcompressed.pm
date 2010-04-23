
package EPrints::Plugin::InputForm::UploadMethod::xcompressed;

use EPrints;
use EPrints::Plugin::InputForm::UploadMethod;

@ISA = ( "EPrints::Plugin::InputForm::UploadMethod" );

use strict;


sub render_tab_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:from_compressed" );
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	my $repo = $self->{session};
	
	my $cgi = $repo->get_query;

	my $filename = Encode::decode_utf8( $cgi->param( $self->{prefix}."_first_file_xcompressed" ) );

	my $mime_type = $repo->call('guess_doc_type',$repo,$filename );

	my( @plugins ) = $repo->get_plugins(
			type=>"Import",
			mime_type => $mime_type,
			);

	my $plugin = $plugins[0];

	if (!(defined $plugin)) {
		$processor->add_message( "error", $self->html_phrase("no_plugin"));
		return 0;
	}

	my $upload_type = $self->{session}->param( $self->{prefix}."_upload_type" );
	my $return_list;
	if ($upload_type eq "single") {
		my $doc = $self->{dataobj}->create_subdataobj( "documents", {
				format => "other",
				} );
		$return_list = $plugin->input_fh(
			fh=>$cgi->upload( $self->{prefix}."_first_file_xcompressed" ),
			dataobj=>$doc	
			);
		if (!defined $return_list) {
			$doc->remove();
		}
	} else {
		$return_list = $plugin->input_fh(
			fh=>$cgi->upload( $self->{prefix}."_first_file_xcompressed" ),
			dataobj=>$self->{dataobj}
			);
	}
	if (!defined $return_list) {
		$processor->add_message( "error", $self->html_phrase("failed"));
		return 0;	
	}
}

sub render_add_document
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:new_from_compressed" ) );

	my $ffname = $self->{prefix}."_first_file_xcompressed";	
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


	my $opt_box = $self->{session}->make_element( "div", "style"=>"padding: 15px;" );
	$f->appendChild( $opt_box );

	$opt_box->appendChild( $self->html_phrase( "extract_type" ) );

	my @tags = ( "single", "multiple" );
        my %labels = (
	"single" => $self->phrase( "single" ),
	"multiple"   => $self->phrase( "multiple" )
	);
	
	my $separate_documents_option = $self->{session}->render_option_list( 
		name=>$self->{prefix}."_upload_type",	
		id=>$self->{prefix}."_upload_type",	
		multiple=>0,
		values=>\@tags,
		default=>( $tags[0] ),
		labels => \%labels 
	);
	
	$opt_box->appendChild($separate_documents_option);

	my $script = $self->{session}->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->{session}->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
	$f->appendChild( $script);

	return $f;
}

