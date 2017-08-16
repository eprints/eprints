=head1 NAME

EPrints::Apache::SiteMap

=cut

######################################################################
#
# EPrints::Apache::SiteMap
#
######################################################################
#
#
######################################################################

package EPrints::Apache::SiteMap;

use EPrints::Apache::AnApache; # exports apache constants

use strict;
use warnings;

#
# This handler has been heavily modified in order to support a static
# sitemap.xml file in addition to the semantic web crawling extensions
# provided by EPrints. The modified handler inserts the semantic web
# crawling extensions into the existing sitemap.xml if it exists, or
# creates a new document if it doesn't. The original handler is now in
# the _insert_semantic_web_extensions below.
#
# If the static sitemap XML is a sitemapindex, this handler inserts a
# new <sitemap> element into the index, which directs crawlers to a
# "sitemap-sc.xml" URL that contains the semantic web sitemap generated
# by _insert_semantic_web_extensions. This handler also implements the
# sitemap-sc.xml URL.
#
sub handler
{
	my( $r ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;
	my $xml = $repository->xml;
	my $sitemap;

	if ( $r->uri =~ m! sitemap-sc\.xml$ !x )
	{
		# this is a direct request for the semantic web extensions
		$sitemap = _new_urlset( $repository, $xml );
	}
	else
	{
		# get the static sitemap.xml
		my $langid = EPrints::Session::get_session_language( $repository, $r );
		my @static_dirs = $repository->get_static_dirs( $langid );
		foreach my $static_dir ( @static_dirs )
		{
			my $file = "$static_dir/sitemap.xml";
			next if( !-e $file );

			$sitemap = $xml->parse_file($file) || EPrints::abort( "Can't parse $file: $!" );
			last;
		}

		if( !defined $sitemap )
		{
			# no static sitemap file - create a new document
			$sitemap = _new_urlset( $repository, $xml );
		}
		elsif( $sitemap->documentElement->localname eq "urlset" )
		{
			# the static sitemap is a <urlset> - append the semantic web extensions to the end
			_insert_semantic_web_extensions($repository, $xml, $sitemap->documentElement);
		}
		elsif( $sitemap->documentElement->localname eq "sitemapindex" )
		{
			# the static sitemap is a <sitemapindex> - append a semantic web sitemap to the index
			my $sw_sitemap = $sitemap->createElement("sitemap");
			$sitemap->documentElement->appendChild($sw_sitemap);

			# append the location of the semantic web sitemap
			my $sw_loc = $sitemap->createElement("loc");
			$sw_sitemap->appendChild($sw_loc);
			$sw_loc->appendChild($sitemap->createTextNode($repository->config('http_url')."/sitemap-sc.xml"));
		}
	}

	# adds local sitemap URLs
	if( $sitemap->documentElement->localname eq "urlset" )
	{
		$repository->run_trigger( EPrints::Const::EP_TRIGGER_LOCAL_SITEMAP_URLS,
			urlset => $sitemap->documentElement,
		);
	} # TODO: else { call some other trigger, with the sitemapindex element }

	binmode( *STDOUT, ":utf8" );
	$repository->send_http_header( "content_type"=>"text/xml; charset=UTF-8" );
	print $xml->to_string( $sitemap );
	return DONE;
}

#
# Creates a new XML document containing a urlset populated
# by _insert_semantic_web_extensions
#
sub _new_urlset
{
	my( $repository, $xml ) = @_;

	my $document = $xml->make_document();
	my $urlset = $xml->create_element(
			"urlset",
			"xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9",
			"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
			"xsi:schemaLocation" => "http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd",
	);
	_insert_semantic_web_extensions( $repository, $xml, $urlset );
	$document->appendChild( $urlset );

	return $document;
}

#
# Insert the semantic web extensions as children of the element given as the
# third argument to the function. This function contains the body of the main
# handler shipped with EPrints 3.2.x
#
sub _insert_semantic_web_extensions
{
	my ( $repository, $xml, $urlset ) = @_;

	$urlset->setAttribute( "xmlns:sc" , "http://sw.deri.org/2007/07/sitemapextension/scschema.xsd" );

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
}

sub _create_data
{
	my( $xml, $name, $data, %attr ) = @_;

	my $node = $xml->create_element( $name, %attr );
	$node->appendChild( $xml->create_text_node( $data ));

	return $node;
}


1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

