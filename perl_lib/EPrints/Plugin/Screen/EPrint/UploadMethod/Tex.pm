package EPrints::Plugin::Screen::EPrint::UploadMethod::Tex;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		flags => [
			media => "yes",
			bibliography => "yes",
		],
		appears => [
			{ place => "upload_methods", position => 250 },
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

	my $flags = $self->param_flags( $basename );

	my $importer = $session->plugin( "Import::Tex",
		Handler => $processor,
	);

	my $list = $importer->input_fh(
		fh => $epdata->{files}->[0]->{_content},
		filename => $filename,
		dataobj => $eprint,
		flags => $flags,
	);

	my $ids = $list->ids;
	foreach my $id (@$ids)
	{
		$processor->{notes}->{upload_plugin}->{to_unroll}->{$id} = 1;
	}
}

1;
