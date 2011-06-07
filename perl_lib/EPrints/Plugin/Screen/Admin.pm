=head1 NAME

EPrints::Plugin::Screen::Admin

=cut

package EPrints::Plugin::Screen::Admin;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "key_tools",
			position => 1000,
		},
	];

	return $self;
}

sub action_lists
{
	return ( "editorial", "system", "config", "misc");
}

sub can_be_viewed
{
	my( $self ) = @_;
	
	foreach my $tab_id ( $self->action_lists )
	{
		my $list_id = "admin_actions_$tab_id";
		$list_id = "admin_actions" if $tab_id eq "misc";
		return 1 if scalar $self->action_list( $list_id );
	}
	return 0;
}

sub render
{
	my( $self ) = @_;

	my $tabs = [];
	my $labels = {};
	my $links = {};
	my $position = {};
	my $id_prefix = "ep_admin_tabs";
	my $view = $self->{session}->param( "view" );

	my $n = 1;
	foreach my $tab_id ( $self->action_lists )
	{
		my $list_id = "admin_actions_$tab_id";
		$list_id = "admin_actions" if $tab_id eq "misc";
		next unless scalar $self->action_list( $list_id );
		$view = $tab_id unless defined $view;
		push @{$tabs}, $tab_id;
		$position->{$tab_id} = $n++;
		$labels->{$tab_id} = $self->html_phrase( "tab_$tab_id" );
		$links->{$tab_id} = "?screen=".$self->{processor}->{screenid}."&view=$tab_id";
	}

	my $chunk = $self->{session}->make_doc_fragment;
	$chunk->appendChild( 
		$self->{session}->render_tabs( 
			id_prefix => $id_prefix,
			current => $view,
			tabs => $tabs,
			labels => $labels,
			links => $links,
		));

	my $panel = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panels", 
			class => "ep_tab_panel" );
	$chunk->appendChild( $panel );

	foreach my $tab_id ( @{$tabs} )
	{
		my %o;
		if( $tab_id ne $view ) { $o{style} = "display:none;";}
		my $tab = $self->{session}->make_element( 
			"div", 
			id => "${id_prefix}_panel_$tab_id", 
			%o );
		my $list_id = "admin_actions_$tab_id";
		$list_id = "admin_actions" if $tab_id eq "misc";
		$tab->appendChild( $self->render_action_list( $list_id ));
		$panel->appendChild( $tab );
	}
			
	return $chunk;
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

