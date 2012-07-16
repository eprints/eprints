=head1 NAME

EPrints::Plugin::Screen::Review

=cut


package EPrints::Plugin::Screen::Review;

use EPrints::Plugin::Screen::Listing;

@ISA = ( 'EPrints::Plugin::Screen::Listing' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 400,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "editorial_review" );
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $repo = $self->{session};

	$processor->{dataset} = $repo->dataset( "buffer" );
	$processor->{columns_key} = "screen.review.columns";

	$self->SUPER::properties_from;
}

sub render_title
{
	my( $self ) = @_;

	return $self->EPrints::Plugin::Screen::render_title();
}

sub get_filters
{
	my( $self ) = @_;

	return(
		{ meta_fields => [qw( eprint_status )], value => "buffer", },
	);
}

sub perform_search
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $list = $repo->current_user->editable_eprints_list( filters => [
		$self->get_filters,
	]);
	my $filter_list = $self->{processor}->{search}->perform_search;

	return $list->intersect( $filter_list );
}

sub render_top_bar
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $frag = $repo->xml->create_document_fragment;
	my $user = $repo->current_user;
	my $imagesurl = $repo->config( "rel_path" )."/style/images";

	if( $user->is_set( "editperms" ) )
	{
		my $div = $repo->xml->create_element( "div", class=>"ep_block" );
		$div->appendChild( $repo->html_phrase( 
			"cgi/users/buffer:buffer_scope",
			scope=>$user->render_value( "editperms" ) ) );
		$frag->appendChild( $div );
	}

	my %options = (
		session => $repo,
		id => "ep_review_instructions",
		title => $repo->html_phrase( "Plugin/Screen/Review:help_title" ),
		content => $repo->html_phrase( "Plugin/Screen/Review:help" ),
		collapsed => 1,
		show_icon_url => "$imagesurl/help.gif",
	);
	my $box = $repo->xml->create_element( "div", style=>"text-align: left" );
	$box->appendChild( EPrints::Box::render( %options ) );
	$frag->appendChild( $box );

	return $frag;
}

sub render_dataobj_actions
{
	my( $self, $dataobj ) = @_;

	my $datasetid = $self->{processor}->{dataset}->id;

	local $self->{processor}->{eprint} = $dataobj; # legacy

	return $self->render_action_list_icons( "eprint_review_actions", {
			eprintid => $dataobj->id,
		} );
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

