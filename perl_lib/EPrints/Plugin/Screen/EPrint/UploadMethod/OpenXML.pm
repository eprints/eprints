package EPrints::Plugin::Screen::EPrint::UploadMethod::OpenXML;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		flags => [
			metadata => "yes",
			media => "",
			bibliography => "yes",
		],
		appears => [
			{ place => "upload_methods", position => 200 },
		],
		%params );
}

sub from
{
	my( $self, $basename ) = @_;
	
	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	return if !$self->SUPER::from( $basename );

	my $epdata = $processor->{notes}->{epdata};

	my $filename = $epdata->{main};
	return if !defined $filename;

	if( $filename !~ /\.(docx|pptx|xlsx)$/ )
	{
		$processor->add_message( "error", $self->html_phrase( "unsupported_format" ) );
		return;
	}

	my $plugin = $self->{session}->plugin( "Import::OpenXML" );
	if( !$plugin )
	{
		$processor->add_message( "error", $self->html_phrase( "plugin_error" ) );
		return;
	}

	my $list = $plugin->input_fh(
		dataobj => $eprint,
		filename => $filename,
		fh => $epdata->{files}->[0]->{_content},
		flags => $self->param_flags( $basename ),
	);

	if( !defined $list || $list->count == 0 )
	{
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$list->ids->[0]} = 1;
}

1;
