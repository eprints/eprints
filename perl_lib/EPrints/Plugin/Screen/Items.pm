
package EPrints::Plugin::Screen::Items;

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
			position => 100,
		}
	];

	$self->{actions} = [qw/ col_left col_right remove_col add_col /];

	return $self;
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

	my %f = ( inbox=>1, buffer=>1, archive=>0, deletion=>0 );

	foreach my $filter ( keys %f )
	{
		my $v = $self->{session}->param( "show_$filter" );
		$f{$filter} = $v if defined $v;
	}	

	return %f;
}
	
sub render_links
{
	my( $self ) = @_;

	my $style = $self->{session}->make_element( "style", type=>"text/css" );
	$style->appendChild( $self->{session}->make_text( ".ep_tm_main { width: 90%; }" ) );

	return $style;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;

	my $user = $session->current_user;

	if( $session->get_lang->has_phrase( $self->html_phrase_id( "intro" ), $session ) )
	{
		my $intro_div_outer = $session->make_element( "div", class => "ep_toolbox" );
		my $intro_div = $session->make_element( "div", class => "ep_toolbox_content" );
		$intro_div->appendChild( $self->html_phrase( "intro" ) );
		$intro_div_outer->appendChild( $intro_div );
		$chunk->appendChild( $intro_div_outer );
	}

	my $imagesurl = $session->get_repository->get_conf( "rel_path" )."/style/images";

	my %options;
 	$options{session} = $session;
	$options{id} = "ep_review_instructions";
	$options{title} = $session->html_phrase( "Plugin/Screen/Items:help_title" );
	$options{content} = $session->html_phrase( "Plugin/Screen/Items:help" );
	$options{collapsed} = 1;
	$options{show_icon_url} = "$imagesurl/help.gif";
	my $box = $session->make_element( "div", style=>"text-align: left" );
	$box->appendChild( EPrints::Box::render( %options ) );
	$chunk->appendChild( $box );

	$chunk->appendChild( $self->render_action_list_bar( "item_tools" ) );

	my %filters = $self->get_filters;
	my @l = ();
	foreach( keys %filters ) { push @l, $_ if $filters{$_}; }

	### Get the items owned by the current user
	my $ds = $session->get_repository->get_dataset( "eprint" );
	my $list = $session->current_user->get_owned_eprints( $ds );
	$list = $list->reorder( "-status_changed" );

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$ds );
	$searchexp->add_field(
		$ds->get_field( "eprint_status" ),
		join( " ", @l ),
		"EQ",
		"ANY" );
	$list = $list->intersect( $searchexp->perform_search, "-eprintid" );
	my $filter_div = $session->make_element( "div", class=>"ep_items_filters" );
	foreach my $f ( qw/ inbox buffer archive deletion / )
	{
		my %f2 = %filters;
		$f2{$f} = 1-$f2{$f};
		my $url = "?screen=Items";
		foreach my $inner_f ( qw/ inbox buffer archive deletion / )
		{
			$url.= "&show_$inner_f=".$f2{$inner_f};
		}
		my $a = $session->render_link( $url,  );
		if( $filters{$f} )
		{
			$a->appendChild( $session->make_element(
				"img",
				src=> "$imagesurl/checkbox_tick.png",
				alt=>"Showing" ) );
		}
		else
		{
			$a->appendChild( $session->make_element(
				"img",
				src=> "$imagesurl/checkbox_empty.png",
				alt=>"Not showing" ) );
		}
		$a->appendChild( $session->make_text( " " ) );
		$a->appendChild( $session->html_phrase( "eprint_fieldopt_eprint_status_$f" ) );
		$filter_div->appendChild( $a );
		$filter_div->appendChild( $session->make_text( ". " ) );
	}

	my $columns = $session->current_user->get_value( "items_fields" );
	if( !EPrints::Utils::is_set( $columns ) )
	{
		$columns = [ "eprintid","type","eprint_status","lastmod" ];
		$session->current_user->set_value( "items_fields", $columns );
		$session->current_user->commit;
	}


	my $len = scalar @{$columns};

	my $final_row = undef;
	if( $len > 1 )
	{	
		$final_row = $session->make_element( "tr" );
		my $imagesurl = $session->get_repository->get_conf( "rel_path" )."/style/images";
		for(my $i=0; $i<$len;++$i )
		{
			my $col = $columns->[$i];
			# Column headings
			my $td = $session->make_element( "td", class=>"ep_columns_alter" );
			$final_row->appendChild( $td );
	
			my $acts_table = $session->make_element( "table", cellpadding=>0, cellspacing=>0, border=>0, width=>"100%" );
			my $acts_row = $session->make_element( "tr" );
			my $acts_td1 = $session->make_element( "td", align=>"left", width=>"14" );
			my $acts_td2 = $session->make_element( "td", align=>"center", width=>"100%");
			my $acts_td3 = $session->make_element( "td", align=>"right", width=>"14" );
			$acts_table->appendChild( $acts_row );
			$acts_row->appendChild( $acts_td1 );
			$acts_row->appendChild( $acts_td2 );
			$acts_row->appendChild( $acts_td3 );
			$td->appendChild( $acts_table );

			if( $i!=0 )
			{
				my $form_l = $session->render_form( "post" );
				$form_l->appendChild( 
					$session->render_hidden_field( "screen", "Items" ) );
				$form_l->appendChild( 
					$session->render_hidden_field( "colid", $i ) );
				$form_l->appendChild( $session->make_element( 
					"input",
					type=>"image",
					value=>"Move Left",
					title=>"Move Left",
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
			my $form_rm = $session->render_form( "post" );
			$form_rm->appendChild( 
				$session->render_hidden_field( "screen", "Items" ) );
			$form_rm->appendChild( 
				$session->render_hidden_field( "colid", $i ) );
			$form_rm->appendChild( $session->make_element( 
				"input",
				type=>"image",
				value=>"Remove Column",
				title=>"Remove Column",
				src => "$imagesurl/delete.png",
				alt => "X",
				onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm( ".EPrints::Utils::js_string($msg).");",
				name => "_action_remove_col" ) );
			$acts_td2->appendChild( $form_rm );

			if( $i!=$len-1 )
			{
				my $form_r = $session->render_form( "post" );
				$form_r->appendChild( 
					$session->render_hidden_field( "screen", "Items" ) );
				$form_r->appendChild( 
					$session->render_hidden_field( "colid", $i ) );
				$form_r->appendChild( $session->make_element( 
					"input",
					type=>"image",
					value=>"Move Right",
					title=>"Move Right",
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
	}

	# Paginate list
	my %opts = (
		params => {
			screen => "Items",
			show_inbox=>$filters{inbox},
			show_buffer=>$filters{buffer},
			show_archive=>$filters{archive},
			show_deletion=>$filters{deletion},
		},
		columns => [@{$columns}, undef ],
		above_results => $filter_div,
		render_result => sub {
			my( $session, $e, $info ) = @_;

			my $class = "row_".($info->{row}%2?"b":"a");
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
			for( @$columns )
			{
				my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_$status".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $e->render_value( $_ ) );
			}

			$self->{processor}->{eprint} = $e;
			$self->{processor}->{eprintid} = $e->get_id;
			my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( 
				$self->render_action_list_icons( "eprint_item_actions", ['eprintid'] ) );
			delete $self->{processor}->{eprint};

			++$info->{row};

			return $tr;
		},
		rows_after => $final_row,
	);
	$chunk->appendChild( EPrints::Paginate::Columns->paginate_list( $session, "_buffer", $list, %opts ) );


	# Add form
	my $div = $session->make_element( "div", class=>"ep_columns_add" );
	my $form_add = $session->render_form( "post" );
	$form_add->appendChild( $session->render_hidden_field( "screen", "Items" ) );

	my $colcurr = {};
	foreach( @$columns ) { $colcurr->{$_} = 1; }
	my $fieldnames = {};
        foreach my $field ( $ds->get_fields )
        {
                next unless $field->get_property( "show_in_fieldlist" );
		next if $colcurr->{$field->get_name};
		my $name = EPrints::Utils::tree_to_utf8( $field->render_name( $session ) );
		my $parent = $field->get_property( "parent_name" );
		if( defined $parent ) 
		{
			my $pfield = $ds->get_field( $parent );
			$name = EPrints::Utils::tree_to_utf8( $pfield->render_name( $session )).": $name";
		}
		$fieldnames->{$field->get_name} = $name;
        }

	my @tags = sort { $fieldnames->{$a} cmp $fieldnames->{$b} } keys %$fieldnames;

	$form_add->appendChild( $session->render_option_list( 
		name => 'col',
		height => 1,
		multiple => 0,
		'values' => \@tags,
		labels => $fieldnames ) );
		
	$form_add->appendChild( 
			$session->render_button(
				class=>"ep_form_action_button",
				name=>"_action_add_col", 
				value => $self->phrase( "add" ) ) );
	$div->appendChild( $form_add );
	$chunk->appendChild( $div );
	# End of Add form

	return $chunk;
}


1;
