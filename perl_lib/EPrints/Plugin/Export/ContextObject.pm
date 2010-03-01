package EPrints::Plugin::Export::ContextObject;

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

our %TYPES = (
	article => {
		namespace => "info:ofi/fmt:xml:xsd:journal",
		plugin => "Export::ContextObject::Journal"
	},
	book => {
		namespace => "info:ofi/fmt:xml:xsd:book",
		plugin => "Export::ContextObject::Book"
	},
	book_section => {
		namespace => "info:ofi/fmt:xml:xsd:book",
		plugin => "Export::ContextObject::Book"
	},
	conference_item => {
		namespace => "info:ofi/fmt:xml:xsd:book",
		plugin => "Export::ContextObject::Book"
	},
	thesis => {
		namespace => "info:ofi/fmt:xml:xsd:dissertation",
		plugin => "Export::ContextObject::Dissertation"
	},
	other => {
		namespace => "info:ofi/fmt:xml:xsd:oai_dc",
		plugin => "Export::ContextObject::DublinCore"
	},
);

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL ContextObject";
	$self->{accept} = [ 'list/eprint', 'list/access', 'dataobj/eprint', 'dataobj/access' ];
	$self->{visible} = "all";

	$self->{xmlns} = "info:ofi/fmt:xml:xsd:ctx";
	$self->{schemaLocation} = "http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx";

	return $self;
}

# This is used by sub-classed objects
sub convert_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $mapping = $opts{mapping} || {};

	my $dataset = $dataobj->get_dataset;

	my $data = [];

	if( $dataset->has_field( "creators_name" ) and $dataobj->is_set( "creators_name" ) )
	{
		my $field = $dataset->get_field( "creators_name" );
		foreach my $author ( @{$dataobj->get_value( "creators_name" )} )
		{
			push @$data, [ author => {
				aulast => $author->{family},
				aufirst => $author->{given},
				au => EPrints::Utils::tree_to_utf8( $field->render_value( $plugin->{session}, [ $author ] ) )
			} ];
		}
	}

	while(my( $fieldname, $entity_field ) = each %$mapping)
	{
		next unless $dataset->has_field( $fieldname );
		next unless $dataobj->is_set( $fieldname );
		my $field = $dataset->get_field( $fieldname );

		my $value;
		if( $field->is_type( "pagerange" ) )
		{
			$value = $dataobj->get_value( $fieldname );
		}
		else
		{
			$value = EPrints::Utils::tree_to_utf8( $field->render_value( $plugin->{session}, $dataobj->get_value( $fieldname ) ) );
		}
		push @$data, [ $entity_field => $value ];
	}

	return $data;
}

sub xml_entity_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $session = $plugin->{ "session" };
	my $repository = $session->get_repository;

	my $prefix = $opts{prefix};
	my $namespace = $opts{namespace};
	my $schemaLocation = $opts{schemaLocation};

	my $entity = $session->make_element(
		"$prefix:journal",
		"xmlns:$prefix" => $namespace,
		"xmlns:xsi" => "http://www.w3.org/2001/XML",
		"xsi:schemaLocation" => $schemaLocation,
	);

	my $data = $plugin->convert_dataobj( $dataobj, %opts );

	my $auths = $session->make_element( "$prefix:authors" );
	$entity->appendChild( $auths );

	foreach my $e (@$data)
	{
		if( $e->[0] eq "author" )
		{
			my $author = $e->[1];

			my $auth = $auths->appendChild( $session->make_element( "$prefix:author" ) );

			$auth->appendChild(
				$session->make_element( "$prefix:aulast" )
			)->appendChild(
				$session->make_text( $author->{ "aulast" } )
			);

			$auth->appendChild(
				$session->make_element( "$prefix:aufirst" )
			)->appendChild(
				$session->make_text( $author->{ "aufirst" } )
			);

			$auth->appendChild(
				$session->make_element( "$prefix:au" )
			)->appendChild(
				$session->make_text( $author->{ "au" } )
			);
		}
		else
		{
			my $node = $session->make_element( "$prefix:$e->[0]" );
			$entity->appendChild( $node );
			$node->appendChild( $session->make_text( $e->[1] ));
		}
	}

	$entity->removeChild( $auths ) unless $auths->hasChildNodes;

	return $entity;
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = "context-objects";
	
	my $r = [];

	my $part;
	$part = <<EOX;
<?xml version="1.0" encoding="utf-8" ?>

<$toplevel xmlns="info:ofi/fmt:xml:xsd:ctx" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx">
EOX
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	$opts{list}->map( sub {
		my( $session, $dataset, $item ) = @_;

		my $part = $plugin->output_dataobj( $item, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	} );

	$part= "</$toplevel>\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $xml = $plugin->xml_dataobj( $dataobj, %opts );

	return EPrints::XML::to_string( $xml );
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $session = $plugin->{ "session" };

	my $timestamp_field;
	if( $itemtype eq "eprint" )
	{
		$timestamp_field = "lastmod";
	}
	elsif( $itemtype eq "access" )
	{
		$timestamp_field = "datestamp";
	}

	my $timestamp;
	if( $dataobj->dataset->has_field( $timestamp_field ) )
	{
		$timestamp = $dataobj->get_value( $timestamp_field );
		if( $timestamp !~ m/T/ )
		{
			my( $date, $time ) = split / /, $timestamp;
			$timestamp = "${date}T${time}Z";
		}
	}

	# TODO: fix timestamp format
	my $co = $session->make_element(
		"ctx:context-object",
		"xmlns:ctx" => "info:ofi/fmt:xml:xsd:ctx",
		"xmlns:xsi" => "http://www.w3.org/2001/XML",
		"xsi:schemaLocation" => "info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx",
		"timestamp" => $timestamp,
	);

	if( $itemtype eq "eprint" )
	{
		$co->appendChild( $plugin->xml_eprint( $dataobj, %opts ) );
	}
	else
	{
		$co->appendChild( $plugin->xml_access( $dataobj, %opts ) );
	}

	return $co;
}


sub xml_eprint
{
	my( $plugin, $eprint, %opts ) = @_;

	my $session = $plugin->{ "session" };

	# Referent
	my $rft = $session->make_element( "ctx:referent" );
	
	my $oai = $session->get_repository->get_conf( "oai" );

	my $oai_id = EPrints::OpenArchives::to_oai_identifier( 
			$oai->{v2}->{ "archive_id" }, 
			$eprint->get_id );

	$rft->appendChild( 
		$session->make_element( "ctx:identifier" )
	)->appendChild(
		$session->make_text( "info:".$oai_id )
	);

	my $type = $eprint->get_value( "type" );
	$type = "other" unless exists $TYPES{$type};

	$rft->appendChild( $plugin->_metadata_by_val( $eprint, %opts,
		namespace => $TYPES{$type}->{namespace},
		plugin => $TYPES{$type}->{plugin},
	));

	return $rft;
}

sub xml_access
{
	my( $plugin, $access, %opts ) = @_;

	my $session = $plugin->{ "session" };

	my $r = $session->make_doc_fragment;

	my $rft = $session->make_element( "ctx:referent" );
	$r->appendChild( $rft );
	
	$rft->appendChild( 
		$session->make_element( "ctx:identifier" )
	)->appendChild(
		$session->make_text( $access->get_referent_id )
	);

	# referring-entity
	if( $access->exists_and_set( "referring_entity_id" ) )
	{
		my $rfr = $session->make_element( "ctx:referring-entity" );
		$r->appendChild( $rfr );

		$rfr->appendChild(
			$session->make_element( "ctx:identifier" )
		)->appendChild(
			$session->make_text( $access->get_value( "referring_entity_id" ))
		);
	}

	# requester
	my $req = $session->make_element( "ctx:requester" );
	$r->appendChild( $req );

	$req->appendChild(
		$session->make_element( "ctx:identifier" )
	)->appendChild(
		$session->make_text( $access->get_requester_id )
	);
	
	if( $access->exists_and_set( "requester_user_agent" ) )
	{
		$req->appendChild(
			$session->make_element( "ctx:private-accesslog" )
		)->appendChild(
			$session->make_text( $access->get_value( "requester_user_agent" ))
		);
	}

	# service-type
	if( $access->exists_and_set( "service_type_id" ) )
	{
		my $svc = $session->make_element( "ctx:service-type" );
		$r->appendChild( $svc );

		my $md_val = $session->make_element( "ctx:metadata-by-val" );
		$svc->appendChild( $md_val );
	
		my $fmt = $session->make_element( "ctx:format" );
		$md_val->appendChild( $fmt );
		$fmt->appendChild( $session->make_text( "info:ofi/fmt:xml:xsd:sch_svc" ));

		my $md = $session->make_element(
			"sv:svc-list",
			"xmlns:sv" => "info:ofi/fmt:xml:xsd:sch_svc",
			"xsi:schemaLocation" => "info:ofi/fmt:xml:xsd:sch_svc http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:sch_svc",
		);
		$md_val->appendChild( $md );

		my $uri = URI->new( $access->get_value( "service_type_id" ), 'http' );
		my( $key, $value ) = $uri->query_form;
		$md->appendChild(
			$session->make_element( "sv:$key" )
		)->appendChild(
			$session->make_text( $value )
		);
	}

	return $r;	
}

sub _metadata_by_val
{
	my( $plugin, $dataobj, %opts ) = @_;
	my $session = $plugin->{ "session" };

	my $md_val = $session->make_element( "ctx:metadata-by-val" );
	
	$md_val->appendChild(
		$session->make_element( "ctx:format" )
	)->appendChild(
		$session->make_text( $opts{ "namespace" } )
	);
	
	my $md = $session->make_element( "ctx:metadata" );
	$md_val->appendChild( $md );

	my $entity_plugin = $session->plugin( $opts{ "plugin" } );
	$md->appendChild( $entity_plugin->xml_dataobj( $dataobj ) );

	return $md_val;
}

1;
