
$c->add_trigger( "rdf_triples_eprint", sub {
	my( %o ) = @_;
	my $eprint = $o{"dataobj"};
	my $eprint_uri = "<".$eprint->uri.">";

	my $repo = $o{repository};
	my @plugins = $repo->plugin_list( 
					type=>"Export",
					can_accept=>"dataobj/eprint",
					is_advertised=>1,
					is_visible=>"all" );
	my $xml = $repo->xml;
	foreach my $plugin_id ( @plugins ) 
	{
		my $plugin = $repo->plugin( $plugin_id );
		my $url = $plugin->dataobj_export_url( $eprint );

		$o{graph}->add( 
			  subject => $eprint_uri,
			predicate => "rdfs:seeAlso",
  			   object => "<$url>" );
		$o{graph}->add( 
			  subject => $url,
			predicate => "dc:title",
  			   object => $xml->to_string( $plugin->render_name ),
			     type => "literal" );
		$o{graph}->add( 
			  subject => $url,
			predicate => "dc:format",
			   object => $plugin->param("mimetype"),
			     type => "literal" );
	}

} );

