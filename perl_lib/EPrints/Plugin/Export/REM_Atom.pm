######################################################################
#
# EPrints::Plugin::Export::REM_Atom
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

B<EPrints::Plugin::Export::REM_Atom> - OAI_ORE Resource Map Export/Aggregation Plugin (Atom Serialisation).

=head1 DESCRIPTION

This export plugin is written to the early beta-1 specification of OAI-ORE 
(Open Access Initiative Object Reuse and Exchange). It exports a Resource Map 
containing aggregations each of which represent a single EPrint and it's related 
matadata. 

Related to an EPrint are all the documents this EPrint contains as well as a list 
of the possible representations and additional metadata available via ALL other 
export plugins. 

For ORE importers we have included the compulsary dcterms:conformsTo field in each objects
description. This provides the namespace which any metadata related to an EPrint is 
defined by.

This plugin serialises the Resource Map in Atom format.

=over 4

=cut

package EPrints::Plugin::Export::REM_Atom;

use EPrints::Plugin::Export::XMLFile;
@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;
	my $self = $class->SUPER::new( %opts );

	$self->{name} = "OAI-ORE Resource Map (Atom Format)";
	$self->{accept} = [ 'dataobj/eprint', 'list/eprint' ];
	$self->{visible} = "all";
	$self->{mimetype} = "application/atom+xml; charset=utf-8";

	$self->{xmlns} = "http://www.w3.org/2005/Atom";
	$self->{schemaLocation} = "http://exyus.com/xcs/tasklist/source/?f=put_atom.xsd";

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	
	my $part = "";
	
	my $r = [];

	my $xml = $plugin->_root;
	my $header = EPrints::XML::to_string( $xml );
	EPrints::XML::dispose( $xml );
	$header =~ s/(<\/\w+>)$//;
	my $footer = $1;

	$header = "<?xml version='1.0'?>\n\n$header";

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $header;
	}
	else
	{
		push @{$r}, $header;
	}

	$opts{list}->map(sub {
		my( $session, $dataset, $dataobj ) = @_;
		$part = $plugin->output_dataobj( $dataobj, multiple => 1, %opts );
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
		print {$opts{fh}} $footer;
	}
	else
	{
		push @{$r}, $footer;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $multiple = $opts{"multiple"};
	
	my $title = $dataobj->get_value( "title" );
	#my $lastmod = EPrints::Time::get_iso_timestamp()
	my $lastmod = $dataobj->get_value( "lastmod" );
	$lastmod =~ s/ /T/;
	$lastmod = $lastmod."Z";
	my $eprint_id = $dataobj->get_value( "eprintid" );
	my $eprint_rev = $dataobj->get_value( "rev_number" );
	my $eprint_url = $dataobj->get_url;
	my $resmap_url = $plugin->dataobj_export_url( $dataobj );
	my $session = $plugin->{session};
	my $base_url = $session->get_repository->get_conf("base_url");
	my $archive_id = $session->get_repository->get_id;
	my $archive_name = $session->phrase( "archive_name" );
	my $response = $session->make_doc_fragment;

	my $topcontent = $session->render_data_element(
		4,
		"id",
		"$resmap_url#aggregation"
	);
	$response->appendChild( $topcontent );
	
	my $sub_content = $session->make_element ("link",
		"href"=>"$resmap_url",
		"rel"=>"self",
		"type"=>"application/atom+xml"
	);
	
	$response->appendChild( $sub_content );
	
	$topcontent = $session->render_data_element(
		4,
		"updated",
		$lastmod
	);
	$response->appendChild( $topcontent );
	
	$sub_content = $session->render_data_element ( 
		4,
		"generator",
		$archive_name,
		url=>"$base_url"
	);

	$response->appendChild( $sub_content);
	

	$sub_content = $session->make_element ("category",
		"scheme"=>"http://www.openarchives.org/ore/terms/",
		"term"=>"http://www.openarchives.org/ore/terms/Aggregation",
		"label"=>"Aggregation"
	);

	$response->appendChild( $sub_content );
	
	$topcontent = $session->render_data_element(
		4,
		"title",
		$title
	);
	$response->appendChild( $topcontent );

	my $author = $session->make_element("author");	
	$topcontent = $session->render_data_element(
		4,
		"name",
		"$archive_id EPrints Repository @ $base_url"
	);
	$author->appendChild( $topcontent );
	$response->appendChild( $author );

	
	my $content = $session->make_element("entry");
	$sub_content = $session->render_data_element(
		4,
		"id",
		"http://oreproxy.org/r?what=$base_url/$eprint_id&where=$resmap_url#aggregation"
	);
	$content->appendChild( $sub_content );
	$sub_content = $session->make_element("link",
		"href"=>"$base_url/$eprint_id",
		"rel"=>"alternate",
		"type"=>"text/html"
	);
	$content->appendChild( $sub_content );
	$sub_content = $session->render_data_element(
		4,
		"title",
		"Splash Page for \"$title\" (text/html)"
	);
	$content->appendChild( $sub_content );
	$sub_content = $session->render_data_element(
		4,
		"updated",
		$lastmod
	);
	$content->appendChild( $sub_content );
	$sub_content = $session->make_element("category",
		"scheme"=>"info:eu-repo/semantics/",
		"term"=>"info:eu-repo/semantics/humanStartPage",
		"label"=>"humanStartPage"
	);
	$content->appendChild( $sub_content );
	$response->appendChild( $content );	
	my @docs = $dataobj->get_all_documents;
	foreach my $doc (@docs)
	{
		my $format = $doc->get_value("format");
		my $rev_number = $doc->get_value("rev_number");
		my %files = $doc->files;
		foreach my $key (keys %files)
		{
			my $fileurl = $doc->get_url($key);
			my $content = $session->make_element("entry");
			$sub_content = $session->render_data_element(
				4,
				"id",
				"http://oreproxy.org/r?what=$fileurl&where=$resmap_url#aggregation"
			);
			$content->appendChild( $sub_content );
			$sub_content = $session->make_element("link",
				"href"=>$fileurl,
				"rel"=>"alternate",
				"type"=>$format
 			);
			$content->appendChild( $sub_content );
			$sub_content = $session->render_data_element(
					4,
					"updated",
					$lastmod
					);
			$content->appendChild( $sub_content );
			$sub_content = $session->render_data_element(
				4,
				"title",
				"$title ($format)" 
			);
			$content->appendChild ( $sub_content );
			
			$response->appendChild( $content );	
		}

	}
	
	my $xml_node = $session->make_element("entry");
	my $sub_xml_node;

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
				$sub_content = $session->render_data_element(
					4,
					"id",
					"http://oreproxy.org/r?what=$url&where=$resmap_url#aggregation" 
				);
				$xml_node->appendChild ( $sub_content );
				my $dc_title = $plugin_temp->param("name") || "";
				my $dc_format = $plugin_temp->param("mimetype") || "";
				my $dc_conformsTo = $plugin_temp->param("xmlns") || "";
				my $schema_location = $plugin_temp->param("schemaLocation") || "";
			
				$sub_content = $session->make_element( "link",
					"href"=>$url,
					"rel"=>"alternate",
					"type"=>$dc_format
				);
				$xml_node->appendChild ( $sub_content );
				
				$sub_content = $session->render_data_element(
						4,
						"updated",
						$lastmod
						);
				$xml_node->appendChild( $sub_content );
				
				$sub_content = $session->render_data_element(
					4,
					"title",
					"$dc_title for Resource @ $base_url/$eprint_id ($dc_format)" 
				);
				$xml_node->appendChild ( $sub_content );
	
				my $additional = $session->make_element("rdf:Description",
					"rdf:about"=>"http://oreproxy.org/r?what=$url&where=$resmap_url#aggregation" );

				if ( $dc_title ne "" )
				{	
					$sub_content = $session->render_data_element(
						4,
						"dcterms:title",
						$dc_title
		 			);
					$additional->appendChild( $sub_content );
				}
			
				if ( $dc_format ne "" )		
				{
					$sub_content = $session->render_data_element(
						4,
						"dcterms:format",
						$dc_format
	 				);
					$additional->appendChild( $sub_content );
				}
			
				if ( $dc_conformsTo ne "" ) 
				{
					$sub_content = $session->render_data_element(
						4,
						"dcterms:conformsTo",
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
				 	$sub_xml_node = $additional;
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
				#$sub_xml_node->appendChild ( $sub_content );
				my $dc_title = $plugin_temp->param("name") || "";
				my $dc_format = $plugin_temp->param("mimetype") || "";
				my $dc_conformsTo = $plugin_temp->param("xmlns") || "";
				my $schema_location = $plugin_temp->param("schemaLocation") || "";

				my $additional = $session->make_element( "link",
						"rel"=>"alternate",
						"href"=>$url,
						"type"=>$dc_format
				);
				$xml_node->appendChild( $additional );

			}
		}
	}	
	$xml_node->appendChild( $sub_xml_node );	
	$response->appendChild( $xml_node );
	if( $multiple )
	{
		return $response;
	}
	else 
	{
		my $feed = $plugin->_root;
		$feed->appendChild( $response );
		return $feed;
	}
}

sub _root
{
	my( $self ) = @_;

	my $feed = $self->{session}->make_element( "feed",
			"xmlns"=>"http://www.w3.org/2005/Atom",
			"xmlns:rdf"=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#",
			"xmlns:rdfs"=>"http://www.w3.org/2000/01/rdf-schema#",
			"xmlns:ore"=>"http://www.openarchives.org/ore/terms/",
			"xmlns:dcterms"=>"http://purl.org/dc/terms/",
		);

	return $feed;
}

1;
