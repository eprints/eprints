=head1 NAME

EPrints::Plugin::Screen::EPrint::Duplicates

=cut

package EPrints::Plugin::Screen::EPrint::Duplicates;

use base qw( EPrints::Plugin::Screen::EPrint );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{expensive} = 1;
	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 1800,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/edit" );
}

sub render_tab_title
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $eprint = $self->{processor}->{eprint};

	my $id = "eprint_duplicates_tab_title";

	my $title = $repo->xml->create_element( "span",
			id => $id,
		);
	
	$title->appendChild( $self->SUPER::render_tab_title );

	my $url = $repo->current_url( query => 0 );
	$url->query_form(
			$self->hidden_bits,
			ajax => 1,
		);
	$title->appendChild( $repo->make_javascript( <<"EOJ" ) );
new Ajax.Updater('$id', '$url', { method: 'get' });
EOJ

	return $title;
}

sub wishes_to_export { shift->EPrints::Plugin::Screen::EPrint::View::wishes_to_export }
sub export_mime_type { shift->EPrints::Plugin::Screen::EPrint::View::export_mime_type }

sub export
{
	my( $self ) = @_;

	my $xml = $self->repository->xml;

	my $title = $self->SUPER::render_tab_title;

	my $eprint = $self->{processor}->{eprint};

	if( $eprint->duplicates->count )
	{
		my $url = $self->repository->current_url( path => "static",
				"style/images/warning-icon.png" );
		$title = $xml->create_data_element( "span", $title,
			style => "padding-left: 20px; background: url('$url') no-repeat;",
		);
	}

	binmode(STDOUT, ":utf8");
	print $self->repository->xhtml->to_xhtml( $title );
	$xml->dispose( $title );
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;

	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	my $dupes = $eprint->duplicates;

	my $frag = $xml->create_document_fragment;

	local $processor->{dataset} = $eprint->{dataset};
	local $processor->{dataobj} = $eprint;
	local $processor->{results} = $dupes;

	my $plugin = $repo->plugin( "Screen::Merge",
			processor => $processor,
		);

	$frag->appendChild( $plugin->render_duplicates );

	return $frag;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2012-2012 University of Southampton.

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

