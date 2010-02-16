
# These triples will be supplied in any serialisation of RDF your repository
# produces, use it to describe rights information etc.

$c->add_trigger( "rdf_triples_general", sub {
	my( %o ) = @_;
	
	my @triples;

	push @triples, [ "<>", "rdfs:comment", "The repository adminiatrator has not yet configured an RDF policy.", "literal" ];

	# Here's some possible items you may wish to add. Note that these describe 
	# rights on the RDF data output by your repository, not on the documents. 
	
	# push @triples, [ "<>", "cc:license", "<http://creativecommons.org/licenses/by/3.0/>" ];
	# push @triples, [ "<>", "cc:attributionName", $o{repository}->phrase( "archive_name" ), "literal" ];
	# push @triples, [ "<>", "cc:attributionURL", "<".$o{repository}->config( "base_url" ).">" ];
	# push @triples, [ "<>", "dc:creator", $o{repository}->phrase( "archive_name" ), "literal" ];
	# push @triples, [ "<>", "dct:rightsHolder", $o{repository}->phrase( "archive_name" ), "literal" ];

	push @{$o{triples}->{"<>"}}, @triples;
} );

