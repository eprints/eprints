package EPrints::Plugin::Export::Atom;

use EPrints::Plugin::Export::Feed;

@ISA = ( "EPrints::Plugin::Export::Feed" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Atom";
	$self->{accept} = [qw(
		list/eprint dataobj/eprint
		list/document dataobj/document
		list/file dataobj/file
	)];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "application/atom+xml";

	return $self;
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $r = '';
	my $f = defined($opts{fh}) ?
		sub { print {$opts{fh}} "$_[0]\n" } :
		sub { $r .= "$_[0]\n" };
	my $fx = sub { &$f( $xml->to_string( $_[0] ) ); $xml->dispose( $_[0] ); };

	my $list = $opts{list};
	my $dataset = $list->{dataset};
	my $dataset_id = $dataset->base_id;

	&$f( '<?xml version="1.0" encoding="utf-8" ?>' );
	&$f( '<feed xmlns="http://www.w3.org/2005/Atom" xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1">' );
	
	# title
	my $title = $repo->phrase( "archive_name" );
	$title.= ": ".$xhtml->to_text_dump( $list->render_description );
	&$fx( $xml->create_data_element(
		"title",
		$title ) );

	# self link
	if( exists $opts{link_self} )
	{
		&$fx( $xml->create_data_element(
			"link",
			undef,
			rel => "self",
			href => $opts{link_self} ) );
	}

	# front-page link
	&$fx( $xml->create_data_element(
		"link",
		undef,
		rel => "alternate",
		href => $repo->config( "frontpage" ) ) );
	
	# feed last-update
	&$fx( $xml->create_data_element(
		"updated", 
		EPrints::Time::get_iso_timestamp() ) );

	# feed generator
	&$fx( $xml->create_data_element(
		"generator",
		"EPrints",
		uri => "http://www.eprints.org/",
		version => EPrints->human_version ) );

	# feed logo
	my $site_logo = $self->param( "logo" ) || $repo->config( "site_logo" );
	$site_logo = URI->new_abs( $site_logo, $repo->current_url( host => 1, path => 'static' ) );
	&$fx( $xml->create_data_element(
		"logo",
		$site_logo ) );

	# feed id
	&$fx( $xml->create_data_element(
		"id", 
		$repo->config( "frontpage" ) ) );

	# opensearch
	local $_;
	for(qw( totalResults itemsPerPage startIndex ))
	{
		if( exists $opts{$_} )
		{
			&$fx( $xml->create_data_element(
				"opensearch:$_",
				$opts{$_}
				) );
		}
	}
	if( exists $opts{offsets} )
	{
		foreach my $key (sort keys %{$opts{offsets}})
		{
			&$fx( $xml->create_data_element(
				"link",
				undef,
				rel => $key,
				type => $self->param( "mimetype" ),
				href => $opts{offsets}->{$key} ) );
		}
	}

	# entries
	my $fn = "output_$dataset_id";
	$list->map(sub {
		my( undef, undef, $dataobj ) = @_;

		&$f( $self->$fn( $dataobj, %opts ) );
	});

	&$f( '</feed>' );

	return $r;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $dataset_id = $dataobj->get_dataset_id;
	my $fn = "output_$dataset_id";

	return $self->$fn( $dataobj, %opts );
}

sub output_eprint
{
	my( $self, $dataobj, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $entry = $xml->create_element( "entry" );

	$entry->appendChild( $xml->create_data_element(
			"title",
			$xhtml->to_text_dump( $dataobj->render_description ) ) );
	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "self",
			href => $self->dataobj_export_url( $dataobj ) ) );
	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "contents",
			href => $dataobj->uri . "/contents" ) );
	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "alternate",
			href => $dataobj->uri ) );
	$entry->appendChild( $xml->create_data_element(
			"summary",
			$xhtml->to_text_dump( $dataobj->render_citation ) ) );

	my $updated;
	my $datestamp = $dataobj->get_value( "datestamp" );
	if( $datestamp =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})$/ )
	{
		$updated = "$1T$2Z";
	}
	else
	{
		$updated =  EPrints::Time::get_iso_timestamp();
	}

	$entry->appendChild( $xml->create_data_element(
				"updated",
				$updated ) );	

	$entry->appendChild( $xml->create_data_element(
				"id", 
				$dataobj->uri ) );

	$entry->appendChild( $xml->create_data_element(
		"category",
		undef,
		term => $dataobj->value( "type" ),
		scheme => $repo->config( "base_url" )."/data/eprint#type"
	) );

	if( $dataobj->exists_and_set( "creators" ) )
	{
		my $names = $dataobj->get_value( "creators" );
		foreach my $name ( @$names )
		{
			my $author = $xml->create_element( "author" );

			my $name_str = EPrints::Utils::make_name_string( $name->{name}, 1 );
			$author->appendChild( $xml->create_data_element(
						"name",
						$name_str ) );
			$entry->appendChild( $author );
		}
	}

	my $r = $xml->to_string( $entry, indent => 1 );
	$xml->dispose( $entry );

	return $r;
}

sub output_document
{
	my( $self, $dataobj, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $entry = $xml->create_element( "entry" );
	
	$entry->appendChild( $xml->create_data_element(
			"id",
			$dataobj->uri ) );
	$entry->appendChild( $xml->create_data_element(
			"title",
			$xhtml->to_text_dump( $dataobj->render_description ) ) );
	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "alternate",
			href => $dataobj->get_url ) );
	$entry->appendChild( $xml->create_data_element(
			"summary",
			$xhtml->to_text_dump( $dataobj->render_citation ) ) );

	my $r = $xml->to_string( $entry, indent => 1 );
	$xml->dispose( $entry );

	return $r;
}

sub output_file
{
	my( $self, $dataobj, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $doc = $dataobj->parent();

	my $entry = $xml->create_element( "entry" );
	
	$entry->appendChild( $xml->create_data_element(
			"id",
			$dataobj->uri ) );
	$entry->appendChild( $xml->create_data_element(
			"title",
			$dataobj->get_value("filename") ) );
	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "alternate",
			href => $doc->get_url( $dataobj->value( "filename" ) ) ) );

	my $r = $xml->to_string( $entry, indent => 1 );
	$xml->dispose( $entry );

	return $r;
}

1;

