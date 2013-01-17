
# This is an example of a custom browse items renderer.

# To use this add render_fn=render_view_items_3col_boxes" to the options of a variation of a view.
# eg:
#		variations => [
#			"DEFAULT;render_fn=render_view_items_3col_boxes",
#		],

$c->{render_view_items_3col_boxes} = sub
{
	my( $repository, $item_list, $view_definition, $path_to_this_page, $filename ) = @_;

	my $xml = $repository->xml();

	my $table = $xml->create_element( "table" );
	my $columns = 3;
	my $tr = $xml->create_element( "tr" );
	$table->appendChild( $tr );
	my $cells = 0;
	foreach my $item ( @{$item_list} )
	{
		if( $cells > 0 && $cells % $columns == 0 )
		{
			$tr = $xml->create_element( "tr" );
			$table->appendChild( $tr );
		}

		my $link = $item->get_url;

		my $td = $xml->create_element( "td", style=>"vertical-align: top; padding: 1em; text-align: center; width: 200px;" );
		$tr->appendChild( $td );

		my $a1 = $repository->render_link( $link );
		my $piccy = $xml->create_element( "span", style=>"display: block; width: 200px; height: 150px; border: solid 1px #888; background-color: #ccf; padding: 0.25em" );
		$piccy->appendChild( $xml->create_text_node( "Imagine I'm a picture!" ));
		$a1->appendChild( $piccy );
		$td->appendChild( $a1 );

		$td->appendChild( $item->render_citation_link );

		$cells += 1;
	}

	return $table;
};

