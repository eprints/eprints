
$c->add_trigger( "rdf_triples_eprint", sub {
	my( %o ) = @_;
	my $eprint = $o{"dataobj"};
	my $eprint_uri = "<".$eprint->uri.">";
	my $eprint_url = "<".$eprint->url.">";

	my $repo = $o{repository};
	my $xml = $repo->xml;

	my $title = $xml->to_string( $eprint->render_citation( 'brief' ));

	$o{graph}->add( 
		  subject => $eprint_uri,
		predicate => "rdfs:seeAlso",
  		   object => $eprint_url );
	$o{graph}->add( 
		  subject => $eprint_url,
		predicate => "dc:title",
  		   object => "HTML Summary of of #".$eprint->id." $title",
		     type => "literal" );
	$o{graph}->add( 
		  subject => $eprint_url,
		predicate => "dc:format",
		   object => "text/html",
		     type => "literal" );
	$o{graph}->add( 
		  subject => $eprint_url,
		predicate => "foaf:primaryTopic",
  		   object => $eprint_uri );

	my @plugins = $repo->plugin_list( 
					type=>"Export",
					can_accept=>"dataobj/eprint",
					is_advertised=>1,
					is_visible=>"all" );
	foreach my $plugin_id ( @plugins ) 
	{
		my $plugin = $repo->plugin( $plugin_id );
		my $url = "<".$plugin->dataobj_export_url( $eprint ).">";

		$o{graph}->add( 
			  subject => $eprint_uri,
			predicate => "rdfs:seeAlso",
  			   object => $url );
		$o{graph}->add( 
			  subject => $url,
			predicate => "dc:title",
  			   object => $xml->to_string( $plugin->render_name )." of #".$eprint->id." $title",
			     type => "literal" );
		$o{graph}->add( 
			  subject => $url,
			predicate => "dc:format",
			   object => $plugin->param("mimetype"),
			     type => "literal" );
		$o{graph}->add( 
			  subject => $url,
			predicate => "foaf:primaryTopic",
  			   object => $eprint_uri );
	}

} );

