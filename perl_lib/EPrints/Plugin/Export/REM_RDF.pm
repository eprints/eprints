######################################################################
#
# EPrints::Plugin::Export::REM_RDF
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Plugin::Export::REM_RDF> - OAI ORE Resource Map Export/Aggregation Plugin.

=head1 DESCRIPTION

This export plugin is written to the early beta-1 specification of OAI-ORE 
(Open Access Initiative Object Reuse and Exchange). It exports a Resource Map 
containing aggregations each of which represent a single EPrint and it's related 
matadata. 

Related to an EPrint are all the documents this EPrint contains as well as a list 
of the possible representations and additional metadata available via ALL other 
export plugins. 

For ORE importers we have included the compulsary dc:conformsTo field in each objects
description. This provides the namespace which any metadata related to an EPrint is 
defined by.

This plugin serialises the Resource Map in RDF/XML format.
=over 4

=cut

package EPrints::Plugin::Export::REM_RDF;

use EPrints::Plugin::Export;
@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
        my( $class, %opts ) = @_;
	my $self = $class->SUPER::new( %opts );

        $self->{name} = "REM (RDF Format)";
        $self->{accept} = [ 'dataobj/eprint', 'list/eprint' ];
        $self->{visible} = "all";
        $self->{suffix} = ".xml";
        $self->{mimetype} = "application/rdf+xml; charset=utf-8";

	$self->{xmlns} = "http://www.openarchives.org/ore/terms/";

        return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	
	my $part = "";
	
	my $r = [];

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	$opts{list}->map(sub {
		my( $session, $dataset, $dataobj ) = @_;
		$part = $plugin->output_dataobj( $dataobj, single => 1, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	});

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
        my( $plugin, $dataobj, %opts ) = @_;

	my $single = $opts{"single"};
	
	my $title = $dataobj->get_value( "title" );
	my $lastmod = $dataobj->get_value( "lastmod" );
	my $eprint_id = $dataobj->get_value( "eprintid" );
	my $eprint_rev = $dataobj->get_value( "rev_number" );
	my $eprint_url = $dataobj->get_url;
	my $resmap_url = $plugin->dataobj_export_url( $dataobj );
	my $session = $plugin->{session};
	my $base_url = $session->get_repository->get_conf("base_url");
	my $archive_id = $session->get_repository->get_id;
	
	my $response = $session->make_doc_fragment;

	my $topcontent = $session->make_element( "rdf:Description",
		"rdf:about"=>"$resmap_url" );
	
	my $sub_content = $session->make_element ("rdf:type",
		"rdf:resource"=>"http://www.openarchives.org/ore/terms/ResourceMap" );
	
	$topcontent->appendChild( $sub_content );
	
	$sub_content = $session->render_data_element (
		4,
		"dc:modified",
		$lastmod,
		"rdf:datatype"=>"http://www.w3.org/2001/XMLSchema#dateTime" );

	$topcontent->appendChild( $sub_content);

	$sub_content = $session->make_element ("ore:describes",
		"rdf:resource"=>"$resmap_url#aggregation" );

	$topcontent->appendChild( $sub_content );
	
	my $aggregation = $session->make_element( "rdf:Description",
		"rdf:about"=>"$resmap_url#aggregation" );
	
	$response->appendChild( $topcontent );	
	$response->appendChild( $aggregation );

	my @docs = $dataobj->get_all_documents;
	foreach my $doc (@docs)
	{
		my $format = $doc->get_value("format");
		my $rev_number = $doc->get_value("rev_number");
		my %files = $doc->files;
		foreach my $key (keys %files)
		{
			my $fileurl = $doc->get_url($key);
			$sub_content = $session->make_element("ore:aggregates",
				"rdf:resource"=>"$fileurl" );
			$aggregation->appendChild ( $sub_content );
			my $additional = $session->make_element( "rdf:Description",
				"rdf:about"=>"$fileurl" );
			$sub_content = $session->render_data_element(
				4,
				"dc:format",
				$format
 			);
			$additional->appendChild( $sub_content );
		
			$sub_content = $session->render_data_element(
				4,
				"dc:hasVersion",
				$rev_number
			);
			$additional->appendChild( $sub_content );
			
			$response->appendChild( $additional );	
		}

	}
	
	my $xml_node;
	
	my @plugins = $session->plugin_list();
	foreach my $plugin_name (@plugins) 
	{
		my $url = "$base_url/cgi/export/$eprint_id/";
		my $string = substr($plugin_name,0,6);
		if ($string eq "Export") 
		{
			my $plugin_id = $plugin_name;
			$plugin_name = substr($plugin_id,8,length($plugin_id));
			my $plugin_temp = $session->plugin($plugin_id);
			my $plugin_suffix = $plugin_temp->param("suffix");
			my $uri =  $plugin_temp->local_uri();
			$uri =~ /Export/g;
			my $plugin_location = substr($uri,pos($uri)+1,length($uri));
			$url = $url."$plugin_location/$archive_id-eprint-$eprint_id$plugin_suffix";

			if ($plugin_name eq "XML") {
				$sub_content = $session->make_element("ore:aggregates",
					"rdf:resource"=>"$url" );
				$aggregation->appendChild ( $sub_content );
				my $dc_title = $plugin_temp->param("name") || "";
				my $dc_format = $plugin_temp->param("mimetype") || "";
				my $dc_conformsTo = $plugin_temp->param("xmlns") || "";
				my $schema_location = $plugin_temp->param("schemaLocation") || "";
			
				my $additional = $session->make_element( "rdf:Description",
					"rdf:about"=>"$url" );

				if ( $dc_title ne "" )
				{	
					$sub_content = $session->render_data_element(
						4,
						"dc:title",
						$dc_title
		 			);
					$additional->appendChild( $sub_content );
				}
			
				if ( $dc_format ne "" )		
				{
					$sub_content = $session->render_data_element(
						4,
						"dc:format",
						$dc_format
	 				);
					$additional->appendChild( $sub_content );
				}
			
				if ( $dc_conformsTo ne "" ) 
				{
					$sub_content = $session->render_data_element(
						4,
						"dc:conformsTo",
						$dc_conformsTo
 					);
					$additional->appendChild( $sub_content );
				}
			
				if ( $schema_location ne "") 
				{
					$sub_content = $session->render_data_element(
						4,
						"rdfs:comment",
						$schema_location
	 				);
					$additional->appendChild( $sub_content );
				}
				if ( $plugin_name eq "XML" ) {
				 	$xml_node = $additional;
				}
			
			}
		}
	}

	@plugins = $session->plugin_list();
	foreach my $plugin_name (@plugins) 
	{
		my $url = "$base_url/cgi/export/$eprint_id/";
		my $string = substr($plugin_name,0,6);
		if ($string eq "Export") 
		{
			my $plugin_id = $plugin_name;
			$plugin_name = substr($plugin_id,8,length($plugin_id));
			my $plugin_temp = $session->plugin($plugin_id);
			my $plugin_suffix = $plugin_temp->param("suffix");
			my $uri =  $plugin_temp->local_uri();
			$uri =~ /Export/g;
			my $plugin_location = substr($uri,pos($uri)+1,length($uri));
			$url = $url."$plugin_location/$archive_id-eprint-$eprint_id$plugin_suffix";

			if ($plugin_name eq "XML") {
			} else {
				$sub_content = $session->make_element("rdfs:seeAlso",
					"rdf:resource"=>"$url" );
				$xml_node->appendChild ( $sub_content );
				my $dc_title = $plugin_temp->param("name") || "";
				my $dc_format = $plugin_temp->param("mimetype") || "";
				my $dc_conformsTo = $plugin_temp->param("xmlns") || "";
				my $schema_location = $plugin_temp->param("schemaLocation") || "";

				my $additional = $session->make_element( "rdf:Description",
						"rdf:about"=>"$url" );

				if ( $dc_title ne "" )
				{	
					$sub_content = $session->render_data_element(
							4,
							"dc:title",
							$dc_title
							);
					$additional->appendChild( $sub_content );
				}

				if ( $dc_format ne "" )		
				{
					$sub_content = $session->render_data_element(
							4,
							"dc:format",
							$dc_format
							);
					$additional->appendChild( $sub_content );
				}

				if ( $dc_conformsTo ne "" ) 
				{
					$sub_content = $session->render_data_element(
							4,
							"dc:conformsTo",
							$dc_conformsTo
							);
					$additional->appendChild( $sub_content );
				}

				if ( $schema_location ne "") 
				{
					$sub_content = $session->render_data_element(
							4,
							"rdfs:comment",
							$schema_location
							);
					$additional->appendChild( $sub_content );
				}
				$response->appendChild( $additional );

			}
		}
	}	
	
	$response->appendChild( $xml_node );
	EPrints::XML::tidy( $response );

	my $resourceMap= EPrints::XML::to_string( $response );
	EPrints::XML::dispose( $response );
	
	if( $single )
	{
		return $resourceMap;
	}
	else 
	{
		return $plugin->rdf_header.$resourceMap.$plugin->rdf_footer;
	}

}

sub rdf_header
{
	return "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n\txmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"\n\txmlns:ore=\"http://www.openarchives.org/ore/terms/\"\n\txmlns:dc=\"http://purl.org/dc/terms/\">\n";
}

sub rdf_footer
{
	return "</rdf:RDF>";
}

1;
