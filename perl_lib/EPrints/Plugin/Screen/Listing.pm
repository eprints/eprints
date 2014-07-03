=head1 NAME

EPrints::Plugin::Screen::Listing

=cut

package EPrints::Plugin::Screen::Listing;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
#		{
#			place => "key_tools",
#			position => 100,
#		}
	];

	$self->{actions} = [qw/ search newsearch col_left col_right remove_col add_col set_filters reset_filters /];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $self->{session};

	if( !defined $processor->{dataset} )
	{
		my $datasetid = $session->param( "dataset" );

		if( $datasetid )
		{
			$processor->{"dataset"} = $session->dataset( $datasetid );
		}
	}

	my $dataset = $processor->{"dataset"};
	if( !defined $dataset )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $session->html_phrase(
			"lib/history:no_such_item",
			datasetid=>$session->make_text( $session->param( "dataset" ) ),
			objectid=>$session->make_text( "" ) ) );
		return;
	}

	if( !defined $processor->{columns_key} )
	{
		$processor->{columns_key} = "screen.listings.columns.".$dataset->id;
	}

	if( !defined $processor->{filters_key} )
	{
		$processor->{filters_key} = "screen.listings.filters.".$dataset->id;
	}

	my $columns = $self->show_columns();
	$processor->{"columns"} = $columns;
	my %columns = map { $_->name => 1 } @$columns;

	my $order = $session->param( "_listing_order" );
	if( !EPrints::Utils::is_set( $order ) )
	{
		# default to ordering by the first column
		$order = join '/', map {
			($_->should_reverse_order ? '-' : '') . $_->name
		} (@$columns)[0];
	}
	else
	{
		# remove any order-bys that aren't visible
		$order = join '/', 
			map { ($_->[0] ? '-' : '') . $_->[1] }
			grep { $columns{$_->[1]} }
			map { [ $_ =~ s/^-//, $_ ]}
			split /\//, $order;
	}

	my $filters = [$self->get_filters];
	my $priv = $self->{processor}->{dataset}->id . "/view";
	if( !$self->allow( $priv ) )
	{
		if( $self->allow( "$priv:owner" ) )
		{
			push @$filters, {
				meta_fields => [qw( userid )], value => $session->current_user->id,
			};
		}
	}

	$self->{processor}->{search} = $dataset->prepare_search(
		filters => $filters,
		search_fields => [
			(map { { meta_fields => [$_->name] } } @$columns)
		],
		custom_order => $order,
	);

	$self->SUPER::properties_from;
}

sub from
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $search = $self->{processor}->{search};
	my $exp = $session->param( "exp" );

	if( $self->{processor}->{action} ne "newsearch" )
	{
		if( $exp )
		{
			my $order = $search->{custom_order};
			$search->from_string( $exp );
			$search->{custom_order} = $order;
		}
		else
		{
			foreach my $sf ( $search->get_non_filter_searchfields )
			{
				my $prob = $sf->from_form();
				if( defined $prob )
				{
					$self->{processor}->add_message( "warning", $prob );
				}
			}
		}
	}

	# don't apply the user filters (/preferences) if they're about to be changed or reset
	my $action = $self->{processor}->{action};
	unless( $action eq 'set_filters' || $action eq 'reset_filters' )
	{
		$self->apply_user_filters();
	}

	$self->SUPER::from();
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $uri = URI->new( $self->SUPER::redirect_to_me_url );
	$uri->query_form(
		$uri->query_form,
		$self->hidden_bits,
	);

	return $uri;
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $priv = $self->{processor}->{dataset}->id . "/view";

	return $self->allow( $priv ) || $self->allow( "$priv:owner" ) || $self->allow( "$priv:editor" );
}

sub allow_action
{
	my( $self, $action ) = @_;

	return $self->can_be_viewed();
}

sub action_search
{
}

sub action_newsearch
{
}

sub _set_user_columns
{
	my( $self, $columns ) = @_;

	my $user = $self->{session}->current_user;

	$user->set_preference( $self->{processor}->{columns_key}, join( " ", map { $_->name } @$columns ) );
	$user->commit;

	# update the list of columns
	$self->{processor}->{columns} = $self->show_columns();
}

sub action_col_left
{
	my( $self ) = @_;

	my $i = $self->{session}->param( "column" );
	return if !defined $i || $i !~ /^[0-9]+$/;

	my $columns = $self->{processor}->{columns};
	@$columns[$i-1,$i] = @$columns[$i,$i-1];

	$self->_set_user_columns( $columns );
}
sub action_col_right
{
	my( $self ) = @_;

	my $i = $self->{session}->param( "column" );
	return if !defined $i || $i !~ /^[0-9]+$/;

	my $columns = $self->{processor}->{columns};
	@$columns[$i+1,$i] = @$columns[$i,$i+1];

	$self->_set_user_columns( $columns );
}
sub action_add_col
{
	my( $self ) = @_;

	my $name = $self->{session}->param( "column" );
	return if !defined $name;
	my $field = $self->{processor}->{dataset}->field( $name );
	return if !defined $field;
	return if !$field->get_property( "show_in_fieldlist" );

	my $columns = $self->{processor}->{columns};
	push @$columns, $field;

	$self->_set_user_columns( $columns );
}
sub action_remove_col
{
	my( $self ) = @_;

	my $i = $self->{session}->param( "column" );
	return if !defined $i || $i !~ /^[0-9]+$/;

	my $columns = $self->{processor}->{columns};
	splice( @$columns, $i, 1 );

	$self->_set_user_columns( $columns );
}

sub action_set_filters
{
        my( $self ) = @_;

        my $user = $self->{session}->current_user;

        my @filters = ();
        foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
        {
		push @filters, $sf->serialise;
        }

        $user->set_preference( $self->{processor}->{filters_key}, \@filters );
        $user->commit;

	$self->{session}->redirect( $self->redirect_to_me_url );
	return;
}

sub action_reset_filters
{
        my( $self ) = @_;

        $self->{session}->current_user->set_preference( $self->{processor}->{filters_key}, undef );
        $self->{session}->current_user->commit();

	$self->{session}->redirect( $self->redirect_to_me_url );
	return;
}

sub get_filters
{
	my( $self ) = @_;

	return ();
}

sub get_user_filters
{
        my( $self ) = @_;

	my @filters;

        my $pref = $self->{session}->current_user->preference( $self->{processor}->{filters_key} );

        if( EPrints::Utils::is_set( $pref ) && ref( $pref ) eq 'ARRAY' )
        {
                push @filters, $_ for( @$pref );
        }

        return @filters;
}

sub apply_user_filters
{
	my( $self ) = @_;

	my @user_filters = $self->get_user_filters;

	foreach my $uf ( @user_filters )
	{
		my $sf = EPrints::Search::Field->unserialise( repository => $self->{session}, 
			dataset => $self->{processor}->{dataset}, 
			string => $uf 
		);
		next unless( defined $sf );

		$self->{processor}->{search}->add_field( fields => $sf->get_fields, 
			value => $sf->get_value, 
			match => $sf->get_match, 
			merge => $sf->get_merge 
		);
	}
}

sub perform_search
{
	my( $self ) = @_;

	return $self->{processor}->{search}->perform_search;
}

sub render_links
{
	my( $self ) = @_;

	my $style = $self->{session}->make_element( "style", type=>"text/css" );
	$style->appendChild( $self->{session}->make_text( ".ep_tm_main { width: 90%; }" ) );

	return $style;
}

sub show_columns
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{dataset};
	my $user = $self->{session}->current_user;

	my $columns = $user->preference( $self->{processor}->{columns_key} );
	if( defined $columns )
	{
		$columns = [split / /, $columns];
		$columns = [grep { defined $_ } map { $dataset->field( $_ ) } @$columns];
	}
	if( !defined $columns || @{$columns} == 0 )
	{
		$columns = $dataset->columns();
	}
	if( !defined $columns || @{$columns} == 0 )
	{
		$columns = [$dataset->fields];
		splice(@$columns,4);
	}

	return $columns;
}

sub render_title
{
	my( $self ) = @_;

	my $session = $self->{session};

	return $session->html_phrase( "Plugin/Screen/Listing:page_title",
		dataset => $session->html_phrase( "datasetname_".$self->{processor}->{dataset}->id ) );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my $imagesurl = $session->config( "rel_path" )."/style/images";

	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $self->render_top_bar() );

	$chunk->appendChild( $self->render_filters() );

	### Get the items owned by the current user
	my $ds = $self->{processor}->{dataset};

	my $search = $self->{processor}->{search};
	my $list = $self->perform_search;
	my $exp;
	if( !$search->is_blank )
	{
		$exp = $search->serialise;
	}

	my $columns = $self->{processor}->{columns};

	my $len = scalar @{$columns};

	my $final_row = $session->make_element( "tr" );
	foreach my $i (0..$#$columns)
	{
		# Column headings
		my $td = $session->make_element( "td", class=>"ep_columns_alter" );
		$final_row->appendChild( $td );

		my $acts_table = $session->make_element( "table", cellpadding=>0, cellspacing=>0, border=>0, width=>"100%" );
		my $acts_row = $session->make_element( "tr" );
		my $acts_td1 = $session->make_element( "td", align=>"left", width=>"14px" );
		my $acts_td2 = $session->make_element( "td", align=>"center", width=>"100%");
		my $acts_td3 = $session->make_element( "td", align=>"right", width=>"14px" );
		$acts_table->appendChild( $acts_row );
		$acts_row->appendChild( $acts_td1 );
		$acts_row->appendChild( $acts_td2 );
		$acts_row->appendChild( $acts_td3 );
		$td->appendChild( $acts_table );

		if( $i > 0 )
		{
			my $form_l = $self->render_form;
			$form_l->appendChild( $session->render_hidden_field( "column", $i ) );
			$form_l->appendChild( $session->make_element( 
				"input",
				type=>"image",
				value=>$session->phrase( "lib/paginate:move_left" ),
				title=>$session->phrase( "lib/paginate:move_left" ),
				src => "$imagesurl/left.png",
				alt => "<",
				name => "_action_col_left" ) );
			$acts_td1->appendChild( $form_l );
		}
		else
		{
			$acts_td1->appendChild( $session->make_element("img",src=>"$imagesurl/noicon.png",alt=>"") );
		}

		my $msg = $self->phrase( "remove_column_confirm" );
		my $form_rm = $self->render_form;
		$form_rm->appendChild( $session->render_hidden_field( "column", $i ) );
		$form_rm->appendChild( $session->make_element( 
			"input",
			type=>"image",
			value=>$session->phrase( "lib/paginate:remove_column" ),
			title=>$session->phrase( "lib/paginate:remove_column" ),
			src => "$imagesurl/delete.png",
			alt => "X",
			onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm( ".EPrints::Utils::js_string($msg).");",
			name => "_action_remove_col" ) );
		$acts_td2->appendChild( $form_rm );

		if( $i < $#$columns )
		{
			my $form_r = $self->render_form;
			$form_r->appendChild( $session->render_hidden_field( "column", $i ) );
			$form_r->appendChild( $session->make_element( 
				"input",
				type=>"image",
				value=>$session->phrase( "lib/paginate:move_right" ),
				title=>$session->phrase( "lib/paginate:move_right" ),
				src => "$imagesurl/right.png",
				alt => ">",
				name => "_action_col_right" ) );
			$acts_td3->appendChild( $form_r );
		}
		else
		{
			$acts_td3->appendChild( $session->make_element("img",src=>"$imagesurl/noicon.png",alt=>"")  );
		}
	}
	my $td = $session->make_element( "td", class=>"ep_columns_alter ep_columns_alter_last" );
	$final_row->appendChild( $td );

	# Paginate list
	my $row = 0;
	my %opts = (
		params => {
			screen => $self->{processor}->{screenid},
			exp => $exp,
			$self->hidden_bits,
		},
		custom_order => $search->{custom_order},
		columns => [(map{ $_->name } @{$columns}), undef ],
		above_results => $session->make_doc_fragment,
		render_result => sub {
			my( undef, $dataobj ) = @_;

			local $self->{processor}->{dataobj} = $dataobj;
			my $class = "row_".($row % 2 ? "b" : "a");

			my $tr = $session->make_element( "tr", class=>$class );

			my $first = 1;
			for( map { $_->name } @$columns )
			{
				my $td = $session->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $dataobj->render_value( $_ ) );
			}

			my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( $self->render_dataobj_actions( $dataobj ) );

			++$row;

			return $tr;
		},
		rows_after => $final_row,
	);

	$opts{page_size} = $self->param( 'page_size' );

	$chunk->appendChild( EPrints::Paginate::Columns->paginate_list( $session, "_listing", $list, %opts ) );


	# Add form
	my $div = $session->make_element( "div", class=>"ep_columns_add" );
	my $form_add = $self->render_form;

	my %col_shown = map { $_->name() => 1 } @$columns;
	my $fieldnames = {};
	foreach my $field ( $ds->fields )
	{
		next if !$field->get_property( "show_in_fieldlist" );
		next if $col_shown{$field->name};
		my $name = EPrints::Utils::tree_to_utf8( $field->render_name( $session ) );
		my $parent = $field->get_property( "parent_name" );
		if( defined $parent ) 
		{
			my $pfield = $ds->field( $parent );
			$name = EPrints::Utils::tree_to_utf8( $pfield->render_name( $session )).": $name";
		}
		$fieldnames->{$field->name} = $name;
	}

	my @tags = sort { $fieldnames->{$a} cmp $fieldnames->{$b} } keys %$fieldnames;

	$form_add->appendChild( $session->render_option_list( 
		name => 'column',
		height => 1,
		multiple => 0,
		'values' => \@tags,
		labels => $fieldnames ) );
		
	$form_add->appendChild( 
			$session->render_button(
				class=>"ep_form_action_button",
				name=>"_action_add_col", 
				value => $session->phrase( "lib/paginate:add_column" ),
			) );
	$div->appendChild( $form_add );
	$chunk->appendChild( $div );
	# End of Add form

	return $chunk;
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		dataset => $self->{processor}->{dataset}->id,
		_listing_order => $self->{processor}->{search}->{custom_order},
		$self->SUPER::hidden_bits,
	);
}

sub render_top_bar
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $chunk = $session->make_doc_fragment;

	if( $session->get_lang->has_phrase( $self->html_phrase_id( "intro" ), $session ) )
	{
		my $intro_div_outer = $session->make_element( "div", class => "ep_toolbox" );
		my $intro_div = $session->make_element( "div", class => "ep_toolbox_content" );
		$intro_div->appendChild( $self->html_phrase( "intro" ) );
		$intro_div_outer->appendChild( $intro_div );
		$chunk->appendChild( $intro_div_outer );
	}

	# we've munged the argument list below
	$chunk->appendChild( $self->render_action_list_bar( "dataobj_tools", {
		dataset => $self->{processor}->{dataset}->id,
	} ) );

	return $chunk;
}

sub render_dataobj_actions
{
	my( $self, $dataobj ) = @_;

	my $datasetid = $self->{processor}->{dataset}->base_id;

	return $self->render_action_list_icons( ["${datasetid}_item_actions", "dataobj_actions"], {
			dataset => $datasetid,
			dataobj => $dataobj->id,
		} );
}

sub render_filters
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;
	my $dataset = $self->{processor}->{dataset};
	my $imagesurl = $session->config( "rel_path" )."/style/images";

	my $f = $xml->create_document_fragment;

	my $form = $self->render_search_form();

	my %options = (
		session => $session,
		id => "ep_listing_search",
		title => $session->html_phrase( "lib/searchexpression:action_filter" ),
		content => $form,
		collapsed => $self->{processor}->{search}->is_blank(),
		show_icon_url => "$imagesurl/help.gif",
	);
	my $box = $session->make_element( "div", style=>"text-align: left" );
	$box->appendChild( EPrints::Box::render( %options ) );
	$f->appendChild( $box );

	return $f;
}

sub render_search_form
{
	my( $self ) = @_;

	my $form = $self->render_form;
	$form->setAttribute( method => "get" );

	my $table = $self->{session}->make_element( "table", class=>"ep_search_fields" );
	$form->appendChild( $table );

	$table->appendChild( $self->render_search_fields );

#	$table->appendChild( $self->render_anyall_field );

	$form->appendChild( $self->render_controls );

	return( $form );
}


sub render_search_fields
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
	{
		$frag->appendChild( 
			$self->{session}->render_row_with_help( 
				help_prefix => $sf->get_form_prefix."_help",
				help => $sf->render_help,
				label => $sf->render_name,
				field => $sf->render,
				no_toggle => ( $sf->{show_help} eq "always" ),
				no_help => ( $sf->{show_help} eq "never" ),
			 ) );
	}

	return $frag;
}


sub render_anyall_field
{
	my( $self ) = @_;

	my @sfields = $self->{processor}->{search}->get_non_filter_searchfields;
	if( (scalar @sfields) < 2 )
	{
		return $self->{session}->make_doc_fragment;
	}

	my $menu = $self->{session}->render_option_list(
			name=>"satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{processor}->{search}->{satisfy_all} && $self->{processor}->{search}->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{session}->phrase( 
						"lib/searchexpression:all" ),
				  "ANY" => $self->{session}->phrase( 
						"lib/searchexpression:any" )} );

	return $self->{session}->render_row_with_help( 
			no_help => 1,
			label => $self->{session}->html_phrase( 
				"lib/searchexpression:must_fulfill" ),  
			field => $menu,
	);
}

sub render_controls
{
        my( $self ) = @_;

        my $div = $self->{session}->make_element(
                "div" ,
                class => "ep_search_buttons" );
        $div->appendChild( $self->{session}->render_action_buttons(
                set_filters => $self->{session}->phrase( "lib/searchexpression:action_filter" ),
                reset_filters => $self->{session}->phrase( "lib/searchexpression:action_reset" ),
                _order => [ "set_filters", "reset_filters" ],
        ) );

        return $div;
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

