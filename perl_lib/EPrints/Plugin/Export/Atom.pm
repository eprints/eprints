package EPrints::Plugin::Export::Atom;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Atom";
	$self->{accept} = [ 'list/eprint', 'list/document', 'list/file' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "application/atom+xml";

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list};
	my $list_dataset = $list->{dataset};
	my $list_dataset_id = $list_dataset->id;

	my $session = $plugin->{session};

	my $response = $session->make_element( "feed",
		"xmlns"=>"http://www.w3.org/2005/Atom" );
	
	my $title = $session->phrase( "archive_name" );

	$title.= ": ".EPrints::Utils::tree_to_utf8( $list->render_description );

	my $host = $session->config( 'host' );

	$response->appendChild( $session->render_data_element(
		4,
		"title",
		$title ) );
	
	$response->appendChild( $session->render_data_element(
		4,
		"link",
		"",
		href => $session->get_repository->get_conf( "frontpage" ) ) );
	
	$response->appendChild( $session->render_data_element(
		4,
		"updated", 
		EPrints::Time::get_iso_timestamp() ) );

	my( $sec,$min,$hour,$mday,$mon,$year ) = localtime;

	$response->appendChild( $session->render_data_element(
		4,
		"id", 
		$session->get_repository->get_conf( "frontpage" ) ) );

	if ($list_dataset_id eq "file") {
		$list->map(sub {
				my( undef, undef, $file ) = @_;
				my $doc = $file->parent();

				my $item = $session->make_element( "entry" );
				
				$item->appendChild( $session->render_data_element(
						2,
						"id",
						$file->uri ) );
				$item->appendChild( $session->render_data_element(
						2,
						"title",
						$file->get_value("filename") ) );
				$item->appendChild( $session->render_data_element(
						2,
						"link",
						"",
						href => $doc->get_url( $file->get_value( "filename" ) ) ) );
				$response->appendChild( $item );		
		});	
	} elsif ($list_dataset_id eq "document") {
		$list->map(sub {
				my( undef, undef, $document ) = @_;

				my $item = $session->make_element( "entry" );
				
				$item->appendChild( $session->render_data_element(
						2,
						"id",
						$document->uri ) );
				$item->appendChild( $session->render_data_element(
						2,
						"title",
						EPrints::Utils::tree_to_utf8( $document->render_description ) ) );
				$item->appendChild( $session->render_data_element(
						2,
						"link",
						"",
						href => $document->get_url ) );
				$item->appendChild( $session->render_data_element(
						2,
						"summary",
						EPrints::Utils::tree_to_utf8( $document->render_citation ) ) );

				$response->appendChild( $item );		
		});		
	} elsif ($list_dataset_id eq "eprint")  {
		$list->map(sub {
				my( undef, undef, $eprint ) = @_;
				my $item = $session->make_element( "entry" );

				$item->appendChild( $session->render_data_element(
						2,
						"title",
						EPrints::Utils::tree_to_utf8( $eprint->render_description ) ) );
				$item->appendChild( $session->render_data_element(
						2,
						"link",
						"",
						href => $eprint->uri ) );
				$item->appendChild( $session->render_data_element(
						2,
						"summary",
						EPrints::Utils::tree_to_utf8( $eprint->render_citation ) ) );

				my $updated;
				my $datestamp = $eprint->get_value( "datestamp" );
				if( $datestamp =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})$/ )
				{
					$updated = "$1T$2Z";
				}
				else
				{
					$updated =  EPrints::Time::get_iso_timestamp();
				}

				$item->appendChild( $session->render_data_element(
							2,
							"updated",
							$updated ) );	

				$item->appendChild( $session->render_data_element(
							4,
							"id", 
							$eprint->uri ) );

				if( $eprint->exists_and_set( "creators" ) )
				{
					my $names = $eprint->get_value( "creators" );
					foreach my $name ( @$names )
					{
						my $author = $session->make_element( "author" );

						my $name_str = EPrints::Utils::make_name_string( $name->{name}, 1 );
						$author->appendChild( $session->render_data_element(
									4,
									"name",
									$name_str ) );
						$item->appendChild( $author );
					}
				}

				$response->appendChild( $item );		
		});	
	}

	my $atomfeed = <<END;
<?xml version="1.0" encoding="utf-8" ?>
END
	$atomfeed.= EPrints::XML::to_string( $response );
	EPrints::XML::dispose( $response );

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $atomfeed;
		return undef;
	} 

	return $atomfeed;
}

1;

