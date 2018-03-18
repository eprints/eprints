
$c->{rdf}->{xmlns}->{event} = "http://purl.org/NET/c4dm/event.owl#";
$c->{rdf}->{xmlns}->{bibo}  = "http://purl.org/ontology/bibo/";
$c->{rdf}->{xmlns}->{geo}   = "http://www.w3.org/2003/01/geo/wgs84_pos#";


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

$c->add_dataset_trigger( "eprint", EP_TRIGGER_RDF, sub {
	my( %o ) = @_;
	my $eprint = $o{"dataobj"};
	my $eprint_uri = "<".$eprint->uri.">";

	##############################
	# Main Object 
	##############################

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
			$o{"graph"}->add( 
				  subject => $eprint_uri,
				predicate => "rdf:type",
				   object => $bibo_type );	
		}
	}
	$o{"graph"}->add( 
		  subject => $eprint_uri,
		predicate => "rdf:type",
		   object => "bibo:Article" );
	if( $eprint->dataset->has_field( "title" ) && $eprint->is_set( "title" ) )
	{
		$o{"graph"}->add( 
			  subject => $eprint_uri,
			predicate => "dct:title",
			   object => $eprint->get_value( "title" ),
			     type => "xsd:string" );	
	}
	if( $eprint->dataset->has_field( "abstract" ) && $eprint->is_set( "abstract" ) )
	{
		$o{"graph"}->add( 
			  subject => $eprint_uri,
			predicate => "bibo:abstract",
			   object => $eprint->get_value( "abstract" ),
			     type => "xsd:string" );	
	}
	if( $eprint->dataset->has_field( "date" ) && $eprint->is_set( "date" ) )
	{
		$o{"graph"}->add( 
			  subject => $eprint_uri,
			predicate => "dct:date",
			   object => $eprint->get_value( "date" ),
			     type => "literal" );	# not xsd:date as can be just CCYY
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
		$o{"graph"}->add( 
			  subject => $doc_uri,
			predicate => "rdf:type",
			   object => $bibo_type );
	}

	# Thesis

	# can't do masters as bibo splits them into art/science and eprints does not.
	if( $type eq "thesis" )
	{
		if( $eprint->dataset->has_field( "thesis_type" ) && $eprint->is_set( "thesis_type" ) 
	 	 && $eprint->get_value( "thesis_type" ) eq "phd" )
		{
			$o{"graph"}->add(
				   subject => $eprint_uri,
				 predicate => "bibo:degree",
				    object => "<http://purl.org/ontology/bibo/degrees/phd>" );
		}
		if( $eprint->dataset->has_field( "institution" ) && $eprint->is_set( "institution" )  )
		{
			my $inst_name = $eprint->get_value( "institution" );
			my $inst_uri = &{$c->{rdf}->{org_uri}}( $eprint, $inst_name );
			if( $inst_uri )
			{
				$o{"graph"}->add(
				   	  subject => $inst_uri,
				 	predicate => "rdf:type",
				    	   object => "foaf:Organization",
					secondary_resource => $inst_uri );
				$o{"graph"}->add(
				   	  subject => $inst_uri,
				 	predicate => "foaf:name",
				    	   object => $inst_name,
					     type => "xsd:string",
					secondary_resource => $inst_uri );
				$o{"graph"}->add(
				   	  subject => $eprint_uri,
				 	predicate => "dct:issuer",
				    	   object => $inst_uri,
					secondary_resource => $inst_uri );
				if( $eprint->dataset->has_field( "department" ) && $eprint->is_set( "department" )  )
				{
					my $dept_name = $eprint->get_value( "department" ).", $inst_name";
					my $dept_uri = &{$c->{rdf}->{org_uri}}( $eprint, $dept_name );
					if( $dept_uri )
					{
						# added to the school/dept
						$o{"graph"}->add(
						   	  subject => $dept_uri,
						 	predicate => "rdf:type",
						    	   object => "foaf:Organization",
							secondary_resource => $dept_uri );
						$o{"graph"}->add(
						   	  subject => $dept_uri,
						 	predicate => "foaf:name",
						    	   object => $dept_name,
							     type => "xsd:string",
							secondary_resource => $dept_uri );
						$o{"graph"}->add(
						   	  subject => $dept_uri,
						 	predicate => "dct:isPartOf",
						    	   object => $inst_uri,
							secondary_resource => $dept_uri );
						$o{"graph"}->add(
						   	  subject => $eprint_uri,
						 	predicate => "dct:issuer",
						    	   object => $dept_uri,
							secondary_resource => $dept_uri );

						# added to the institution
						$o{"graph"}->add(
						   	  subject => $inst_uri,
						 	predicate => "dct:hasPart",
						    	   object => $dept_uri,
							secondary_resource => $inst_uri );
					}
				}
			}
		}
	}

	# DOI

	if( $eprint->dataset->has_field( "id_number" ) && $eprint->is_set( "id_number" ) )
	{
		my $doi = EPrints::DOI->parse( $eprint->get_value( "id_number" ) );
		if( $doi )
		{
			$o{"graph"}->add(
				  subject => $eprint_uri,
				predicate => "owl:sameAs",
				   object => "<$doi>" );
		}
	}

	# PageRange

	if( $eprint->dataset->has_field( "page_range" ) && $eprint->is_set( "page_range" ) )
	{
		my $page_range = $eprint->get_value( "page_range" );
		my( $start, $end ) = split( "-", $page_range );

		$o{"graph"}->add(
		   	  subject => $eprint_uri,
		 	predicate => "bibo:pageStart",
		    	   object => $start,
			     type => "literal" );
		$o{"graph"}->add(
		   	  subject => $eprint_uri,
		 	predicate => "bibo:pageEnd",
		    	   object => $end,
			     type => "literal" );
	}

	# Volume

	if( $eprint->dataset->has_field( "volume" ) && $eprint->is_set( "volume" ) )
	{
		$o{"graph"}->add(
		   	  subject => $eprint_uri,
		 	predicate => "bibo:volume",
		    	   object => $eprint->get_value( "volume" ),
			     type => "literal" );
	}

	# Issue Number

	if( $eprint->dataset->has_field( "number" ) && $eprint->is_set( "number" ) )
	{
		$o{"graph"}->add(
		   	  subject => $eprint_uri,
		 	predicate => "bibo:issue",
		    	   object => $eprint->get_value( "number" ),
			     type => "literal" );
	}

	# ISBN

	if( $eprint->dataset->has_field( "isbn" ) && $eprint->is_set( "isbn" ) )
	{
		my $isbn = $eprint->get_value( "isbn" );
		$isbn =~ s/[^0-9X]//g;
		if( $type eq "book" )
		{
			$o{"graph"}->add(
			   	  subject => $eprint_uri,
			 	predicate => "owl:sameAs",
			    	   object => "<urn:isbn:$isbn>" );
			$o{"graph"}->add(
			   	  subject => $eprint_uri,
			 	predicate => "bibo:isbn",
			    	   object => $isbn,
				     type => "literal" );
		}
		if( $type eq "book_chapter" )
		{
			$o{"graph"}->add(
			   	  subject => $eprint_uri,
			 	predicate => "dct:isPartOf",
			    	   object => "<urn:isbn:$isbn>" );
		}
		if( $eprint->dataset->has_field( "publisher" ) )
		{
			my $org_name = $eprint->get_value( "publisher" );
			my $org_uri = &{$c->{rdf}->{org_uri}}( $eprint, $org_name );
			if( $org_uri )
			{
				$o{"graph"}->add(
				   	  subject => $org_uri,
				 	predicate => "rdf:type",
				    	   object => "foaf:Organization",
					secondary_resource => $org_uri );
				$o{"graph"}->add(
				   	  subject => $org_uri,
				 	predicate => "foaf:name",
				    	   object => $org_name,
					     type => "xsd:string",
					secondary_resource => $org_uri );
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
			$o{"graph"}->add(
			   	  subject => $publisher_uri,
			 	predicate => "rdf:type",
			    	   object => "foaf:Organization",
				secondary_resource => $publisher_uri );
			$o{"graph"}->add(
			   	  subject => $publisher_uri,
			 	predicate => "foaf:name",
			    	   object => $publisher_name,
				     type => "xsd:string",
				secondary_resource => $publisher_uri );
			$o{"graph"}->add(
			   	  subject => $eprint_uri,
			 	predicate => "dct:publisher",
			    	   object => $publisher_uri,
				secondary_resource => $publisher_uri );
		}
	}

	# Publication

	if( $eprint->dataset->has_field( "publication" ) && $eprint->is_set( "publication" ) )
	{
		my $publication_uri = &{$c->{rdf}->{publication_uri}}( $eprint );
		if( $publication_uri )
		{
			$o{"graph"}->add(
			   	  subject => $publication_uri,
			 	predicate => "rdf:type",
			    	   object => "bibo:Collection",
				secondary_resource => $publication_uri );
			$o{"graph"}->add(
			   	  subject => $publication_uri,
			 	predicate => "foaf:name",
			    	   object => $eprint->get_value( "publication" ),
			    	     type => "xsd:string",
				secondary_resource => $publication_uri );
			$o{"graph"}->add(
			   	  subject => $eprint_uri,
			 	predicate => "dct:isPartOf",
			    	   object => $publication_uri,
				secondary_resource => $publication_uri );
			if( $eprint->dataset->has_field( "issn" ) && $eprint->is_set( "issn" ))
			{
				my $issn = $eprint->get_value( "issn" );
				$issn =~ s/[^0-9X]//g;
				$o{"graph"}->add(
				   	  subject => $publication_uri,
				 	predicate => "owl:sameAs",
				    	   object => "<urn:issn:$issn>",
					secondary_resource => $publication_uri );
				$o{"graph"}->add(
				   	  subject => $publication_uri,
				 	predicate => "bibo:issn",
				    	   object => $issn,
					     type => "literal",
					secondary_resource => $publication_uri );
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
		$o{"graph"}->add(
		   	  subject => $eprint_uri,
		 	predicate => "bibo:status",
		    	   object => "<http://purl.org/ontology/bibo/status/$status>" );
	}

} );


##############################
# Contributors
##############################

$c->add_dataset_trigger( "eprint", EP_TRIGGER_RDF, sub {
	my( %o ) = @_;
	my $eprint = $o{"dataobj"};
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

		$o{"graph"}->add(
			secondary_resource => $creator_uri,
		   	  subject => $eprint_uri,
		 	predicate => "dct:creator",
		    	   object => $creator_uri );
		$o{"graph"}->add(
			secondary_resource => $creator_uri,
		   	  subject => $eprint_uri,
		 	predicate => "bibo:authorList",
		    	   object => $authors_uri );
		$o{"graph"}->add(
			secondary_resource => $creator_uri,
		   	  subject => $authors_uri,
		 	predicate => "rdf:_$i",
		    	   object => $creator_uri );
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
		$o{"graph"}->add(
			secondary_resource => $editor_uri,
		   	  subject => $eprint_uri,
		 	predicate => "<http://www.loc.gov/loc.terms/relators/EDT>",
		    	   object => $editor_uri );
		$o{"graph"}->add(
			secondary_resource => $editor_uri,
		   	  subject => $eprint_uri,
		 	predicate => "bibo:editorList",
		    	   object => $editors_uri );
		$o{"graph"}->add(
			secondary_resource => $editor_uri,
		   	  subject => $editors_uri,
		 	predicate => "rdf:_$i",
		    	   object => $editor_uri );
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
		$o{"graph"}->add(
			secondary_resource => $contributor_uri,
		   	  subject => $eprint_uri,
		 	predicate => "<".$contributor->{type}.">",
		    	   object => $contributor_uri );
		$all_people->{$contributor_uri} = $contributor;
	}

	# Contributors names

	foreach my $person_uri ( keys %{$all_people} )
	{
		my $e_given = $all_people->{$person_uri}->{name}->{given} || "";
		my $e_family = $all_people->{$person_uri}->{name}->{family} || "";
		$o{"graph"}->add(
			secondary_resource => $person_uri,
		   	  subject => $person_uri,
		 	predicate => "rdf:type",
		    	   object => "foaf:Person" );
		$o{"graph"}->add(
			secondary_resource => $person_uri,
		   	  subject => $person_uri,
		 	predicate => "foaf:givenName",
		    	   object => $e_given,
			     type => "xsd:string" );
		$o{"graph"}->add(
			secondary_resource => $person_uri,
		   	  subject => $person_uri,
		 	predicate => "foaf:familyName",
		    	   object => $e_family,
			     type => "xsd:string" );
		$o{"graph"}->add(
			secondary_resource => $person_uri,
		   	  subject => $person_uri,
		 	predicate => "foaf:name",
		    	   object => "$e_given $e_family",
			     type => "xsd:string" );
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
		$o{"graph"}->add(
			secondary_resource => $org_uri,
		   	  subject => $org_uri,
		 	predicate => "rdf:type",
		    	   object => "foaf:Organization" );
		$o{"graph"}->add(
			secondary_resource => $org_uri,
		   	  subject => $org_uri,
		 	predicate => "foaf:name",
		    	   object => $corp_creator,
			     type => "xsd:string" );
		$o{"graph"}->add(
			secondary_resource => $org_uri,
		   	  subject => $eprint_uri,
		 	predicate => "dct:creator",
		    	   object => $org_uri );
	}
		
} );


##############################
# Event
##############################

$c->add_dataset_trigger( "eprint", EP_TRIGGER_RDF, sub {
	my( %o ) = @_;
	my $eprint = $o{"dataobj"};

	return () if( !$eprint->dataset->has_field( "type" ) );
	return () if( !$eprint->get_value( "type" ) eq "conference_item" );

	my $event_uri = &{$c->{rdf}->{event_uri}}( $eprint );
	return if !defined $event_uri;

	my $eprint_uri = "<".$eprint->uri.">";
	my $event_title = $eprint->get_value( "event_title" )||"";

	$o{"graph"}->add(
		secondary_resource => $event_uri,
	   	  subject => $eprint_uri,
	 	predicate => "rdf:type",
	    	   object => "bibo:Article" );
	$o{"graph"}->add(
		secondary_resource => $event_uri,
	   	  subject => $eprint_uri,
	 	predicate => "bibo:presentedAt",
	    	   object => $event_uri );
	$o{"graph"}->add(
		secondary_resource => $event_uri,
	   	  subject => $event_uri,
	 	predicate => "rdf:type",
	    	   object => "bibo:Conference" );
	$o{"graph"}->add(
		secondary_resource => $event_uri,
	   	  subject => $event_uri,
	 	predicate => "dct:title",
	    	   object => $event_title,
		     type => "xsd:string" );

	my $event_loc_uri = &{$c->{rdf}->{event_location_uri}}( $eprint );
	if( $event_loc_uri )
	{
		my $event_location = $eprint->get_value( "event_location" );
		$o{"graph"}->add(
			secondary_resource => $event_uri,
		   	  subject => $event_uri,
		 	predicate => "event:place",
		    	   object => $event_loc_uri );

		$o{"graph"}->add(
			secondary_resource => $event_loc_uri,
		   	  subject => $event_uri,
		 	predicate => "rdf:type",
		    	   object => "event:Event" );
		$o{"graph"}->add(
			secondary_resource => $event_loc_uri,
		   	  subject => $event_uri,
		 	predicate => "event:place",
		    	   object => $event_loc_uri );
		$o{"graph"}->add(
			secondary_resource => $event_loc_uri,
		   	  subject => $event_loc_uri,
		 	predicate => "rdf:type",
		    	   object => "geo:SpatialThing" );
		$o{"graph"}->add(
			secondary_resource => $event_loc_uri,
		   	  subject => $event_loc_uri,
		 	predicate => "rdfs:label",
		    	   object => $event_location,
			     type => "xsd:string" );
	}
} );

