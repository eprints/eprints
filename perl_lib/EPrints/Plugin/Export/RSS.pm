=head1 NAME

EPrints::Plugin::Export::RSS

=cut

package EPrints::Plugin::Export::RSS;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "RSS 1.0";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".rss";
	$self->{mimetype} = "application/rss+xml";

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list};

	my $session = $plugin->{session};

	my $response = $session->make_element( "rdf:RDF",
		"xmlns:rdf"=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#",
		"xmlns"=>"http://purl.org/rss/1.0/" );

	my $channel = $session->make_element( "channel",
		"rdf:about"=>$session->get_full_url );
	$response->appendChild( $channel );

	my $title = $session->phrase( "archive_name" );

	$title.= ": ".EPrints::Utils::tree_to_utf8( $list->render_description );

	$channel->appendChild( $session->render_data_element(
		4,
		"title",
		$title ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"link",
		$session->config( "frontpage" ) ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"description", 
		$session->config( "oai","content","text" ) ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"pubDate", 
		EPrints::Time::rfc822_datetime() ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"lastBuildDate", 
		EPrints::Time::rfc822_datetime() ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"language", 
		$session->get_langid ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"copyright", 
		"" ) );

	$channel->appendChild( $session->make_text( "\n    " ) );
	
	my $items = $session->make_element( "items" );
	$channel->appendChild( $items );
	my $seq = $session->make_element( "rdf:Seq" );
	$items->appendChild( $seq );

	$list->map(sub {
		my( undef, undef, $eprint ) = @_;

		my $li = $session->make_element( "rdf:li",
			"rdf:resource"=>$eprint->get_url );
		$seq->appendChild( $li );

		my $item = $session->make_element( "item",
			"rdf:about"=>$eprint->get_url );

		$item->appendChild( $session->render_data_element(
			2,
			"title",
			EPrints::Utils::tree_to_utf8( $eprint->render_description ) ) );
		$item->appendChild( $session->render_data_element(
			2,
			"link",
			$eprint->get_url ) );
		$item->appendChild( $session->render_data_element(
			2,
			"description",
			EPrints::Utils::tree_to_utf8( $eprint->render_citation ) ) );
		$response->appendChild( $item );		
	});	

	my $rssfeed = <<END;
<?xml version="1.0" encoding="utf-8" ?>
END
	$rssfeed.= EPrints::XML::to_string( $response );
	EPrints::XML::dispose( $response );

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $rssfeed;
		return undef;
	} 

	return $rssfeed;
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

