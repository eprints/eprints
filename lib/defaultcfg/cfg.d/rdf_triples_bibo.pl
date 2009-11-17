
$c->{rdf}->{xmlns}->{geonames} = "http://www.geonames.org/ontology#";
$c->{rdf}->{xmlns}->{event}    = "http://purl.org/NET/c4dm/event.owl#";

push @{$c->{rdf}->{get_triples}}, sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};
	my $eprint_uri = "<".$eprint->uri.">";

	##############################
	# Main Object 
	##############################

	my @ep3s;
	push @ep3s, [ $eprint_uri, "rdf:type", "bibo:Article" ];
	if( $eprint->dataset->has_field( "title" ) && $eprint->is_set( "title" ) )
	{
		push @ep3s, [ $eprint_uri, "dct:title", $eprint->get_value( "title" ), "plain" ];
	}
	if( $eprint->dataset->has_field( "abstract" ) && $eprint->is_set( "abstract" ) )
	{
		push @ep3s, [ $eprint_uri, "bibo:abstract", $eprint->get_value( "abstract" ), "xsd:string" ];
		push @ep3s, [ $eprint_uri, "dct:description", $eprint->get_value( "abstract" ), "xsd:string"];
	}
	if( $eprint->dataset->has_field( "date" ) && $eprint->is_set( "date" ) )
	{
		push @ep3s, [ $eprint_uri, "dct:date", $eprint->get_value( "date" ), "plain" ];
	}
		
	my $formats = "";
	foreach my $doc ( $eprint->get_all_documents )
	{
		push @ep3s, [ $eprint_uri, "dct:hasFormat", "<".$doc->get_url.">" ];
	}

	push @{$o{triples}->{$eprint_uri}}, @ep3s;

	##############################
	# Creators
	##############################

	my @creators;
	if( $eprint->dataset->has_field( "creators" ) && $eprint->is_set( "creators" ) )
	{
		@creators = @{$eprint->get_value( "creators" )};
	}

	my $authors_uri = "<".$eprint->uri."#authors>";

	my $i = 0;
	foreach my $creator ( @creators )
	{
		++$i;
		my $e_given = $creator->{name}->{given} || "";
		my $e_family = $creator->{name}->{family} || "";

		my $creator_uri = &{$c->{rdf}->{person_uri}}( $eprint, $creator );
		push @{$o{triples}->{$creator_uri}},
[ $creator_uri, "rdf:type", 		"foaf:Person" ],
[ $creator_uri, "foaf:givenname", 	$e_given, "plain" ],
[ $creator_uri, "foaf:family_name", 	$e_family, "plain" ],
[ $eprint_uri,  "dct:creator", 		$creator_uri ],
[ $eprint_uri,  "bibo:authorList", 	$authors_uri ],
[ $authors_uri, "rdf:_$i", 		$creator_uri ],
	}
};


##############################
# Event
##############################

push @{$c->{rdf}->{get_triples}}, sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};

	return () if( !$eprint->dataset->has_field( "type" ) );
	return () if( !$eprint->get_value( "type" ) eq "conference_item" );

	my $event_uri = &{$c->{rdf}->{event_uri}}( $eprint );
	return if !defined $event_uri;

	my $eprint_uri = "<".$eprint->uri.">";
	my $event_title = $eprint->get_value( "event_title" )||"";

	push @{$o{triples}->{$event_uri}},
[ $eprint_uri,	"rdf:type",		"bibo:Article" ],
[ $eprint_uri,	"bibo:presentedAt",	$event_uri ],
[ $event_uri,	"rdf:type",		"bibo:Conference" ],
[ $event_uri,	"dc:title",		$event_title, "xsd:string" ],
;
	my $event_loc_uri = &{$c->{rdf}->{event_location_uri}}( $eprint );
	if( $event_loc_uri )
	{
		my $event_location = $eprint->get_value( "event_location" );
		push @{$o{triples}->{$event_uri}},
[ $event_uri, 	"event:place", 		$event_loc_uri ];

		push @{$o{triples}->{$event_loc_uri}},
[ $event_uri,	"rdf:type",		"bibo:Conference" ],
[ $event_uri,	"event:place",		$event_loc_uri ],
[ $event_loc_uri,	"geonames:name",	$event_location, "xsd:string" ],
[ $event_loc_uri,	"dc:title",		$event_location, "xsd:string" ];
	}
};

