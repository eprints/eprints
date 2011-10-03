=head1 NAME

EPrints::Plugin::Screen::EPrint::UploadMethod

=cut

package EPrints::Plugin::Screen::EPrint::UploadMethod;

use EPrints::Plugin::Screen::EPrint;

@ISA = qw( EPrints::Plugin::Screen::EPrint );

use strict;

sub render_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}

sub action_add_format
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};

	my $ffname = join('_', $self->{prefix}, "file");

	my $filename = Encode::decode_utf8( $session->query->param( $ffname ) );
	my $fh = $session->query->upload( $ffname );

	if( !EPrints::Utils::is_set( $filename ) || !defined $fh )
	{
		$processor->{notes}->{upload} = {};
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:upload_failed" ) );

		return 0;
	}

	# strip the filepath from the uploaded filename parameter
	if( $filename =~ /^[A-Z]:/i )
	{
		$filename =~ s/^.*\\//;
	}
	else
	{
		$filename =~ s/^.*\///;
	}
	$filename = EPrints->system->sanitise( $filename );

	my $filepath = $session->query->tmpFileName( $fh );

	my $epdata = {};

	$session->run_trigger( EPrints::Const::EP_TRIGGER_MEDIA_INFO,
		filepath => $filepath,
		filename => $filename,
		epdata => $epdata,
	);

	$epdata->{main} = $filename;
	$epdata->{files} = [{
		filename => $filename,
		filesize => (-s $fh),
		mime_type => $epdata->{mime_type},
		_content => $fh,
	}];

	$processor->{notes}->{epdata} = $epdata;

	return 1;
}

sub get_state_params
{
	my( $self ) = @_;

	return "";
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

