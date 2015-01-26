######################################################################
#
# EPrints::Update::Views
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Update::Views> - Update view pages

=head1 SYNOPSIS

	$c->{browse_views} = [
		{
			id => "year",
			order => "creators_name/title",
			menus => [
				{
					fields => [qw( date;res=year )],
					reverse_order => 1,
					allow_null => 1,
					new_column_at => [10, 10]
				},
			],
			variations => [qw(
				creators_name;first_letter
				type
				DEFAULT
			)],
		},
	];

=head1 DESCRIPTION

Update the browse-by X web pages on demand.

=head1 LIMITS TO LIST PAGE SIZE

By default an error page will be generated if a browse view list exceeds 2000 items. This can be controlled by the global setting:

	$c->{browse_views_max_items} = 300;

Or, per view:

	$c->{browse_views} = [{
		...
		max_items => 300,
	}];

To disable the limit set C<max_items> to 0.

=head1 OPTIONS

=over 4

=item id

Set the unique id for the view, which in the URL will be /view/[id]/...

=item dataset = "archive"

Set the dataset id to retrieve records from.

=item menus = [ ... ]

An array of hierarchical menu choices.

=item order = ""

Order matching records by the given field structure.

=item variations = [qw( DEFAULT )]

Add group-bys on additional pages. "DEFAULT" shows all of the records in a list.

=item nolink = 0

Don't show a link to this view from the /view/ page.

=back

=head2 Menus

=over 4

=item allow_null = 0

=item fields = [qw( ... )]

=item new_column_at = [x, y]

=item reverse_order = 0

=item mode = "default"

Use "sections" to cause the menu to be broken into sections.

=item open_first_section = 1

Open the first section of the browse menu.

=back

=head2 Variations

Format is:

	[fieldname];[options]

Where options is:

	[option1],[option2],[option3]=[value]

If no value is given the option is implicitly 1 (enable).

	creators_name;first_letter,allow_null=1

=over 4

=item allow_null = 0

Show items that have no value(s) for the selected field.

=item cloud

Render a "Tag Cloud" of links, where the individual links are scaled by their frequency of occurence.

=item cloudmin = 80, cloudmax = 200

Scale cloud tag links by between cloudmin and cloudmax percent from normal text size.

=item first_letter

Implies truncate=1 and first_value.

=item first_value

Only group-by on the first value in a multiple field.

=item jump = none|plain|default

Hide the jump-to links, render just the links or render as a phrase ('Update/Views:jump_to').

=item tags

Treat the field value as a comma or semi-colon separated list of values.

=item truncate = n

Truncate the value to at most n characters.

=back

=head1 METHODS

=over 4

=cut

package EPrints::Update::Views;

use Digest::MD5;
use Unicode::Collate;
use EPrints::Const qw/ :http /;

# TODO replace this with a system config
our $DEBUG = 0;

use strict;
  
my $MAX_ITEMS = 2000;

=item $filename = update_view_file( $repo, $langid, $localpath, $uri )

This is the function which decides which type of view it is:

	* the main menu of views
	* the top level menu of a view
	* the sub menu of a view
	* a page within a single value of a view

Does not update the file if it's not needed.

=cut

sub update_view_file
{
	my( $repo, $langid, $uri ) = @_;

	$uri =~ s# ^/ ##x;

	# remove extension from target e.g. .type.html [grouping + HTML]
	my $ext = $uri =~ s/(\.[^\/]*)$// ? $1 : "";

	my $target = join "/", $repo->config( "htdocs_path" ), $langid, abbr_path( split '/', $uri );

	my $age;
	if( -e "$target.page" ) 
	{
		my $target_timestamp = EPrints::Utils::mtime( "$target.page" );

		$age = time - $target_timestamp;

		my $timestampfile = $repo->config( "variables_path" )."/views.timestamp";	
		if( -e $timestampfile )
		{
			my $poketime = (stat( $timestampfile ))[9];
			# if the poktime is more recent than the file then make it look like the 
			# file does not exist (forcing it to regenerate)
			$age = undef if( $target_timestamp < $poketime );
		}		
	}

# TODO replace this with a system config
undef $age if $DEBUG;

	# 'view', view-id, escaped path values
	my( undef, $viewid, @view_path ) = split '/', $uri;

	if( !@view_path )
	{
		# update the main browse view list once a day
		return "$target$ext" if defined $age && $age < 24*60*60;

		my $rc = update_browse_view_list( $repo, $target, $langid );
		return $rc == OK ? "$target$ext" : undef;
	}
	
	# retrieve the views configuration
	my $view;
	foreach my $a_view ( @{$repo->config( "browse_views" )} )
	{
		$view = $a_view, last if( $a_view->{id} eq $viewid );
	}
	if( !defined $view )
	{
		$repo->log( "'$viewid' was not found in browse_views configuration" );
		return;
	}

	my $max_menu_age = $view->{max_menu_age} || 24*60*60;
	my $max_list_age = $view->{max_list_age} || 24*60*60;

	my $fn;

	# if page name is 'index' it must be a menu
	if( $view_path[-1] eq 'index' )
	{
		return "$target$ext" if defined $age && $age < $max_menu_age;

		# strip 'index'
		pop @view_path;

		$fn = \&update_view_menu;
	}
	# otherwise it's (probably) a view list
	else
	{
		return "$target$ext" if defined $age && $age < $max_list_age;

		$fn = \&update_view_list;
	}

	$view = __PACKAGE__->new( repository => $repo, view => $view );

	# unescape the path values
	@view_path = $view->unescape_path_values( @view_path );

	my $rc = &$fn( $repo, $target, $langid, $view, \@view_path );
	return $rc == OK ? "$target$ext" : undef;
}

=begin InternalDoc

=item $rc = update_browse_view_list( $repo, $target, $langid )

Update the main menu of views at C</view/>.

Pretty cheap to do.

=end InternalDoc

=cut

sub update_browse_view_list
{
	my( $repo, $target, $langid ) = @_;

	my $xml = $repo->xml;

	my( $ul, $li, $page, $file, $title );

	$page = $repo->make_doc_fragment();
	$page->appendChild( $repo->html_phrase( "bin/generate_views:browseintro" ) );

	my $div = $repo->make_element( "div", class => "ep_view_browse_list" );
	$page->appendChild( $div );

	$ul = $repo->make_element( "ul" );
	foreach my $view ( @{$repo->config( "browse_views" )} )
	{
		$view = __PACKAGE__->new( repository => $repo, view => $view );
		next if( $view->{nolink} );
		$li = $repo->make_element( "li" );
		my $link = $repo->render_link( $view->{id}."/" );
		$link->appendChild( $view->render_name );
		$li->appendChild( $link );
		$ul->appendChild( $li );
	}
	$div->appendChild( $ul );

	$title = $repo->html_phrase( "bin/generate_views:browsetitle" );

	$repo->write_static_page( 
			$target, 
			{
				title => $title, 
				page => $page,
			},
			"browsemain" );

	$xml->dispose( $title );
	$xml->dispose( $page );

	return OK;
}

=begin InternalDoc

=item $rc = update_view_menu( $repo, $target, $langid, $view, $path_values )

Update a view menu at C</view/VIEWID(/VALUE)*/(index)?>. A view menu shows the unique values available to browse by (e.g. a list of years).

Potentially expensive to do.

=end InternalDoc

=cut

sub update_view_menu
{
	my( $repo, $target, $langid, $view, $path_values ) = @_;

	$target =~ s/\/index$/\//;

	my $menu_level = scalar @{$path_values};
	my $menus_fields = $view->menus_fields;

	# menu must be less than a leaf node
	if( $menu_level >= scalar @{$menus_fields} )
	{
		return NOT_FOUND;
	}

	# fields & config for the current menu level
	my $menu_fields = $menus_fields->[$menu_level];
	my $menu = $view->{menus}->[$menu_level];

	# get the list of unique value-counts for this menu level
	my $sizes = $view->fieldlist_sizes(
		$path_values,
		$menu_level,
		$view->get_filters( $path_values, 1 ) # EXact matches only
	);

	my $nav_sizes = $sizes;

	my $nav_level = @$path_values ? $#$path_values : 0;
	if( $menus_fields->[$nav_level]->[0]->isa( "EPrints::MetaField::Subject" ) )
	{
		$nav_sizes = $view->fieldlist_sizes( $path_values, $nav_level );
	}

	# no values to show at this level nor a navigation tree (subjects)
	if( !scalar(keys(%$sizes)) && !scalar(keys(%$nav_sizes)) )
	{
		$repo->log( sprintf( "Warning! No values were found for %s [%s] - configuration may be wrong",
			$view->name,
			join(',', map { $_->[0]->name } @{$menus_fields}[0..$nav_level])
		) );
	}

	# translate ids to values
	my @values = map { $menu_fields->[0]->get_value_from_id( $repo, $_ ) } keys %$sizes;

	# OK now we have a sorted list of values....
	@values = @{$menu_fields->[0]->sort_values( $repo, \@values, $langid )};

	if( $menu->{reverse_order} )
	{
		@values = reverse @values;
	}

	# now render the menu page

	# Not doing submenus just yet.
	my $has_submenu = 0;
	if( scalar @{$menus_fields} > $menu_level+1 )
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
			push @indexes, "$target$fn";
		}
		closedir( $dh );
	}

	my @wrote_files = &{$fn}(
			repository => $repo,
			path_values => $path_values,
			view => $view,
			values => \@values,
			sizes => $sizes,
			nav_sizes => $nav_sizes,
			has_submenu => $has_submenu,
			menu_level => $menu_level,
			target => $target,
			langid => $langid
		);
	
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

	return OK;
}

=begin InternalDoc

=item $rc = update_view_list( $repo, $target, $langid, $view, $path_values [, %opts ] )

Update a (set of) view list(s) at C</view/VIEWID(/VALUE)*/value.html>.

Potentially expensive to do.

Options:
	sizes - cached copy of the sizes at this menu level

=end InternalDoc

=cut

sub update_view_list
{
	my( $repo, $target, $langid, $view, $path_values, %opts ) = @_;

	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $menus_fields = $view->menus_fields;
	my $menu_level = scalar @{$path_values};

	# update_view_list must be a leaf node
	if( $menu_level != scalar @{$menus_fields} )
	{
		return;
	}

	# get all of the items for this level
	my $filters = $view->get_filters( $path_values, 1 ); # EXact

	my $ds = $view->dataset;

	my $max_items = $view->{max_items};
	$max_items = $repo->config("browse_views_max_items") if !defined $max_items;
	$max_items = $MAX_ITEMS if !defined $max_items;

	my $list = $ds->search(
		custom_order=>$view->{order},
		satisfy_all=>1,
		filters=>$filters,
		($max_items > 0 ? (limit => $max_items+1) : ()),
	);

	my $count = $list->count;

	# construct the export and navigation bars, which are common to all "alt_views"
	my $menu_fields = $menus_fields->[$#$path_values];

	my $nav_sizes = $opts{sizes};
	if( !defined $nav_sizes && $menu_fields->[0]->isa( "EPrints::MetaField::Subject" ) )
	{
		$nav_sizes = $view->fieldlist_sizes( $path_values, $#$path_values );
	}
	$nav_sizes = {} if !defined $nav_sizes;

	# nothing to show at this level or anywhere below a subject tree
	return if $count == 0 && !scalar(keys(%$nav_sizes));

	my $export_bar = render_export_bar( $repo, $view, $path_values );

	my $navigation_aids = render_navigation_aids( $repo, $path_values, $view, "list",
		export_bar => $xml->clone( $export_bar ),
		sizes => $nav_sizes,
	);

	# hit the limit
	if( $max_items && $count > $max_items )
	{
		my $PAGE = $xml->create_element( "div",
			class => "ep_view_page ep_view_page_view_$view->{id}"
		);
		$PAGE->appendChild( $navigation_aids );
		$PAGE->appendChild( $repo->html_phrase( "bin/generate_views:max_items",
			n => $xml->create_text_node( $count ),
			max => $xml->create_text_node( $max_items ),
		) );
		output_files( $repo,
			"$target.page" => $PAGE,
		);
		return $target;
	}

	# Timestamp div
	my $time_div;
	if( !$view->{notimestamp} )
	{
		$time_div = $repo->html_phrase(
			"bin/generate_views:timestamp",
			time=>$xml->create_text_node( EPrints::Time::human_time() ) );
	}
	else
	{
		$time_div = $xml->create_document_fragment;
	}

	# modes = first_letter, first_value, all_values (default)
	my $alt_views = $view->{variations};
	if( !defined $alt_views )
	{
		$alt_views = [ 'DEFAULT' ];
	}

	my @items = $list->get_records;

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
		my $phrase_id = "viewtitle_".$ds->base_id()."_".$view->{id}."_list";
		my $null_phrase_id = "viewnull_".$ds->base_id()."_".$view->{id};

		my %files;

		if( $repo->get_lang()->has_phrase( $phrase_id, $repo ) )
		{
			my %o = ();
			for( my $i = 0; $i < scalar( @{$path_values} ); ++$i )
			{
				my $menu_fields = $menus_fields->[$i];
				my $value = $path_values->[$i];
				$o{"value".($i+1)} = $menu_fields->[0]->render_single_value( $repo, $value);
				if( !EPrints::Utils::is_set( $value ) && $repo->get_lang()->has_phrase($null_phrase_id) )
				{
					$o{"value".($i+1)} = $repo->html_phrase( $null_phrase_id );
				}
			}		
			my $grouping_phrase_id = "viewgroup_".$ds->base_id()."_".$view->{id}."_".$opts->{filename};
			if( $repo->get_lang()->has_phrase( $grouping_phrase_id, $repo ) )
			{
				$o{"grouping"} = $repo->html_phrase( $grouping_phrase_id );
			}
			elsif( $fieldname eq "DEFAULT" )
			{
				$o{"grouping"} = $repo->html_phrase( "Update/Views:no_grouping_title" );
			}	
			else
			{
				my $gfield = $ds->get_field( $fieldname );
				$o{"grouping"} = $gfield->render_name( $repo );
			}

			$title = $repo->html_phrase( $phrase_id, %o );
		}
	
		if( !defined $title )
		{
			$title = $repo->html_phrase(
				"bin/generate_views:indextitle",
				viewname=>$view->render_name,
			);
		}


		# This writes the title including HTML tags
		$files{"$page_file_name.title"} = $title;

		# This writes the title with HTML tags stripped out.
		$files{"$page_file_name.title.textonly"} = $title;

		if( defined $view->{template} )
		{
			$files{"$page_file_name.template"} = $xml->create_text_node( $view->{template} );
		}

		$files{"$page_file_name.export"} = $export_bar;

		my $PAGE = $files{"$page_file_name.page"} = $xml->create_document_fragment;
		my $INCLUDE = $files{"$page_file_name.include"} = $xml->create_document_fragment;

		$PAGE->appendChild( $xml->clone( $navigation_aids ) );
		
		$PAGE = $PAGE->appendChild( $xml->create_element( "div",
			class => "ep_view_page ep_view_page_view_$view->{id}"
		) );
		$INCLUDE = $INCLUDE->appendChild( $xml->create_element( "div",
			class => "ep_view_page ep_view_page_view_$view->{id}"
		) );

		# Render links to alternate groupings
		if( scalar @{$alt_views} > 1 && $count )
		{
			my $groups = $repo->make_doc_fragment;
			my $first = 1;
			foreach my $alt_view2 ( @{$alt_views} )
			{
				my( $fieldname2, $options2 ) = split( /;/, $alt_view2 );
				my $opts2 = get_view_opts( $options2,$fieldname2 );

				my $link_name = join '/', $view->escape_path_values( @$path_values );
				if( !$first ) { $link_name .= ".".$opts2->{"filename"} }

				if( !$first )
				{
					$groups->appendChild( $repo->html_phrase( "Update/Views:group_seperator" ) );
				}

				my $group;
				my $phrase_id = "viewgroup_".$ds->base_id()."_".$view->{id}."_".$opts2->{filename};
				if( $repo->get_lang()->has_phrase( $phrase_id, $repo ) )
				{
					$group = $repo->html_phrase( $phrase_id );
				}
				elsif( $fieldname2 eq "DEFAULT" )
				{
					$group = $repo->html_phrase( "Update/Views:no_grouping" );
				}
				else
				{
					$group = $ds->get_field( $fieldname2 )->render_name( $repo );
				}
				
				if( $opts->{filename} eq $opts2->{filename} )
				{
					$group = $repo->html_phrase( "Update/Views:current_group", group=>$group );
				}
				else
				{
					$link_name =~ /([^\/]+)$/;
					my $link = $repo->render_link( "$1.html" );
					$link->appendChild( $group );
					$group = $link;
				}
		
				$groups->appendChild( $group );

				$first = 0;
			}

			$PAGE->appendChild( $repo->html_phrase( "Update/Views:group_by", groups=>$groups ) );
		}

		# Intro phrase, if any 
		my $intro_phrase_id =
			"viewintro_".$view->{id}.join('', map { "/$_" } $view->escape_path_values( @$path_values ));
		my $intro;
		if( $repo->get_lang()->has_phrase( $intro_phrase_id, $repo ) )
		{
			$intro = $repo->html_phrase( $intro_phrase_id );
		}
		else
		{
			$intro = $xml->create_document_fragment;
		}

		# Number of items div.
		my $count_div;
		if( !$view->{nocount} )
		{
			my $phraseid = "bin/generate_views:blurb";
			if( $menus_fields->[-1]->[0]->isa( "EPrints::MetaField::Subject" ) )
			{
				$phraseid = "bin/generate_views:subject_blurb";
			}
			$count_div = $repo->html_phrase(
				$phraseid,
				n=>$xml->create_text_node( $count ) );
		}
		else
		{
			$count_div = $xml->create_document_fragment;
		}


		if( defined $opts->{render_fn} )
		{
			my $block = $repo->call( $opts->{render_fn}, 
					$repo,
					\@items,
					$view,
					$path_values,
					$opts->{filename} );
			$block = $xml->parse_string( $block )
				if !ref( $block );

			$PAGE->appendChild( $xml->clone( $intro ) );
			$INCLUDE->appendChild( $xml->clone( $intro ) );

			$PAGE->appendChild( $view->render_count( $count ) );
			$INCLUDE->appendChild( $view->render_count( $count ) );

			$PAGE->appendChild( $xml->clone( $block ) );
			$INCLUDE->appendChild( $block );

			$PAGE->appendChild( $xml->clone( $time_div ) );
			$INCLUDE->appendChild( $xml->clone( $time_div ) );

			$first_view = 0;

			output_files( $repo, %files );
			next ALTVIEWS;
		}


		# If this grouping is "DEFAULT" then there is no actual grouping-- easy!
		if( $fieldname eq "DEFAULT" ) 
		{
			my $block = render_array_of_eprints( $repo, $view, \@items );

			$PAGE->appendChild( $xml->clone( $intro ) );
			$INCLUDE->appendChild( $xml->clone( $intro ) );

			$PAGE->appendChild( $view->render_count( $count ) );
			$INCLUDE->appendChild( $view->render_count( $count ) );

			$PAGE->appendChild( $xml->clone( $block ) );
			$INCLUDE->appendChild( $block );

			$PAGE->appendChild( $xml->clone( $time_div ) );
			$INCLUDE->appendChild( $xml->clone( $time_div ) );

			$first_view = 0;
			output_files( $repo, %files );
			next ALTVIEWS;
		}

		my $data = group_items( $repo, \@items, $ds->field( $fieldname ), $opts );

		my $first = 1;
		my $jumps = $repo->make_doc_fragment;
		my $total = 0;
		my $maxsize = 1;
		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};
			my $n = scalar @$items;
			$total += $n;
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
					$jumps->appendChild( $repo->make_text( " " ) );
				}
				else
				{
					$jumps->appendChild( $repo->html_phrase( "Update/Views:jump_seperator" ) );
				}
			}

			my $link = $repo->render_link( "#group_".EPrints::Utils::escape_filename( $code ) );
			$link->appendChild( $repo->clone_for_me($heading,1) );
			if( $opts->{cloud} )
			{
				my $size = int( $range * ( log(1+scalar @$items ) / log(1+$maxsize) ) ) + $opts->{cloudmin};
				my $span = $repo->make_element( "span", style=>"font-size: $size\%" );
				$span->appendChild( $link );
				$jumps->appendChild( $span );
			}
			else
			{
				$jumps->appendChild( $link );
			}

			$first = 0;
		}

		if( $total > 0 )
		{
			# css for your convenience
			my $jumpmenu = $xml->create_element( "div",
				class => "ep_view_jump ep_view_$view->{id}_${fieldname}_jump"
			);
			if( $opts->{"jump"} eq "plain" ) 
			{
				$jumpmenu->appendChild( $jumps );
			}
			elsif( $opts->{"jump"} eq "default" )
			{
				$jumpmenu->appendChild( $repo->html_phrase(
					"Update/Views:jump_to",
					jumps=>$jumps ) );
			}

			$PAGE->appendChild( $xml->clone( $jumpmenu ) );
			$INCLUDE->appendChild( $jumpmenu );
		}

		$PAGE->appendChild( $xml->clone( $intro ) );
		$INCLUDE->appendChild( $xml->clone( $intro ) );

		$PAGE->appendChild( $view->render_count( $total ) );
		$INCLUDE->appendChild( $view->render_count( $total ) );

		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};

			my $link = $xml->create_element( "a",
				name => "group_".EPrints::Utils::escape_filename( $code )
			);
			my $h2 = $xml->create_element( "h2" );
			$h2->appendChild( $heading );
			my $block = render_array_of_eprints( $repo, $view, $items );

			$PAGE->appendChild( $xml->clone( $link ) );
			$INCLUDE->appendChild( $link );
		
			$PAGE->appendChild( $xml->clone( $h2 ) );
			$INCLUDE->appendChild( $h2 );

			$PAGE->appendChild( $xml->clone( $block ) );
			$INCLUDE->appendChild( $block );
		}

		$PAGE->appendChild( $xml->clone( $time_div ) );
		$INCLUDE->appendChild( $xml->clone( $time_div ) );

		$first_view = 0;
		output_files( $repo, %files );
	}

	return $target;
}

# things we need to know to update a view menu
# char is optional, for browse-by-char menus
sub create_single_page_menu
{
	my %args = @_;
	my( $repo, $path_values, $view, $sizes, $values, $nav_sizes, $has_submenu, $menu_level, $langid, $ranges, $groupings, $range ) =
		@args{qw( repository path_values view sizes values nav_sizes has_submenu menu_level langid ranges groupings range )};

	my $menus_fields = $view->menus_fields;
	my $menu_fields = $menus_fields->[$menu_level];
	my $menu = $view->{menus}->[$menu_level];

	my $target = join '/', $repo->config( "htdocs_path" ), $langid, "view", $view->{id};

	# work out filename
	$target = join '/', $target, abbr_path( $view->escape_path_values( @$path_values ) ), "index";
	if( defined $range )
	{
		$target .= ".".EPrints::Utils::escape_filename( $range->[0] );
	}
	
	if( $menu->{open_first_section} && defined $ranges && !defined $range )
	{
		# the front page should show the first section
		$range = $ranges->[0];
	}

	my $page = $repo->make_element( "div", class=>"ep_view_menu" );

	my $navigation_aids = render_navigation_aids( $repo, $path_values, $view, "menu",
		sizes => $nav_sizes
	);
	$page->appendChild( $navigation_aids );

	if( scalar @$values )
	{
		my $phrase_id = "viewintro_".$view->{id};
		if( scalar(@{$path_values}) )
		{
			$phrase_id.= "/".join( "/", map {
					defined $_ ? $_ : "NULL"
				} @{$path_values} );
		}
		unless( $repo->get_lang()->has_phrase( $phrase_id, $repo ) )
		{
			$phrase_id = "bin/generate_views:intro";
		}
		$page->appendChild( $repo->html_phrase( $phrase_id ));
	}

	if( defined $ranges )
	{
		my $div_box = $repo->make_element( "div", class=>"ep_toolbox" );
		my $div_contents = $repo->make_element( "div", class=>"ep_toolbox_content" );
		$page->appendChild( $div_box );
		$div_box->appendChild( $div_contents );
		my $first = 1;
		foreach my $range_i ( @{$ranges} )
		{
			my $l;
			if( !$first )
			{
				$div_contents->appendChild( $repo->make_text( " | " ) );
			}
			$first = 0 ;
			if( defined $range && $range->[0] eq $range_i->[0] )
			{
				$l = $repo->make_element( "b" );
			}
			else
			{
				$l = $repo->make_element( "a", href=>"index.".EPrints::Utils::escape_filename( $range_i->[0] ).".html" );
			}
			$div_contents->appendChild( $l );
			$l->appendChild( $repo->make_text( $range_i->[0] ) );
		}
	}

	if( defined $range )
	{
		foreach my $group_id ( @{$range->[1]} )
		{
			my @render_menu_opts = ( $repo, $menu, $sizes, $groupings->{$group_id}, $menu_fields, $has_submenu, $view );

			my $h2 = $repo->make_element( "h2" );
			$h2->appendChild( $repo->make_text( "$group_id..." ));
			$page->appendChild( $h2 );
	
			my $menu_xhtml;	
			if( $menu->{render_menu} )
			{
				$menu_xhtml = $repo->call( $menu->{render_menu}, @render_menu_opts );
			}
			else
			{
				$menu_xhtml = render_menu( @render_menu_opts );
			}

			$page->appendChild( $menu_xhtml );
		}
	}

	if( scalar(@$values) )
	{
		my @render_menu_opts = ( $repo, $menu, $sizes, $values, $menu_fields, $has_submenu, $view );

		my $menu_xhtml;
		if( $menu->{render_menu} )
		{
			$menu_xhtml = $repo->call( $menu->{render_menu}, @render_menu_opts );
		}
		elsif( $menu_fields->[0]->isa( "EPrints::MetaField::Subject" ) )
		{
			$menu_xhtml = render_subj_menu( @render_menu_opts );
		}
		else
		{
			$render_menu_opts[3] = get_showvalues_for_menu( $repo, $menu, $sizes, $values, $menu_fields );
			$menu_xhtml = render_menu( @render_menu_opts );

		}

		$page->appendChild( $menu_xhtml );
	}

	my $ds = $view->dataset;
	my $title;
	my $title_phrase_id = "viewtitle_".$ds->base_id()."_".$view->{id}."_menu_".( $menu_level + 1 );

	if( $repo->get_lang()->has_phrase( $title_phrase_id, $repo ) )
	{
		my %o = ();
		for( my $i = 0; $i < scalar( @{$path_values} ); ++$i )
		{
			$o{"value".($i+1)} = $menus_fields->[$i]->[0]->render_single_value( $repo, $path_values->[$i]);
		}
		$title = $repo->html_phrase( $title_phrase_id, %o );
	}
	else
	{
		$title = $repo->html_phrase(
			"bin/generate_views:indextitle",
			viewname=>$view->render_name,
		);
	}


	# Write page to disk
	$repo->write_static_page( 
			$target, 
			{
				title => $title, 
				page => $page,
				template => $repo->make_text($view->{template}),
			},
			"browseindex" );

	open( INCLUDE, ">:utf8", "$target.include" ) || EPrints::abort( "Failed to write $target.include: $!" );
	print INCLUDE EPrints::XML::to_string( $page, undef, 1 );
	close INCLUDE;

	EPrints::XML::dispose( $page );

	return $target;
}

# Update View Config to new structure
# WARNING! This is also used in cgi/exportview!
sub modernise_view
{
	my( $view ) = @_;

	return if $view->{'.modernised'};
	$view->{'.modernised'} = 1;

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

	foreach my $base_id ( qw/ allow_null new_column_at hideempty render_menu / )
	{
		next if( !defined $view->{$base_id} );
		MENU: foreach my $menu ( @{$view->{menus}} )
		{
			next MENU if defined $menu->{$base_id};
			$menu->{$base_id} = $view->{$base_id};
		}
	}

	$view->{dataset} = "archive" if !defined $view->{dataset};
}

=begin InternalDoc

=item $path = abbr_path( $path )

This internal method replaces any part of $path that is longer than 40 characters with the MD5 of that part. It ignores file extensions (dot followed by anything).

=end InternalDoc

=cut

sub abbr_path
{
	my( @parts ) = @_;

	foreach my $part (@parts)
	{
		next if length($part) < 40;
		my( $name, $ext ) = split /\./, $part, 2;
		$part = Digest::MD5::md5_hex($name);
		$part .= ".$ext" if defined $ext;
	}

	return @parts;
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
	my( $repo, $menu, $menu_fields, $values, $n ) = @_;

	my $sections = {};
	foreach my $value ( @{$values} )
	{
		my $v = $repo->xhtml->to_text_dump(
				$menu_fields->[0]->render_single_value( $repo, $value) );

		# lose everything not a letter or number
		$v =~ s/\P{Alnum}+//g;
	
		my $start = uc substr( $v, 0, $n );
		$start = "?" if( $start eq "" );	

		push @{$sections->{$start}}, $value;
	}

	return $sections;
}

# [2015-01-26/drn] A-Z group treating accented characters as the same letter as unaccented ones.
sub group_by_a_to_z_unidecode
{

        my $grouping = group_by_n_chars_unidecode( @_, 1 );

        foreach my $c ( 'A'..'Z' )
        {
                next if defined $grouping->{$c};
                $grouping->{$c} = [];
        }
        return $grouping;
}

sub group_by_first_character_unidecode { return group_by_n_chars_unidecode( @_, 1 ); }
sub group_by_2_characters_unidecode { return group_by_n_chars_unidecode( @_, 2 ); }
sub group_by_3_characters_unidecode { return group_by_n_chars_unidecode( @_, 3 ); }
sub group_by_4_characters_unidecode { return group_by_n_chars_unidecode( @_, 4 ); }
sub group_by_5_characters_unidecode { return group_by_n_chars_unidecoee( @_, 5 ); }

sub group_by_n_chars_unidecode 
{
        my( $session, $menu, $menu_fields, $values, $n ) = @_;

        # cache rendered values
        my %rvals;
        for( @$values )
        {
                $rvals{$_} = EPrints::Utils::tree_to_utf8( $menu_fields->[0]->render_single_value( $session, $_ ) );
        }

        # sort using cache
        my @sorted = sort {
                Text::Unidecode::unidecode(lc $rvals{$a} )
                cmp
                Text::Unidecode::unidecode(lc $rvals{$b} )
        } @{$values};

        my $sections = {};
        foreach my $value ( @sorted )
        {
                # get rendered value from cache
                my $v = $rvals{$value};

                # lose everything not a letter or number
                $v =~ s/[^\p{L}\p{N}]//g;

                my $dc =  Text::Unidecode::unidecode( $v );

                my $start = uc substr( $dc, 0, $n );
                $start = "?" if( $start eq "" );

                push @{$sections->{$start}}, $value;
        }

        return $sections;
}
# END: A-Z group treating accented characters as the same letter as unaccented ones.


sub default_sort
{
	my( $repo, $menu, $values ) = @_;

	my $Collator = Unicode::Collate->new();

	return [ $Collator->sort( @{$values} ) ];
}

# this should probably be a tweak to the repository call function to make
# it handle fn pointers and absolute function names too, but I don't want
# to make the new section code commit touch any other files if I can help
# it. Rationalise into Repository.pm later.
sub call
{
	my( $repo, $v, @args ) = @_;
	
	if( ref( $v ) eq "CODE" || $v =~ m/::/ )
	{
		no strict 'refs';
		return &{$v}(@args);
	}	

	return $repo->call( $v, @args );
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
	my( $repo, $menu, $groupings, $order, $max ) = @_;

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
	my( $repo, $menu, $groupings, $order ) = @_;

	my $ranges;
	foreach my $value ( @{$order} )
	{
		push @{$ranges}, [$value, [ $value ]];
	}
	return $ranges;	
}

sub create_sections_menu
{
	my %args = @_;
	my( $repo, $path_values, $view, $sizes, $values, $has_submenu, $menu_level, $langid ) =
		@args{qw( repository path_values view sizes values has_submenu menu_level langid )};

	my $menus_fields = $view->menus_fields;
	my $menu_fields = $menus_fields->[$menu_level];

	my $showvalues = get_showvalues_for_menu( $repo, $view, $sizes, $values, $menu_fields );
	my $menu = $view->{menus}->[$menu_level-1];

	my $grouping_fn = $menu->{grouping_function};
	$grouping_fn = \&group_by_first_character if( !defined $grouping_fn );
	my $groupings = call( $repo, $grouping_fn,   $repo, $menu, $menu_fields, $showvalues );

	my $groupsort_fn = $menu->{group_sorting_function};
	$groupsort_fn = \&default_sort if( !defined $groupsort_fn );
	my $order = call( $repo, $groupsort_fn,   $repo, $menu, [ keys %{$groupings} ] );

	my $range_fn = $menu->{group_range_function};
	$range_fn = \&no_ranges if( !defined $range_fn );
	my $ranges = call( $repo, $range_fn,   $repo, $menu, $groupings, $order );
	# ranges are of the format:
	#  [ [ "rangeid", ['groupid1','groupid2', ...]], ["rangeid2", ['groupid3', ...]], ... ]

	my @wrote_files = ();
	foreach my $range ( @{$ranges} )
	{
		push @wrote_files, create_single_page_menu(
			repository => $repo,
			path_values => $path_values,
			view => $view,
			sizes => $sizes,
			values => [],
			has_submenu => $has_submenu,
			menu_level => $menu_level,
			langid => $langid,
			ranges => $ranges,
			groupings => $groupings,
			range => $range,
			target => $args{target}
		);
	}

	push @wrote_files, create_single_page_menu(
			repository => $repo,
			path_values => $path_values,
			view => $view,
			sizes => $sizes,
			values => [],
			has_submenu => $has_submenu,
			menu_level => $menu_level,
			langid => $langid,
			ranges => $ranges,
			groupings => $groupings,
			target => $args{target}
		);

	return @wrote_files;
}

sub get_showvalues_for_menu
{
	my( $repo, $view, $sizes, $values, $fields ) = @_;

	my $showvalues = [];

	if( $view->{hideempty} && defined $sizes)
	{
		foreach my $value ( @{$values} )
		{
			my $id = $fields->[0]->get_id_from_value( $repo, $value );
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
	my( $repo, $menu, $sizes, $values, $fields, $has_submenu, $view ) = @_;

	if( scalar @{$values} == 0 )
	{
		if( !$repo->get_lang()->has_phrase( "Update/Views:no_items" ) )
		{
			return $repo->make_doc_fragment;
		}
		return $repo->html_phrase( "Update/Views:no_items" );
	}

	my( $cols, $col_len ) = get_cols_for_menu( $menu, scalar @{$values} );

	my $add_ul;
	my $col_n = 0;
	my $f = $repo->make_doc_fragment;
	my $tr;

	if( $cols > 1 )
	{
		my $table = $repo->make_element( "table", cellpadding=>"0", cellspacing=>"0", border=>"0", class=>"ep_view_cols ep_view_cols_$cols" );
		$tr = $repo->make_element( "tr" );
		$table->appendChild( $tr );	
		$f->appendChild( $table );
	}
	else
	{
		$add_ul = $repo->make_element( "ul" );
		$f->appendChild( $add_ul );	
	}

	my $ds = $view->dataset;

	for( my $i=0; $i<@{$values}; ++$i )
	{
		if( $cols>1 && $i % $col_len == 0 )
		{
			++$col_n;
			my $td = $repo->make_element( "td", valign=>"top", class=>"ep_view_col ep_view_col_".$col_n );
			$add_ul = $repo->make_element( "ul" );
			$td->appendChild( $add_ul );	
			$tr->appendChild( $td );	
		}
		my $value = $values->[$i];
		my $size = 0;
		my $id = $fields->[0]->get_id_from_value( $repo, $value );
		if( defined $sizes && defined $sizes->{$id} )
		{
			$size = $sizes->{$id};
		}

		next if( $menu->{hideempty} && $size == 0 );

		my $fileid = $fields->[0]->get_id_from_value( $repo, $value );

		my $li = $repo->make_element( "li" );

		my $xhtml_value = $fields->[0]->get_value_label( $repo, $value ); 
		my $null_phrase_id = "viewnull_".$ds->base_id()."_".$view->{id};
		if( !EPrints::Utils::is_set( $value ) && $repo->get_lang()->has_phrase($null_phrase_id) )
		{
			$xhtml_value = $repo->html_phrase( $null_phrase_id );
		}

		if( defined $sizes && (!defined $sizes->{$fileid} || $sizes->{$fileid} == 0 ))
		{
			$li->appendChild( $xhtml_value );
		}
		else
		{
			my $link = EPrints::Utils::escape_filename( $fileid );
			if( $has_submenu ) { $link .= '/'; } else { $link .= '.html'; }
			my $a = $repo->render_link( $link );
			$a->appendChild( $xhtml_value );
			$li->appendChild( $a );
		}

		if( defined $sizes && defined $sizes->{$fileid} )
		{
			$li->appendChild( $repo->make_text( " (".$sizes->{$fileid}.")" ) );
		}
		$add_ul->appendChild( $li );
	}
	while( $cols > 1 && $col_n < $cols )
	{
		++$col_n;
		my $td = $repo->make_element( "td", valign=>"top", class=>"ep_view_col ep_view_col_".$col_n );
		$tr->appendChild( $td );	
	}

	return $f;
}

sub render_subj_menu
{
	my( $repo, $menu, $sizes, $values, $fields, $has_submenu ) = @_;

	my $subjects_to_show = $values;

	if( $menu->{hideempty} && defined $sizes)
	{
		my %show = ();
		foreach my $value ( @{$values} )
		{
			next unless( defined $sizes->{$value} && $sizes->{$value} > 0 );
			my $subject = EPrints::DataObj::Subject->new(
					 $repo, $value );
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

	my $f = $repo->make_doc_fragment;
	foreach my $field ( @{$fields} )
	{
		$f->appendChild(
			$repo->render_subjects(
				$subjects_to_show,
				$field->get_property( "top" ),
				undef,
				($has_submenu?3:2),
				$sizes ) );
	}

	return $f;
}

sub output_files
{
	my( $repo, %files ) = @_;

	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	foreach my $fn (sort keys %files)
	{
		open(my $fh, ">:utf8", $fn)
			or EPrints->abort( "Error writing to $fn: $!" );
		if( $fn =~ /\.textonly$/ )
		{
			print $fh $xhtml->to_text_dump( $files{$fn} );
		}
		else
		{
			print $fh $xhtml->to_xhtml( $files{$fn} );
		}
		$xml->dispose( $files{$fn} );
		close( $fh );
	}
}

# pagetype is "menu" or "list"
sub render_navigation_aids
{
	my( $repo, $path_values, $view, $pagetype, %opts ) = @_;

	my $menus_fields = $view->menus_fields;
	my $f = $repo->make_doc_fragment();

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
		$f->appendChild( $repo->html_phrase( "Update/Views:up_a_level", 
			url => $repo->render_link( $url ) ) );
	}

	if( defined $opts{export_bar} )
	{
		$f->appendChild( $opts{export_bar} );
	}

	# this is the field of the level ABOVE this level. So we get options to 
	# go to related values in subjects.	
	my $menu_fields;
	if( $menu_level > 0 )
	{
		$menu_fields = $menus_fields->[$menu_level-1];
	}

	if( defined $menu_fields && $menu_fields->[0]->isa( "EPrints::MetaField::Subject" ) )
	{
		my $subject = EPrints::Subject->new( $repo, $path_values->[-1] );
		if( !defined $subject )
		{
			EPrints->abort( "Weird, no subject match for: '".$path_values->[-1]."'" );
		}
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
				push @newids, $id if $opts{sizes}->{$id};
			}
			@ids = @newids;
		}
		
		my $mode = 2;
		if( $pagetype eq "menu" ) { $mode = 4; }
		foreach my $field ( @{$menu_fields} )
		{
			my $div_box = $repo->make_element( "div", class=>"ep_toolbox" );
			my $div_contents = $repo->make_element( "div", class=>"ep_toolbox_content" );
			$f->appendChild( $div_box );
			$div_box->appendChild( $div_contents );
			$div_contents->appendChild( 
				$repo->render_subjects( 
					\@ids, 
					$field->get_property( "top" ), 
					$path_values->[-1], 
					$mode, 
					$opts{sizes} ) );
		}
	}

	return $f;
}

sub render_export_bar
{
	my( $repo, $view, $path_values ) = @_;

	my $esc_path_values = [$view->escape_path_values( @$path_values )];

	my @plugins = $view->export_plugins();

	return $repo->make_doc_fragment if scalar @plugins == 0;

	my $export_url = $repo->config( "perl_url" )."/exportview";
	my $values = join( "/", @{$esc_path_values} );	

	my $feeds = $repo->make_doc_fragment;
	my $tools = $repo->make_doc_fragment;
	my $select = $repo->make_element( "select", name=>"format" );
	foreach my $plugin ( @plugins )
	{
		my $id = $plugin->get_id;
		$id =~ s/^Export:://;
		if( $plugin->is_feed || $plugin->is_tool )
		{
			my $type = "feed";
			$type = "tool" if( $plugin->is_tool );
			my $span = $repo->make_element( "span", class=>"ep_search_$type" );

			my $fn = join( "_", @{$esc_path_values} );	
			my $url = $export_url."/".$view->{id}."/$values/$id/$fn".$plugin->param("suffix");

			my $a1 = $repo->render_link( $url );
			my $icon = $repo->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
			$a1->appendChild( $icon );
			my $a2 = $repo->render_link( $url );
			$a2->appendChild( $plugin->render_name );
			$span->appendChild( $a1 );
			$span->appendChild( $repo->make_text( " " ) );
			$span->appendChild( $a2 );

			if( $type eq "tool" )
			{
				$tools->appendChild( $repo->make_text( " " ) );
				$tools->appendChild( $span );	
			}
			if( $type eq "feed" )
			{
				$feeds->appendChild( $repo->make_text( " " ) );
				$feeds->appendChild( $span );	
			}
		}
		else
		{
			my $option = $repo->make_element( "option", value=>$id );
			$option->appendChild( $plugin->render_name );
			$select->appendChild( $option );
		}
	}

	my $button = $repo->make_doc_fragment;
	$button->appendChild( $repo->render_button(
			name=>"_action_export_redir",
			value=>$repo->phrase( "lib/searchexpression:export_button" ) ) );
	$button->appendChild( 
		$repo->render_hidden_field( "view", $view->{id} ) );
	$button->appendChild( 
		$repo->render_hidden_field( "values", $values ) ); 

	my $form = $repo->render_form( "GET", $export_url );
	$form->appendChild( $repo->html_phrase( "Update/Views:export_section",
					feeds => $feeds,
					tools => $tools,
					menu => $select,
					button => $button ));

	return $form;
}

	
sub group_items
{
	my( $repo, $items, $field, $opts ) = @_;

	my $code_to_list = {};
	my $code_to_heading = {};
	my $code_to_value = {}; # used if $opts->{string} is NOT set.
	
	foreach my $item ( @$items )
	{
		my $values = $field->get_value( $item );
		if( !$field->get_property( "multiple" ) )
		{
			$values = [$values];
		}
		elsif( !scalar(@$values) )
		{
			$values = [$field->empty_value];
		}
		next if !$opts->{allow_null} && !EPrints::Utils::is_set( $values );
		VALUE: foreach my $value ( @$values )
		{
			next VALUE unless EPrints::Utils::is_set( $value );
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
						$code_to_heading->{"\L$keyword"} = $repo->make_text( $keyword );
					}
					push @{$code_to_list->{"\L$keyword"}}, $item;
				}
			}
			else
			{
				my $code = $value;
				if( ! defined $code ) { $code = ""; }
				if( $field->isa( "EPrints::MetaField::Name" ) )
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
							$code_to_heading->{$code} = $repo->html_phrase( "Update/Views:no_value" );
						}
						else
						{
							$code_to_heading->{$code} = $repo->make_text( $code );
						}
					}
					else
					{
						$code_to_heading->{$code} = $field->render_single_value( $repo, $value );
					}
				}
			}
			
			if( $opts->{first_value} ) { last VALUE; } 
		}
	}

	my $langid = $repo->get_langid;
	my $data = [];
	my @codes = keys %$code_to_list;

	if( $opts->{"string"} )
	{
		@codes = sort @codes;
	}
	else
	{
		my %cmp = map {
			$_ => $field->ordervalue_basic( $code_to_value->{$_}, $repo, $langid )
		} @codes;
		@codes = sort { $cmp{$a} cmp $cmp{$b} } @codes;
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
	my( $repo, $view, $items ) = @_;

	my $xml = $repo->xml;
	my $frag;
	if( defined $view->{layout} && $view->{layout} eq "orderedlist" )
	{
		$frag = $xml->create_element( "ol" );
	}
	elsif( defined $view->{layout} && $view->{layout} eq "unorderedlist" )
	{
		$frag = $xml->create_element( "ol" );
	}
	else
	{
		$frag = $xml->create_document_fragment;
	}

	my @r = ();

	$view->{layout} = "paragraph" unless defined $view->{layout};	
	foreach my $item ( @{$items} )
	{

		my $cite = $view->render_citation_link( $item );

		if( $view->{layout} eq "paragraph" )
		{
			$frag->appendChild( $xml->create_element( "p" ) )
				->appendChild( $xml->clone( $cite ) );
		}
		elsif( 
			$view->{layout} eq "orderedlist" ||
			$view->{layout} eq "unorderedlist" )
		{
			$frag->appendChild( $xml->create_element( "li" ) )
				->appendChild( $xml->clone( $cite ) );
		}
		else
		{
			$frag->appendChild( $xml->clone( $cite ) );
		}
	}

	return $frag;
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

	$opts->{allow_null} = 0 if !defined $opts->{allow_null};

	return $opts;
}

=head2 Pseudo-Views Class

=cut

sub new
{
	my( $class, %opts ) = @_;

	modernise_view( $opts{view} );

	return bless {
		%{$opts{view}},
		_repository => $opts{repository},
		_citescache => {},
	}, __PACKAGE__;
}

=item $desc = $view->name

Returns a human-readable name of this view (for debugging).

=cut

sub name
{
	my( $self ) = @_;

	return sprintf("%s.view.%s",
		$self->dataset->base_id,
		$self->{id},
	);
}

sub escape_path_values
{
	my( $self, @path_values ) = @_;

	my $menus_fields = $self->menus_fields;
	for(my $i = 0; $i < @path_values && $i < @$menus_fields; ++$i)
	{
		$path_values[$i] = EPrints::Utils::escape_filename(
			$menus_fields->[$i]->[0]->get_id_from_value(
				$self->{_repository},
				$path_values[$i]
			) );
	}

	return @path_values;
}

sub unescape_path_values
{
	my( $self, @esc_path_values ) = @_;

	my $menus_fields = $self->menus_fields;
	for(my $i = 0; $i < @esc_path_values && $i < @$menus_fields; ++$i)
	{
		$esc_path_values[$i] = $menus_fields->[$i]->[0]->get_value_from_id(
			$self->{_repository},
			EPrints::Utils::unescape_filename( $esc_path_values[$i] )
		);
	}

	return @esc_path_values;
}

=begin InternalDoc

=item $filters = $view->get_filters( $path_values [, $exact? ] )

Return an array of the filters required for the given $path_values.

If $exact is true will only return values that match $path_values exactly e.g. not any children for subject-fields.

=end InternalDoc

=cut

sub get_filters
{
	my( $self, $path_values, $exact ) = @_;

	my $menus_fields = $self->menus_fields;

	my $filters = $self->{filters};
	$filters = [] if !defined $filters;
	$filters = EPrints::Utils::clone( $filters );

	if( $self->dataset->base_id eq "eprint" )
	{
		push @$filters, { meta_fields=>[qw( metadata_visibility )], value=>"show" };
	}

	for( my $i = 0; $i < @$path_values && $i < @$menus_fields; ++$i )
	{
		my $filter = { meta_fields=>[map { $_->get_name } @{$menus_fields->[$i]}], value=>$path_values->[$i] };
		# if the value is higher than the current level then apply the match
		# exactly (only really applies to Subjects, which at the current level
		# show all ancestors)
		if( !EPrints::Utils::is_set( $path_values->[$i] ) || $i < $#$path_values || $exact )
		{
			$filter->{match} = "EX";
		}
		push @$filters, $filter;
	}

	return $filters;
}

=begin InternalDoc

=item $id_map = $view->fieldlist_sizes( $path_values, $menu_level [, $filters ] )

Returns a map of values (encoded as ids) to counts.

$menu_level is the level you want to get value-counts for.

If $filters is given will use the given filters instead of calling get_filters( $path_values ).

=end InternalDoc

=cut

sub fieldlist_sizes
{
	my( $self, $path_values, $menu_level, $filters ) = @_;

	my $repo = $self->repository;

	my $dataset = $self->dataset;
	my $menus_fields = $self->menus_fields;
	$filters = $self->get_filters( $path_values ) if !defined $filters;

	my $menu_fields = $menus_fields->[$menu_level];

	# if there are lower levels that require a value being set then we need to
	# check that, otherwise we get the wrong counts at this level
	for(my $i = @$path_values; $i < @$menus_fields; ++$i)
	{
		my $menu_fields = $menus_fields->[$i];
		my $menu = $self->{menus}->[$i];
		if( !$menu->{allow_null} )
		{
			push @$filters, 
				{ meta_fields => [map { $_->name } @$menu_fields], match => "SET" };
		}
	}

	my $searchexp = $dataset->prepare_search(
		filters => $filters,
	);
	
	# get the id/counts for the menu level requested
	my $id_map = $searchexp->perform_distinctby( $menu_fields );

	# if the field is a subject then we populate sizes with the entire tree of
	# values - each ancestor is the sum of all unique child node entries
	if( $menu_fields->[0]->isa( "EPrints::MetaField::Subject" ) )
	{
		my( $subject_map, $subject_map_r ) = EPrints::DataObj::Subject::get_all( $repo );

		my %subj_map;

		# for every subject build a running-total for all its ancestors
		foreach my $id (keys %$id_map)
		{
			my $subject = $subject_map->{$id};
			next if !defined $subject; # Hmm, unknown subject
			foreach my $ancestor (@{$subject->value( "ancestors" )})
			{
				next if $ancestor eq $EPrints::DataObj::Subject::root_subject;
				foreach my $item_id (@{$id_map->{$id}})
				{
					$subj_map{$ancestor}->{$item_id} = 1;
				}
			}
		}

		# calculate the totals
		$_ = scalar keys %$_ for values %subj_map;

		return \%subj_map;
	}

	# calculate the totals
	$_ = scalar @$_ for values %$id_map;

	return $id_map;
}

=begin InternalDoc

=item $list = $view->menus_fields()

Returns a list of lists of fields that this view represents.

=end InternalDoc

=cut

sub menus_fields
{
	my( $self ) = @_;

	return $self->{_menus_fields} if defined $self->{_menus_fields};

	my $ds = $self->dataset;

	my $menus_fields = [];
	foreach my $menu ( @{$self->{menus}} )
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

	return $self->{_menus_fields} = $menus_fields
}

=begin InternalDoc

=item $dataset = $view->dataset()

Returns the dataset this view uses items from.

=end InternalDoc

=cut

sub dataset
{
	my( $self ) = @_;

	return $self->{_dataset} ||= $self->{_repository}->dataset( $self->{dataset} );
}

sub repository
{
	my( $self ) = @_;

	return $self->{_repository};
}

=begin InternalDoc

=item $xhtml = $view->render_count( $n )

Return the item count $n.

=end InternalDoc

=cut

sub render_count
{
	my( $self, $n ) = @_;

	my $repo = $self->{_repository};
	return $repo->xml->create_document_fragment if $self->{nocount};

	my $phraseid = "bin/generate_views:blurb";
	if( $self->menus_fields->[-1]->[0]->isa( "EPrints::MetaField::Subject" ) )
	{
		$phraseid = "bin/generate_views:subject_blurb";
	}
	return $repo->html_phrase(
		$phraseid,
		n=>$repo->xml->create_text_node( $n ) );
}

=begin InternalDoc

=item $xhtml = $view->render_name()

Render the name of this view.

=end InternalDoc

=cut

sub render_name
{
	my( $self ) = @_;

	return $self->{_repository}->html_phrase( join "_", "viewname", $self->dataset->base_id, $self->{id} );
}

=item $view->update_view_by_path( %opts )

Updates the view source files.

Options:

	on_write - callback called with the filename written
	langid - language to write
	do_menus - suppress generation of menus
	do_lists - suppress generation of lists

=cut

sub update_view_by_path
{
	my( $self, %opts ) = @_;

	$opts{on_write} ||= sub {};
	$opts{target} ||= join '/', $self->repository->config( "htdocs_path" ), $opts{langid}, "view";

	$self->_update_view_by_path(
		%opts,
		path => [],
		sizes => $self->fieldlist_sizes( [], 0 ),
	);
}

sub _update_view_by_path
{
	my( $self, %opts ) = @_;

	my $repo = $self->repository;

	my $target = join "/", $opts{target}, $self->{id}, abbr_path( $self->escape_path_values( @{$opts{path}} ) );

	if( scalar @{$opts{path}} == scalar @{$self->{menus}} )
	{
		# is a leaf node
		if( $opts{do_lists} )
		{
			my $rc = update_view_list(
				$self->repository,
				$target,
				$opts{langid},
				$self,
				$opts{path},
				sizes => $opts{sizes},
			);
			&{$opts{on_write}}( $target );
		}
	}
	else
	{
		# has sub levels
		if( $opts{do_menus} )
		{
			my $rc = update_view_menu(
				$self->repository,
				$target,
				$opts{langid},
				$self,
				$opts{path}
			);
			&{$opts{on_write}}( $target );
		}

		my $sizes = $self->fieldlist_sizes( $opts{path}, scalar(@{$opts{path}}) );
		foreach my $id ( keys %{$sizes} )
		{
			my $field = $self->menus_fields->[scalar @{$opts{path}}]->[0];
			my $value = $field->get_value_from_id( $self->repository, $id );
			$self->_update_view_by_path( %opts,
				path => [@{$opts{path}}, $value],
				sizes => $sizes,
				);
		}
	}
}

=begin InternalDoc

=item $xhtml = $view->render_citation_link( $item )

Renders a citation link for $item and caches the result.

=end InternalDoc

=cut

sub render_citation_link
{
	my( $self, $item ) = @_;

	my $key = join ":", ($self->{citation}||''), $self->dataset->id, $item->id;

	return $self->{_citescache}->{$key} ||=
		$item->render_citation_link( $self->{citation} );
}

=begin InternalDoc

=item @plugins = $view->export_plugins()

Returns a sorted cached list of plugins that can be used to export items from this view.

=end InternalDoc

=cut

sub export_plugins
{
	my( $self ) = @_;

	return @{$self->{_pluginscache} ||= [
		sort { $a->get_name cmp $b->get_name }
		$self->{_repository}->get_plugins(
			type => "Export",
			can_accept => "list/".$self->dataset->base_id,
			is_visible => "all",
			is_advertised => 1,
		)
	]};
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

