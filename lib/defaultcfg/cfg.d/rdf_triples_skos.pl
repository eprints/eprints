

$c->{rdf}->{xmlns}->{skos} = "http://www.w3.org/2004/02/skos/core#";

$c->add_trigger( "rdf_triples_eprint", sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};
	my $eprint_uri = "<".$eprint->uri.">";

	return if ! $eprint->dataset->has_field( "subjects" );
	return if ! $eprint->is_set( "subjects" );
	
	my @triples;
	foreach my $subject_id ( @{$eprint->get_value( "subjects" )} )
	{
		my $subject = $o{repository}->dataset( "subject" )->dataobj( $subject_id );
		if( $subject )
		{
			my $subject_uri = "<".$subject->uri.">";
			push @triples, [ $subject_uri, "rdf:type", "skos:Concept" ];
			foreach my $name ( @{$subject->get_value( "name" )} )
			{
				push @triples, [ $subject_uri, "skos:prefLabel", $name->{name}, "literal", $name->{lang} ];
			}
			push @triples, [ $eprint_uri, "dct:subject", $subject_uri ];
		}
	}

	push @{$o{triples}->{$eprint_uri}}, @triples;
} );

$c->add_trigger( "rdf_triples_subject", sub {
	my( %o ) = @_;
	my $subject = $o{"subject"};
	my $uri = $subject->uri;
	my $subject_uri = "<$uri>";
	my $subject_prefix = substr( $uri, 0, length( $uri ) - length( $subject->id ) );

	my @triples;
	push @triples, [ $subject_uri, "rdf:type", "skos:Concept" ];
	foreach my $name ( @{$subject->get_value( "name" )} )
	{
		push @triples, [ $subject_uri, "skos:prefLabel", $name->{name}, "literal", $name->{lang} ];
	}

	foreach my $child ( $subject->get_children() )
	{
		push @triples, [ $subject_uri, "skos:narrower", "<".$subject_prefix.$child->id.">" ];
	}

	foreach my $parent_id ( @{$subject->get_value("parents")} )
	{
		if( $parent_id eq "ROOT" )
		{
			my $scheme_uri = "<$uri#scheme>";
			push @triples, [ $subject_uri, "skos:topConceptOf", $scheme_uri ];
			push @triples, [ $scheme_uri, "skos:hasTopConcept", $subject_uri ];
			push @triples, [ $scheme_uri, "rdf:type", "skos:ConceptScheme" ];
			foreach my $name ( @{$subject->get_value( "name" )} )
			{
				push @triples, [ $scheme_uri, "dct:title", $name->{name}, "literal", $name->{lang} ];
			}
		}
		else
		{
			push @triples, [ $subject_uri, "skos:broader", "<".$subject_prefix.$parent_id.">" ];
		}
	}

	push @{$o{triples}->{$subject_uri}}, @triples;
} );

