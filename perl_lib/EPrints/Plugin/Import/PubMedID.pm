=head1 NAME

EPrints::Plugin::Import::PubMedID

=cut

package EPrints::Plugin::Import::PubMedID;

use strict;

# Updated to use HTTPS, XML parser also needed updating as it doesnt support HTTPS.  Note that you must also have LWP::Protocol::https instaled.
# jb4/09nov2016

use EPrints::Plugin::Import;
use URI;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "PubMed ID";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	$self->{EFETCH_URL} = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml&rettype=full';

	return $self;
}

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my @ids;

	my $pubmedxml_plugin = $plugin->{session}->plugin( "Import::PubMedXML", Handler=>$plugin->handler );
	$pubmedxml_plugin->{parse_only} = $plugin->{parse_only};
	my $fh = $opts{fh};
	while( my $pmid = <$fh> )
	{
		$pmid =~ s/^\s+//;
		$pmid =~ s/\s+$//;
		if( $pmid !~ /^[0-9]+$/ ) # primary IDs are always an integer
		{
			$plugin->warning( "Invalid ID: $pmid" );
			next;
		}

		# Fetch metadata for individual PubMed ID 
		# NB. EFetch utility can be passed a list of PubMed IDs but
		# fails to return all available metadata if the list 
		# contains an invalid ID
		my $url = URI->new( $plugin->{EFETCH_URL} );
		$url->query_form( $url->query_form, id => $pmid );

		my $req = HTTP::Request->new("GET", $url);
		$req->header( "Accept" => "text/xml" );
		$req->header( "Accept-Charset" => "utf-8" );

		my $ua = LWP::UserAgent->new;
		my $resp = $ua->request( $req );

		if( $resp->code != 200 )
		{
			$plugin->warning( "Could not connect to remote site: $url (".$resp->code.")" );
			next;
		}

		my $parser = XML::LibXML->new();
		my $xml = $parser->parse_string( $resp->content );

		my $root = $xml->documentElement;

		if( $root->nodeName eq 'ERROR' )
		{
			EPrints::XML::dispose( $xml );
			$plugin->warning( "No match: $pmid" );
			next;
		}

		foreach my $article ($root->getElementsByTagName( "PubmedArticle" ))
		{
			my $item = $pubmedxml_plugin->xml_to_dataobj( $opts{dataset}, $article );
			if( defined $item )
			{
				push @ids, $item->get_id;
			}
		}

		EPrints::XML::dispose( $xml );
	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
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

