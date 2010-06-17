package EPrints::Plugin::Export::RSS2;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

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
		"xmlns:dc" => "http://purl.org/dc/elements/1.1/",
		"xmlns:media" => "http://search.yahoo.com/mrss/" );

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

	if( $session->get_online )
	{
		$channel->appendChild( $session->render_data_element(
			4,
			"atom:link",
			"",
			"xmlns:atom"=>"http://www.w3.org/2005/Atom",
			"href" => $session->get_full_url,
			"type" => "application/rss+xml",
			"rel"  => "self" ) );
	}

	$channel->appendChild( $session->render_data_element(
		4,
		"description", 
		$session->get_repository->get_conf( "oai","content","text" ) ) );

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
				EPrints::Time::rfc822_datetime( $time ) ) );	
			
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
		$item->appendChild( $plugin->render_media_content( $eprint ) );
		
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

sub render_media_content
{
	my( $self, $dataobj ) = @_;

	if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
	{
		return $self->render_eprint_media_content( $dataobj );
	}
	elsif( $dataobj->isa( "EPrints::DataObj::Document" ) )
	{
		return $self->render_doc_media_content( $dataobj );
	}

	return $self->{session}->make_doc_fragment();
}

sub render_eprint_media_content
{
	my( $self, $dataobj ) = @_;

	my $session = $self->{session};

	if( $session->get_repository->can_call( "eprint_rss_media_doc" ) )
	{
		my $doc = $session->get_repository->call(
				"eprint_rss_media_doc",
				$dataobj,
				$self
			);

		if( !defined $doc )
		{
			return $session->make_doc_fragment;
		}

		return $self->render_doc_media_content( $doc );
	}
	else
	{
		my @docs = $dataobj->get_all_documents();

		foreach my $doc (@docs)
		{
			next unless $doc->is_public();
			my $media = $self->render_doc_media_content( $doc );
			return $media if $media->hasChildNodes;
		}

		return $session->make_doc_fragment;
	}
}

sub render_doc_media_content
{
	my( $self, $dataobj ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	my( $thumbnail ) = @{($dataobj->get_related_objects( EPrints::Utils::make_relation( "hassmallThumbnailVersion" ) ))};
	if( $thumbnail )
	{
		$frag->appendChild( $session->make_element( "media:thumbnail", 
			url => $thumbnail->get_url,
			type => $thumbnail->mime_type,
		) );
	}

	my( $preview ) = @{($dataobj->get_related_objects( EPrints::Utils::make_relation( "haspreviewThumbnailVersion" ) ))};
	if( $preview )
	{
		$frag->appendChild( $session->make_element( "media:content", 
			url => $preview->get_url,
			type => $preview->mime_type,
		) );
	}

	return $frag;
}

1;

