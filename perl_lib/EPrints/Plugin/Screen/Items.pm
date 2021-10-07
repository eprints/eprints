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

sub allow_col_left { return $_[0]->can_be_viewed; }
sub allow_col_right { return $_[0]->can_be_viewed; }
sub allow_remove_col { return $_[0]->can_be_viewed; }
sub allow_add_col { return $_[0]->can_be_viewed; }

sub action_col_left
{
	my( $self ) = @_;

	my $col_id = $self->{session}->param( "colid" );
	my $v = $self->{session}->current_user->get_value( "items_fields" );

	my @newlist = @$v;
	my $a = $newlist[$col_id];
	my $b = $newlist[$col_id-1];
	$newlist[$col_id] = $b;
	$newlist[$col_id-1] = $a;

	$self->{session}->current_user->set_value( "items_fields", \@newlist );
	$self->{session}->current_user->commit();
}

sub action_col_right
{
	my( $self ) = @_;

	my $col_id = $self->{session}->param( "colid" );
	my $v = $self->{session}->current_user->get_value( "items_fields" );

	my @newlist = @$v;
	my $a = $newlist[$col_id];
	my $b = $newlist[$col_id+1];
	$newlist[$col_id] = $b;
	$newlist[$col_id+1] = $a;
	
	$self->{session}->current_user->set_value( "items_fields", \@newlist );
	$self->{session}->current_user->commit();
}
sub action_add_col
{
	my( $self ) = @_;

	my $col = $self->{session}->param( "col" );
	my $v = $self->{session}->current_user->get_value( "items_fields" );

	my @newlist = @$v;
	push @newlist, $col;	
	
	$self->{session}->current_user->set_value( "items_fields", \@newlist );
	$self->{session}->current_user->commit();
}
sub action_remove_col
{
	my( $self ) = @_;

	my $col_id = $self->{session}->param( "colid" );
	my $v = $self->{session}->current_user->get_value( "items_fields" );

	my @newlist = @$v;
	splice( @newlist, $col_id, 1 );
	
	$self->{session}->current_user->set_value( "items_fields", \@newlist );
	$self->{session}->current_user->commit();
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

	# @f is like ('archive', 1, 'buffer', 0, 'deletion', 0,
	# 'inbox', 1), i.e., alternating values of keys and
	# values. The code iterates through the keys and checks
	# whether a querystring param has been set, if so it updates
	# the user's preferences and exits.
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

	# Magic code to create an array of eprint states that the
	# user's wishes to see
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
		custom_order => $search->{order}
	);

	return $list;
}

sub render
{
	my( $self ) = @_;

	my $vars = {};

	my $repo = $self->{session};
	my $user = $repo->current_user;
	my $imagesurl = $repo->current_url( path => "static", "style/images" );

	# Get the items owned by the current user
	my $list = $self->perform_search;

	my $has_eprints = $list->count > 0;
	$vars->{has_eprints} = $has_eprints;

	# Dataset filters
	my $pref = $self->{id} . '/eprint_status';
	my %filters = @{$user->preference( $pref ) || [
			    inbox => 1, buffer => 1, archive => 1, deletion => 1
			    ]};
	$vars->{filters} = \%filters;

	# Columns to display
	my $columns = $user->get_value( "items_fields" );
	my $ds = $repo->dataset( "eprint" );
	@{$columns} = grep { $ds->has_field( $_ ) } @{$columns};
	if( !EPrints::Utils::is_set( $columns ) )
	{
		$columns = [ 'eprintid', 'type', 'eprint_status', 'lastmod' ];
		$repo->current_user->set_value( 'items_fields', $columns );
		$repo->current_user->commit;
	}
	$vars->{columns} = $columns;

        # Extra cols that a user may choose to show
	my $shown_cols;
	%{$shown_cols} = map { $_ => 1 } @{$columns};
	my @fields = $ds->fields();
	my $extra_cols = {};
	%{$extra_cols} = map { ( $shown_cols->{$_->name} != 1 ) ? ( $_->render_name => $_->name ) : () } @fields;
	@fields = undef;
	$vars->{extra_cols} = $extra_cols;

	$vars->{basename} = '_buffer';
	my $pagination_vars = EPrints::Paginate::Columns->paginate_list2( $repo, $vars->{basename}, $columns, $list );
	$vars->{eprints} = $pagination_vars->{dataobjs};
	delete $pagination_vars->{dataobjs};

	@{$vars}{keys %{$pagination_vars}} = values %{$pagination_vars};

	# Action list
	my $actions = {};
	for my $eprint ( @{$vars->{eprints}} )
	{
	    $self->{processor}->{eprint} = $eprint;
	    my @eprint_actions = $self->{processor}->list_items( 'eprint_item_actions', filter => 1 );
	    delete $self->{processor}->{eprint};

	    # Add the 'hidden' params so that the icons are generated
	    # correctly
	    for my $action ( @eprint_actions )
	    {
		$action->{hidden} = { eprintid => $eprint->id() };
	    }

	    $actions->{ $eprint->id() } = \@eprint_actions;
	}
	$vars->{actions} = $actions;

	# Item tools
	my @tools = $self->{processor}->list_items( 'item_tools', filter => 1 );
	$vars->{tools} = \@tools;

	# Import bar - getting lazy, use existing DOM, output to
	# string, and send the whole thing to the template!
	my $import_screen = $repo->plugin( "Screen::Import" );
	$vars->{import_bar} =  $import_screen->render_import_bar()->toString() if ( defined $import_screen );

	my $template = $repo->plugin( 'Template::Xslate' );
	return $template->render( 'plugins/screen/items', $vars );
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

