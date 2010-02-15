
# These triples will be supplied to describe your repository. These are given
# if someone queries /id/repository.

# By default it uses some information from the oai.pl configuration to save 
# having to define it twice.

$c->add_trigger( "rdf_triples_repository", sub {
	my( %o ) = @_;
	
	my @l;
	my $repository_uri = "<".$o{repository}->config( "base_url" )."/id/repository>";

	my $oai_config = $o{repository}->config( "oai" );

	push @l, [ "<>", "dct:title", $o{repository}->phrase( "archive_name" ), "literal" ];
	push @l, [ "<>", "foaf:homepage", "<".$o{repository}->config( "base_url" )."/>" ];

	# push @l, [ "<>", "dct:rightsHolder", $o{repository}->phrase( "archive_name" ), "literal" ];

	# Repository Description

	if( $oai_config->{content}->{text} )
	{
		push @l, [ $repository_uri, "dct:description", $oai_config->{content}->{text}, "literal" ];
	}
	if( $oai_config->{content}->{url} )
	{
		push @l, [ $repository_uri, "dct:description", "<".$oai_config->{content}->{url}.">" ];
	}

	# Rights
		
	if( $oai_config->{metadata_policy}->{text} )
	{
		push @l, [ $repository_uri, "dct:rights", $oai_config->{metadata_policy}->{text}, "literal" ];
	}
	if( $oai_config->{metadata_policy}->{url} )
	{
		push @l, [ $repository_uri, "dct:rights", "<".$oai_config->{metadata_policy}->{url}.">" ];
	}

	if( $oai_config->{data_policy}->{text} )
	{
		push @l, [ $repository_uri, "dct:rights", $oai_config->{data_policy}->{text}, "literal" ];
	}
	if( $oai_config->{data_policy}->{url} )
	{
		push @l, [ $repository_uri, "dct:rights", "<".$oai_config->{data_policy}->{url}.">" ];
	}

	if( $oai_config->{submission_policy}->{text} )
	{
		push @l, [ $repository_uri, "dct:rights", $oai_config->{submission_policy}->{text}, "literal" ];
	}
	if( $oai_config->{submission_policy}->{url} )
	{
		push @l, [ $repository_uri, "dct:rights", "<".$oai_config->{submission_policy}->{url}.">" ];
	}

	# Comments

	foreach my $comment ( @{ $oai_config->{comments} } )
	{
		push @l, [ $repository_uri, "rdfs:comment", "The repository adminiatrator has not yet configured an RDF policy.", "literal" ];
	}

	foreach my $id ( sort @{$o{repository}->dataset("eprint")->get_item_ids( $o{repository} )} )
	{
		# Not loading the actual object as that would take a crazy-long time!
		push @l, [ $repository_uri, "ep:hasEPrint", "<".$o{repository}->config( "base_url" )."/id/eprint/".$id.">" ];
	}

	my $root_subject = $o{repository}->dataset("subject")->dataobj("ROOT");
	foreach my $top_subject ( $root_subject->get_children )
	{
		push @l, [ $repository_uri, "ep:hasConceptScheme", "<".$top_subject->uri."#scheme>" ];
	}


	push @{$o{triples}->{$repository_uri}}, @l;
} );
