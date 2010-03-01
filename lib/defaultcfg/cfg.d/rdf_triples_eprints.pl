
$c->{rdf}->{xmlns}->{ep} = "http://eprints.org/ontology/";
$c->{rdf}->{xmlns}->{eprel} = "http://eprints.org/relation/";

$c->{rdf}->{license_uri}->{cc_by_nd}	= "http://creativecommons.org/licenses/by-nd/3.0/";
$c->{rdf}->{license_uri}->{cc_by}	= "http://creativecommons.org/licenses/by/3.0/";
$c->{rdf}->{license_uri}->{cc_by_nc}	= "http://creativecommons.org/licenses/by-nc/3.0/";
$c->{rdf}->{license_uri}->{cc_by_nc_nd}	= "http://creativecommons.org/licenses/by-nc-nd/3.0/";
$c->{rdf}->{license_uri}->{cc_by_nc_sa}	= "http://creativecommons.org/licenses/by-nc-sa/3.0/";
$c->{rdf}->{license_uri}->{cc_by_sa}	= "http://creativecommons.org/licenses/by-sa/3.0/";
$c->{rdf}->{license_uri}->{cc_gnu_gpl}	= "http://creativecommons.org/licenses/GPL/2.0/";
$c->{rdf}->{license_uri}->{cc_gnu_lgpl}	= "http://creativecommons.org/licenses/LGPL/2.1/";
$c->{rdf}->{license_uri}->{cc_public_domain} = "http://creativecommons.org/licenses/publicdomain/";
$c->{rdf}->{license_uri}->{odc_odbl}    = "http://www.opendatacommons.org/licenses/odbl/";
$c->{rdf}->{license_uri}->{odc_by}      = "http://www.opendatacommons.org/licenses/by/";

$c->{rdf}->{content_rel_dc}->{draft} = "dc:hasVersion";
$c->{rdf}->{content_rel_dc}->{submitted} = "dc:hasVersion";
$c->{rdf}->{content_rel_dc}->{accepted} = "dc:hasVersion";
$c->{rdf}->{content_rel_dc}->{published} = "dc:hasVersion";
$c->{rdf}->{content_rel_dc}->{updated} = "dc:hasVersion";

$c->{rdf}->{content_rel_ep}->{draft} = "ep:hasDraft";
$c->{rdf}->{content_rel_ep}->{submitted} = "ep:hasSubmitted";
$c->{rdf}->{content_rel_ep}->{accepted} = "ep:hasAccepted";
$c->{rdf}->{content_rel_ep}->{published} = "ep:hasPublished";
$c->{rdf}->{content_rel_ep}->{updated} = "ep:hasUpdated";
$c->{rdf}->{content_rel_ep}->{supplemental} = "ep:hasSupplemental";
$c->{rdf}->{content_rel_ep}->{presentation} = "ep:hasPresentation";
$c->{rdf}->{content_rel_ep}->{coverimage} = "ep:hasCoverImage";
$c->{rdf}->{content_rel_ep}->{metadata} = "ep:hasMetadata";
$c->{rdf}->{content_rel_ep}->{other} = "ep:hasOther";

$c->add_trigger( "rdf_triples_eprint", sub {
	my( %o ) = @_;
	my $eprint = $o{"eprint"};
	my $eprint_uri = "<".$eprint->uri.">";

	##############################
	# Main Object 
	##############################

	my @triples;
	if( $eprint->is_set( "relation" ) )
	{
		foreach my $rel ( @{ $eprint->get_value( "relation" ) } )
		{
			my $uri = $rel->{uri};
			if( $uri =~ /^\// ) # local URI?
			{
				$uri = $c->{base_url}.$uri;
			}
			my $pred = $rel->{type};
			unless( $pred =~ s!^http://eprints.org/ontology/!ep:!
			     || $pred =~ s!^http://eprints.org/relation/!eprel:! )
			{
				$pred="<$pred>";
			}
			push @triples, [ $eprint_uri, $pred, "<$uri>" ];
		}
	}
	push @triples, [ $eprint_uri, "rdf:type", "ep:EPrint" ];
	push @triples, [ $eprint_uri, "dct:isPartOf", "<".$c->{base_url}."/id/repository>" ];
		
	DOC: foreach my $doc ( @{$eprint->get_value( "documents" )} )
	{
		my $doc_uri = "<".$doc->uri.">";

		push @triples, [ $eprint_uri, "ep:hasDocument", $doc_uri ];
		push @triples, [ $doc_uri, "rdf:type", "ep:Document" ];

		my $content = $doc->get_value( "content" );
		if( $content && $c->{rdf}->{content_rel_dc}->{$content} )
		{
			push @triples, [ $eprint_uri, $c->{rdf}->{content_rel_dc}->{$content}, $doc_uri ];
		}
		if( $content && $c->{rdf}->{content_rel_ep}->{$content} )
		{
			push @triples, [ $eprint_uri, $c->{rdf}->{content_rel_ep}->{$content}, $doc_uri ];
		}

		if( $doc->is_set( "relation" ) )
		{
			REL: foreach my $rel ( @{ $doc->get_value( "relation" ) } )
			{
				my $uri = $rel->{uri};
				next REL if !defined $uri;
				if( $uri =~ /^\// ) # local URI?
				{
					$uri = $c->{base_url}.$uri;
				}
				my $pred = $rel->{type};
				next REL if !defined $pred;
				unless( $pred =~ s!^http://eprints.org/ontology/!ep:!
			     	     || $pred =~ s!^http://eprints.org/relation/!eprel:! )
				{
					$pred="<$pred>";
				}
				push @triples, [ $doc_uri, $pred, "<$uri>" ];
			}
		}
	
		my $license_id = $doc->get_value("license");
		if( defined $license_id )
		{
			my $license_uri = $c->{rdf}->{license_uri}->{$doc->get_value("license")};
			if( defined $license_uri )
			{
				push @triples, [ $doc_uri, "cc:license", "<$license_uri>" ];
			}
		}

		if( $doc->is_public )
		{
			FILE: foreach my $file ( @{$doc->get_value( "files" )} )
			{
				my $url = $doc->get_url( $file->get_value( "filename" ) );
				push @triples, [ $doc_uri, "ep:hasFile", "<$url>" ];
				push @triples, [ $doc_uri, "dct:hasPart", "<$url>" ];
			}
		}
	}	

	push @{$o{triples}->{$eprint_uri}}, @triples;
} );

