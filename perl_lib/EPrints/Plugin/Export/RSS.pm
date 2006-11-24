package EPrints::Plugin::Export::RSS;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

use Unicode::String qw(latin1);

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

	$self->{number_to_show} = 10;

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list}->reorder( "-datestamp" );

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
		$session->get_repository->get_conf( "frontpage" ) ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"description", 
		$session->get_repository->get_conf( "oai","content","text" ) ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"pubDate", 
		RFC822_time() ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"lastBuildDate", 
		RFC822_time() ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"language", 
		$session->get_langid ) );

	$channel->appendChild( $session->render_data_element(
		4,
		"copyright", 
		"" ) );


	my $items = $session->make_element( "items" );
	$channel->appendChild( $items );
	my $seq = $session->make_element( "rdf:Seq" );
	$items->appendChild( $seq );

	foreach my $eprint ( $list->get_records( 0, $plugin->{number_to_show} ) )
	{
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
	}	

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

use POSIX qw(strftime);
sub RFC822_time
{
	return( strftime( "%a,  %d  %b  %Y  %H:%M:%S  %z",localtime ) );
}

1;

