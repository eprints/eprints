
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
	my $eprint = $o{"dataobj"};
	my $eprint_uri = "<".$eprint->uri.">";

	##############################
	# Main Object 
	##############################

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
			$o{graph}->add( 
				  subject => $eprint_uri,
				predicate => $pred,
				   object => "<$uri>" );
		}
	}
	$o{graph}->add( 
		  subject => $eprint_uri,
		predicate => "rdf:type",
		   object => "ep:EPrint" );
	if( $eprint->dataset->has_field( "type" ) && $eprint->is_set( "type" ) )
	{
		my $type = $eprint->get_value( "type" );
		$type = "\u$type";
		$type=~s/_([a-z])/\u$1/g;
		$o{graph}->add( 
		  	  subject => $eprint_uri,
			predicate => "rdf:type",
		   	   object => "ep:${type}EPrint" );
	}
	$o{graph}->add( 
	  	  subject => $eprint_uri,
		predicate => "dct:isPartOf",
	   	   object => "<".$c->{base_url}."/id/repository>" );
		
	DOC: foreach my $doc ( @{$eprint->get_value( "documents" )} )
	{
		my $doc_uri = "<".$doc->uri.">";

		$o{graph}->add( 
	  		  subject => $eprint_uri,
			predicate => "ep:hasDocument",
	   		   object => $doc_uri );
		$o{graph}->add( 
	  		  subject => $doc_uri,
			predicate => "rdf:type",
	   		   object => "ep:Document" );

		my $content = $doc->get_value( "content" );
		if( $content && $c->{rdf}->{content_rel_dc}->{$content} )
		{
			$o{graph}->add( 
	  			  subject => $eprint_uri,
				predicate => $c->{rdf}->{content_rel_dc}->{$content},
	   			   object => $doc_uri );
		}
		if( $content && $c->{rdf}->{content_rel_ep}->{$content} )
		{
			$o{graph}->add( 
	  			  subject => $eprint_uri,
				predicate => $c->{rdf}->{content_rel_ep}->{$content},
	   			   object => $doc_uri );
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
				$o{graph}->add( 
	  			  	  subject => $doc_uri,
					predicate => $pred,
	   			   	   object => "<$uri>" );
			}
		}
	
		my $license_id = $doc->get_value("license");
		if( defined $license_id )
		{
			my $license_uri = $c->{rdf}->{license_uri}->{$doc->get_value("license")};
			if( defined $license_uri )
			{
				$o{graph}->add( 
	  			  	  subject => $doc_uri,
					predicate => "cc:license",
	   			   	   object => "<$license_uri>" );
			}
		}

		if( $doc->is_public )
		{
			FILE: foreach my $file ( @{$doc->get_value( "files" )} )
			{
				my $url = $doc->get_url( $file->get_value( "filename" ) );
				$o{graph}->add( 
	  			  	  subject => $doc_uri,
					predicate => "ep:hasFile",
	   			   	   object => "<$url>" );
				$o{graph}->add( 
	  			  	  subject => $doc_uri,
					predicate => "dct:hasPart",
	   			   	   object => "<$url>" );
			}
		}
	}	

} );

