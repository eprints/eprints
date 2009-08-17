
# This is an example of a custom browse menu renderer.

$c->{render_view_menu_3col_boxes} = sub
{
	my( $handle, $view, $sizes, $values, $fields, $has_submenu ) = @_;

	my $table = $handle->make_element( "table" );
	my $columns = 3;
	my $tr = $handle->make_element( "tr" );
	$table->appendChild( $tr );
	my $cells = 0;
	foreach my $value ( @{$values} )
	{
		my $size = 0;
		$size = $sizes->{$value} if( defined $sizes && defined $sizes->{$value} );

		next if( $view->{hideempty} && $size == 0 );

		if( $cells > 0 && $cells % $columns == 0 )
		{
			$tr = $handle->make_element( "tr" );
			$table->appendChild( $tr );
		}

		# work out what filename to link to 
		my $fileid = $fields->[0]->get_id_from_value( $handle, $value );
		my $link = EPrints::Utils::escape_filename( $fileid );
		if( $has_submenu ) { $link .= '/'; } else { $link .= '.html'; }

		my $td = $handle->make_element( "td", style=>"padding: 1em; text-align: center" );
		$tr->appendChild( $td );

		my $a1 = $handle->render_link( $link );
		my $piccy = $handle->make_element( "span", style=>"display: block; width: 200px; height: 150px; border: solid 1px #888; background-color: #ccf; padding: 0.25em" );
		$piccy->appendChild( $handle->make_text( "Imagine I'm a picture!" ));
		$a1->appendChild( $piccy );
		$td->appendChild( $a1 );

		my $a2 = $handle->render_link( $link );
		$a2->appendChild( $fields->[0]->get_value_label( $handle, $value ) );
		$td->appendChild( $a2 );

		$cells += 1;
	}

	return $table;
};

