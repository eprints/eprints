package EPrints::Plugin::Screen::EPrint::UploadMethod;

use EPrints::Plugin::Screen::EPrint;

@ISA = qw( EPrints::Plugin::Screen::EPrint );

use strict;

# used to determine import plugin
our %MIME_TYPES = reverse qw(
    application/vnd.openxmlformats-officedocument.wordprocessingml.document	 docx
    application/vnd.ms-word.document.macroEnabled.12	 docm
    application/vnd.openxmlformats-officedocument.wordprocessingml.template	 dotx
    application/vnd.ms-word.template.macroEnabled.12	 dotm
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet	 xlsx
    application/vnd.ms-excel.sheet.macroEnabled.12	 xlsm
    application/vnd.openxmlformats-officedocument.spreadsheetml.template	 xltx
    application/vnd.ms-excel.template.macroEnabled.12	 xltm
    application/vnd.ms-excel.sheet.binary.macroEnabled.12	 xlsb
    application/vnd.ms-excel.addin.macroEnabled.12	 xlam
    application/vnd.openxmlformats-officedocument.presentationml.presentation	pptx
    application/vnd.ms-powerpoint.presentation.macroEnabled.12	 pptm
    application/vnd.openxmlformats-officedocument.presentationml.slideshow	 ppsx
    application/vnd.ms-powerpoint.slideshow.macroEnabled.12	 ppsm
    application/vnd.openxmlformats-officedocument.presentationml.template	 potx
    application/vnd.ms-powerpoint.template.macroEnabled.12	 potm
    application/vnd.ms-powerpoint.addin.macroEnabled.12	 ppam
    application/vnd.openxmlformats-officedocument.presentationml.slide	 sldx
    application/vnd.ms-powerpoint.slide.macroEnabled.12	 sldm
    application/vnd.ms-officetheme	 thmx
    application/pdf    pdf
	application/x-latex    tar.gz
	application/x-latex    tgz
);

sub render_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub from
{
	my( $self, $basename ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};

	my $ffname = join(',', $basename, $self->get_id, "file");

	my $filename = Encode::decode_utf8( $session->query->param( $ffname ) );
	my $fh = $session->query->upload( $ffname );

	if( !EPrints::Utils::is_set( $filename ) || !defined $fh )
	{
		$processor->{notes}->{upload} = {};
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );

		return 0;
	}

	my $filepath = $session->query->tmpFileName( $fh );

	my $epdata = {};

	$session->run_trigger( EPrints::Const::EP_TRIGGER_MEDIA_INFO,
		epdata => $epdata,
		filename => $filename,
		filepath => $filepath,
	);

	$epdata->{main} = $filename;
	$epdata->{files} = [{
		filename => $filename,
		filesize => (-s $fh),
		mime_type => $epdata->{format},
		_content => $fh,
	}];

	$processor->{notes}->{epdata} = $epdata;

	return 1;
}

sub render
{
	my( $self, $basename ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;
	my $ffname = join(',', $basename, $self->get_id, "file");

	my $f = $xml->create_document_fragment;

	# upload help
	$f->appendChild( $session->html_phrase( "Plugin/InputForm/Component/Upload:new_document" ) );

	# file selection button
	my $file_button = $xml->create_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);

	# progress bar
	my $upload_progress_url = $session->current_url( path => "cgi" ) . "/users/ajax/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $add_format_button = $session->render_button(
		value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$basename."_add_format_".$self->get_id,
		onclick => $onclick );
	$f->appendChild( $file_button );
	$f->appendChild( $session->make_text( " " ) );
	$f->appendChild( $add_format_button );
	$f->appendChild( $session->make_element( "div", id => "progress" ) );

	$f->appendChild( $self->render_flags( $basename ) );

	# warn if the user selected a file but didn't upload it
	my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($session->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
	$f->appendChild( $script);
	
	return $f;
}

# metadata, media, bibliography
sub render_flags
{
	my( $self, $basename ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;

	my $f = $xml->create_document_fragment;

	my $flags = $self->param( "flags" );

	my $ul = $xml->create_element( "ul", style => "list-style: none" );
	$f->appendChild( $ul );

	foreach my $i (grep { !($_ % 2) } 0..$#$flags)
	{
		my $li = $xml->create_element( "li" );
		$ul->appendChild( $li );

		my $fname = join('_', $basename, $self->get_id, "flag", $$flags[$i]);
		my $input = $xml->create_element( "input",
			type => "checkbox",
			name => $fname,
			id => $fname,
		);
		if( $flags->[$i+1] )
		{
			$input->setAttribute( checked => "yes" );
		}
		$li->appendChild( $input );
		my $label = $xml->create_element( "label",
			for => $fname,
		);
		$li->appendChild( $label );
		$label->appendChild( $session->html_phrase( "Plugin/Screen/EPrint/UploadMethod:flag:$$flags[$i]" ) );
	}

	return $f;
}

sub param_flags
{
	my( $self, $basename ) = @_;

	my $values = {};

	my $session = $self->{session};

	my $flags = $self->param( "flags" );

	foreach my $i (grep { !($_ % 2) } 0..$#$flags)
	{
		my $fname = join('_', $basename, $self->get_id, "flag", $$flags[$i]);
		$values->{$$flags[$i]} = $session->param( $fname );
	}

	return $values;
}

sub parse_and_import
{
	my( $self, $basename, $epdata ) = @_;

	my $session = $self->{session};
	my $flags = $self->param_flags( $basename );

	my $filename = $epdata->{main};
	return if !defined $filename;

	my $plugin;

	my( $ext ) = $filename =~ /\.(.+)$/;
	my $mime_type = $MIME_TYPES{$ext};
	$mime_type = "application/octet-stream" if !defined $mime_type;

	my @plugins = $session->get_plugins(
		type => "Import",
		can_produce => "dataobj/document",
		can_accept => $mime_type );
	return if !@plugins;

	return $plugins[0]->input_fh(
		dataobj => $self->{processor}->{eprint},
		filename => $filename,
		fh => $epdata->{files}->[0]->{_content},
		flags => $flags,
	);
}

1;
