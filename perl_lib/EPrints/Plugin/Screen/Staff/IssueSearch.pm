=head1 NAME

EPrints::Plugin::Screen::Staff::IssueSearch

=cut


package EPrints::Plugin::Screen::Staff::IssueSearch;

use EPrints::Plugin::Screen::Search;
@ISA = ( 'EPrints::Plugin::Screen::Search' );

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

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "staff/issue_search" );
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{dataset} = $self->repository->dataset( "eprint" );
	$self->{processor}->{searchid} = "issues";

	$self->SUPER::properties_from;
}

sub default_search_config
{
	return {
		search_fields => [
			{ meta_fields => [ "item_issues.type" ] },
			{ meta_fields => [ "item_issues.status" ], default=>'discovered reported' },
			{ meta_fields => [ "userid.username" ] },
			{ meta_fields => [ "eprint_status" ], default=>'buffer archive' },
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

# Suppress the anyall field - not interesting.
sub render_anyall_field
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

# suppress dataset=
sub hidden_bits
{
	return shift->EPrints::Plugin::Screen::AbstractSearch::hidden_bits();
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

