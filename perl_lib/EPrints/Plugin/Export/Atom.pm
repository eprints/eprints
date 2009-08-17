package EPrints::Plugin::Export::Atom;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Atom";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "application/atom+xml";

	$self->{number_to_show} = 10;

	return $self;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $list = $opts{list}->reorder( "-datestamp" );

	my $handle = $plugin->{handle};

	my $response = $handle->make_element( "feed",
		"xmlns"=>"http://www.w3.org/2005/Atom" );

	my $title = $handle->phrase( "archive_name" );

	$title.= ": ".EPrints::Utils::tree_to_utf8( $list->render_description );

	my $host = $handle->{repository}->get_conf( 'host' );

	$response->appendChild( $handle->render_data_element(
		4,
		"title",
		$title ) );

	$response->appendChild( $handle->render_data_element(
		4,
		"link",
		"",
		href => $handle->get_repository->get_conf( "frontpage" ) ) );
	
	$response->appendChild( $handle->render_data_element(
		4,
		"link",
		"",
		rel => "self",
		href => $handle->get_full_url ) );

	$response->appendChild( $handle->render_data_element(
		4,
		"updated", 
		EPrints::Time::get_iso_timestamp() ) );

	my( $sec,$min,$hour,$mday,$mon,$year ) = localtime;

	$response->appendChild( $handle->render_data_element(
		4,
		"id", 
		"tag:".$host.",".($year+1900).":feed:feed-title" ) );


	foreach my $eprint ( $list->get_records( 0, $plugin->{number_to_show} ) )
	{
		my $item = $handle->make_element( "entry" );
		
		$item->appendChild( $handle->render_data_element(
			2,
			"title",
			EPrints::Utils::tree_to_utf8( $eprint->render_description ) ) );
		$item->appendChild( $handle->render_data_element(
			2,
			"link",
			"",
			href => $eprint->get_url ) );
		$item->appendChild( $handle->render_data_element(
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
			print STDERR "Invalid date\n";
			$updated =  EPrints::Time::get_iso_timestamp();
		}
		
		$item->appendChild( $handle->render_data_element(
			2,
			"updated",
			$updated ) );	

		$item->appendChild( $handle->render_data_element(
			4,
			"id", 
			"tag:".$host.",".$eprint->get_value( "date" ).":item:/".$eprint->get_id ) );

		my $names = $eprint->get_value( "creators" );
		foreach my $name ( @$names )
		{
			my $author = $handle->make_element( "author" );
			
			my $name_str = EPrints::Utils::make_name_string( $name->{name}, 1 );
			$author->appendChild( $handle->render_data_element(
				4,
				"name",
				$name_str ) );
			$item->appendChild( $author );
		}

		$response->appendChild( $item );		
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

