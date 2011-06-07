
# This is an example of a custom browse menu renderer.

# To use this add render_menu => "render_view_menu_3col_boxes" to a view in views.pl

$c->{render_view_menu_3col_boxes} = sub
{
	my( $repository, $view, $sizes, $values, $fields, $has_submenu ) = @_;

	my $xml = $repository->xml();

	my $table = $xml->create_element( "table" );
	my $columns = 3;
	my $tr = $xml->create_element( "tr" );
	$table->appendChild( $tr );
	my $cells = 0;
	foreach my $value ( @{$values} )
	{
		my $size = 0;
		$size = $sizes->{$value} if( defined $sizes && defined $sizes->{$value} );

		next if( $view->{hideempty} && $size == 0 );

		if( $cells > 0 && $cells % $columns == 0 )
		{
			$tr = $xml->create_element( "tr" );
			$table->appendChild( $tr );
		}

		# work out what filename to link to 
		my $fileid = $fields->[0]->get_id_from_value( $repository, $value );
		my $link = EPrints::Utils::escape_filename( $fileid );
		if( $has_submenu ) { $link .= '/'; } else { $link .= '.html'; }

		my $td = $xml->create_element( "td", style=>"padding: 1em; text-align: center;vertical-align:top" );
		$tr->appendChild( $td );

		my $a1 = $repository->render_link( $link );
		my $piccy = $xml->create_element( "span", style=>"display: block; width: 200px; height: 150px; border: solid 1px #888; background-color: #ccf; padding: 0.25em" );
		$piccy->appendChild( $xml->create_text_node( "Imagine I'm a picture!" ));
		$a1->appendChild( $piccy );
		$td->appendChild( $a1 );

		my $a2 = $repository->render_link( $link );
		$a2->appendChild( $fields->[0]->get_value_label( $repository, $value ) );
		$td->appendChild( $a2 );

		$cells += 1;
	}

	return $table;
};

