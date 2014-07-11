######################################################################
#
# EPrints::Paginate
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Paginate> - Methods for rendering a paginated List

=head1 DESCRIPTION

=over 4

=cut

######################################################################
package EPrints::Paginate;

use URI::Escape;
use strict;

######################################################################
=pod

=item $xhtml = EPrints::Paginate->paginate_list( $session, $basename, $list, %opts )

Render a "paginated" view of the list i.e. display a "page" of items 
with links to navigate through the list.

$basename is the basename to use for pagination-specific CGI parameters, to avoid clashes.

%opts is a hash of options which can be used to customise the 
behaviour and/or rendering of the paginated list. See EPrints::Search 
for a good example!

B<Behaviour options:>

=over 4

=item page_size	

The maximum number of items to display on a page.

=item pagejumps

The maximum number of page jump links to display.

=item params

A hashref of parameters to include in the prev/next/jump URLs, 
e.g. to maintain the state of other controls on the page between jumps.

=back

B<Rendering options:>

=over 4

=item controls_before, controls_after

Additional links to display before/after the page navigation controls.

=item container

A containing XML DOM element for the list of items on the current page.

=item render_result, render_result_params

A custom subroutine for rendering an individual item on the current 
page. The subroutine will be called with $session, $item, and the
parameter specified by the render_result_params option. The
rendered item should be returned.

=item phrase

The phrase to use to render the entire "page". Can make use of the following pins:

=over 4

=item controls

prev/next/jump links

=item searchdesc

description of list e.g. what search parameters produced it

=item matches

total number of items in list, range of items displayed on current page

=item results

list of rendered items

=item controls_if_matches

prev/next/jump links (only if list contains >0 items)

=back

These can be overridden in the "pins" option (below).

=item pins

Named "pins" to render on the page. These may override the default 
"pins" (see above), or specify new "pins" (although you would need 
to define a custom phrase in order to make use of them).

=back

=cut
######################################################################

sub paginate_list
{
	my( $class, $session, $basename, $list, %opts ) = @_;

	my $n_results = $list->count();
	my $offset = defined $opts{offset} ? $opts{offset} : ($session->param( $basename."_offset" ) || 0);
	$offset += 0;
	my $pagesize = defined $opts{page_size} ? $opts{page_size} : ($session->param( $basename."page_size" ) || 10); # TODO: get default from somewhere?
	$pagesize += 0;
	my @results = $list->get_records( $offset , $pagesize );
	my $plast = $offset + $pagesize;
	$plast = $n_results if $n_results< $plast;

	my %pins;

	# Add params to action urls
	my $url = URI->new( $session->get_uri );
	my @param_list;
	#push @param_list, "_cache=" . $list->get_cache_id; # if cached
	#my $escexp = $list->{encoded}; # serialised search expression
	#$escexp =~ s/ /+/g; # not great way...
	#push @param_list, "_exp=$escexp";
	if( defined $opts{params} )
	{
		my $params = $opts{params};
		foreach my $key ( keys %$params )
		{
			my $value = $params->{$key};
			push @param_list, $key => $value if defined $value;
		}
	}
	$url->query_form( @param_list );

	my $matches = $session->make_doc_fragment;	
	if( scalar $n_results > 0 )
	{
		# TODO default phrase for item range
		# TODO override default phrase with opts
		my %numbers = ();
		$numbers{from} = $session->make_element( "span", class=>"ep_search_number" );
		$numbers{from}->appendChild( $session->make_text( $offset+1 ) );
		$numbers{to} = $session->make_element( "span", class=>"ep_search_number" );
		$numbers{to}->appendChild( $session->make_text( $plast ) );
		$numbers{n} = $session->make_element( "span", class=>"ep_search_number" );
		$numbers{n}->appendChild( $session->make_text( $n_results ) );
		$matches->appendChild( 
			$session->html_phrase( "lib/searchexpression:results", %numbers )
			);
		if( !$opts{page_size} )
		{
			$matches->appendChild( $session->make_text( " " ) );
			my %links;
			for(10,25,100)
			{
				$links{"n_$_"} = $session->render_link( $url . "&${basename}page_size=$_" );
				$links{"n_$_"}->appendChild( $session->make_text( $_ ) );
			}

			# option to show all results
			$links{n_all} = $session->render_link( $url . "&${basename}page_size=$n_results" );

			$matches->appendChild(
				$session->html_phrase( "lib/searchexpression:results_page_size", %links )
				);
			if( defined $session->param( "${basename}page_size" ) )
			{
				$url->query_form( @param_list, $basename."page_size" => $pagesize );
			}
		}
	}
	else
	{
		# override default phrase with opts
		$matches->appendChild( $session->html_phrase( 
				"lib/searchexpression:noresults" ) );
	}

	$pins{above_results} = $opts{above_results};
	if( !defined $pins{above_results} )
	{
		$pins{above_results} = $session->make_doc_fragment;
	}
	$pins{below_results} = $opts{below_results};
	if( !defined $pins{below_results} )
	{
		$pins{below_results} = $session->make_doc_fragment;
	}

	my @controls; # page controls
	if( defined $opts{controls_before} )
	{
		my $custom_controls = $opts{controls_before};
		foreach my $control ( @$custom_controls )
		{
			my $custom_control = $session->render_link( $control->{url} );
			$custom_control->appendChild( $control->{label} );
			push @controls, $custom_control;
		}
	}

	# Previous page link
	if( $offset > 0 ) 
	{
		my $bk = $offset-$pagesize;
		my $prevurl = "$url&$basename\_offset=".($bk<0?0:$bk);
		my $prevlink = $session->render_link( $prevurl );
		my $pn = $pagesize>$offset?$offset:$pagesize;
		$prevlink->appendChild( 
			$session->html_phrase( 
				"lib/searchexpression:prev",
				n=>$session->make_doc_fragment ) );
				#n=>$session->make_text( $pn ) ) );
		push @controls, $prevlink;
	}

	# Page jumps
	my $pages_to_show = $opts{pagejumps} || 10; # TODO: get default from somewhere?
	my $cur_page = $offset / $pagesize;
	my $num_pages = int( $n_results / $pagesize );
	$num_pages++ if $n_results % $pagesize;
	$num_pages--; # zero based

	my $start_page = $cur_page - ( $pages_to_show / 2 );
	my $end_page = $cur_page + ( $pages_to_show / 2 );

	if( $start_page < 0 )
	{
		$end_page += -$start_page; # end page takes up slack
	}
	if( $end_page > $num_pages )
	{
		$start_page -= $end_page - $num_pages; # start page takes up slack
	}

	$start_page = 0 if $start_page < 0; # normalise
	$end_page = $num_pages if $end_page > $num_pages; # normalise
	unless( $start_page == $end_page ) # only one page, don't need jumps
	{
		for my $page_n ( $start_page..$end_page )
		{
			my $jumplink;
			if( $page_n != $cur_page )
			{
				my $jumpurl = "$url&$basename\_offset=" . $page_n * $pagesize;
				$jumplink = $session->render_link( $jumpurl );
				$jumplink->appendChild( $session->make_text( $page_n + 1 ) );
			}
			else
			{
				$jumplink = $session->make_element( "strong" );
				$jumplink->appendChild( $session->make_text( $page_n + 1 ) );
			}
			push @controls, $jumplink;
		}
	}

	# Next page link
	if( $offset + $pagesize < $n_results )
	{
		my $nexturl="$url&$basename\_offset=".($offset+$pagesize);
		my $nextlink = $session->render_link( $nexturl );
		my $nn = $n_results - $offset - $pagesize;
		$nn = $pagesize if( $pagesize < $nn);
		$nextlink->appendChild( $session->html_phrase( "lib/searchexpression:next",
					n=>$session->make_doc_fragment ) );
					#n=>$session->make_text( $nn ) ) );
		push @controls, $nextlink;
	}

#	if( defined $opts{controls_after} )
#	{
#		my $custom_controls = $opts{controls_after};
#		foreach my $control ( @$custom_controls )
#		{
#			my $custom_control = $session->render_link( $control->{url} );
#			$custom_control->appendChild( $control->{label} );
#			push @controls, $custom_control;
#		}
#	}

	if( scalar @controls )
	{
		$pins{controls} = $session->make_element( "div" );
		$pins{controls}->appendChild( $matches );

		$pins{controls}->appendChild( $session->make_element( "br" ) );

		my $first = 1;
		foreach my $control ( @controls )
		{
			if( $first )
			{
				$first = 0;
			}
			else
			{
				$pins{controls}->appendChild( $session->html_phrase( "lib/searchexpression:seperator" ) );
			}
			my $cspan = $session->make_element( 'span', class=>"ep_search_control" );
			$cspan->appendChild( $control );
			$pins{controls}->appendChild( $cspan );
		}
	}
	
	if( defined $opts{controls_after} )
	{
		$pins{controls} = $session->make_element( 'div' ) if( !defined $pins{controls} );
		$pins{controls}->appendChild( $opts{controls_after} );	
	}

	my $type;
	# Container for results (e.g. table, div..)
	if( defined $opts{container} )
	{
		$pins{results} = $opts{container};
	}
	else
	{
		$type = $session->get_citation_type( $list->get_dataset );
		if( $type eq "table_row" )
		{
			$pins{results} = $session->make_element( 
					"table", 
					class=>"ep_paginate_list" );
		}
		else
		{
			$pins{results} = $session->make_element( 
					"div", 
					class=>"ep_paginate_list" );
		}
	}

	if( defined $opts{rows_before} )
	{
		$pins{results}->appendChild( $opts{rows_before} );
	}

	my $n = $offset;
	foreach my $result ( @results )
	{
		$n += 1;
		# Render individual results
		if( defined $opts{render_result} )
		{
			# Custom rendering routine specified
			my $params = $opts{render_result_params};
			my $custom = &{ $opts{render_result} }( 
						$session, 
						$result, 
						$params, 
						$n );
			$pins{results}->appendChild( $custom );
		}
		elsif( $type eq "table_row" )
		{
			$pins{results}->appendChild( 
				$result->render_citation_link() ); 
		}
		else
		{
			my $div = $session->make_element( 
				"div", 
				class=>"ep_paginate_result" );
			$div->appendChild( 
				$result->render_citation_link() ); 
			$pins{results}->appendChild( $div );
		}
	}

	# If we have no results, we can use a custom renderer to	
	# put a descriptive phrase in place of the result list.

	if( $n_results == 0 )
	{
		if( defined $opts{render_no_results} )
		{
			my $params = $opts{render_result_params};
			my $no_res = &{ $opts{render_no_results} }(
					$session,
					$params,
					$session->html_phrase( 
						"lib/paginate:no_items" )
					);
			$pins{results}->appendChild( $no_res );
		}
	}
	
	if( defined $opts{rows_after} )
	{
		$pins{results}->appendChild( $opts{rows_after} );
	}

	# Render a page of results
	my $custom_pins = $opts{pins};
	for( keys %$custom_pins )
	{
		$pins{$_} = $custom_pins->{$_} if defined $custom_pins->{$_};
	}


	my $page = $session->make_doc_fragment;

	if( defined $pins{controls} )
	{
		my $div = $session->make_element( "div", class=>"ep_search_controls" );
		$div->appendChild( $pins{controls} );
		$page->appendChild( $div );
	}	
	if( defined $pins{above_results} )
	{
		$page->appendChild( $pins{above_results} );
	}	
	if( defined $pins{results} )
	{
		my $div = $session->make_element( "div", class=>"ep_search_results" );
		$div->appendChild( $pins{results} );
		$page->appendChild( $div );
	}	
	if( defined $pins{below_results} )
	{
		$page->appendChild( $pins{below_results} );
	}	
	if( $n_results > 0 && defined $pins{controls} )
	{
		my $div = $session->make_element( "div", class=>"ep_search_controls_bottom" );
		$div->appendChild( $session->clone_for_me( $pins{controls}, 1 ) );
		$page->appendChild( $div );
	}	


	return $page;
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

