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
		$age = time - EPrints::Utils::mtime( "$target.page" );
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
	
	$uri =~ m#^/view(/(([^/]+)(/(.*))?)?)?$#;

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
	my( $session, $view, $path_values ) = @_;

	my $repository = $session->get_repository;

	my $ds = $repository->get_dataset( "archive" );

	my @fields = get_fields_from_config( $ds, $view->{fields} );

	my @menu_levels = split( ",", $view->{fields} );
	my $menu_level = scalar @{$path_values};

	my $filters = [];

	for( my $i=0; $i<$menu_level; ++$i )
	{
		my $ok = 0;
		LEVELTEST: foreach my $a_value ( get_fieldlist_values( $session, $ds, $fields[$i] ) )
		{
			if( $a_value eq $path_values->[$i] )
			{
				$ok = 1;
				last LEVELTEST;
			}
		}
		if( !$ok )
		{
			$repository->log( "Invalid path value '".$path_values->[$i]."' in menu: ".$view->{id}."/".join( "/", @{$path_values} )."/" );
			return;
		}
		push @{$filters}, { fields=>$fields[$i], value=>$path_values->[$i] };
	}

	return $filters;
}

# return a hash mapping keys at this level to number of items in db
# if a leaf level, return undef

sub get_sizes
{
	my( $session, $view, $path_values ) = @_;

	my $ds = $session->get_repository->get_dataset( "archive" );

	my @fields = get_fields_from_config( $ds, $view->{fields} );

	my $menu_level = scalar @{$path_values};

	if( !defined $fields[$menu_level] )
	{
		# no sub pages at this level
		return undef;
	}

	my $filters = get_filters( $session, $view, $path_values );

	my @menu_fields = @{$fields[$menu_level]};

	my $show_sizes = get_fieldlist_totals( $session, $ds, \@menu_fields, $filters );

	return $show_sizes;
}

# Update a view menu - potentially expensive to do.

sub update_view_menu
{
	my( $session, $view, $langid, $path_values ) = @_;

	my $repository = $session->get_repository;
	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/".$view->{id}."/";
	if( defined $path_values )
	{
		$target .= join( "/", @{$path_values}, "index" );
	}
	else
	{
		$target .= "index";
	}

	my $menu_level = 0;
	my $filters;
	if( defined $path_values )
	{
		$filters = [];
		$menu_level = scalar @{$path_values};

		$filters = get_filters( $session, $view, $path_values );
	
		return if !defined $filters;
	}	

	my $ds = $repository->get_dataset( "archive" );
	my @fields = get_fields_from_config( $ds, $view->{fields} );
	my @menu_levels = split( ",", $view->{fields} );

	# if number of fields is 1 then menu_level must be 0
	# if number of fields is 2 then menu_level must be 0 or 1 
	# etc.
	if( $menu_level >= scalar @fields )
	{
		$repository->log( "Too many values when asked for a for view menu: ".$view->{id}."/".join( "/", @{$path_values} )."/" );
		return;
	}

	# fields for the current menu level
	my @menu_fields = @{$fields[$menu_level]};

	my @values = get_fieldlist_values( $session, $ds, \@menu_fields );

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

	my $show_sizes = get_fieldlist_totals( $session, $ds, \@menu_fields, $filters );

	# Not doing submenus just yet.
	my $has_submenu = 0;
	if( scalar @menu_levels > $menu_level+1 )
	{
		$has_submenu = 1;
	}

	my $page = $session->make_element( "div", class=>"ep_view_menu" );
	$page->appendChild( $session->html_phrase( "bin/generate_views:intro" ) );

	my $render_menu_fn = \&render_view_menu;
	if( $menu_fields[0]->is_type( "subject" ) )
	{
		$render_menu_fn = \&render_view_subj_menu;
	}
	$page->appendChild( &{$render_menu_fn}(
				$session,
				$view,
				$show_sizes,
				\@values,
				\@menu_fields,
				$has_submenu ) );


	my $title;
	my $phrase_id = "viewtitle_".$ds->confid()."_".$view->{id}."_menu_".( $menu_level + 1 );

	if( $session->get_lang()->has_phrase( $phrase_id ) && defined $path_values )
	{
		my %o = ();
		for( my $i = 0; $i < scalar( @{$path_values} ); ++$i )
		{
			my @menu_fields = @{$fields[$i]};
			$o{"value".($i+1)} = $menu_fields[0]->render_single_value( $session, $path_values->[$i]);
		}
		$title = $session->html_phrase( $phrase_id, %o );
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

	return( $target );
}

sub get_fieldlist_totals
{
	my( $session, $ds, $fields, $filters ) = @_;

	my %map=();
	foreach my $field ( @{$fields} )
	{
		my $vref = $field->get_ids_by_value( $session, $ds, filters=>$filters );

		foreach my $v ( keys %{$vref} )
		{
			foreach my $id ( @{$vref->{$v}} )
			{
				$map{$v}->{$id} = 1;
			}
		}
	}

	my $totals = {};
	foreach my $v ( keys %map )
	{
		$totals->{$v} = scalar keys %{$map{$v}};
	}
	
	return $totals;
}

sub get_fieldlist_values
{
	my( $session, $ds, $fields ) = @_;

	if( $fields->[0]->is_type( "name" ) )
	{
		my %v=();
		foreach my $field ( @{$fields} )
		{
			my $vref = $field->get_values( $session, $ds );
			foreach( @{$vref} )
			{
				if( !defined $_ ) { $_=""; }
				$_->{given} = '' unless defined( $_->{given} );
				$_->{family} = '' unless defined( $_->{family} );
				$v{$_->{given}.':'.$_->{family}}=$_; 
			}
		}
		return values %v;
	}

	my %v=();
	foreach my $field ( @{$fields} )
	{
		my $vref = $field->get_values( $session, $ds );
		foreach( @{$vref} )
		{ 
			if( !defined $_ ) { $_=""; }
			$v{$_}=1; 
		}
	}
	return keys %v;
}

sub render_view_menu
{
	my( $session, $view, $sizes, $values, $fields, $has_submenu ) = @_;

	my $ul = $session->make_element( "ul" );

	foreach my $value ( @{$values} )
	{
		my $size = 0;
		if( defined $sizes && defined $sizes->{$value} )
		{
			$size = $sizes->{$value};
		}

		next if( $view->{hideempty} && $size == 0 );

		my $fileid = &mk_file_id( $value, $fields->[0]->get_type );

		my $li = $session->make_element( "li" );

		my $link = $fileid;
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
		$ul->appendChild( $li );
	}

	return $ul;
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


sub mk_file_id
{
	my( $value, $type ) = @_;

	my $fileid = $value;
	if( $type eq "name" )
	{
		$fileid = EPrints::Utils::make_name_string( $value );
	}

	return EPrints::Utils::escape_filename( $fileid );
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
			#print STDERR "cjg-($fieldid)\n";
			push @cofields, $field;
		}
		push @fields,[@cofields];
	}
	return @fields
}


# Update a (set of) view list(s) - potentially expensive to do.

sub update_view_list
{
	my( $session, $view, $langid, $path_values ) = @_;

	my $repository = $session->get_repository;

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/".$view->{id}."/";

	my $filename = pop @{$path_values};
	foreach( @{$path_values} ) { $target .= "$_/"; }

	my( $value, $suffix ) = split( /\./, $filename );
	$target .= $value;

	push @{$path_values}, $value;
	for(@$path_values)
	{
		$_ = EPrints::Utils::unescape_filename( $_ );
	}

	my $ds = $repository->get_dataset( "archive" );

	my @fields = get_fields_from_config( $ds, $view->{fields} );
	my @menu_levels = split( ",", $view->{fields} );

	my $menu_level = 0;
	my $filters;
	if( defined $path_values )
	{
		$filters = [];
		$menu_level = scalar @{$path_values};
		# check values are valid
		for( my $i=0; $i<$menu_level; ++$i )
		{
			my $ok = 0;
			LEVELTEST: foreach my $a_value ( get_fieldlist_values( $session, $ds, $fields[$i] ) )
			{
				if( $a_value eq $path_values->[$i] )
				{
					$ok = 1;
					last LEVELTEST;
				}
			}
			if( !$ok )
			{
				$repository->log( "Invalid path value '".$path_values->[$i]."' in menu: ".$view->{id}."/".join( "/", @{$path_values} ) );
				return;
			}
			push @{$filters}, { fields=>$fields[$i], value=>$path_values->[$i] };
		}
	}

	# if number of fields is 1 then menu_level must be 1
	# if number of fields is 2 then menu_level must be 2
	# etc.
	if( $menu_level != scalar @fields )
	{
		$repository->log( "Wrong depth to generate a view list: ".$view->{id}."/".join( "/", @{$path_values} ) );
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
		my( $fieldname, $mode ) = split( ";", $alt_view );
		$mode = "all_values" if( !defined $mode );

		my $page_file_name = "$target.\L$fieldname";
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
			for( my $i = 0; $i < scalar( @{$path_values} ); ++$i )
			{
				my @menu_fields = @{$fields[$i]};
				$o{"value".($i+1)} = EPrints::Utils::tree_to_utf8($menu_fields[0]->render_single_value( $session, $path_values->[$i]));
			}
			if( $fieldname eq "DEFAULT" )
			{
				$o{"grouping"} = $session->phrase( "Update/Views:no_grouping_title" );
			}	
			else
			{
				my $gfield = $ds->get_field( $fieldname );
				$o{"grouping"} = $gfield->render_name( $session )->toString;
			}

			$title = $session->phrase( $phrase_id, %o );
		}
	
		if( !defined $title )
		{
			$title = $session->phrase(
				"bin/generate_views:indextitle",
				viewname=>$session->get_view_name( $ds, $view->{id} ) );
		}


		# needs html escaping?
		# needs open testing etc.
		open( TITLE, ">$page_file_name.title" ) || EPrints::abort( "Failed to write $page_file_name.title: $!" );
		print TITLE $title;
		close TITLE;
		open( TITLETXT, ">$page_file_name.title.textonly" ) || EPrints::abort( "Failed to write $page_file_name.title.textonly: $!" );
		print TITLETXT $title;
		close TITLETXT;
		if( defined $view->{template} )
		{
			open( TEMPLATE, ">$page_file_name.template" ) || EPrints::abort( "Failed to write $page_file_name.template: $!" );
			print TEMPLATE $view->{template};
			close TEMPLATE;
		}

		open( PAGE, ">$page_file_name.page" ) || EPrints::abort( "Failed to write $page_file_name.page: $!" );

		print PAGE "<div class='ep_view_page ep_view_page_view_".$view->{id}."'>";


		if( scalar @{$alt_views} > 1 )
		{
			my $groups = $session->make_doc_fragment;
			my $first = 1;
			foreach my $alt_view2 ( @{$alt_views} )
			{
				my( $fieldname2, $mode2 ) = split( /;/, $alt_view2 );

				my $link_name = "$target.\L$fieldname2";

				if( $first ) { $link_name = $target; }

				if( !$first )
				{
					$groups->appendChild( $session->html_phrase( "Update/Views:group_seperator" ) );
				}

				my $group;
				if( $fieldname2 eq "DEFAULT" )
				{
					$group = $session->html_phrase( "Update/Views:no_grouping" );
				}
				else
				{
					$group = $ds->get_field( $fieldname2 )->render_name( $session );
				}
				
				if( $fieldname eq $fieldname2 )
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

		if( $fieldname eq "DEFAULT" ) 
		{
			my( $block, $n ) = render_array_of_eprints( $session, $view, \@items );
			print PAGE $block;
			print PAGE "</div>\n";
			close PAGE;
			$first_view = 0;
			next ALTVIEWS;
		}


		my $field = $ds->get_field( $fieldname );
		my $data = group_items( $session, \@items, $field, $mode );


		my $first = 1;
		my $jumps = $session->make_doc_fragment;
		foreach my $pair ( @{$data} )
		{
			my( $code, $value, $items ) = @{$pair};
	
			if( !$first )
			{
				$jumps->appendChild( $session->html_phrase( "Update/Views:jump_seperator" ) );
			}

			my $link = $session->render_link( "#".EPrints::Utils::escape_filename( $code ) );
			if( $mode eq "first_letter" )
			{
				$link->appendChild( $session->make_text( $code ) );
			}
			else
			{
				$link->appendChild( $field->render_single_value( $session, $value ) );
			}

			$jumps->appendChild( $link );

			$first = 0;
		}
		print PAGE $session->html_phrase( "Update/Views:jump_to", jumps=>$jumps )->toString;

		foreach my $pair ( @{$data} )
		{
			my( $code, $value, $items ) = @{$pair};

			print PAGE "<a name='".EPrints::Utils::escape_filename( $code )."'></a>\n";
			my $heading;
			if( $mode eq "first_letter" )
			{
				$heading = $code;
			}
			else
			{
				$heading = EPrints::XML::to_string( $field->render_single_value( $session, $value ) );
			}
			
			print PAGE "<h2>$heading</h2>";
			my( $block, $n ) = render_array_of_eprints( $session, $view, $items );
			print PAGE $block;
		}



		print PAGE "</div>\n";
		close PAGE;
		$first_view = 0;
	}

	return @files;
}
	
sub group_items
{
	my( $session, $items, $field, $mode ) = @_;

	$mode = "all_values" unless defined $mode;

	my $code_to_list = {};
	my $code_to_value = {};
	
	foreach my $item ( @$items )
	{
		my $values = $item->get_value( $field->get_name );
		if( !$field->get_property( "multiple" ) )
		{
			$values = [$values];
		}
		VALUES: foreach my $value ( @$values )
		{
			my $code = $value;
			if( $field->get_type eq "name" )
			{
				$code = $value->{family}.", ".$value->{given};
			}
			if( $mode eq "first_letter" )
			{
				$code = substr( "\u$code", 0, 1 );
			}
			$code_to_value->{$code} = $value;
			push @{$code_to_list->{$code}}, $item;
			if( $mode eq "first_value" ) { last VALUES; } 
			if( $mode eq "first_letter" ) { last VALUES; } 
		}
	}
	my $langid = $session->get_langid;
	my $data = [];
	my @codes;

	if( $mode eq "first_letter" )
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

	foreach my $code ( @codes )
	{
		push @{$data}, [ $code, $code_to_value->{$code}, $code_to_list->{$code} ];
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
			$session->{citesdone}->{$ctype}->{$item->get_id} = $item->render_citation_link( $view->{citation} )->toString;;
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










1;
