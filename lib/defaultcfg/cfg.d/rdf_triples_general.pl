
# These triples will be supplied in any serialisation of RDF your repository
# produces, use it to describe rights information etc.

$c->add_trigger( "rdf_triples_general", sub {
	my( %o ) = @_;
	
	my @triples;

	push @triples, [ "<>", "rdfs:comment", "The repository administrator has not yet configured an RDF policy.", "literal" ];

	# Here's some possible items you may wish to add. Note that these describe 
	# rights on the RDF data output by your repository, not on the documents. 
	
	# Using Open Data Commons licenses as these are more sutiable for data than normal 
	# Creative Commons. Follow the license URLs for more information.

	# push @triples, [ "<>", "cc:license", "<http://www.opendatacommons.org/licenses/by/>";
	#  OR
	# push @triples, [ "<>", "cc:license", "<http://www.opendatacommons.org/licenses/odbl/>";

	# push @triples, [ "<>", "cc:attributionName", $o{repository}->phrase( "archive_name" ), "literal" ];
	# push @triples, [ "<>", "cc:attributionURL", "<".$o{repository}->config( "base_url" ).">" ];
	# push @triples, [ "<>", "dc:creator", $o{repository}->phrase( "archive_name" ), "literal" ];
	# push @triples, [ "<>", "dct:rightsHolder", $o{repository}->phrase( "archive_name" ), "literal" ];

	push @{$o{triples}->{"<>"}}, @triples;
} );

