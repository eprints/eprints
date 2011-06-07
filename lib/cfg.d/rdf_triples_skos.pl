

$c->{rdf}->{xmlns}->{skos} = "http://www.w3.org/2004/02/skos/core#";

$c->add_dataset_trigger( "eprint", EP_TRIGGER_RDF, sub {
	my( %o ) = @_;
	my $eprint = $o{"dataobj"};
	my $eprint_uri = "<".$eprint->uri.">";

	return if ! $eprint->dataset->has_field( "subjects" );
	return if ! $eprint->is_set( "subjects" );
	
	foreach my $subject_id ( @{$eprint->get_value( "subjects" )} )
	{
		my $subject = $o{repository}->dataset( "subject" )->dataobj( $subject_id );
		if( $subject )
		{
			my $subject_uri = "<".$subject->uri.">";
			$o{graph}->add( 
				subject => $subject_uri,
				predicate => "rdf:type",
				object => "skos:Concept" );
			foreach my $name ( @{$subject->get_value( "name" )} )
			{
				$o{graph}->add( 
					subject => $subject_uri,
					predicate => "skos:prefLabel",
					object => $name->{name},
					type => "literal",
					lang => $name->{lang} );
			}
			$o{graph}->add( 
				subject => $eprint_uri,
				predicate => "dct:subject",
				object => $subject_uri );
		}
	}

} );

$c->add_dataset_trigger( "subject", EP_TRIGGER_RDF, sub {
	my( %o ) = @_;
	my $subject = $o{"dataobj"};
	my $uri = $subject->uri;
	my $subject_uri = "<$uri>";
	my $subject_prefix = substr( $uri, 0, length( $uri ) - length( $subject->id ) );

	$o{graph}->add( 
		subject => $subject_uri,
		predicate => "rdf:type",
		object => "skos:Concept" );
	foreach my $name ( @{$subject->get_value( "name" )} )
	{
		$o{graph}->add( 
			subject => $subject_uri,
			predicate => "skos:prefLabel",
			object => $name->{name},
			type => "literal",
			lang => $name->{lang} );
	}

	foreach my $child ( $subject->get_children() )
	{
		$o{graph}->add( 
			subject => $subject_uri,
			predicate => "skos:narrower",
			object => "<".$subject_prefix.$child->id.">" );
	}

	foreach my $parent_id ( @{$subject->get_value("parents")} )
	{
		if( $parent_id eq "ROOT" )
		{
			my $scheme_uri = "<$uri#scheme>";
			$o{graph}->add( 
				subject => $subject_uri,
				predicate => "skos:topConceptOf",
				object => $scheme_uri );
			$o{graph}->add( 
				subject => $scheme_uri,
				predicate => "skos:hasTopConcept",
				object => $subject_uri );
			$o{graph}->add( 
				subject => $scheme_uri,
				predicate => "rdf:type",
				object => "skos:ConceptScheme" );
			foreach my $name ( @{$subject->get_value( "name" )} )
			{
				$o{graph}->add( 
					subject => $scheme_uri,
					predicate => "dct:title",
					object => $name->{name},
					type => "literal",
					lang => $name->{lang} );
			}
		}
		else
		{
			$o{graph}->add( 
				subject => $subject_uri,
				predicate => "skos:broader",
				object => "<".$subject_prefix.$parent_id.">" );
		}
	}

} );

