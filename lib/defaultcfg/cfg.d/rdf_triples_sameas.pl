
$c->add_trigger( "rdf_triples_eprint", sub {
	my( %o ) = @_;
	my $eprint = $o{"dataobj"};
	my $eprint_uri = "<".$eprint->uri.">";

	my $formats = "";
	foreach my $doc ( $eprint->get_all_documents )
	{
		my $format = $doc->get_value( "format" );
		next if( $format ne "application/rdf+xml" && $format ne "text/n3" );
		$o{graph}->add( 
			subject => $eprint_uri,
			predicate => "rdfs:seeAlso",
			object => "<".$doc->get_url.">" );
	}
} );
