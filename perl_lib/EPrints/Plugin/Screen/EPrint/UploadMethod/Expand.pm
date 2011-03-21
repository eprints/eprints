=head1 NAME

EPrints::Plugin::Screen::EPrint::UploadMethod::Expand

=cut

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
		actions => [qw( add_format )],
		%params );
}

sub render_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:from_compressed" );
}

sub allow_add_format { shift->can_be_viewed }

sub action_add_format
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};
	
	return if !$self->SUPER::action_add_format();

	my $epdata = $processor->{notes}->{epdata};
	return if !defined $epdata->{main};

	my( @plugins ) = $session->get_plugins(
		type => "Import",
		can_produce => "dataobj/document",
		can_accept => $epdata->{format},
	);

	my $plugin = $plugins[0];

	if( !defined $plugin )
	{
		$processor->add_message( "error", $self->html_phrase("no_plugin",
			mime_type => $session->make_text( $epdata->{format} )
		));
		return 0;
	}

	my $list;

	my $flags = $self->param_flags();

	my $fh = $epdata->{files}->[0]->{_content};
	if( $flags->{explode} )
	{
		$list = $plugin->input_fh(
			fh => $fh,
			dataobj => $eprint,
		);
	}
	else
	{
		my $doc = $eprint->create_subdataobj( "documents", {
			format => "other",
		} );
		$list = $plugin->input_fh(
			fh => $fh,
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

