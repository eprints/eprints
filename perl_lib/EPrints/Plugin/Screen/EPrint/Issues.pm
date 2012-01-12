=head1 NAME

EPrints::Plugin::Screen::EPrint::Issues

=cut

package EPrints::Plugin::Screen::EPrint::Issues;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{expensive} = 1;
	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 1500,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/issues" );
}

sub render_tab_title
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $eprint = $self->{processor}->{eprint};

	my $id = "eprint_issues_tab_title";

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

	if( $self->issues )
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

	my $eprint = $self->{processor}->{eprint};
	my $session = $eprint->{session};

	my $page = $session->make_doc_fragment;
	$page->appendChild( $self->html_phrase( "live_audit_intro" ) );

	if( my @issues = $self->issues )
	{
		my $ol = $session->make_element( "ol" );
		foreach my $issue ( @issues )
		{
			my $li = $session->make_element( "li" );
			$li->appendChild( $issue->render_description );
			$ol->appendChild( $li );
		}
		$page->appendChild( $ol );
	}
	else
	{
		$page->appendChild( $self->html_phrase( "no_live_issues" ) );
	}

	return $page;
}

sub issues
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $eprint = $self->{processor}->{eprint};

	my @issues;

	foreach my $issue (@{$eprint->value( "item_issues" )})
	{
		if( $issue->value( "status" ) =~ /^discovered|reported$/ )
		{
			push @issues, $issue;
		}
	}

	my $epdata_to_dataobj = sub {
		my( $epdata ) = @_;

		push @issues, $repo->dataset( "issue" )->make_dataobj( $epdata );

		return undef;
	};

	# Run all available Issues plugins
	my @plugins = $repo->get_plugins(
		{
			Handler => EPrints::CLIProcessor->new(
				session => $repo,
				epdata_to_dataobj => $epdata_to_dataobj,
			),
		},
		type => "Issues",
		can_accept => "dataobj/eprint",
	);

	foreach my $plugin ( @plugins )
	{
		$plugin->process_dataobj( $eprint );
		$plugin->finish;
	}

	return @issues;
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

