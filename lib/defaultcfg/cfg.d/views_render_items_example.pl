
# This is an example of a custom browse items renderer.

# Note: This function needs to return a UTF-8 encoded string NOT XHTML DOM.
# (this is to speed things up).

$c->{render_view_items_3col_boxes} = sub
{
	my( $session, $item_list, $view_definition, $path_to_this_page, $filename ) = @_;

	my $table = $session->make_element( "table" );
	my $columns = 3;
	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );
	my $cells = 0;
	foreach my $item ( @{$item_list} )
	{
		if( $cells > 0 && $cells % $columns == 0 )
		{
			$tr = $session->make_element( "tr" );
			$table->appendChild( $tr );
		}

		my $link = $item->get_url;

		my $td = $session->make_element( "td", style=>"padding: 1em; text-align: center; width: 200px;" );
		$tr->appendChild( $td );

		my $a1 = $session->render_link( $link );
		my $piccy = $session->make_element( "span", style=>"display: block; width: 200px; height: 150px; border: solid 1px #888; background-color: #ccf; padding: 0.25em" );
		$piccy->appendChild( $session->make_text( "Imagine I'm a picture!" ));
		$a1->appendChild( $piccy );
		$td->appendChild( $a1 );

		$td->appendChild( $item->render_citation_link );

		$cells += 1;
	}

	return EPrints::XML::to_string( $table );
};

