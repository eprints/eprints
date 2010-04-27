package EPrints::Plugin::Screen::EPrint::UploadMethod::Expand;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		flags => [
			explode => "",
		],
		appears => [
			{ place => "upload_methods", position => 1000 },
		],
		%params );
}

sub render_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:from_compressed" );
}

sub from
{
	my( $self, $basename ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};
	
	return if !$self->SUPER::from( $basename );

	my $upload = $processor->{notes}->{upload};

	my( @plugins ) = $session->get_plugins(
		type => "Import",
		mime_type => $upload->{format},
	);

	my $plugin = $plugins[0];

	if( !defined $plugin )
	{
		$processor->add_message( "error", $self->html_phrase("no_plugin"));
		return 0;
	}

	my $list;

	my $flags = $self->param_flags( $basename );

	if( $flags->{explode} )
	{
		$list = $plugin->input_fh(
			fh => $upload->{fh},
			dataobj => $eprint,
		);
	}
	else
	{
		my $doc = $eprint->create_subdataobj( "documents", {
			format => "other",
		} );
		$list = $plugin->input_fh(
			fh => $upload->{fh},
			dataobj => $doc	
		);
		$doc->remove if !defined $list;
	}

	if( !defined $list || $list->count == 0 )
	{
		$processor->add_message( "error", $self->html_phrase( "create_failed" ) );
		return 0;	
	}

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$list->ids->[0]} = 1;
}

1;
