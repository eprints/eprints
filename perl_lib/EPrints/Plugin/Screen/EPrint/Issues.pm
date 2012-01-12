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

		push @issues, $session->dataset( "issue" )->make_dataobj( $epdata );

		return undef;
	};

	# Run all available Issues plugins
	my @plugins = $session->get_plugins(
		{
			Handler => EPrints::CLIProcessor->new(
				session => $session,
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

	if( scalar @issues ) 
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

