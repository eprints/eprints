=head1 NAME

EPrints::Plugin::Screen::Admin::EPM

=cut

package EPrints::Plugin::Screen::Admin::EPM;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [];
		
	$self->{appears} = [
		{ 
			place => "admin_actions_system", 
			position => 1450, 
		},
	];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	my $dataset = $processor->{dataset} = $repo->dataset( "epm" );

	my $epmid = $repo->param( "dataobj" );
	if( defined $epmid )
	{
		$processor->{dataobj} = $dataset->dataobj( $epmid );
	}

	$processor->{sources} = $repo->config( "epm", "sources" );
	$processor->{sources} = [
		{ name => "EPrints Bazaar", base_url => "http://bazaar.eprints.org/" },
	] if !defined $processor->{sources};
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $url = URI->new( $self->SUPER::redirect_to_me_url );

	$url->query_form(
		$url->query_form,
		%{$self->{processor}->{notes}},
	);

	return $url;
}

sub wishes_to_export { shift->{repository}->param( "ajax" ) }

sub export_mime_type { "text/html;charset=utf-8" }

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "repository/epm" );
}

sub export
{
	my( $self ) = @_;

	my $current = $self->{repository}->param( "ep_tabs_current" );
	$current = "" if !defined $current;

	my $screen;

	foreach my $item ($self->list_items( "admin_epm_tabs" ))
	{
		next if !$item->{screen}->can_be_viewed;
		$screen = $item->{screen}, last
			if $item->{screen}->get_subtype eq $current;
	}

	return if !defined $screen;

	my $content = $screen->render;
	binmode(STDOUT, ":utf8");
	print $self->{repository}->xhtml->to_xhtml( $content );
	$self->{repository}->xml->dispose( $content );
}

sub render_links
{
	my( $self ) = @_;

	my $frag = $self->{repository}->xml->create_document_fragment;

	foreach my $item ($self->list_items( "admin_epm_tabs" ))
	{
		next if !$item->{screen}->can_be_viewed;
		$frag->appendChild( $item->{screen}->render_links );
	}

	return $frag;
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	my $current = $repo->param( "ep_tabs_current" );
	$current = "" if !defined $current;

	my @labels;
	my @tabs;
	my @expensive;
	my %aliases;

	my $i = 0;
	foreach my $item ($self->list_items( "admin_epm_tabs" ))
	{
		next if !$item->{screen}->can_be_viewed;
		my $screen = $item->{screen};

		push @labels, $screen->render_title;
		if( $screen->get_subtype ne $current && $screen->param( "expensive" ) )
		{
			push @tabs, $repo->html_phrase( "cgi/users/edit_eprint:loading" );
			push @expensive, $i;
		}
		else
		{
			push @tabs, $screen->render;
		}
		$aliases{$i} = $screen->get_subtype;
		++$i;
	}

	return $xhtml->tabs( \@labels, \@tabs,
		current => $current,
		expensive => \@expensive,
		aliases => \%aliases,
	);
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

