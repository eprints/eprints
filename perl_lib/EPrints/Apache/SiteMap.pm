######################################################################
#
# EPrints::Apache::SiteMap
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Apache::SiteMap;

use EPrints::Apache::AnApache; # exports apache constants

use strict;
use warnings;

sub handler
{
	my( $r ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;
	my $xml = $repository->xml;

	my $urlset = $xml->create_element( "urlset", 
		xmlns => "http://www.sitemaps.org/schemas/sitemap/0.9",
		"xmlns:sc" => "http://sw.deri.org/2007/07/sitemapextension/scschema.xsd" );
	my $sc_dataset = $xml->create_element( "sc:dataset" );

	$urlset->appendChild( $sc_dataset );	
	$sc_dataset->appendChild( _create_data( $xml,
		"sc:linkedDataPrefix",
		$repository->config( 'http_url' )."/id/",
		slicing => "subject-object", ));
	$sc_dataset->appendChild( _create_data( $xml,
		"sc:datasetURI",
		$repository->config( 'http_url' )."/id/repository" ));
	
	
	$sc_dataset->appendChild( _create_data( $xml,
		"sc:dataDumpLocation",
		$repository->config( 'http_url' )."/id/repository" ));
	$sc_dataset->appendChild( _create_data( $xml,
		"sc:dataDumpLocation",
		$repository->config( 'http_url' )."/id/dump" ));

	my $root_subject = $repository->dataset("subject")->dataobj("ROOT");
	foreach my $top_subject ( $root_subject->get_children )
	{
		$sc_dataset->appendChild( _create_data( $xml,
			"sc:dataDumpLocation",
			$top_subject->uri ) );
	}


	binmode( *STDOUT, ":utf8" );
	$repository->send_http_header( "content_type"=>"text/xml; charset=UTF-8" );
	print "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
	print $xml->to_string( $urlset );

	return DONE;
}

sub _create_data
{
	my( $xml, $name, $data, %attr ) = @_;

	my $node = $xml->create_element( $name, %attr );
	$node->appendChild( $xml->create_text_node( $data ));

	return $node;
}


1;
