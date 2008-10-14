######################################################################
#
# EPrints::Update::Views
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Update::Views

=head1 DESCRIPTION

Update the browse-by X web pages on demand.

=over 4

=cut

package EPrints::Update::Views;

use Data::Dumper;

use strict;
  
# This is the function which decides which type of view it is:
# * the main menu of views
# * the top level menu of a view
# * the sub menu of a view
# * a page within a single value of a view

# Does not update the file if it's not needed.

sub update_view_file
{
	my( $session, $langid, $localpath, $uri ) = @_;

	my $repository = $session->get_repository;

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid.$localpath;
	$target =~ s/\.[^\.]*$//;
	my $age;
	if( -e "$target.page" ) 
	{
		my $target_timestamp = EPrints::Utils::mtime( "$target.page" );

		$age = time - $target_timestamp;

		my $timestampfile = $repository->get_conf( "variables_path" )."/views.timestamp";	
		if( -e $timestampfile )
		{
			my $poketime = (stat( $timestampfile ))[9];
			# if the poktime is more recent than the file then make it look like the 
			# file does not exist (forcing it to regenerate)
			$age = undef if( $target_timestamp < $poketime );
		}		
	}

	if( $uri eq "/view/" )
	{
		# This should really be updated by hand, but updating it once
		# a day shouldn't hurt.
		if( defined $age && $age < 24*60*60 )
		{
			return;
		}
		update_browse_view_list( $session, $langid );
		return;
	}
	
	$uri =~ m/^\/view(\/(([^\/]+)(\/(.*))?)?)?$/;

	my( $x, $y, $viewid, $z, $viewinfo ) = ( $1,$2,$3,$4,$5 );

	my $view;
	foreach my $a_view ( @{$repository->get_conf( "browse_views" )} )
	{
		$view = $a_view if( $a_view->{id} eq $viewid );
	}
	if( !defined $view ) 
	{
		EPrints::abort( "view with ID '$viewid' is not available." );
	}

	my $max_menu_age = $view->{max_menu_age} || 24*60*60;
	my $max_list_age = $view->{max_list_age} || 24*60*60;

	if( !EPrints::Utils::is_set( $viewinfo ) )
	{
		if( defined $age && $age < $max_menu_age )
		{
			return;
		}

		update_view_menu( $session, $view, $langid );
		return;
	}

	if( $viewinfo =~ s/\/$// )
	{
		if( defined $age && $age < $max_menu_age )
		{
			return;
		}

		# if it ends with "/" then it's a submenu
		my @view_path = split( '/', $viewinfo );
		
		update_view_menu( $session, $view, $langid, \@view_path );
		return;
	}

	# Otherwise it's (probably) a view list

	if( defined $age && $age < $max_list_age )
	{
		return;
	}

	my @view_path = split( '/', $viewinfo );
	
	update_view_list( $session, $view, $langid, \@view_path );
}



# Update the main menu of views (pretty cheap to do)
# return list of files written

sub update_browse_view_list
{
	my( $session, $langid ) = @_;

	my $repository = $session->get_repository;

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/index";

	my $ds = $repository->get_dataset( "archive" );

	my( $ul, $li, $page, $a, $file, $title );

	$page = $session->make_doc_fragment();
	$page->appendChild( $session->html_phrase( "bin/generate_views:browseintro" ) );

	$ul = $session->make_element( "ul" );
	foreach my $view ( @{$repository->get_conf( "browse_views" )} )
	{
		next if( $view->{nolink} );
		$li = $session->make_element( "li" );
		$a = $session->render_link( $view->{id}."/" );
		$a->appendChild( $session->make_text( $session->get_view_name( $ds, $view->{id} ) ) );
		$li->appendChild( $a );
		$ul->appendChild( $li );
	}
	$page->appendChild( $ul );

	$title = $session->html_phrase( "bin/generate_views:browsetitle" );

	$session->write_static_page( 
			$target, 
			{
				title => $title, 
				page => $page,
			},
			"browsemain" );

	return( $target );
}

# return an array of the filters required for the given path_values
# or undef if something funny occurs.

sub get_filters
{
	my( $session, $view, $esc_path_values ) = @_;

	my $repository = $session->get_repository;

	my $ds = $repository->get_dataset( "archive" );

	my @fields = get_fields_from_config( $ds, $view->{fields} );

	my @menu_levels = split( ",", $view->{fields} );
	my $menu_level = scalar @{$esc_path_values};

	my $filters = [];

	for( my $i=0; $i<$menu_level; ++$i )
	{
		if( $esc_path_values->[$i] eq "NULL" )
		{
			push @{$filters}, { fields=>$fields[$i], value=>"" };
			next;
		}
		my $key_values = get_fieldlist_values( $session, $ds, $fields[$i] );
		my $value = $key_values->{EPrints::Utils::unescape_filename( $esc_path_values->[$i] )};
		if( !defined($value) )
		{
			$repository->log( "Invalid value id in get_filters '".$esc_path_values->[$i]."' in menu: ".$view->{id}."/".join( "/", @{$esc_path_values} )."/" );
			return;
		}
		push @{$filters}, { fields=>$fields[$i], value=>$value };
	}

	return $filters;
}

# return a hash mapping keys at this level to number of items in db
# if a leaf level, return undef

# path_values is escaped 
sub get_sizes
{
	my( $session, $view, $esc_path_values ) = @_;

	my $ds = $session->get_repository->get_dataset( "archive" );

	my @fields = get_fields_from_config( $ds, $view->{fields} );

	my $menu_level = scalar @{$esc_path_values};

	if( !defined $fields[$menu_level] )
	{
		# no sub pages at this level
		return undef;
	}

	my $filters = get_filters( $session, $view, $esc_path_values );

	my @menu_fields = @{$fields[$menu_level]};

	my $show_sizes = get_fieldlist_totals( $session, $ds, \@menu_fields, $filters, $view->{allow_null} );

	return $show_sizes;
}

# Update a view menu - potentially expensive to do.

# nb. path_values are considered escaped at this point
sub update_view_menu
{
	my( $session, $view, $langid, $esc_path_values ) = @_;

	my $repository = $session->get_repository;
	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/".$view->{id}."/";
	if( defined $esc_path_values )
	{
		$target .= join( "/", @{$esc_path_values}, "index" );
	}
	else
	{
		$target .= "index";
	}

	my $menu_level = 0;
	my $path_values = [];
	my $filters;
	if( defined $esc_path_values )
	{
		$filters = [];
		$menu_level = scalar @{$esc_path_values};

		$filters = get_filters( $session, $view, $esc_path_values );
	
		return if !defined $filters;

		foreach my $esc_value (@{$esc_path_values})
		{
			push @{$path_values}, EPrints::Utils::unescape_filename( $esc_value );
		}
	}	


	my $ds = $repository->get_dataset( "archive" );
	my @fields = get_fields_from_config( $ds, $view->{fields} );
	my @menu_levels = split( ",", $view->{fields} );

	# if number of fields is 1 then menu_level must be 0
	# if number of fields is 2 then menu_level must be 0 or 1 
	# etc.
	if( $menu_level >= scalar @fields )
	{
		$repository->log( "Too many values when asked for a for view menu: ".$view->{id}."/".join( "/", @{$esc_path_values} )."/" );
		return;
	}

	# fields for the current menu level
	my @menu_fields = @{$fields[$menu_level]};

	my $key_values = get_fieldlist_values( $session, $ds, \@menu_fields );
	my @values = values %$key_values;

	if( !$view->{allow_null} )
	{
		my @new_values = ();
		foreach( @values ) { push @new_values,$_ unless $_ eq ""; }
		@values = @new_values;
	}

	# OK now we have a sorted list of values....

	@values = @{$menu_fields[0]->sort_values( $session, \@values )};

	if( $menu_levels[$menu_level] =~ m/^-/ )
	{
		@values = reverse @values;
	}


	# now render the menu page

	my $show_sizes = get_fieldlist_totals( $session, $ds, \@menu_fields, $filters, $view->{allow_null} );

	# Not doing submenus just yet.
	my $has_submenu = 0;
	if( scalar @menu_levels > $menu_level+1 )
	{
		$has_submenu = 1;
	}

	my $page = $session->make_element( "div", class=>"ep_view_menu" );

	my $navigation_aids = render_navigation_aids( $session, $path_values, $view, \@fields, "menu" );
	$page->appendChild( $navigation_aids );

	my $phrase_id = "viewintro_".$view->{id};
	if( defined $esc_path_values )
	{
		$phrase_id.= "/".join( "/", @{$path_values} );
	}
	unless( $session->get_lang()->has_phrase( $phrase_id ) )
	{
		$phrase_id = "bin/generate_views:intro";
	}
	$page->appendChild( $session->html_phrase( $phrase_id ));

	my @render_menu_opts = (
				$session,
				$view,
				$show_sizes,
				\@values,
				\@menu_fields,
				$has_submenu );

	my $menu_xhtml;
	if( $menu_fields[0]->is_type( "subject" ) )
	{
		$menu_xhtml = render_view_subj_menu( @render_menu_opts );
	}
	elsif( $view->{render_menu} )
	{
		$menu_xhtml = $repository->call( $view->{render_menu}, @render_menu_opts );
	}
	else
	{
		$menu_xhtml = render_view_menu( @render_menu_opts );
	}
	$page->appendChild( $menu_xhtml );

	my $title;
	my $title_phrase_id = "viewtitle_".$ds->confid()."_".$view->{id}."_menu_".( $menu_level + 1 );

	if( $session->get_lang()->has_phrase( $title_phrase_id ) && defined $esc_path_values )
	{
		my %o = ();
		for( my $i = 0; $i < scalar( @{$esc_path_values} ); ++$i )
		{
			my @menu_fields = @{$fields[$i]};
			$o{"value".($i+1)} = $menu_fields[0]->render_single_value( $session, $path_values->[$i]);
		}
		$title = $session->html_phrase( $title_phrase_id, %o );
	}

	if( !defined $title )
	{
		$title = $session->html_phrase(
			"bin/generate_views:indextitle",
			viewname=>$session->make_text(
				$session->get_view_name( $ds, $view->{id} ) ) );
	}


	# Write page to disk
	
	$session->write_static_page( 
			$target, 
			{
				title => $title, 
				page => $page,
				template => $session->make_text($view->{template}),
			},
			"browseindex" );

	open( INCLUDE, ">$target.include" ) || EPrints::abort( "Failed to write $target.include: $!" );
	binmode(INCLUDE,":utf8");
	print INCLUDE $page->toString;
	close INCLUDE;

	return( $target );
}

sub get_fieldlist_totals
{
	my( $session, $ds, $fields, $filters ) = @_;

	my $is_subject = $fields->[0]->is_type( "subject" );
	my $subject_map;
	my $subject_map_r;
	my $topsubj;
	if( $is_subject )
	{
		( $subject_map, $subject_map_r ) = EPrints::DataObj::Subject::get_all( $session );
	}


	my %map=();
	my %only_these_values = ();
	FIELD: foreach my $field ( @{$fields} )
	{
		my $vref = $field->get_ids_by_value( $session, $ds, filters=>$filters );
		if( $is_subject )
		{
			my $top_node_id= $field->get_property( "top" );
			SUBJECT: foreach my $subject_id ( keys %{$subject_map} )
			{
				foreach my $ancestor ( @{$subject_map->{$subject_id}->get_value( "ancestors" )} )
				{
					if( $ancestor eq $top_node_id )
					{
						$only_these_values{$subject_id} = 1;
						next SUBJECT;
					}
				}
			}
		}

		VALUE: foreach my $value ( keys %{$vref} )
		{
			$only_these_values{$value} = 1;
			if( $is_subject )
			{
				my $subject = $subject_map->{$value};
				next VALUE if ( !defined $subject );
				foreach my $ancestor ( @{$subject->get_value( "ancestors" )} )
				{
					foreach my $itemid ( @{$vref->{$value}} ) 
					{ 
						$map{$ancestor}->{$itemid} = 1; 
					}
				}
			}
			else
			{
				foreach my $itemid ( @{$vref->{$value}} ) 
				{ 
					$map{$value}->{$itemid} = 1; 
				}
			}
		}
	}

	my $totals = {};
	foreach my $value ( keys %map )
	{
		next unless $only_these_values{$value};
		$totals->{$value} = scalar keys %{$map{$value}};
	}

	return $totals;
}

sub get_fieldlist_values
{
	my( $session, $ds, $fields ) = @_;

	my $values = {};
	foreach my $field ( @{$fields} )
	{
		foreach my $value ( @{$field->get_values( $session, $ds )} )
		{ 
			my $id = $fields->[0]->get_id_from_value( $session, $value );
			$id = "" if !defined $id;
			$values->{$id} = $value;
		}
	}

	return $values;
}

sub render_view_menu
{
	my( $session, $view, $sizes, $values, $fields, $has_submenu ) = @_;

	my @showvalues = ();
	if( $view->{hideempty} && defined $sizes)
	{
		foreach my $value ( @{$values} )
		{
			my $id = $fields->[0]->get_id_from_value( $session, $value );
			push @showvalues, $value if( $sizes->{$id} );
		}
	}
	else
	{
		@showvalues = @{$values};
	}

	my $nitems = scalar @showvalues;
	my $cols = 1;
	if( defined $view->{new_column_at} )
	{
		foreach my $min ( @{$view->{new_column_at}} )
		{
			if( $nitems >= $min ) { ++$cols; }
		}
	}

	my $add_ul;
	my $col_n = 0;
	my $col_len = POSIX::ceil( $nitems / $cols );

	my $f = $session->make_doc_fragment;
	my $tr;

	if( $cols > 1 )
	{
		my $table = $session->make_element( "table", cellpadding=>"0", cellspacing=>"0", border=>"0", class=>"ep_view_cols ep_view_cols_$cols" );
		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );	
		$f->appendChild( $table );
	}
	else
	{
		$add_ul = $session->make_element( "ul" );
		$f->appendChild( $add_ul );	
	}

	for( my $i=0; $i<@showvalues; ++$i )
	{
		if( $cols>1 && $i % $col_len == 0 )
		{
			++$col_n;
			my $td = $session->make_element( "td", valign=>"top", class=>"ep_view_col_".$col_n );
			$add_ul = $session->make_element( "ul" );
			$td->appendChild( $add_ul );	
			$tr->appendChild( $td );	
		}
		my $value = $showvalues[$i];
		my $size = 0;
		my $id = $fields->[0]->get_id_from_value( $session, $value );
		if( defined $sizes && defined $sizes->{$id} )
		{
			$size = $sizes->{$id};
		}

		next if( $view->{hideempty} && $size == 0 );

		my $fileid = $fields->[0]->get_id_from_value( $session, $value );

		my $li = $session->make_element( "li" );

		my $link = EPrints::Utils::escape_filename( $fileid );
		if( $has_submenu )
		{
			$link .= '/';
		}
		else
		{
			$link .= '.html';
		}
		my $a = $session->render_link( $link );
		$a->appendChild(
			$fields->[0]->get_value_label(
				$session,
				$value ) );
		$li->appendChild( $a );
		if( defined $sizes && defined $sizes->{$value} )
		{
			$li->appendChild( $session->make_text( " (".$sizes->{$value}.")" ) );
		}
		$add_ul->appendChild( $li );
	}

	return $f;
}

sub render_view_subj_menu
{
	my( $session, $view, $sizes, $values, $fields, $has_submenu ) = @_;

	my $subjects_to_show = $values;

	if( $view->{hideempty} && defined $sizes)
	{
		my %show = ();
		foreach my $value ( @{$values} )
		{
			next unless( defined $sizes->{$value} && $sizes->{$value} > 0 );
			my $subject = EPrints::DataObj::Subject->new(
					 $session, $value );
			my @ids= @{$subject->get_value( "ancestors" )};
			foreach my $id ( @ids ) { $show{$id} = 1; }
		}
		$subjects_to_show = [];
		foreach my $value ( @{$values} )
		{
			next unless( $show{$value} );
			push @{$subjects_to_show}, $value;
		}
	}

	my $f = $session->make_doc_fragment;
	foreach my $field ( @{$fields} )
	{
		$f->appendChild(
			$session->render_subjects(
				$subjects_to_show,
				$field->get_property( "top" ),
				undef,
				($has_submenu?3:2),
				$sizes ) );
	}

	return $f;
}


sub get_fields_from_config
{
	my( $ds, $fieldconfig ) = @_;

	my @fields = ();
	foreach my $cofieldconfig ( split( ",", $fieldconfig ))
	{
		$cofieldconfig =~ s/^-//;
		my @cofields = ();
		foreach my $fieldid ( split( "/", $cofieldconfig ))
		{
			my $field = EPrints::Utils::field_from_config_string( $ds, $fieldid );
			unless( $field->is_browsable() )
			{
				EPrints::abort( "Cannot generate browse pages for field \"".$fieldid."\"\n- Type \"".$field->get_type()."\" cannot be browsed.\n" );
			}
			push @cofields, $field;
		}
		push @fields,[@cofields];
	}
	return @fields
}


# Update a (set of) view list(s) - potentially expensive to do.

# nb. path_values are considered escaped at this point
sub update_view_list
{
	my( $session, $view, $langid, $esc_path_values ) = @_;

	my $repository = $session->get_repository;

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/".$view->{id}."/";

	my $filename = pop @{$esc_path_values};
	foreach( @{$esc_path_values} ) { $target .= "$_/"; }

	my( $value, $suffix ) = split( /\./, $filename );
	$target .= $value;

	push @{$esc_path_values}, $value;

	my $path_values = [];
	foreach my $esc_value (@{$esc_path_values})
	{
		push @{$path_values}, EPrints::Utils::unescape_filename( $esc_value );
	}

	my $ds = $repository->get_dataset( "archive" );

	my @fields = get_fields_from_config( $ds, $view->{fields} );
	my @menu_levels = split( ",", $view->{fields} );

	my $menu_level = 0;
	my $filters;
	if( defined $esc_path_values )
	{
		$filters = [];
		$menu_level = scalar @{$esc_path_values};
		# check values are valid
		for( my $i=0; $i<$menu_level; ++$i )
		{
			if( $path_values->[$i] eq "NULL" )
			{
				push @{$filters}, { fields=>$fields[$i], value=>"" };
				next;
			}
			my $key_values = get_fieldlist_values( $session, $ds, $fields[$i] );
			my $value = $key_values->{$path_values->[$i]};
			if( !defined($value) )
			{
				$repository->log( "Invalid value id in update_view_list '".$esc_path_values->[$i]."' in menu: ".$view->{id}."/".join( "/", @{$esc_path_values} )."/" );
				return;
			}
			push @{$filters}, { fields=>$fields[$i], value=>$value };
		}
	}

	# if number of fields is 1 then menu_level must be 1
	# if number of fields is 2 then menu_level must be 2
	# etc.
	if( $menu_level != scalar @fields )
	{
		$repository->log( "Wrong depth to generate a view list: ".$view->{id}."/".join( "/", @{$esc_path_values} ) );
		return;
	}

	my $searchexp = new EPrints::Search(
				custom_order=>$view->{order},
				satisfy_all=>1,
				session=>$session,
				dataset=>$ds );
	$searchexp->add_field( $ds->get_field('metadata_visibility'), 'show', 'EQ' );
	my $n=0;
	foreach my $filter ( @{$filters} )
	{
     		$searchexp->add_field( $filter->{fields}, $filter->{value}, "EX", undef, "filter".($n++), 1 );
	}
      	my $list = $searchexp->perform_search;

	my $count = $list->count;
	my @items = $list->get_records;
	$list->dispose;

	# modes = first_letter, first_value, all_values (default)
	my $alt_views = $view->{variations};
	if( !defined $alt_views )
	{
		$alt_views = [ 'DEFAULT' ];
	}

	my @files = ();
	my $first_view = 1;	
	ALTVIEWS: foreach my $alt_view ( @{$alt_views} )
	{
		my( $fieldname, $options ) = split( ";", $alt_view );
		my $opts = get_view_opts( $options, $fieldname );

		my $page_file_name = "$target.".$opts->{"filename"};
		if( $first_view ) { $page_file_name = $target; }

		push @files, $page_file_name;

		my $need_path = $page_file_name;
		$need_path =~ s/\/[^\/]*$//;
		EPrints::Platform::mkdir( $need_path );

		my $title;
		my $phrase_id = "viewtitle_".$ds->confid()."_".$view->{id}."_list";
	
		if( $session->get_lang()->has_phrase( $phrase_id ) )
		{
			my %o = ();
			for( my $i = 0; $i < scalar( @{$esc_path_values} ); ++$i )
			{
				my @menu_fields = @{$fields[$i]};
				my $value = EPrints::Utils::unescape_filename($esc_path_values->[$i]);
				$value = "" if $value eq "NULL";
				$o{"value".($i+1)} = $menu_fields[0]->render_single_value( $session, $value);
			}		
			my $grouping_phrase_id = "viewgroup_".$ds->confid()."_".$view->{id}."_".$opts->{filename};
			if( $session->get_lang()->has_phrase( $grouping_phrase_id ) )
			{
				$o{"grouping"} = $session->html_phrase( $grouping_phrase_id );
			}
			elsif( $fieldname eq "DEFAULT" )
			{
				$o{"grouping"} = $session->html_phrase( "Update/Views:no_grouping_title" );
			}	
			else
			{
				my $gfield = $ds->get_field( $fieldname );
				$o{"grouping"} = $gfield->render_name( $session );
			}

			$title = $session->html_phrase( $phrase_id, %o );
		}
	
		if( !defined $title )
		{
			$title = $session->html_phrase(
				"bin/generate_views:indextitle",
				viewname=>$session->make_text( $session->get_view_name( $ds, $view->{id} ) ) );
		}


		# This writes the title including HTML tags
		open( TITLE, ">$page_file_name.title" ) || EPrints::abort( "Failed to write $page_file_name.title: $!" );
		binmode(TITLE,":utf8");
		print TITLE $title->toString;
		close TITLE;

		# This writes the title with HTML tags stripped out.
		open( TITLETXT, ">$page_file_name.title.textonly" ) || EPrints::abort( "Failed to write $page_file_name.title.textonly: $!" );
		binmode(TITLETXT,":utf8");
		print TITLETXT EPrints::Utils::tree_to_utf8( $title );
		close TITLETXT;

		if( defined $view->{template} )
		{
			open( TEMPLATE, ">$page_file_name.template" ) || EPrints::abort( "Failed to write $page_file_name.template: $!" );
			binmode(TEMPLATE,":utf8");
			print TEMPLATE $view->{template};
			close TEMPLATE;
		}

		open( PAGE, ">$page_file_name.page" ) || EPrints::abort( "Failed to write $page_file_name.page: $!" );
		binmode(PAGE,":utf8");
		open( INCLUDE, ">$page_file_name.include" ) || EPrints::abort( "Failed to write $page_file_name.include: $!" );
		binmode(INCLUDE,":utf8");

		my $navigation_aids = EPrints::XML::to_string( 
			render_navigation_aids( $session, $path_values, $view, \@fields, "list" ) );

		print PAGE $navigation_aids;
		print INCLUDE $navigation_aids;
		
		print PAGE "<div class='ep_view_page ep_view_page_view_".$view->{id}."'>";
		print INCLUDE "<div class='ep_view_page ep_view_page_view_".$view->{id}."'>";

		# Render links to alternate groupings
		if( scalar @{$alt_views} > 1 && $count )
		{
			my $groups = $session->make_doc_fragment;
			my $first = 1;
			foreach my $alt_view2 ( @{$alt_views} )
			{
				my( $fieldname2, $options2 ) = split( /;/, $alt_view2 );
				my $opts2 = get_view_opts( $options2,$fieldname2 );

				my $link_name = "$target.".$opts2->{"filename"};
				if( $first ) { $link_name = $target; }

				if( !$first )
				{
					$groups->appendChild( $session->html_phrase( "Update/Views:group_seperator" ) );
				}

				my $group;
				my $phrase_id = "viewgroup_".$ds->confid()."_".$view->{id}."_".$opts2->{filename};
				if( $session->get_lang()->has_phrase( $phrase_id ) )
				{
					$group = $session->html_phrase( $phrase_id );
				}
				elsif( $fieldname2 eq "DEFAULT" )
				{
					$group = $session->html_phrase( "Update/Views:no_grouping" );
				}
				else
				{
					$group = $ds->get_field( $fieldname2 )->render_name( $session );
				}
				
				if( $opts->{filename} eq $opts2->{filename} )
				{
					$group = $session->html_phrase( "Update/Views:current_group", group=>$group );
				}
				else
				{
					$link_name =~ /([^\/]+)$/;
					my $link = $session->render_link( "$1.html" );
					$link->appendChild( $group );
					$group = $link;
				}
		
				$groups->appendChild( $group );

				$first = 0;
			}

			print PAGE $session->html_phrase( "Update/Views:group_by", groups=>$groups )->toString;
		}

		my $field;
		if( $fieldname ne "DEFAULT" )
		{
			$field = $ds->get_field( $fieldname );
		}


		# Intro phrase, if any 
		my $intro_phrase_id = "viewintro_".$view->{id};
		if( defined $esc_path_values )
		{
			$intro_phrase_id.= "/".join( "/", @{$esc_path_values} );
		}
		my $intro = "";
		if( $session->get_lang()->has_phrase( $intro_phrase_id ) )
		{
			$intro = $session->html_phrase( $intro_phrase_id )->toString;
		}

		# Number of items div.
		my $count_div = "";
		unless( $view->{nocount} )
		{
			my $phraseid = "bin/generate_views:blurb";
			if( $fields[-1]->[0]->is_type( "subject" ) )
			{
				$phraseid = "bin/generate_views:subject_blurb";
			}
			$count_div = $session->html_phrase(
				$phraseid,
				n=>$session->make_text( $count ) )->toString;
		}

		# Timestamp div
		my $time_div = "";
		unless( $view->{notimestamp} )
		{
			$time_div = $session->html_phrase(
				"bin/generate_views:timestamp",
					time=>$session->make_text(
						EPrints::Time::human_time() ) )->toString;
		}


		if( defined $opts->{render_fn} )
		{
			my $block = $repository->call( $opts->{render_fn}, 
					$session,
					\@items,
					$view,
					$path_values,
					$opts->{filename} );

			print PAGE $intro;
			print PAGE $count_div;
			print PAGE $block;
			print PAGE $time_div;
			print PAGE "</div>\n";
			close PAGE;

			print INCLUDE $intro;
			print INCLUDE $count_div;
			print INCLUDE $block;
			print INCLUDE $time_div;
			print INCLUDE "</div>\n";
			close INCLUDE;

			$first_view = 0;
			next ALTVIEWS;
		}


		# If this grouping is "DEFAULT" then there is no actual grouping-- easy!
		if( $fieldname eq "DEFAULT" ) 
		{
			my( $block, $n ) = render_array_of_eprints( $session, $view, \@items );
			print PAGE $intro;
			print PAGE $count_div;
			print PAGE $block;
			print PAGE $time_div;
			print PAGE "</div>\n";
			close PAGE;

			print INCLUDE $intro;
			print INCLUDE $count_div;
			print INCLUDE $block;
			print INCLUDE $time_div;
			print INCLUDE "</div>\n";
			close INCLUDE;

			$first_view = 0;
			next ALTVIEWS;
		}

		my $data = group_items( $session, \@items, $field, $opts );

		my $first = 1;
		my $jumps = $session->make_doc_fragment;
		my $total = 0;
		my $maxsize = 1;
		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};
			my $n = scalar @$items;
			if( $n > $maxsize ) { $maxsize = $n; }
		}
		my $range;
		if( $opts->{cloud} )
		{
			$range = $opts->{cloudmax} - $opts->{cloudmin};
		}
		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};
			if( scalar @$items == 0 )
			{
				print STDERR "ODD: $code has no items\n";
				next;
			}
	
			if( !$first )
			{
				if( $opts->{"no_seperator"} ) 
				{
					$jumps->appendChild( $session->make_text( " " ) );
				}
				else
				{
					$jumps->appendChild( $session->html_phrase( "Update/Views:jump_seperator" ) );
				}
			}

			my $link = $session->render_link( "#group_".EPrints::Utils::escape_filename( $code ) );
			$link->appendChild( $session->clone_for_me($heading,1) );
			if( $opts->{cloud} )
			{
				my $size = int( $range * ( log(1+scalar @$items ) / log(1+$maxsize) ) ) + $opts->{cloudmin};
				my $span = $session->make_element( "span", style=>"font-size: $size\%" );
				$span->appendChild( $link );
				$jumps->appendChild( $span );
			}
			else
			{
				$jumps->appendChild( $link );
			}

			$first = 0;
		}
		my $jumpmenu = "";
		if( $opts->{"jump"} eq "plain" ) 
		{
			$jumpmenu = $jumps->toString;
		}
		if( $opts->{"jump"} eq "default" )
		{
			$jumpmenu = $session->html_phrase( "Update/Views:jump_to", jumps=>$jumps )->toString;
		}

		# css for your convenience
		my $viewid = $view->{id};
		$jumpmenu =  "<div class='ep_view_jump ep_view_${viewid}_${fieldname}_jump'>$jumpmenu</div>";

		if( $count )
		{
			print PAGE $jumpmenu;
			print INCLUDE $jumpmenu;
		}

		print PAGE $intro;
		print INCLUDE $intro;

		print PAGE $count_div;
		print INCLUDE $count_div;

		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};

			print PAGE "<a name='group_".EPrints::Utils::escape_filename( $code )."'></a>\n";
			print INCLUDE "<a name='group_".EPrints::Utils::escape_filename( $code )."'></a>\n";
		
			print PAGE "<h2>".$heading->toString."</h2>";
			print INCLUDE "<h2>".$heading->toString."</h2>";
			my( $block, $n ) = render_array_of_eprints( $session, $view, $items );
			print PAGE $block;
			print INCLUDE $block;
		}

		print PAGE $time_div;
		print INCLUDE $time_div;

		print PAGE "</div>\n";
		print INCLUDE "</div>\n";

		close PAGE;
		close INCLUDE;
		$first_view = 0;
	}

	return @files;
}

# pagetype is "menu" or "list"
sub render_navigation_aids
{
	my( $session, $path_values, $view, $fields, $pagetype ) = @_;

	my $f = $session->make_doc_fragment();

	# this is the field of the level ABOVE this level. So we get options to 
	# go to related values in subjects.	
	my $fields_being_browsed;
	if( scalar @{$path_values} )
	{
		$fields_being_browsed = $fields->[scalar @{$path_values}-1];
	}

	if( scalar @{$path_values} && !$view->{hideup} )
	{
		$f->appendChild( $session->html_phrase( "Update/Views:up_a_level" ) );
	}

	if( defined $fields_being_browsed && $fields_being_browsed->[0]->is_type( "subject" ) )
	{
		my @all_but_this_level_path_values = @{$path_values};
		pop @all_but_this_level_path_values;
		my $sizes = get_sizes( $session, $view, \@all_but_this_level_path_values );
		my $subject = EPrints::Subject->new( $session, $path_values->[-1] );
		my @ids= @{$subject->get_value( "ancestors" )};
		foreach my $sub_subject ( $subject->get_children() )
		{
			push @ids, $sub_subject->get_value( "subjectid" );
		}
	
		# strip empty subjects if needed
		if( $view->{hideempty} )
		{
			my @newids = ();
			foreach my $id ( @ids )
			{
				push @newids, $id if $sizes->{$id};
			}
			@ids = @newids;
		}
		
		my $mode = 2;
		if( $pagetype eq "menu" ) { $mode = 4; }
		foreach my $field ( @{$fields_being_browsed} )
		{
			my $div_box = $session->make_element( "div", class=>"ep_toolbox" );
			my $div_contents = $session->make_element( "div", class=>"ep_toolbox_content" );
			$f->appendChild( $div_box );
			$div_box->appendChild( $div_contents );
			$div_contents->appendChild( 
				$session->render_subjects( 
					\@ids, 
					$field->get_property( "top" ), 
					$path_values->[-1], 
					$mode, 
					$sizes ) );
		}
	}

	return $f;
}
	
sub group_items
{
	my( $session, $items, $field, $opts ) = @_;

	my $code_to_list = {};
	my $code_to_heading = {};
	my $code_to_value = {}; # used if $opts->{string} is NOT set.
	
	foreach my $item ( @$items )
	{
		my $values = $item->get_value( $field->get_name );
		if( !$field->get_property( "multiple" ) )
		{
			$values = [$values];
		}
		VALUE: foreach my $value ( @$values )
		{
			my $code = $value;
			if( $opts->{tags} )
			{
				$value =~ s/\.$//;
				KEYWORD: foreach my $keyword ( split /[;,]\s*/, $value )
				{
					next KEYWORD if( !defined $keyword );
					$keyword =~ s/^\s+//;
					$keyword =~ s/\s+$//;
					next KEYWORD if( $keyword eq "" );

					if( !defined $code_to_heading->{"\L$keyword"} )
					{
						$code_to_heading->{"\L$keyword"} = $session->make_text( $keyword );
					}
					push @{$code_to_list->{"\L$keyword"}}, $item;
				}
			}
			else
			{
				if( $field->get_type eq "name" )
				{
					if( $opts->{first_initial} )
					{
						$code = $value->{family}.", ".(substr( $value->{given},0,1));
					}
					else
					{
						$code = $value->{family}.", ".$value->{given};
					}
				}
				if( $opts->{"truncate"} )
				{
					$code = substr( "\u$code", 0, $opts->{"truncate"} );
				}
				push @{$code_to_list->{$code}}, $item;

				if( !defined $code_to_heading->{$code} )
				{
					$code_to_value->{$code} = $value;
					if( $opts->{"string"} )
					{
						if( $code eq "" )
						{
							$code_to_heading->{$code} = $session->make_text( "NULL" );
						}
						else
						{
							$code_to_heading->{$code} = $session->make_text( $code );
						}
					}
					else
					{
						$code_to_heading->{$code} = $field->render_single_value( $session, $value );
					}
				}
			}
			
			if( $opts->{first_value} ) { last VALUE; } 
		}
	}

	my $langid = $session->get_langid;
	my $data = [];
	my @codes;

	if( $opts->{"string"} )
	{
		@codes = sort keys %{$code_to_list};
	}
	else
	{
		@codes = sort 
			{ 
				my $v_a = $code_to_value->{$a};
				my $v_b = $code_to_value->{$b};
				my $o_a = $field->ordervalue_basic( $v_a, $session, $langid );
				my $o_b = $field->ordervalue_basic( $v_b, $session, $langid );
				return $o_a cmp $o_b;
			}
			keys %{$code_to_list};
	}

	if( $opts->{reverse} )
	{
		@codes = reverse @codes;
	}

	foreach my $code ( @codes )
	{
		push @{$data}, [ $code, $code_to_heading->{$code}, $code_to_list->{$code} ];
	}
	return $data;
}

sub render_array_of_eprints
{
	my( $session, $view, $items ) = @_;

	my @r = ();

	$view->{layout} = "paragraph" unless defined $view->{layout};	
	foreach my $item ( @{$items} )
	{

		my $ctype = $view->{citation}||"default";
		if( !defined $session->{citesdone}->{$ctype}->{$item->get_id} )
		{
			my $cite = EPrints::XML::to_string( $item->render_citation_link( $view->{citation} ) );
			$session->{citesdone}->{$ctype}->{$item->get_id} = $cite;
		}
		my $cite = $session->{citesdone}->{$ctype}->{$item->get_id};

		if( $view->{layout} eq "paragraph" )
		{
			push @r, "<p>", $cite, "</p>\n";
		}
		elsif( 
			$view->{layout} eq "orderedlist" ||
			$view->{layout} eq "unorderedlist" )
		{
			push @r, "<li>", $cite, "</li>\n";
		}
		else
		{
			push @r, $cite, "\n";
		}
	}

	my $n = @{$items};
	if( !defined $view->{layout} )
	{
		return( join( "", @r ), $n );
	}
	elsif( $view->{layout} eq "orderedlist" )
	{
		return( join( "", "<ol>",@r,"</ol>" ), $n );
	}
	elsif( $view->{layout} eq "unorderedlist" )
	{
		return( join( "", "<ul>",@r,"</ul>" ), $n );
	}
	else
	{
		return( join( "", @r ), $n );
	}
}



sub get_view_opts
{
	my( $options, $fieldname ) = @_;
 
	my $opts = {};
	$options = "" unless defined $options;
	foreach my $optspec ( split( ",", $options ) )
	{
		my( $opt, $opt_value );
		if( $optspec =~ m/=/ )
		{
			( $opt, $opt_value ) = split( /=/, $optspec );
		}	
		else
		{
			( $opt, $opt_value ) = ( $optspec, 1 );
		}
		$opts->{$opt} = $opt_value;
	}

	if( $opts->{first_letter} )
	{
		$opts->{"truncate"} = 1;
		$opts->{"first_value"} = 1;
	}
	
	# string indicates that the values of the headings are not
	# values suitable for the field value renderer & ordering.
	$opts->{"string"} = 1 if( $opts->{"truncate"} );
	$opts->{"string"} = 1 if( $opts->{"tags"} );
	$opts->{"string"} = 1 if( $opts->{"first_initial"} );

	# other options are "none" and "plain";
	$opts->{"jump"} = "default" if( !defined $opts->{"jump"} );

	$opts->{"cloud"} = 1 if( $opts->{"cloudmin"} );
	$opts->{"cloud"} = 1 if( $opts->{"cloudmax"} );
	if( $opts->{"cloud"} )
	{
		$opts->{"jump"} = "plain";
		$opts->{"no_seperator"} = 1;
		$opts->{"cloudmin"} = 80 unless defined $opts->{"cloudmin"};
		$opts->{"cloudmax"} = 200 unless defined $opts->{"cloudmax"};
	}

	if( !defined $opts->{"filename"} )
	{
		$opts->{"filename"} = "\L$fieldname";
	}

	return $opts;
}








1;
