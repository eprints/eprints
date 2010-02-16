
# These triples will be supplied to describe your repository. These are given
# if someone queries /id/repository.

# By default it uses some information from the oai.pl configuration to save 
# having to define it twice.

$c->add_trigger( "rdf_triples_repository", sub {
	my( %o ) = @_;
	
	my @triples;
	my $repository_uri = "<".$o{repository}->config( "base_url" )."/id/repository>";

	my $oai_config = $o{repository}->config( "oai" );

	push @triples, [ $repository_uri, "rdf:type", "ep:Repository" ];
	push @triples, [ $repository_uri, "dct:title", $o{repository}->phrase( "archive_name" ), "literal" ];
	push @triples, [ $repository_uri, "foaf:homepage", "<".$o{repository}->config( "base_url" )."/>" ];

	# push @triples, [ $repository_uri, "dct:rightsHolder", $o{repository}->phrase( "archive_name" ), "literal" ];

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
		push @triples, [ $repository_uri, "dct:rights", $oai_config->{metadata_policy}->{text}, "literal" ];
	}
	if( $oai_config->{metadata_policy}->{url} )
	{
		push @triples, [ $repository_uri, "dct:rights", "<".$oai_config->{metadata_policy}->{url}.">" ];
	}

	if( $oai_config->{data_policy}->{text} )
	{
		push @triples, [ $repository_uri, "dct:rights", $oai_config->{data_policy}->{text}, "literal" ];
	}
	if( $oai_config->{data_policy}->{url} )
	{
		push @triples, [ $repository_uri, "dct:rights", "<".$oai_config->{data_policy}->{url}.">" ];
	}

	if( $oai_config->{submission_policy}->{text} )
	{
		push @triples, [ $repository_uri, "dct:rights", $oai_config->{submission_policy}->{text}, "literal" ];
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

	foreach my $id ( sort @{$o{repository}->dataset("archive")->get_item_ids( $o{repository} )} )
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
