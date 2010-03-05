
# These triples will be supplied to describe your repository. These are given
# if someone queries /id/repository.

# By default it uses some information from the oai.pl configuration to save 
# having to define it twice.

$c->{rdf}->{xmlns}->{void} = "http://rdfs.org/ns/void#";

$c->add_trigger( "rdf_triples_repository", sub {
	my( %o ) = @_;
	
	my @triples;
	my $repository_uri = "<".$o{repository}->config( "base_url" )."/id/repository>";

	my @eprint_ids = sort @{$o{repository}->dataset("archive")->get_item_ids( $o{repository} )};

	my $oai_config = $o{repository}->config( "oai" );

	push @triples, [ $repository_uri, "rdf:type", "ep:Repository" ];
	push @triples, [ $repository_uri, "dct:title", $o{repository}->phrase( "archive_name" ), "literal" ];
	push @triples, [ $repository_uri, "foaf:homepage", "<".$o{repository}->config( "base_url" )."/>" ];
	push @triples, [ $repository_uri, "ep:OAIPMH2", "<".$o{repository}->config( "base_url" )."/cgi/oai2>" ];


	# Do not use your homepage as your URL (one is an organisation, the other a webpage)
	# If you can't find anything better, use "http://yoursite.org/#org" 
	# push @triples, [ $repository_uri, "dct:rightsHolder", "<http://Your ORG URI>" ];
	# push @triples, [ $repository_uri, "dct:publisher", "<http://Your ORG URI>" ];

	# voID

	push @triples, [ $repository_uri, "rdf:type", "void:Dataset" ];
	push @triples, [ $repository_uri, "void:vocabulary", "<http://purl.org/dc/terms/>" ];
	if( @eprint_ids )
	{
		push @triples, [ $repository_uri, "void:exampleResource", "<".$o{repository}->config( "base_url" )."/id/eprint/".$eprint_ids[0].">" ];
	}
	my $xmlns = $o{repository}->config( "rdf","xmlns" );
	foreach my $nsid ( keys %{$xmlns} )
	{
		push @triples, [ $repository_uri, "void:vocabulary", "<".$xmlns->{$nsid}.">" ];
	}

	# Repository Description

	if( $oai_config->{content}->{text} )
	{
		push @triples, [ $repository_uri, "dct:description", $oai_config->{content}->{text}, "literal" ];
	}
	if( $oai_config->{content}->{url} )
	{
		push @triples, [ $repository_uri, "dct:description", "<".$oai_config->{content}->{url}.">" ];
	}

	# Rights
		
	if( $oai_config->{metadata_policy}->{text} )
	{
		push @triples, [ $repository_uri, "dc:rights", $oai_config->{metadata_policy}->{text}, "literal" ];
	}
	if( $oai_config->{metadata_policy}->{url} )
	{
		push @triples, [ $repository_uri, "dct:rights", "<".$oai_config->{metadata_policy}->{url}.">" ];
	}

	if( $oai_config->{data_policy}->{text} )
	{
		push @triples, [ $repository_uri, "dc:rights", $oai_config->{data_policy}->{text}, "literal" ];
	}
	if( $oai_config->{data_policy}->{url} )
	{
		push @triples, [ $repository_uri, "dct:rights", "<".$oai_config->{data_policy}->{url}.">" ];
	}

	if( $oai_config->{submission_policy}->{text} )
	{
		push @triples, [ $repository_uri, "dc:rights", $oai_config->{submission_policy}->{text}, "literal" ];
	}
	if( $oai_config->{submission_policy}->{url} )
	{
		push @triples, [ $repository_uri, "dct:rights", "<".$oai_config->{submission_policy}->{url}.">" ];
	}

	# Comments

	foreach my $comment ( @{ $oai_config->{comments} } )
	{
		push @triples, [ $repository_uri, "rdfs:comment", $comment, "literal" ];
	}

	foreach my $id ( sort @eprint_ids )
	{
		# Not loading the actual object as that would take a crazy-long time!
		push @triples, [ $repository_uri, "ep:hasEPrint", "<".$o{repository}->config( "base_url" )."/id/eprint/".$id.">" ];
	}

	my $root_subject = $o{repository}->dataset("subject")->dataobj("ROOT");
	foreach my $top_subject ( $root_subject->get_children )
	{
		push @triples, [ $repository_uri, "ep:hasConceptScheme", "<".$top_subject->uri."#scheme>" ];
	}


	push @{$o{triples}->{$repository_uri}}, @triples;
} );
