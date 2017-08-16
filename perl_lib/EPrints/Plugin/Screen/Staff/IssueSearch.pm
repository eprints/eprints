=head1 NAME

EPrints::Plugin::Screen::Staff::IssueSearch

=cut


package EPrints::Plugin::Screen::Staff::IssueSearch;

@ISA = ( 'EPrints::Plugin::Screen::AbstractSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "admin_actions_editorial",
			position => 550,
		},
	];

	return $self;
}

sub search_dataset
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_dataset( "eprint" );
}

sub search_filters
{
	my( $self ) = @_;

	return;
}

sub allow_export { return 1; }

sub allow_export_redir { return 1; }

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "staff/issue_search" );
}

sub from
{
	my( $self ) = @_;

	my $sconf = $self->{session}->get_repository->get_conf( "issues_search" );
	if( !defined $sconf) { $sconf = $self->default_search_config; }

	my %sopts = %{$sconf};
	$sopts{filters} = [ { meta_fields => [ 'item_issues_count' ], value => '1-', describe=>1 } ];

	$self->{processor}->{sconf} = \%sopts;

	$self->SUPER::from;
}

sub default_search_config
{
	return {
	search_fields => [
		{ meta_fields => [ "item_issues_type" ] },
		{ meta_fields => [ "item_issues_timestamp" ] },
		{ meta_fields => [ "userid.username" ] },
		{ meta_fields => [ "eprint_status" ], default=>'archive' },
		{ meta_fields => [ "creators_name" ] },
		{ meta_fields => [ "date" ] },
		{ meta_fields => [ "subjects" ] },
		{ meta_fields => [ "type" ] },
	],
	preamble_phrase => "search/issues:preamble",
	title_phrase => "search/issues:title",
	citation => "issue",
	page_size => 100,
	staff => 1,
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"bydatestamp"	 => "-datestamp",
		"bydatestampoldest" => "datestamp",
		"byfirstseen" => "item_issues",
		"bynissues" => "-item_issues_count",
	},
	default_order => "byfirstseen",
	show_zero_results => 0,
	};
}

sub _vis_level
{
	my( $self ) = @_;

	return "staff";
}

sub get_controls_before
{
	my( $self ) = @_;

	return $self->get_basic_controls_before;	
}

sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	return $result->render_citation_link_staff(
			$self->{processor}->{sconf}->{citation},  #undef unless specified
			n => [$n,"INTEGER"] );
}

# Suppress the anyall field - not interesting.
sub render_anyall_field
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
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

