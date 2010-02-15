
# These triples will be supplied in any serialisation of RDF your repository
# produces, use it to describe rights information etc.

$c->add_trigger( "rdf_triples_general", sub {
	my( %o ) = @_;
	
	my @l;

	push @l, [ "<>", "rdfs:comment", "The repository adminiatrator has not yet configured an RDF policy.", "literal" ];

	# Here's some possible items you may wish to add.
	# push @l, [ "<>", "cc:attributionName", $o{repository}->phrase( "archive_name" ), "literal" ];
	# push @l, [ "<>", "cc:attributionURL", "<".$o{repository}->config( "base_url" ).">" ];
	# push @l, [ "<>", "cc:license", "<http://creativecommons.org/licenses/by/3.0/>" ];
	# push @l, [ "<>", "dc:creator", $o{repository}->phrase( "archive_name" ), "literal" ];
	# push @l, [ "<>", "dct:rightsHolder", $o{repository}->phrase( "archive_name" ), "literal" ];

	push @{$o{triples}->{"<>"}}, @l;
} );

