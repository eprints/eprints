$c->{rdf}->{xmlns}->{dc}   = 'http://purl.org/dc/elements/1.1/';





push @{$c->{rdf}->{get_triples}}, sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};
	my $eprint_uri = "<".$eprint->uri.">";

	my $main_dc_plugin = $eprint->get_session->plugin( "Export::DC" );
	my $data = $main_dc_plugin->convert_dataobj( $eprint );

	foreach my $dcitem ( @{$data} )
	{
		push @{$o{triples}->{$eprint_uri}},
			[ $eprint_uri, "dc:".$dcitem->[0], $dcitem->[1], "plain" ];
	}
};

