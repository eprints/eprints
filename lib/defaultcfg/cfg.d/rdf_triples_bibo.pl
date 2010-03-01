
$c->{rdf}->{xmlns}->{event} = "http://purl.org/NET/c4dm/event.owl#";
$c->{rdf}->{xmlns}->{bibo}  = "http://purl.org/ontology/bibo/";
$c->{rdf}->{xmlns}->{cc}    = "http://creativecommons.org/ns#";


$c->{rdf}->{bibo_type}->{article} = "bibo:AcademicArticle"; # bit risky, but most things in a repo are.
$c->{rdf}->{bibo_type}->{book_section} = "bibo:BookSection";
$c->{rdf}->{bibo_type}->{monograph} = "bibo:Manuscript";
$c->{rdf}->{bibo_type}->{conference_item} = "bibo:AcademicArticle";
$c->{rdf}->{bibo_type}->{book} = "bibo:Book";
$c->{rdf}->{bibo_type}->{thesis} = "bibo:Thesis";
$c->{rdf}->{bibo_type}->{patent} = "bibo:Patent";
#$c->{rdf}->{bibo_type}->{artefact} = "xxx";
#$c->{rdf}->{bibo_type}->{exhibition} = "xxx";
$c->{rdf}->{bibo_type}->{composition} = "<http://purl.org/ontology/mo/MusicalWork>";
$c->{rdf}->{bibo_type}->{performance} = "bibo:Performance";
$c->{rdf}->{bibo_type}->{image} = "bibo:Image";
$c->{rdf}->{bibo_type}->{video} = "bibo:AudioVisualDocument";
$c->{rdf}->{bibo_type}->{audio} = "bibo:AudioDocument";
#$c->{rdf}->{bibo_type}->{dataset} = "xxx";
#$c->{rdf}->{bibo_type}->{experiment} = "xxx";
#$c->{rdf}->{bibo_type}->{teaching_resource} = "xxx";
#$c->{rdf}->{bibo_type}->{other} = "xxx";

$c->add_trigger( "rdf_triples_eprint", sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};
	my $eprint_uri = "<".$eprint->uri.">";

	##############################
	# Main Object 
	##############################

	my @triples;
	my $type="";
	if( $eprint->dataset->has_field( "type" ) && $eprint->is_set( "type" ) )
	{
		$type = $eprint->get_value( "type" );
		my $bibo_type = $c->{rdf}->{bibo_type}->{$type};
		if( defined $bibo_type )
		{
			if( $eprint->dataset->has_field( "editors" ) && $eprint->is_set( "editors" ) )
			{
				if( $bibo_type eq "bibo:Book" )
				{
					$bibo_type = "bibo:EditedBook";
				}
			}
			push @triples, [ $eprint_uri, "rdf:type", $bibo_type ];
		}
	}
	push @triples, [ $eprint_uri, "rdf:type", "bibo:Article" ];
	if( $eprint->dataset->has_field( "title" ) && $eprint->is_set( "title" ) )
	{
		push @triples, [ $eprint_uri, "dct:title", $eprint->get_value( "title" ), "literal" ];
	}
	if( $eprint->dataset->has_field( "abstract" ) && $eprint->is_set( "abstract" ) )
	{
		push @triples, [ $eprint_uri, "bibo:abstract", $eprint->get_value( "abstract" ), "xsd:string" ];
	}
	if( $eprint->dataset->has_field( "date" ) && $eprint->is_set( "date" ) )
	{
		push @triples, [ $eprint_uri, "dct:date", $eprint->get_value( "date" ), "literal" ];
	}
		
	my $formats = "";
	DOC: foreach my $doc ( $eprint->get_all_documents )
	{
		my $doc_uri = "<".$doc->uri.">";
		my $format = $doc->get_value( "format" );
		my $bibo_type = "bibo:Document";
		if( $format && $format =~ m/^image\// ) { $bibo_type = "bibo:Image"; }
		if( $format && $format =~ m/^video\// ) { $bibo_type = "bibo:AudioVisualDocument"; }
		if( $format && $format =~ m/^audio\// ) { $bibo_type = "bibo:AudioDocument"; }
		if( $format && $format eq "application/vnd.ms-powerpoint" ) { $bibo_type = "bibo:Slideshow"; }
		push @triples, [ $doc_uri, "rdf:type", $bibo_type ];
	}

	push @{$o{triples}->{$eprint_uri}}, @triples;

	# Thesis

	# can't do masters as bibo splits them into art/science and eprints does not.
	if( $type eq "thesis" )
	{
		if( $eprint->dataset->has_field( "thesis_type" ) && $eprint->is_set( "thesis_type" ) 
	 	 && $eprint->get_value( "thesis_type" ) eq "phd" )
		{
			push @{$o{triples}->{$eprint_uri}},
				[ $eprint_uri, "bibo:degree", "<http://purl.org/ontology/bibo/degrees/phd>" ];
		}
		if( $eprint->dataset->has_field( "institution" ) && $eprint->is_set( "institution" )  )
		{
			my $inst_name = $eprint->get_value( "institution" );
			my $inst_uri = &{$c->{rdf}->{org_uri}}( $eprint, $inst_name );
			if( $inst_uri )
			{
				push @{$o{triples}->{$inst_uri}},
					[ $inst_uri, "rdf:type", 	"foaf:Organization" ],
					[ $inst_uri, "foaf:name", 	$inst_name, "literal" ],
					[ $eprint_uri, "dct:issuer",	$inst_uri ],
				;
				if( $eprint->dataset->has_field( "department" ) && $eprint->is_set( "department" )  )
				{
					my $dept_name = $eprint->get_value( "department" ).", $inst_name";
					my $dept_uri = &{$c->{rdf}->{org_uri}}( $eprint, $dept_name );
					if( $dept_uri )
					{
						push @{$o{triples}->{$dept_uri}},
							[ $dept_uri, "rdf:type", 	"foaf:Organization" ],
							[ $dept_uri, "foaf:name", 	$dept_name, "literal" ],
							[ $dept_uri, "dct:isPartOf", 	$inst_uri ],
							[ $eprint_uri, "dct:issuer",	$dept_uri ],
						;
						push @{$o{triples}->{$inst_uri}},
							[ $inst_uri, "dct:hasPart", $dept_uri ];
					}
				}
			}
		}
	}

	# DOI

	if( $eprint->dataset->has_field( "id_number" ) && $eprint->is_set( "id_number" ) )
	{
		my $doi = $eprint->get_value( "id_number" );
		if( $doi =~ s/^doi:/info:doi\// )
		{
			push @{$o{triples}->{$eprint_uri}},
				[ $eprint_uri, "owl:sameAs", "<$doi>" ];
		}
	}

	# PageRange

	if( $eprint->dataset->has_field( "page_range" ) && $eprint->is_set( "page_range" ) )
	{
		my $page_range = $eprint->get_value( "page_range" );
		my( $start, $end ) = split( "-", $page_range );
		push @{$o{triples}->{$eprint_uri}},
			[ $eprint_uri, "bibo:pageStart", $start, "literal" ],
			[ $eprint_uri, "bibo:pageEnd", $end, "literal" ];
	}

	# Volumne

	if( $eprint->dataset->has_field( "volume" ) && $eprint->is_set( "volume" ) )
	{
		push @{$o{triples}->{$eprint_uri}},
			[ $eprint_uri, "bibo:volume", $eprint->get_value( "volume" ), "literal" ];
	}

	# Issue Number

	if( $eprint->dataset->has_field( "number" ) && $eprint->is_set( "number" ) )
	{
		push @{$o{triples}->{$eprint_uri}},
			[ $eprint_uri, "bibo:issue", $eprint->get_value( "number" ), "literal" ];
	}

	# ISBN

	if( $eprint->dataset->has_field( "isbn" ) && $eprint->is_set( "isbn" ) )
	{
		my $isbn = $eprint->get_value( "isbn" );
		$isbn =~ s/[^0-9X]//g;
		if( $type eq "book" )
		{
			push @{$o{triples}->{$eprint_uri}},
				[ $eprint_uri, "owl:sameAs", "<urn:isbn:$isbn>" ];
		}
		if( $type eq "book_chapter" )
		{
			push @{$o{triples}->{$eprint_uri}},
				[ $eprint_uri, "dct:isPartOf", "<urn:isbn:$isbn>" ];
		}
		if( $eprint->dataset->has_field( "publisher" ) )
		{
			my $org_name = $eprint->get_value( "publisher" );
			my $org_uri = &{$c->{rdf}->{org_uri}}( $eprint, $org_name );
			if( $org_uri )
			{
				push @{$o{triples}->{$org_uri}},
					[ $org_uri, "rdf:type", 	"foaf:Organization" ],
					[ $org_uri, "foaf:name", 	$org_name, "literal" ],
				;
			}
		}
	}

	# Publisher

	my $publisher_uri;
	if( $eprint->dataset->has_field( "publisher" ) && $eprint->is_set( "publisher" ) )
	{
		my $publisher_name = $eprint->get_value( "publisher" );
		$publisher_uri = &{$c->{rdf}->{org_uri}}( $eprint, $publisher_name );
		if( $publisher_uri )
		{
			push @{$o{triples}->{$publisher_uri}},
				[ $publisher_uri, "rdf:type", 	"foaf:Organization" ],
				[ $publisher_uri, "foaf:name", 	$publisher_name, "literal" ],
				[ $eprint_uri, "dct:publisher",	$publisher_uri ],
			;
		}
	}

	# Publication

	if( $eprint->dataset->has_field( "publication" ) && $eprint->is_set( "publication" ) )
	{
		my $publication_uri = &{$c->{rdf}->{publication_uri}}( $eprint );
		my $publication_name = $eprint->get_value( "publication" );
		if( $publication_uri )
		{
			push @{$o{triples}->{$publication_uri}},
				[ $publication_uri, "rdf:type", 	"foaf:Collection" ],
				[ $publication_uri, "foaf:name", 	$publication_name, "literal" ],
				[ $eprint_uri, "dct:isPartOf",	$publication_uri ],
			;
			if( $eprint->dataset->has_field( "issn" ) && $eprint->is_set( "issn" ))
			{
				my $issn = $eprint->get_value( "issn" );
				$issn =~ s/[^0-9X]//g;
				push @{$o{triples}->{$publication_uri}},
				[ $publication_uri, "owl:sameAs", "<urn:issn:$issn>" ];
			}
		}
	}


	# Status

	my @statuses= ();
	if( $eprint->dataset->has_field( "refereed" ) && $eprint->is_set( "refereed" ) )
	{
        	if( $eprint->get_value( "refereed" ) eq "TRUE" )
		{
			push @statuses, "peerReviewed";
		}
		else
		{
			push @statuses, "nonPeerReviewed";
		}
	}
	if( $eprint->dataset->has_field( "ispublished" ) && $eprint->is_set( "ispublished" ) )
	{
		my $ispub = $eprint->get_value( "ispublished" );
		if( $ispub eq "pub" ) { push @statuses, "published"; }
		if( $ispub eq "inpress" ) { push @statuses, "forthcoming"; }
		if( $ispub eq "unpub" ) { push @statuses, "unpublished"; }
	}
	foreach my $status ( @statuses )
	{
		push @{$o{triples}->{$eprint_uri}},
			[ $eprint_uri, "bibo:status", "<http://purl.org/ontology/bibo/status/$status>" ];
	}

} );


##############################
# Contributors
##############################

$c->add_trigger( "rdf_triples_eprint", sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};
	my $eprint_uri = "<".$eprint->uri.">";

	my $all_people = {};

	# authors

	my @creators;
	if( $eprint->dataset->has_field( "creators" ) && $eprint->is_set( "creators" ) )
	{
		@creators = @{$eprint->get_value( "creators" )};
	}
	my $authors_uri = "<".$eprint->uri."#authors>";
	for( my $i=1; $i<=@creators; ++$i )
	{
		my $creator_uri = &{$c->{rdf}->{person_uri}}( $eprint, $creators[$i-1] );
		push @{$o{triples}->{$creator_uri}},
			[ $eprint_uri,  "dct:creator", 		$creator_uri ],
			[ $eprint_uri,  "bibo:authorList", 	$authors_uri ],
			[ $authors_uri, "rdf:_$i", 		$creator_uri ],
		;
		$all_people->{$creator_uri} = $creators[$i-1];
	}

	# editors

	my @editors;
	if( $eprint->dataset->has_field( "editors" ) && $eprint->is_set( "editors" ) )
	{
		@editors = @{$eprint->get_value( "editors" )};
	}
	my $editors_uri = "<".$eprint->uri."#editors>";
	for( my $i=1; $i<=@editors; ++$i )
	{
		my $editor_uri = &{$c->{rdf}->{person_uri}}( $eprint, $editors[$i-1] );
		push @{$o{triples}->{$editor_uri}},
			[ $eprint_uri,  "<http://www.loc.gov/loc.terms/relators/EDT>", 		$editor_uri ],
			[ $eprint_uri,  "bibo:editorList", 	$editors_uri ],
			[ $editors_uri, "rdf:_$i", 		$editor_uri ],
		;
		$all_people->{$editor_uri} = $editors[$i-1];
	}

	# other contributors

	my @contributors;
	if( $eprint->dataset->has_field( "contributors" ) && $eprint->is_set( "contributors" ) )
	{
		@contributors = @{$eprint->get_value( "contributors" )};
	}
	foreach my $contributor ( @contributors )
	{
		my $contributor_uri = &{$c->{rdf}->{person_uri}}( $eprint, $contributor );
		push @{$o{triples}->{$contributor_uri}},
			[ $eprint_uri,  "<".$contributor->{type}.">", $contributor_uri ];
		$all_people->{$contributor_uri} = $contributor;
	}

	# Contributors names

	foreach my $person_uri ( keys %{$all_people} )
	{
		my $e_given = $all_people->{$person_uri}->{name}->{given} || "";
		my $e_family = $all_people->{$person_uri}->{name}->{family} || "";
		push @{$o{triples}->{$person_uri}},
			[ $person_uri, "rdf:type", 		"foaf:Person" ],
			[ $person_uri, "foaf:givenname", 	$e_given, "literal" ],
			[ $person_uri, "foaf:family_name", 	$e_family, "literal" ],
		;
	}

	# Corporate Creators
	my @corp_creators;
	if( $eprint->dataset->has_field( "corp_creators" ) && $eprint->is_set( "corp_creators" ) )
	{
		@corp_creators = @{$eprint->get_value( "corp_creators" )};
	}
	foreach my $corp_creator ( @corp_creators )
	{
		my $org_uri = &{$c->{rdf}->{org_uri}}( $eprint, $corp_creator );
		next unless $org_uri;
		push @{$o{triples}->{$org_uri}},
			[ $org_uri, "rdf:type", 	"foaf:Organization" ],
			[ $org_uri, "foaf:name", 	$corp_creator, "literal" ],
			[ $eprint_uri, "dct:creator", 	$org_uri ],
		;
	}
		
} );


##############################
# Event
##############################

$c->add_trigger( "rdf_triples_eprint", sub {
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
[ $event_uri,	"dct:title",		$event_title, "xsd:string" ],
;
	my $event_loc_uri = &{$c->{rdf}->{event_location_uri}}( $eprint );
	if( $event_loc_uri )
	{
		my $event_location = $eprint->get_value( "event_location" );
		push @{$o{triples}->{$event_uri}},
[ $event_uri, 	"event:place", 		$event_loc_uri ];

		push @{$o{triples}->{$event_loc_uri}},
[ $event_uri,	"rdf:type",		"event:Event" ],
[ $event_uri,	"event:place",		$event_loc_uri ],
[ $event_loc_uri,	"foaf:name",	$event_location, "xsd:string" ];
	}
} );

