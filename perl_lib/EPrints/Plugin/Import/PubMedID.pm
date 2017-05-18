=head1 NAME

EPrints::Plugin::Import::PubMedID

=cut

package EPrints::Plugin::Import::PubMedID;

use strict;


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

		# EPrints::XML::parse_url() does not support HTTPS URLs
		# c.f. http://mailman.ecs.soton.ac.uk/pipermail/eprints-tech/2016-November/006070.html
		#my $xml = EPrints::XML::parse_url( $url );
		# TODO: revert this workaround when EPrints::XML::parse_url() works
		# c.f. http://mailman.ecs.soton.ac.uk/pipermail/eprints-tech/2016-November/006071.html
		my $xml = $plugin->_get_pubmed_data( $pmid );
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

# from https://github.com/eprintsug/PubMedID-Import/blob/617b21e276c110507900d8b22554367b88513042/perl_lib/EPrints/Plugin/Import/PubMedID.pm#L256-L307
# TODO: Remove when EPrints::XML::parse_url() works with HTTPS URLs
sub _get_pubmed_data
{
	my ( $plugin, $pmid ) = @_;
	
	my $xml;
	my $response;
	
	my $parser = XML::LibXML->new();
	$parser->validation(0);
	
	my $host = $plugin->{session}->get_repository->config( 'host ');
	my $request_retry = 3;
	my $request_delay = 10;
	
	my $url = URI->new( $plugin->{EFETCH_URL} );
	$url->query_form( $url->query_form, id => $pmid );
	
	my $req = HTTP::Request->new( "GET", $url );
	$req->header( "Accept" => "text/xml" );
	$req->header( "Accept-Charset" => "utf-8" );
	$req->header( "User-Agent" => "EPrints 3.3.x; " . $host  );
	
	my $request_counter = 1;
	my $success = 0;
	
	while (!$success && $request_counter <= $request_retry)
	{
		my $ua = LWP::UserAgent->new;
		$ua->env_proxy;
		$ua->timeout(60);
		$response = $ua->request($req);
		$success = $response->is_success;
		$request_counter++;
		sleep $request_delay if !$success;
	}

	if ( $response->code != 200 )
	{
		print STDERR "HTTP status " . $response->code .  " from ncbi.nlm.nih.gov for PubMed ID $pmid\n";
	}
	
	if (!$success)
	{	
		$xml = $parser->parse_string( '<?xml version="1.0" ?><eFetchResult><ERROR>' . $response->code . '</ERROR></eFetchResult>' );
	}
	else
	{
		$xml = $parser->parse_string( $response->content );
	}
	
	return $xml;
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

