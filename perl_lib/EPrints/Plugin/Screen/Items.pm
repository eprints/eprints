=head1 NAME

EPrints::Plugin::Screen::Items

=cut


package EPrints::Plugin::Screen::Items;

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
			position => 100,
		}
	];

	$self->{actions} = [qw/ col_left col_right remove_col add_col /];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $self->{session};

	$processor->{dataset} = $session->dataset( "eprint" );

	$self->SUPER::properties_from();
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "items" );
}

sub get_filters
{
	my( $self ) = @_;

	my $pref = $self->{id}."/eprint_status";
	my $user = $self->{session}->current_user;
	my @f = @{$user->preference( $pref ) || []};
	if( !scalar @f )
	{
		@f = ( inbox=>1, buffer=>1, archive=>1, deletion=>1 );
	}

	foreach my $i (0..$#f)
	{
		next if $i % 2;
		my $filter = $f[$i];
		my $v = $self->{session}->param( "set_show_$filter" );
		if( defined $v )
		{
			$f[$i+1] = $v;
			$user->set_preference( $pref, \@f );
			$user->commit;
			last;
		}
	}	

	my @l = map { $f[$_] } grep { $_ % 2 == 0 && $f[$_+1] } 0..$#f;

	return (
		{ meta_fields => [qw( eprint_status )], value => "@l", match => "EQ", merge => "ANY" },
	);
}

sub render_title
{
	my( $self ) = @_;

	return $self->EPrints::Plugin::Screen::render_title();
}

sub perform_search
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $search = $processor->{search};

	# dirty hack to pass the internal search through to owned_eprints_list
	my $list = $self->{session}->current_user->owned_eprints_list( %$search,
		custom_order => $search->{custom_order}
	);

	return $list;
}

sub render_filters
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $dataset = $self->{processor}->{dataset};
	my $imagesurl = $repo->config( "rel_path" )."/style/images";

	my $frag = $xml->create_document_fragment;

	my $filter_div = $xml->create_element( "div", class=>"ep_items_filters" );
	$frag->appendChild( $filter_div );

	my $pref = $self->{id}."/eprint_status";
	my %filters = @{$repo->current_user->preference( $pref ) || [
		inbox=>1, buffer=>1, archive=>1, deletion=>1
	]};

	foreach my $f ( qw/ inbox buffer archive deletion / )
	{
		my $url = URI->new( $repo->current_url() );
		my %q = $self->hidden_bits;
		$q{"set_show_$f"} = !$filters{$f};
		$url->query_form( %q );
		my $link = $repo->render_link( $url );
		if( $filters{$f} )
		{
			$link->appendChild( $xml->create_element(
				"img",
				src=> "$imagesurl/checkbox_tick.png",
				alt=>"Showing" ) );
		}
		else
		{
			$link->appendChild( $xml->create_element(
				"img",
				src=> "$imagesurl/checkbox_empty.png",
				alt=>"Not showing" ) );
		}
		$link->appendChild( $xml->create_text_node( " " ) );
		$link->appendChild( $repo->html_phrase( "eprint_fieldopt_eprint_status_$f" ) );
		$filter_div->appendChild( $link );
		$filter_div->appendChild( $xml->create_text_node( ". " ) );
	}

	return $frag;
}

sub render_result_row
{
	my( $self, $e ) = @_;

	my $session = $self->{session};
	my $columns = $self->{processor}->{columns};

	my $class = "";
# "row_".($info->{row}%2?"b":"a");
	if( $e->is_locked )
	{
		$class .= " ep_columns_row_locked";
		my $my_lock = ( $e->get_value( "edit_lock_user" ) == $session->current_user->get_id );
		if( $my_lock )
		{
			$class .= " ep_columns_row_locked_mine";
		}
		else
		{
			$class .= " ep_columns_row_locked_other";
		}
	}

	my $tr = $session->make_element( "tr", class=>$class );

	my $status = $e->get_value( "eprint_status" );

	my $first = 1;
	for( map { $_->name } @$columns )
	{
		my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_$status".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
		$first = 0;
		$tr->appendChild( $td );
		$td->appendChild( $e->render_value( $_ ) );
	}

	local $self->{processor}->{eprint} = $e;
	local $self->{processor}->{eprintid} = $e->get_id;
	my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
	$tr->appendChild( $td );
	$td->appendChild( 
		$self->render_action_list_icons( "eprint_item_actions", { 'eprintid' => $self->{processor}->{eprintid} } ) );

	return $tr;
}

sub render_top_bar
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $self->SUPER::render_top_bar );

	$chunk->appendChild( $self->render_action_list_bar( "item_tools" ) );

	$chunk->appendChild( $self->{processor}->render_item_list(
			[ $self->{processor}->list_items( "user_tasks" ) ],
			class => "ep_user_tasks",
		) );

	return $chunk;
}

sub render_items
{
	my( $self, $list ) = @_;

	if( $list->count == 0 )
	{
		return $self->{session}->make_doc_fragment;
	}

	return $self->SUPER::render_items( $list );
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

