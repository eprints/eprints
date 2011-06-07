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

sub render
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $session = $eprint->{session};

	my $page = $session->make_doc_fragment;
	$page->appendChild( $self->html_phrase( "live_audit_intro" ) );


	# Run all available Issues plugins
	my @issues_plugins = $session->plugin_list(
		type=>"Issues",
		is_available=>1 );
	my @issues = ();
	foreach my $plugin_id ( @issues_plugins )
	{
		my $plugin = $session->plugin( $plugin_id );
		push @issues, $plugin->item_issues( $eprint );
	}

	if( scalar @issues ) 
	{
		my $ol = $session->make_element( "ol" );
		foreach my $issue ( @issues )
		{
			my $li = $session->make_element( "li" );
			$li->appendChild( $issue->{description} );
			$ol->appendChild( $li );
		}
		$page->appendChild( $ol );
	}
	else
	{
		$page->appendChild( $self->html_phrase( "no_live_issues" ) );
	}

	if( $eprint->get_value( "item_issues_count" ) > 0 )
	{
		$page->appendChild( $self->html_phrase( "issues" ) );
		$page->appendChild( $eprint->render_value( "item_issues" ) );
	}

	return $page;
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

