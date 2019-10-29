######################################################################
#
# EPrints::Paginate::Columns
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Paginate::Columns> - Methods for rendering a paginated List as sortable columns

=head1 DESCRIPTION

=over 4

=cut

######################################################################
package EPrints::Paginate::Columns;

@ISA = ( 'EPrints::Paginate' );

use POSIX qw(ceil);
use URI::Escape;
use strict;

sub paginate_list
{
	my( $class, $session, $basename, $list, %opts ) = @_;

	my %newopts = %opts;
	
	if( EPrints::Utils::is_set( $basename ) )
	{
		$basename .= '_';
	}
	else
	{
		$basename = '';
	}

	# Build base URL
	my $url = $session->get_uri . "?";
	my @param_list;
	if( defined $opts{params} )
	{
		my $params = $opts{params};
		foreach my $key ( keys %$params )
		{
			next if $key eq $basename."order";
			my $value = $params->{$key};
			push @param_list, "$key=$value" if defined $value;
		}
	}
	$url .= join "&", @param_list;

	my $offset = defined $opts{offset} ? $opts{offset} : ($session->param( $basename."offset" ) || 0);
	$offset += 0;
	$url .= "&".$basename."offset=$offset"; # $basename\_offset used by paginate_list

	# Sort param
	my $sort_order = $opts{custom_order};
	if( !defined $sort_order )
	{
		$sort_order = $session->param( $basename."order" );
	}
	if( !defined $sort_order ) 
	{
		foreach my $sort_col (@{$opts{columns}})
		{
			next if !defined $sort_col;
			my $field = $list->get_dataset->get_field( $sort_col );
			next if !defined $field;

			if( $field->should_reverse_order )
			{
				$sort_order = "-$sort_col";
			}	
			else	
			{
				$sort_order = "$sort_col";
			}	
			last;
		}
	}	
	if( EPrints::Utils::is_set( $sort_order ) )
	{
		$newopts{params}{ $basename."order" } = $sort_order;
		if( !$opts{custom_order} )
		{
			$list = $list->reorder( $sort_order );
		}
	}
	
	# URL for images
	my $imagesurl = $session->config( "rel_path" )."/style/images";

	# Container for list
	my $table = $session->make_element( "table", border=>0, cellpadding=>4, cellspacing=>0, class=>"ep_columns" );
	my $tr = $session->make_element( "tr", class=>"header_plain" );
	$table->appendChild( $tr );

	my $len = scalar(@{$opts{columns}});

	for(my $i = 0; $i<$len;++$i )
	{
		my $col = $opts{columns}->[$i];
		my $last = ($i == $len-1);
		# Column headings
		my $th = $session->make_element( "th", style=>"padding:0px", class=>"ep_columns_title".($last?" ep_columns_title_last":"") );
		$tr->appendChild( $th );
		next if !defined $col;
	
		my $linkurl = "$url&${basename}order=$col";
		if( $col eq $sort_order )
		{
			$linkurl = "$url&${basename}order=-$col";
		}
		my $field = $list->get_dataset->get_field( $col );
		if( $field->should_reverse_order )
		{
			$linkurl = "$url&${basename}order=-$col";
			if( "-$col" eq $sort_order )
			{
				$linkurl = "$url&${basename}order=$col";
			}
		}
		my $itable = $session->make_element( "table", cellpadding=>0, border=>0, cellspacing=>0, width=>"100%" );
		$th->appendChild( $itable );
		my $itr = $session->make_element( "tr" );
		$itable->appendChild( $itr );
		my $itd1 = $session->make_element( "td" );
		$itr->appendChild( $itd1 );
		my $link = $session->make_element( "a", href=>$linkurl, style=>'display:block;padding:4px' );
		$link->appendChild( $list->get_dataset->get_field( $col )->render_name( $session ) );
		$itd1->appendChild( $link );

		# Sort controls

		if( $sort_order eq $col || $sort_order eq "-$col")
		{
			my $itd2 = $session->make_element( "td", style=>"width:22px; text-align: right" );
			$itr->appendChild( $itd2 );
			my $link2 = $session->render_link( $linkurl );
			$itd2->appendChild( $link2 );
			if( $sort_order eq $col )
			{
				$link2->appendChild( $session->make_element(
					"img",
					alt=>"Up",
					style=>"border:0px;padding:4px",
					border=>0,
					src=> "$imagesurl/sorting_up_arrow.gif" ));
			}
			if( $sort_order eq "-$col" )
			{
				$link2->appendChild( $session->make_element(
					"img",
					alt=>"Down",
					style=>"border:0px;padding:4px",
					border=>0,
					src=> "$imagesurl/sorting_down_arrow.gif" ));
			}
		}
			
	}
	
	my $info = {
		row => 1,
		columns => $opts{columns},
	};
	$newopts{container} = $table unless defined $newopts{container};
	$newopts{render_result_params} = $info unless defined $newopts{render_result_params};
	$newopts{render_result} = sub {
		my( $session, $e, $info ) = @_;

		my $tr = $session->make_element( "tr" );
		my $first = 1;
		foreach my $column ( @{ $info->{columns} } )
		{
			my $td = $session->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"") );
			$first = 0;
			$tr->appendChild( $td );
			$td->appendChild( $e->render_value( $column ) );
		}
		return $tr;
	} unless defined $newopts{render_result};

	$newopts{render_no_results} = sub {
		my( $session, $info, $phrase ) = @_;
		my $tr = $session->make_element( "tr" );
		my $td = $session->make_element( "td", class=>"ep_columns_no_items", colspan => scalar @{ $opts{columns} } );
		$td->appendChild( $phrase ); 
		$tr->appendChild( $td );
		return $tr;
	} unless defined $newopts{render_no_results};
	
	return EPrints::Paginate->paginate_list( $session, $basename, $list, %newopts );
}

#
# Return $list sliced and sorted as another List
#
sub paginate_list2
{
    my( $class, $repo, $basename, $columns, $list ) = @_;

    my $ds = $list->get_dataset();

    # Determine the sort order for the table
    my $sort_order = $repo->param( '_buffer_order' );
    my ( $sort_dir, $sort_col ) = ( $sort_order =~ m/^(-?)([a-zA-Z0-9_]+)$/ );

    if( !defined $sort_order )
    {
	foreach my $col ( @{$columns} )
	{
	    next if !defined $col;
	    my $field = $ds->get_field( $col );
	    next if !defined $field;

	    if( $field->should_reverse_order )
	    {
		$sort_dir = '-';
	    }
	    $sort_col = $col;
	    last;
	}
    }

    $list = $list->reorder( "${sort_dir}${sort_col}" );

    my $offset = $repo->param( "${basename}__offset" ) || 0;
    $offset += 0;

    my $pagesize = $repo->param( "${basename}_page_size" ) || 10;
    $pagesize += 0;

    my @items = $list->slice( $offset, $pagesize );

    my $total = $list->count();
    return {
	sort_dir => $sort_dir,
	sort_col => $sort_col,
	order => "${sort_dir}${sort_col}",
	dataset => $ds->id(),
	total => $total,
	pages => ceil( $total / $pagesize ),
	current_page => ( $offset / $pagesize ) + 1,
	offset => $offset,
	pagesize => $pagesize,
	dataobjs => \@items,
    };

}

1;

######################################################################
=pod

=back

=cut


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

