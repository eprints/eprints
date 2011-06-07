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

sub handler
{
	my( $r ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;

        my $langid = EPrints::Session::get_session_language( $repository, $r );
        my @static_dirs = $repository->get_static_dirs( $langid );
        my $sitemap;
        foreach my $static_dir ( @static_dirs )
        {
                my $file = "$static_dir/sitemap.xml";
                next if( !-e $file );

                open( SITEMAP, $file ) || EPrints::abort( "Can't read $file: $!" );
                $sitemap = join( "", <SITEMAP> );
                close SITEMAP;
                last;
        }

	if( defined $sitemap )
	{
	        binmode( *STDOUT, ":utf8" );
        	$repository->send_http_header( "content_type"=>"text/xml; charset=UTF-8" );
	        print $sitemap;
        	return DONE;
	}

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

       	# adds local sitemap URLs
	$repository->run_trigger( EPrints::Const::EP_TRIGGER_LOCAL_SITEMAP_URLS,
		urlset => $urlset,
	); 

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

