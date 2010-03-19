
# We shuggest using Open Data Commons licenses as these are more sutiable for 
# data than normal Creative Commons. Follow the license URLs for more 
# information.

# $c->{rdf}->{license} = "http://www.opendatacommons.org/licenses/by/";
# OR
# $c->{rdf}->{license} = "http://www.opendatacommons.org/licenses/odbl/";

# $c->{rdf}->{attributionName} = ".....";
# $c->{rdf}->{attributionURL} = ".....";



# These triples will be supplied in any serialisation of RDF your repository
# produces, use it to describe rights information etc.

$c->add_trigger( "rdf_triples_general", sub {
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


