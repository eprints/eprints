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
use Unicode::Collate;

use strict;
  
# This is the function which decides which type of view it is:
# * the main menu of views
# * the top level menu of a view
# * the sub menu of a view
# * a page within a single value of a view

# Does not update the file if it's not needed.

=item $path = abbr_path( $path )

This internal method replaces any part of $path that is longer than 40 characters with the MD5 of that part. It ignores file extensions (dot followed by anything).

=cut

sub abbr_path
{
	my( $path ) = @_;

	my @parts = split /\//, $path;
	foreach my $part (@parts)
	{
		next if length($part) < 40;
		my( $name, $ext ) = split /\./, $part, 2;
		$part = Digest::MD5::md5_hex($name);
		$part .= ".$ext" if defined $ext;
	}

	return join "/", @parts;
}

sub update_view_file
{
	my( $handle, $langid, $localpath, $uri ) = @_;

	my $repository = $handle->get_repository;

	$localpath = abbr_path( $localpath );

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid.$localpath;
	my $ext = $target =~ s/(\..*)// ? $1 : "";
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
			return "$target$ext";
		}
		return update_browse_view_list( $handle, $langid ) . $ext;
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

	if( !EPrints::Utils::is_set( $viewinfo ) || $viewinfo =~ s/^index[^\/]+$// )
	{
		if( defined $age && $age < $max_menu_age )
		{
			return "$target$ext";
		}

		return update_view_menu( $handle, $view, $langid ) . $ext;
	}

	if( $viewinfo =~ s/\/$// || $viewinfo =~ s/\/index[^\/]+$// )
	{
		if( defined $age && $age < $max_menu_age )
		{
			return "$target$ext";
		}

		# if it ends with "/" then it's a submenu
		my @view_path = split( '/', $viewinfo );
		
		return update_view_menu( $handle, $view, $langid, \@view_path ) . $ext;
	}

	# Otherwise it's (probably) a view list

	if( defined $age && $age < $max_list_age )
	{
		return "$target$ext";
	}

	my @view_path = split( '/', $viewinfo );
	return update_view_list( $handle, $view, $langid, \@view_path ) . $ext;
}



# Update the main menu of views (pretty cheap to do)
# return list of files written

sub update_browse_view_list
{
	my( $handle, $langid ) = @_;

	my $repository = $handle->get_repository;

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/index";

	my $ds = $repository->get_dataset( "archive" );

	my( $ul, $li, $page, $a, $file, $title );

	$page = $handle->make_doc_fragment();
	$page->appendChild( $handle->html_phrase( "bin/generate_views:browseintro" ) );

	$ul = $handle->make_element( "ul" );
	foreach my $view ( @{$repository->get_conf( "browse_views" )} )
	{
		modernise_view( $view );
		next if( $view->{nolink} );
		$li = $handle->make_element( "li" );
		$a = $handle->render_link( $view->{id}."/" );
		$a->appendChild( $handle->make_text( $handle->get_view_name( $ds, $view->{id} ) ) );
		$li->appendChild( $a );
		$ul->appendChild( $li );
	}
	$page->appendChild( $ul );

	$title = $handle->html_phrase( "bin/generate_views:browsetitle" );

	$handle->write_static_page( 
			$target, 
			{
				title => $title, 
				page => $page,
			},
			"browsemain" );

	return $target;
}

# return an array of the filters required for the given path_values
# or undef if something funny occurs.

sub get_filters
{
	my( $handle, $view, $esc_path_values ) = @_;

	my $repository = $handle->get_repository;

	my $menus_fields = get_fields_from_view( $repository, $view );

	my $menu_level = scalar @{$esc_path_values};

	my $filters = [];

	for( my $i=0; $i<$menu_level; ++$i )
	{
		my $menu_fields = $menus_fields->[$i];
		if( $esc_path_values->[$i] eq "NULL" )
		{
			push @{$filters}, { fields=>$menu_fields, value=>"" };
			next;
		}
		my $key_values = get_fieldlist_values( $handle, $menu_fields );
		my $value = $key_values->{EPrints::Utils::unescape_filename( $esc_path_values->[$i] )};
		if( !defined($value) )
		{
			$repository->log( "Invalid value id in get_filters '".$esc_path_values->[$i]."' in menu: ".$view->{id}."/".join( "/", @{$esc_path_values} )."/" );
			return;
		}
		push @{$filters}, { fields=>$menu_fields, value=>$value };
	}

	return $filters;
}

# return a hash mapping keys at this level to number of items in db
# if a leaf level, return undef

# path_values is escaped 
sub get_sizes
{
	my( $handle, $view, $esc_path_values ) = @_;

	my $menus_fields = get_fields_from_view( $handle->get_repository, $view );

	my $menu_level = scalar @{$esc_path_values};

	my $menu_fields = $menus_fields->[$menu_level];
	my $menu = $view->{menus}->[$menu_level];
	if( !defined $menu_fields )
	{
		# no sub pages at this level
		return undef;
	}

	my $filters = get_filters( $handle, $view, $esc_path_values );

	my $sizes = get_fieldlist_sizes( $handle, $menu_fields, $filters, $menu->{allow_null} );

	return $sizes;
}

# Update View Config to new structure
sub modernise_view
{
	my( $view ) = @_;

	if( defined $view->{fields} )
	{
		if( defined $view->{menus} )
		{
			EPrints::abort( "View ".$view->{id}." contains both fields and menus. Menus is the replacement for fields." );
		}

		$view->{menus} = [];
		foreach my $cofieldconfig ( split( ",", $view->{fields} ))
		{
			my $menu = { fields=>[] };
			if( $cofieldconfig =~ s/^-// )
			{
				$menu->{reverse_order} = 1;
			}
			my @cofields = ();
			foreach my $fieldid ( split( "/", $cofieldconfig ))
			{
				push @{$menu->{fields}}, $fieldid;
			}	
			push @{$view->{menus}}, $menu;
		}
		delete $view->{fields};
	}

	foreach my $confid ( qw/ allow_null new_column_at hideempty render_menu / )
	{
		next if( !defined $view->{$confid} );
		MENU: foreach my $menu ( @{$view->{menus}} )
		{
			next MENU if defined $menu->{$confid};
			$menu->{$confid} = $view->{$confid};
		}
	}
}

# Update a view menu - potentially expensive to do.

# nb. path_values are considered escaped at this point
sub update_view_menu
{
	my( $handle, $view, $langid, $esc_path_values ) = @_;

	modernise_view( $view );

	my $repository = $handle->get_repository;
	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/".$view->{id}."/";
	if( defined $esc_path_values && scalar @$esc_path_values )
	{
		$target .= abbr_path(join( "/", @{$esc_path_values}, "index" ));
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

		$filters = get_filters( $handle, $view, $esc_path_values );
	
		return if !defined $filters;

		foreach my $esc_value (@{$esc_path_values})
		{
			push @{$path_values}, EPrints::Utils::unescape_filename( $esc_value );
		}
	}	

	my $menus_fields = get_fields_from_view( $repository, $view );

	# if number of fields is 1 then menu_level must be 0
	# if number of fields is 2 then menu_level must be 0 or 1 
	# etc.
	if( $menu_level >= scalar @{$menus_fields} )
	{
		$repository->log( "Too many values when asked for a for view menu: ".$view->{id}."/".join( "/", @{$esc_path_values} )."/" );
		return;
	}

	# fields & config for the current menu level
	my $menu_fields = $menus_fields->[$menu_level];
	my $menu = $view->{menus}->[$menu_level];

	my $key_values = get_fieldlist_values( $handle, $menu_fields );
	my @values = values %$key_values;

	if( !$menu->{allow_null} )
	{
		my @new_values = ();
		foreach( @values ) { push @new_values,$_ unless $_ eq ""; }
		@values = @new_values;
	}

	# OK now we have a sorted list of values....

	@values = @{$menu_fields->[0]->sort_values( $handle, \@values )};

	if( $menu->{reverse_order} )
	{
		@values = reverse @values;
	}


	# now render the menu page

	my $sizes = get_fieldlist_sizes( $handle, $menu_fields, $filters, $menu->{allow_null} );

	# Not doing submenus just yet.
	my $has_submenu = 0;
	if( scalar @{$view->{menus}} > $menu_level+1 )
	{
		$has_submenu = 1;
	}

	my $mode = $menu->{mode};
	$mode = "default" unless defined $mode;

	my $fn;
	if( $mode eq "sections" ) 
	{
		$fn = \&create_sections_menu;
	}
	elsif( $mode eq "default" )
	{
		$fn = \&create_single_page_menu;
	}
	else
	{
		EPrints::abort( "Unknown menu mode for view '".$view->{id}."': mode=$mode" );
	}

	# note existing indexes
	my $dh;
	my @indexes = ();
	if( opendir( $dh, $target ) )
	{
		while( my $fn = readdir( $dh ) )
		{
			next unless( $fn =~ m/^index\./ );
			push @indexes, "$target/$fn";
		}
		closedir( $dh );
	}

	my @wrote_files = &{$fn}( $handle, $path_values, $esc_path_values, $menus_fields, $view, $sizes, \@values, $menu_fields, $has_submenu, $menu_level, $langid );
	
	FILE: foreach my $old_index_file ( @indexes )
	{
		foreach my $wrote_file ( @wrote_files )
		{
			foreach my $suffix ( qw/ title template page title.textonly include html / )
			{
				next FILE if( "$wrote_file.$suffix" eq $old_index_file );
			}
		}
		# file was not written this time around
		unlink( $old_index_file );
	}

	return $target;
}

# things we need to know to update a view menu
# char is optional, for browse-by-char menus
sub create_single_page_menu
{
	my( $handle, $path_values, $esc_path_values, $menus_fields, $view, $sizes, $values, $menu_fields, $has_submenu, $menu_level, $langid,    $ranges, $groupings, $range ) = @_;

	my $menu = $view->{menus}->[$menu_level];

	# work out filename
	my $target = $handle->get_repository->get_conf( "htdocs_path" )."/".$langid."/view/".$view->{id}."/";
	if( defined $esc_path_values && scalar @{$esc_path_values} > 0 )
	{
		$target .= join( "/", @{$esc_path_values}, "index" );
	}
	else
	{
		$target .= "index";
	}
	if( defined $range )
	{
		$target .= ".".EPrints::Utils::escape_filename( $range->[0] );
	}
	
	if( $menu->{open_first_section} && defined $ranges && !defined $range )
	{
		# the front page should show the first section
		$range = $ranges->[0];
	}

	my $page = $handle->make_element( "div", class=>"ep_view_menu" );

	my $navigation_aids = render_navigation_aids( $handle, $path_values, $esc_path_values, $view, $menus_fields, "menu" );
	$page->appendChild( $navigation_aids );

	my $phrase_id = "viewintro_".$view->{id};
	if( defined $esc_path_values )
	{
		$phrase_id.= "/".join( "/", @{$path_values} );
	}
	unless( $handle->get_lang()->has_phrase( $phrase_id, $handle ) )
	{
		$phrase_id = "bin/generate_views:intro";
	}
	$page->appendChild( $handle->html_phrase( $phrase_id ));

	if( defined $ranges )
	{
		my $div_box = $handle->make_element( "div", class=>"ep_toolbox" );
		my $div_contents = $handle->make_element( "div", class=>"ep_toolbox_content" );
		$page->appendChild( $div_box );
		$div_box->appendChild( $div_contents );
		my $first = 1;
		foreach my $range_i ( @{$ranges} )
		{
			my $l;
			if( !$first )
			{
				$div_contents->appendChild( $handle->make_text( " | " ) );
			}
			$first = 0 ;
			if( defined $range && $range->[0] eq $range_i->[0] )
			{
				$l = $handle->make_element( "b" );
			}
			else
			{
				$l = $handle->make_element( "a", href=>"index.".EPrints::Utils::escape_filename( $range_i->[0] ).".html" );
			}
			$div_contents->appendChild( $l );
			$l->appendChild( $handle->make_text( $range_i->[0] ) );
		}
	}

	if( defined $range )
	{
		foreach my $group_id ( @{$range->[1]} )
		{
			my @render_menu_opts = ( $handle, $menu, $sizes, $groupings->{$group_id}, $menu_fields, $has_submenu );

			my $h2 = $handle->make_element( "h2" );
			$h2->appendChild( $handle->make_text( "$group_id..." ));
			$page->appendChild( $h2 );
	
			my $menu_xhtml;	
			if( $menu->{render_menu} )
			{
				$menu_xhtml = $handle->get_repository->call( $menu->{render_menu}, @render_menu_opts );
			}
			else
			{
				$menu_xhtml = render_menu( @render_menu_opts );
			}

			$page->appendChild( $menu_xhtml );
		}
	}

	if( defined $values )
	{
		my @render_menu_opts = ( $handle, $menu, $sizes, $values, $menu_fields, $has_submenu );

		my $menu_xhtml;
		if( $menu_fields->[0]->is_type( "subject" ) )
		{
			$menu_xhtml = render_subj_menu( @render_menu_opts );
		}
		elsif( $menu->{render_menu} )
		{
			$menu_xhtml = $handle->get_repository->call( $menu->{render_menu}, @render_menu_opts );
		}
		else
		{
			$render_menu_opts[3] = get_showvalues_for_menu( $handle, $menu, $sizes, $values, $menu_fields );
			$menu_xhtml = render_menu( @render_menu_opts );

		}

		$page->appendChild( $menu_xhtml );
	}

	my $ds = $handle->get_repository->get_dataset( "archive" );
	my $title;
	my $title_phrase_id = "viewtitle_".$ds->confid()."_".$view->{id}."_menu_".( $menu_level + 1 );

	if( $handle->get_lang()->has_phrase( $title_phrase_id, $handle ) && defined $esc_path_values )
	{
		my %o = ();
		for( my $i = 0; $i < scalar( @{$esc_path_values} ); ++$i )
		{
			for( my $i = 0; $i < scalar( @{$esc_path_values} ); ++$i )
			{
				$o{"value".($i+1)} = $menus_fields->[$i]->[0]->render_single_value( $handle, $path_values->[$i]);
			}
		}
		$title = $handle->html_phrase( $title_phrase_id, %o );
	}

	if( !defined $title )
	{
		$title = $handle->html_phrase(
			"bin/generate_views:indextitle",
			viewname=>$handle->make_text(
				$handle->get_view_name( $ds, $view->{id} ) ) );
	}


	# Write page to disk
	$handle->write_static_page( 
			$target, 
			{
				title => $title, 
				page => $page,
				template => $handle->make_text($view->{template}),
			},
			"browseindex" );

	open( INCLUDE, ">:utf8", "$target.include" ) || EPrints::abort( "Failed to write $target.include: $!" );
	print INCLUDE EPrints::XML::to_string( $page, undef, 1 );
	close INCLUDE;

	EPrints::XML::dispose( $page );

	return $target;
}

sub get_fieldlist_sizes
{
	my( $handle, $fields, $filters ) = @_;

	if( $fields->[0]->is_type( "subject" ) )
	{
		# this got compicated enough to need its own sub.
		return get_fieldlist_sizes_subject( $handle, $fields, $filters );
	}

	my $ds = $handle->get_repository->get_dataset( "archive" );

	my %map=();
	my %only_these_values = ();
	FIELD: foreach my $field ( @{$fields} )
	{
		my $vref = $field->get_ids_by_value( $handle, $ds, filters=>$filters );

		VALUE: foreach my $value ( keys %{$vref} )
		{
			$only_these_values{$value} = 1;
			foreach my $itemid ( @{$vref->{$value}} ) 
			{ 
				$map{$value}->{$itemid} = 1; 
			}
		}
	}

	my $sizes = {};
	foreach my $value ( keys %map )
	{
		next unless $only_these_values{$value};
		$sizes->{$value} = scalar keys %{$map{$value}};
	}

	return $sizes;
}

sub get_fieldlist_sizes_subject
{
	my( $handle, $fields, $filters ) = @_;

	my $ds = $handle->get_repository->get_dataset( "archive" );

	my( $subject_map, $subject_map_r ) = EPrints::DataObj::Subject::get_all( $handle );

	my %map=();
	my %only_these_values = ();
	FIELD: foreach my $field ( @{$fields} )
	{
		my $vref = $field->get_ids_by_value( $handle, $ds, filters=>$filters );

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

		VALUE: foreach my $value ( keys %{$vref} )
		{
			$only_these_values{$value} = 1;

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
	}

	my $sizes = {};
	foreach my $value ( keys %map )
	{
		next unless $only_these_values{$value};
		$sizes->{$value} = scalar keys %{$map{$value}};
	}

	return $sizes;
}

sub get_fieldlist_values
{
	my( $handle, $fields ) = @_;

	my $ds = $handle->get_repository->get_dataset( "archive" );

	my $values = {};
	foreach my $field ( @{$fields} )
	{	
		my @values = @{$field->get_values( $handle, $ds )};
		foreach my $value ( @values )
		{ 
			my $id = $fields->[0]->get_id_from_value( $handle, $value );
			$id = "" if !defined $id;
			$values->{$id} = $value;
		}
	}

	return $values;
}

sub group_by_a_to_z 
{ 
	my $grouping = group_by_n_chars( @_, 1 ); 
	foreach my $c ( 'A'..'Z' )
	{
		next if defined $grouping->{$c};
		$grouping->{$c} = [];
	}
	return $grouping;
}
sub group_by_first_character { return group_by_n_chars( @_, 1 ); }
sub group_by_2_characters { return group_by_n_chars( @_, 2 ); }
sub group_by_3_characters { return group_by_n_chars( @_, 3 ); }
sub group_by_4_characters { return group_by_n_chars( @_, 4 ); }
sub group_by_5_characters { return group_by_n_chars( @_, 5 ); }

sub group_by_n_chars
{
	my( $handle, $menu, $menu_fields, $values, $n ) = @_;

	my $sections = {};
	foreach my $value ( @{$values} )
	{
		my $v = EPrints::Utils::tree_to_utf8(
				$menu_fields->[0]->render_single_value( $handle, $value) );

		utf8::decode( $v );
		# lose everything not a letter or number
		$v =~ s/[^\p{L}\p{N}]//g;
	
		my $start = uc substr( $v, 0, $n );
		$start = "?" if( $start eq "" );	
		utf8::encode( $start );

		push @{$sections->{$start}}, $value;
	}

	return $sections;
}

sub default_sort
{
	my( $handle, $menu, $values ) = @_;

	my $Collator = Unicode::Collate->new();

	return [ $Collator->sort( @{$values} ) ];
}

# this should probably be a tweak to the repository call function to make
# it handle fn pointers and absolute function names too, but I don't want
# to make the new section code commit touch any other files if I can help
# it. Rationalise into Repository.pm later.
sub call
{
	my( $repository, $v, @args ) = @_;
	
	if( ref( $v ) eq "CODE" || $v =~ m/::/ )
	{
		no strict 'refs';
		return &{$v}(@args);
	}	

	return $repository->call( $v, @args );
}

sub cluster_ranges_10 { return cluster_ranges_n( @_, 10 ); }
sub cluster_ranges_20 { return cluster_ranges_n( @_, 20 ); }
sub cluster_ranges_30 { return cluster_ranges_n( @_, 30 ); }
sub cluster_ranges_40 { return cluster_ranges_n( @_, 40 ); }
sub cluster_ranges_50 { return cluster_ranges_n( @_, 50 ); }
sub cluster_ranges_60 { return cluster_ranges_n( @_, 60 ); }
sub cluster_ranges_70 { return cluster_ranges_n( @_, 70 ); }
sub cluster_ranges_80 { return cluster_ranges_n( @_, 80 ); }
sub cluster_ranges_90 { return cluster_ranges_n( @_, 90 ); }
sub cluster_ranges_100 { return cluster_ranges_n( @_, 100 ); }
sub cluster_ranges_200 { return cluster_ranges_n( @_, 200 ); }

sub cluster_ranges_n
{
	my( $handle, $menu, $groupings, $order, $max ) = @_;

	my $set = [];
	my $startid;
	my $endid;
	my $size = 0;
	my $ranges;
	foreach my $value ( @{$order} )
	{
		my $gsize = scalar @{$groupings->{$value}};

		if( $size != 0 && $size+$gsize >= $max )
		{
			my $rangeid = $startid."-".$endid;
			if( $startid eq $endid ) { $rangeid = $endid; }
			push @{$ranges}, [$rangeid, $set];
	
			$startid = undef;
			$set = [];
			$size = 0;
		}

		if( $size == 0 ) { $startid = $value; }
		$endid = $value;
		$size += $gsize;

		push @{$set}, $value;
	}

	my $rangeid = $startid."-".$endid;
	if( $startid eq $endid ) { $rangeid = $endid; }
	push @{$ranges}, [$rangeid, $set];

	return $ranges;
}
sub no_ranges
{
	my( $handle, $menu, $groupings, $order ) = @_;

	my $ranges;
	foreach my $value ( @{$order} )
	{
		push @{$ranges}, [$value, [ $value ]];
	}
	return $ranges;	
}

sub create_sections_menu
{
	my( $handle, $path_values, $esc_path_values, $menus_fields, $view, $sizes, $values, $menu_fields, $has_submenu, $menu_level, $langid ) = @_;

	my $showvalues = get_showvalues_for_menu( $handle, $view, $sizes, $values, $menu_fields );
	my $menu = $view->{menus}->[$menu_level-1];

	my $grouping_fn = $menu->{grouping_function};
	$grouping_fn = \&group_by_first_character if( !defined $grouping_fn );
	my $groupings = call( $handle->get_repository, $grouping_fn,   $handle, $menu, $menu_fields, $showvalues );

	my $groupsort_fn = $menu->{group_sorting_function};
	$groupsort_fn = \&default_sort if( !defined $groupsort_fn );
	my $order = call( $handle->get_repository, $groupsort_fn,   $handle, $menu, [ keys %{$groupings} ] );

	my $range_fn = $menu->{group_range_function};
	$range_fn = \&no_ranges if( !defined $range_fn );
	my $ranges = call( $handle->get_repository, $range_fn,   $handle, $menu, $groupings, $order );
	# ranges are of the format:
	#  [ [ "rangeid", ['groupid1','groupid2', ...]], ["rangeid2", ['groupid3', ...]], ... ]

	my @wrote_files = ();
	foreach my $range ( @{$ranges} )
	{
		push @wrote_files, create_single_page_menu( $handle, $path_values, $esc_path_values, $menus_fields, $view, $sizes, undef, $menu_fields, $has_submenu, $menu_level, $langid,    $ranges, $groupings, $range );
	}

	push @wrote_files, create_single_page_menu( $handle, $path_values, $esc_path_values, $menus_fields, $view, $sizes, undef, $menu_fields, $has_submenu, $menu_level, $langid,     $ranges, $groupings );

	return @wrote_files;
}

sub get_showvalues_for_menu
{
	my( $handle, $view, $sizes, $values, $fields ) = @_;

	my $showvalues = [];

	if( $view->{hideempty} && defined $sizes)
	{
		foreach my $value ( @{$values} )
		{
			my $id = $fields->[0]->get_id_from_value( $handle, $value );
			push @{$showvalues}, $value if( $sizes->{$id} );
		}
	}
	else
	{
		@{$showvalues} = @{$values};
	}

	return $showvalues;
}

sub get_cols_for_menu
{
	my( $menu, $nitems ) = @_;
	
	my $cols = 1;
	if( defined $menu->{new_column_at} )
	{
		foreach my $min ( @{$menu->{new_column_at}} )
		{
			if( $nitems >= $min ) { ++$cols; }
		}
	}

	my $col_len = POSIX::ceil( $nitems / $cols );

	return( $cols, $col_len );
}

sub render_menu
{
	my( $handle, $menu, $sizes, $values, $fields, $has_submenu ) = @_;

	if( scalar @{$values} == 0 )
	{
		if( !$handle->get_lang()->has_phrase( "Update/Views:no_items" ) )
		{
			return $handle->make_doc_fragment;
		}
		return $handle->html_phrase( "Update/Views:no_items" );
	}

	my( $cols, $col_len ) = get_cols_for_menu( $menu, scalar @{$values} );

	my $add_ul;
	my $col_n = 0;
	my $f = $handle->make_doc_fragment;
	my $tr;

	if( $cols > 1 )
	{
		my $table = $handle->make_element( "table", cellpadding=>"0", cellspacing=>"0", border=>"0", class=>"ep_view_cols ep_view_cols_$cols" );
		$tr = $handle->make_element( "tr" );
		$table->appendChild( $tr );	
		$f->appendChild( $table );
	}
	else
	{
		$add_ul = $handle->make_element( "ul" );
		$f->appendChild( $add_ul );	
	}

	for( my $i=0; $i<@{$values}; ++$i )
	{
		if( $cols>1 && $i % $col_len == 0 )
		{
			++$col_n;
			my $td = $handle->make_element( "td", valign=>"top", class=>"ep_view_col ep_view_col_".$col_n );
			$add_ul = $handle->make_element( "ul" );
			$td->appendChild( $add_ul );	
			$tr->appendChild( $td );	
		}
		my $value = $values->[$i];
		my $size = 0;
		my $id = $fields->[0]->get_id_from_value( $handle, $value );
		if( defined $sizes && defined $sizes->{$id} )
		{
			$size = $sizes->{$id};
		}

		next if( $menu->{hideempty} && $size == 0 );

		my $fileid = $fields->[0]->get_id_from_value( $handle, $value );

		my $li = $handle->make_element( "li" );

		if( defined $sizes && $sizes->{$fileid} == 0 )
		{
			$li->appendChild( $fields->[0]->get_value_label( $handle, $value ) );
		}
		else
		{
			my $link = EPrints::Utils::escape_filename( $fileid );
			if( $has_submenu ) { $link .= '/'; } else { $link .= '.html'; }
			my $a = $handle->render_link( $link );
			$a->appendChild( $fields->[0]->get_value_label( $handle, $value ) );
			$li->appendChild( $a );
		}

		if( defined $sizes && defined $sizes->{$fileid} )
		{
			$li->appendChild( $handle->make_text( " (".$sizes->{$fileid}.")" ) );
		}
		$add_ul->appendChild( $li );
	}
	while( $cols > 1 && $col_n < $cols )
	{
		++$col_n;
		my $td = $handle->make_element( "td", valign=>"top", class=>"ep_view_col ep_view_col_".$col_n );
		$tr->appendChild( $td );	
	}

	return $f;
}

sub render_subj_menu
{
	my( $handle, $menu, $sizes, $values, $fields, $has_submenu ) = @_;

	my $subjects_to_show = $values;

	if( $menu->{hideempty} && defined $sizes)
	{
		my %show = ();
		foreach my $value ( @{$values} )
		{
			next unless( defined $sizes->{$value} && $sizes->{$value} > 0 );
			my $subject = $handle->get_subject( $value );
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

	my $f = $handle->make_doc_fragment;
	foreach my $field ( @{$fields} )
	{
		$f->appendChild(
			$handle->render_subjects(
				$subjects_to_show,
				$field->get_property( "top" ),
				undef,
				($has_submenu?3:2),
				$sizes ) );
	}

	return $f;
}

sub get_fields_from_view
{
	my( $repository, $view ) = @_;

	modernise_view( $view );

	my $ds = $repository->get_dataset( "archive" );
	my $menus_fields = [];
	foreach my $menu ( @{$view->{menus}} )
	{
		my $menu_fields = [];
		foreach my $field_id ( @{$menu->{fields}} )
		{
			my $field = EPrints::Utils::field_from_config_string( $ds, $field_id );
			unless( $field->is_browsable() )
			{
				EPrints::abort( "Cannot generate browse pages for field \"".$field_id."\"\n- Type \"".$field->get_type()."\" cannot be browsed.\n" );
			}
			push @{$menu_fields}, $field;
		}
		push @{$menus_fields},$menu_fields;
	}

	return $menus_fields
}



# Update a (set of) view list(s) - potentially expensive to do.

# nb. path_values are considered escaped at this point
sub update_view_list
{
	my( $handle, $view, $langid, $esc_path_values ) = @_;

	modernise_view( $view );

	my $repository = $handle->get_repository;

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid."/view/".$view->{id}."/";

	my $filename = pop @{$esc_path_values};
	my( $value, $suffix ) = split( /\./, $filename );
	$target .= abbr_path( join "/", @$esc_path_values, $value );

	push @{$esc_path_values}, $value;

	my $path_values = [];
	foreach my $esc_value (@{$esc_path_values})
	{
		push @{$path_values}, EPrints::Utils::unescape_filename( $esc_value );
	}

	my $ds = $repository->get_dataset( "archive" );

	my $menus_fields = get_fields_from_view( $repository, $view );

	my $menu_level = 0;
	my $filters;
	if( defined $esc_path_values )
	{
		$filters = get_filters( $handle, $view, $esc_path_values );
		return if !defined $filters;
		$menu_level = scalar @{$esc_path_values};
	}

	# if number of fields is 1 then menu_level must be 1
	# if number of fields is 2 then menu_level must be 2
	# etc.
	if( $menu_level != scalar @{$view->{menus}} )
	{
		$repository->log( "Wrong depth to generate a view list: ".$view->{id}."/".join( "/", @{$esc_path_values} ) );
		return;
	}

	my $searchexp = new EPrints::Search(
				custom_order=>$view->{order},
				satisfy_all=>1,
				handle =>$handle,
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
	
		if( $handle->get_lang()->has_phrase( $phrase_id, $handle ) )
		{
			my %o = ();
			for( my $i = 0; $i < scalar( @{$esc_path_values} ); ++$i )
			{
				my $menu_fields = $menus_fields->[$i];
				my $value = EPrints::Utils::unescape_filename($esc_path_values->[$i]);
				$value = $menu_fields->[0]->get_value_from_id( $handle, $value );
				$o{"value".($i+1)} = $menu_fields->[0]->render_single_value( $handle, $value);
			}		
			my $grouping_phrase_id = "viewgroup_".$ds->confid()."_".$view->{id}."_".$opts->{filename};
			if( $handle->get_lang()->has_phrase( $grouping_phrase_id, $handle ) )
			{
				$o{"grouping"} = $handle->html_phrase( $grouping_phrase_id );
			}
			elsif( $fieldname eq "DEFAULT" )
			{
				$o{"grouping"} = $handle->html_phrase( "Update/Views:no_grouping_title" );
			}	
			else
			{
				my $gfield = $ds->get_field( $fieldname );
				$o{"grouping"} = $gfield->render_name( $handle );
			}

			$title = $handle->html_phrase( $phrase_id, %o );
		}
	
		if( !defined $title )
		{
			$title = $handle->html_phrase(
				"bin/generate_views:indextitle",
				viewname=>$handle->make_text( $handle->get_view_name( $ds, $view->{id} ) ) );
		}


		# This writes the title including HTML tags
		open( TITLE, ">:utf8", "$page_file_name.title" ) || EPrints::abort( "Failed to write $page_file_name.title: $!" );
		print TITLE EPrints::XML::to_string( $title, undef, 1 );
		close TITLE;

		# This writes the title with HTML tags stripped out.
		open( TITLETXT, ">:utf8", "$page_file_name.title.textonly" ) || EPrints::abort( "Failed to write $page_file_name.title.textonly: $!" );
		print TITLETXT EPrints::Utils::tree_to_utf8( $title );
		close TITLETXT;

		if( defined $view->{template} )
		{
			open( TEMPLATE, ">:utf8", "$page_file_name.template" ) || EPrints::abort( "Failed to write $page_file_name.template: $!" );
			print TEMPLATE $view->{template};
			close TEMPLATE;
		}

		open( EXPORT , ">:utf8", "$page_file_name.export" )  || EPrints::abort( "Failed to write $page_file_name.export: $!" );
		print EXPORT EPrints::XML::to_string( render_export_bar( $handle, $esc_path_values, $view ) , undef, 1);
		close EXPORT;

		open( PAGE, ">:utf8", "$page_file_name.page" ) || EPrints::abort( "Failed to write $page_file_name.page: $!" );
		open( INCLUDE, ">:utf8", "$page_file_name.include" ) || EPrints::abort( "Failed to write $page_file_name.include: $!" );

		my $navigation_aids = EPrints::XML::to_string( 
		render_navigation_aids( $handle, $path_values, $esc_path_values, $view, $menus_fields, "list" ) );

		print PAGE $navigation_aids;
		
		print PAGE "<div class='ep_view_page ep_view_page_view_".$view->{id}."'>";
		print INCLUDE "<div class='ep_view_page ep_view_page_view_".$view->{id}."'>";

		# Render links to alternate groupings
		if( scalar @{$alt_views} > 1 && $count )
		{
			my $groups = $handle->make_doc_fragment;
			my $first = 1;
			foreach my $alt_view2 ( @{$alt_views} )
			{
				my( $fieldname2, $options2 ) = split( /;/, $alt_view2 );
				my $opts2 = get_view_opts( $options2,$fieldname2 );

				my $link_name = "$target.".$opts2->{"filename"};
				if( $first ) { $link_name = $target; }

				if( !$first )
				{
					$groups->appendChild( $handle->html_phrase( "Update/Views:group_seperator" ) );
				}

				my $group;
				my $phrase_id = "viewgroup_".$ds->confid()."_".$view->{id}."_".$opts2->{filename};
				if( $handle->get_lang()->has_phrase( $phrase_id, $handle ) )
				{
					$group = $handle->html_phrase( $phrase_id );
				}
				elsif( $fieldname2 eq "DEFAULT" )
				{
					$group = $handle->html_phrase( "Update/Views:no_grouping" );
				}
				else
				{
					$group = $ds->get_field( $fieldname2 )->render_name( $handle );
				}
				
				if( $opts->{filename} eq $opts2->{filename} )
				{
					$group = $handle->html_phrase( "Update/Views:current_group", group=>$group );
				}
				else
				{
					$link_name =~ /([^\/]+)$/;
					my $link = $handle->render_link( "$1.html" );
					$link->appendChild( $group );
					$group = $link;
				}
		
				$groups->appendChild( $group );

				$first = 0;
			}

			print PAGE EPrints::XML::to_string( $handle->html_phrase( "Update/Views:group_by", groups=>$groups ), undef, 1 );
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
		if( $handle->get_lang()->has_phrase( $intro_phrase_id, $handle ) )
		{
			$intro = EPrints::XML::to_string( $handle->html_phrase( $intro_phrase_id ), undef, 1 );
		}

		# Number of items div.
		my $count_div = "";
		unless( $view->{nocount} )
		{
			my $phraseid = "bin/generate_views:blurb";
			if( $menus_fields->[-1]->[0]->is_type( "subject" ) )
			{
				$phraseid = "bin/generate_views:subject_blurb";
			}
			$count_div = EPrints::XML::to_string( $handle->html_phrase(
				$phraseid,
				n=>$handle->make_text( $count ) ), undef, 1 );
		}

		# Timestamp div
		my $time_div = "";
		unless( $view->{notimestamp} )
		{
			$time_div = EPrints::XML::to_string( $handle->html_phrase(
				"bin/generate_views:timestamp",
					time=>$handle->make_text(
						EPrints::Time::human_time() ) ), undef, 1 );
		}


		if( defined $opts->{render_fn} )
		{
			my $block = $repository->call( $opts->{render_fn}, 
					$handle,
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
			my( $block, $n ) = render_array_of_eprints( $handle, $view, \@items );
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

		my $data = group_items( $handle, \@items, $field, $opts );

		my $first = 1;
		my $jumps = $handle->make_doc_fragment;
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
					$jumps->appendChild( $handle->make_text( " " ) );
				}
				else
				{
					$jumps->appendChild( $handle->html_phrase( "Update/Views:jump_seperator" ) );
				}
			}

			my $link = $handle->render_link( "#group_".EPrints::Utils::escape_filename( $code ) );
			$link->appendChild( $handle->clone_for_me($heading,1) );
			if( $opts->{cloud} )
			{
				my $size = int( $range * ( log(1+scalar @$items ) / log(1+$maxsize) ) ) + $opts->{cloudmin};
				my $span = $handle->make_element( "span", style=>"font-size: $size\%" );
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
			$jumpmenu = EPrints::XML::to_string( $jumps, undef, 1);
		}
		if( $opts->{"jump"} eq "default" )
		{
			$jumpmenu = EPrints::XML::to_string( $handle->html_phrase( "Update/Views:jump_to", jumps=>$jumps ), undef, 1 );
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
		
			print PAGE "<h2>".EPrints::XML::to_string( $heading, undef, 1 )."</h2>";
			print INCLUDE "<h2>".EPrints::XML::to_string( $heading, undef, 1 )."</h2>";
			my( $block, $n ) = render_array_of_eprints( $handle, $view, $items );
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

	return $target;
}

# pagetype is "menu" or "list"
sub render_navigation_aids
{
	my( $handle, $path_values, $esc_path_values, $view, $menus_fields, $pagetype ) = @_;

	my $f = $handle->make_doc_fragment();

	my $menu_level = scalar @{$path_values};

	if( $menu_level > 0 && !$view->{hideup} )
	{
		my $url = '../';
		my $maxdepth = scalar( @{$view->{menus}} );
		my $depth = scalar( @{$path_values} );
		if( $depth == $maxdepth ) 
		{
			$url = "./";
		}
		$f->appendChild( $handle->html_phrase( "Update/Views:up_a_level", 
			url => $handle->render_link( $url ) ) );
	}

	if( $pagetype eq "list" )
	{
		$f->appendChild( render_export_bar( $handle, $esc_path_values, $view ) );
	}

	# this is the field of the level ABOVE this level. So we get options to 
	# go to related values in subjects.	
	my $menu_fields;
	if( $menu_level > 0 )
	{
		$menu_fields = $menus_fields->[$menu_level-1];
	}

	if( defined $menu_fields && $menu_fields->[0]->is_type( "subject" ) )
	{
		my @all_but_this_level_path_values = @{$path_values};
		pop @all_but_this_level_path_values;
		my $sizes = get_sizes( $handle, $view, \@all_but_this_level_path_values );
		my $subject = EPrints::Subject->new( $handle, $path_values->[-1] );
		my @ids= @{$subject->get_value( "ancestors" )};
		foreach my $sub_subject ( $subject->get_children() )
		{
			push @ids, $sub_subject->get_value( "subjectid" );
		}
	
		# strip empty subjects if needed
		my $menu = $view->{menus}->[$menu_level-1];
		if( $menu->{hideempty} )
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
		foreach my $field ( @{$menu_fields} )
		{
			my $div_box = $handle->make_element( "div", class=>"ep_toolbox" );
			my $div_contents = $handle->make_element( "div", class=>"ep_toolbox_content" );
			$f->appendChild( $div_box );
			$div_box->appendChild( $div_contents );
			$div_contents->appendChild( 
				$handle->render_subjects( 
					\@ids, 
					$field->get_property( "top" ), 
					$path_values->[-1], 
					$mode, 
					$sizes ) );
		}
	}

	return $f;
}

sub render_export_bar
{
	my( $handle, $esc_path_values, $view ) = @_;

	my %opts =  (
			type=>"Export",
			can_accept=>"list/eprint",
			is_visible=>"all",
	);
	my @plugins = $handle->plugin_list( %opts );

	if( scalar @plugins == 0 ) 
	{
		return $handle->make_doc_fragment;
	}

	my $export_url = $handle->get_repository->get_conf( "perl_url" )."/exportview";
	my $values = join( "/", @{$esc_path_values} );	

	my $feeds = $handle->make_doc_fragment;
	my $tools = $handle->make_doc_fragment;
	my $options = {};
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $handle->plugin( $plugin_id );
		my $dom_name = $plugin->render_name;
		if( $plugin->is_feed || $plugin->is_tool )
		{
			my $type = "feed";
			$type = "tool" if( $plugin->is_tool );
			my $span = $handle->make_element( "span", class=>"ep_search_$type" );

			my $fn = join( "_", @{$esc_path_values} );	
			my $url = $export_url."/".$view->{id}."/$values/$id/$fn".$plugin->param("suffix");

			my $a1 = $handle->render_link( $url );
			my $icon = $handle->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
			$a1->appendChild( $icon );
			my $a2 = $handle->render_link( $url );
			$a2->appendChild( $dom_name );
			$span->appendChild( $a1 );
			$span->appendChild( $handle->make_text( " " ) );
			$span->appendChild( $a2 );

			if( $type eq "tool" )
			{
				$tools->appendChild( $handle->make_text( " " ) );
				$tools->appendChild( $span );	
			}
			if( $type eq "feed" )
			{
				$feeds->appendChild( $handle->make_text( " " ) );
				$feeds->appendChild( $span );	
			}
		}
		else
		{
			my $option = $handle->make_element( "option", value=>$id );
			$option->appendChild( $dom_name );
			$options->{EPrints::XML::to_string($dom_name, undef, 1 )} = $option;
		}
	}

	my $select = $handle->make_element( "select", name=>"format" );
	foreach my $optname ( sort keys %{$options} )
	{
		$select->appendChild( $options->{$optname} );
	}
	my $button = $handle->make_doc_fragment;
	$button->appendChild( $handle->render_button(
			name=>"_action_export_redir",
			value=>$handle->phrase( "lib/searchexpression:export_button" ) ) );
	$button->appendChild( 
		$handle->render_hidden_field( "view", $view->{id} ) );
	$button->appendChild( 
		$handle->render_hidden_field( "values", $values ) ); 

	my $form = $handle->render_form( "GET", $export_url );
	$form->appendChild( $handle->html_phrase( "Update/Views:export_section",
					feeds => $feeds,
					tools => $tools,
					menu => $select,
					button => $button ));

	return $form;
}

	
sub group_items
{
	my( $handle, $items, $field, $opts ) = @_;

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
						$code_to_heading->{"\L$keyword"} = $handle->make_text( $keyword );
					}
					push @{$code_to_list->{"\L$keyword"}}, $item;
				}
			}
			else
			{
				if( $field->get_type eq "name" )
				{
					$code = "";
					$code.= $value->{family} if defined $value->{family};
					if( defined $value->{given} )
					{
						$code .= ", ";
						if( $opts->{first_initial} )
						{
							$code .= substr( $value->{given},0,1);
						}
						else
						{
							$code .= $value->{given};
						}
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
							$code_to_heading->{$code} = $handle->make_text( "NULL" );
						}
						else
						{
							$code_to_heading->{$code} = $handle->make_text( $code );
						}
					}
					else
					{
						$code_to_heading->{$code} = $field->render_single_value( $handle, $value );
					}
				}
			}
			
			if( $opts->{first_value} ) { last VALUE; } 
		}
	}

	my $langid = $handle->get_langid;
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
				my $o_a = $field->ordervalue_basic( $v_a, $handle, $langid );
				my $o_b = $field->ordervalue_basic( $v_b, $handle, $langid );
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
	my( $handle, $view, $items ) = @_;

	my @r = ();

	$view->{layout} = "paragraph" unless defined $view->{layout};	
	foreach my $item ( @{$items} )
	{

		my $ctype = $view->{citation}||"default";
		if( !defined $handle->{citesdone}->{$ctype}->{$item->get_id} )
		{
			my $cite = EPrints::XML::to_string( $item->render_citation_link( $view->{citation} ), undef, 1 );
			$handle->{citesdone}->{$ctype}->{$item->get_id} = $cite;
		}
		my $cite = $handle->{citesdone}->{$ctype}->{$item->get_id};

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
