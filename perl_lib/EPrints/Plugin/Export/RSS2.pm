package EPrints::Plugin::Export::RSS2;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

use Unicode::String qw(latin1);
use Time::Local;

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "RSS 2.0";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "application/rss+xml";

	$self->{number_to_show} = 10;

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list}->reorder( "-datestamp" );

	my $session = $plugin->{session};

	my $response = $session->make_element( "rss",
		"version" => "2.0",
		"xmlns:content" => "http://purl.org/rss/1.0/modules/content/",
		"xmlns:dc" => "http://purl.org/dc/elements/1.1/" );

	my $channel = $session->make_element( "channel" );
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


	foreach my $eprint ( $list->get_records( 0, $plugin->{number_to_show} ) )
	{
		my $item = $session->make_element( "item" );
		
		my $datestamp = $eprint->get_value( "datestamp" );
		if( $datestamp =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/ )
		{
			my $time = timelocal( $6, $5, $4, $3, $2-1, $1 );
			$item->appendChild( $session->render_data_element(
				2,
				"pubDate",
				RFC822_time( $time ) ) );	
			
		}

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
			"guid",
			$eprint->get_url ) );
		$item->appendChild( $session->render_data_element(
			2,
			"description",
			EPrints::Utils::tree_to_utf8( $eprint->render_citation ) ) );
		
		$channel->appendChild( $item );		
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
	my( $time ) = @_;
	$time = time if( !defined $time );
	return( strftime( "%a, %d %b %Y %H:%M:%S %z", localtime( $time ) ) );
}

1;

