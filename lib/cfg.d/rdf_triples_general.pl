

# These triples will be supplied in any serialisation of RDF your repository
# produces, use it to describe rights information etc.

$c->add_trigger( EP_TRIGGER_BOILERPLATE_RDF, sub {
	my( %o ) = @_;

	my $license_uri = $o{repository}->config( "rdf", "license" );
	if( defined $license_uri )
	{
		$o{graph}->add( 
		  	subject => "<>",
			predicate => "cc:license",
		   	object => $license_uri );
	}
	else
	{
		$o{graph}->add( 
		  	subject => "<>",
			predicate => "rdfs:comment",
		   	object => "The repository administrator has not yet configured an RDF license.",
		     	type => "xsd:string" );
	}	
	
	my $attributionName = $o{repository}->config( "rdf", "attributionName" );
	if( defined $license_uri )
	{
		$o{graph}->add( 
		  	  subject => "<>",
			predicate => "cc:attributionName",
		   	   object => $attributionName,
			     type => "xsd:string" );
	}

	my $attributionURL = $o{repository}->config( "rdf", "attributionURL" );
	if( defined $attributionURL )
	{
		$o{graph}->add( 
		  	subject => "<>",
			predicate => "cc:attributionURL",
		   	object => $attributionURL );
	}

	# [ "<>", "dc:creator", $o{repository}->phrase( "archive_name" ), "literal" ];
	# [ "<>", "dct:rightsHolder", $o{repository}->phrase( "archive_name" ), "literal" ];
} );


