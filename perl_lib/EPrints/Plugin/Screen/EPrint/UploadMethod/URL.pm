package EPrints::Plugin::Screen::EPrint::UploadMethod::URL;

use EPrints::Plugin::Screen::EPrint::UploadMethod::File;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod::File );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{appears} = [
			{ place => "upload_methods", position => 300 },
	];

	return $self;
}

sub from
{
	my( $self, $basename ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $ffname = join('_', $basename, $self->get_id, "url");
	my $eprint = $processor->{eprint};

	my $url = Encode::decode_utf8( $session->param( $ffname ) );

	my $document = $eprint->create_subdataobj( "documents", {
		format => "other",
	});
	if( !defined $document )
	{
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}
	my $success = $document->upload_url( $url );
	if( !$success )
	{
		$document->remove();
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );
		return;
	}

	$document->set_value( "format", $session->call( 'guess_doc_type', 
		$self->{session},
		$document->get_main ) );
	$document->commit;

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$document->get_id} = 1;
}


sub render
{
	my( $self, $basename ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:new_from_url" ) );

	my $ffname = join('_', $basename, $self->get_id, "url");
	my $file_button = $self->{session}->make_element( "input",
		name => $ffname,
		size => "30",
		id => $ffname,
		);
	my $add_format_button = $self->{session}->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$basename."_add_format_".$self->get_id );
	$f->appendChild( $file_button );
	$f->appendChild( $self->{session}->make_text( " " ) );
	$f->appendChild( $add_format_button );
	
	return $f; 
}

1;
