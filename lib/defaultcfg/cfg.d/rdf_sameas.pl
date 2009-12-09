
push @{$c->{rdf}->{get_triples}}, sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};
	my $eprint_uri = "<".$eprint->uri.">";

	my $formats = "";
	foreach my $doc ( $eprint->get_all_documents )
	{
		my $format = $doc->get_value( "format" );
		next if( $format ne "application/rdf+xml" && $format ne "text/n3" );
		push @{$o{triples}->{$eprint_uri}}, 
			[ $eprint_uri, "rdfs:seeAlso", "<".$doc->get_url.">" ];
	}

}
