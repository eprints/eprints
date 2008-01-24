package EPrints::Plugin::Export::ContextObject;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL ContextObject";
	$self->{accept} = [ 'list/eprint', 'list/access', 'dataobj/eprint', 'dataobj/access' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	$self->{xmlns} = "info:ofi/fmt:xml:xsd:ctx";
	$self->{schemaLocation} = "http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx";

	return $self;
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

	foreach my $dataobj ( $opts{list}->get_records )
	{
		$part = $plugin->output_dataobj( $dataobj, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	}	

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

	my $timestamp = $dataobj->get_value( $timestamp_field );
	my( $date, $time ) = split / /, $timestamp;
	$timestamp = "${date}T${time}Z";

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

	my $etype = $eprint->get_value( "type" );
	if( $etype eq "article" or $etype eq "conference_item" )
	{
		$rft->appendChild( $plugin->_metadata_by_val( $eprint, %opts,
			schema => "info:ofi/fmt:xml:xsd:journal",
			plugin => "Export::ContextObject::Journal"
		));
	}
	elsif( $etype eq "thesis" )
	{
		$rft->appendChild( $plugin->_metadata_by_val( $eprint, %opts,
			schema => "info:ofi/fmt:xml:xsd:dissertation",
			plugin => "Export::ContextObject::Dissertation"
		));
	}
	else
	{
		$rft->appendChild( $plugin->_metadata_by_val( $eprint, %opts,
			schema => "info:ofi/fmt:xml:xsd:oai_dc",
			plugin => "Export::OAI_DC"
		));
	}

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
		$session->make_text( $opts{ "schema" } )
	);
	
	my $md = $session->make_element( "ctx:metadata" );
	$md_val->appendChild( $md );

	my $jnl_plugin = $session->plugin( $opts{ "plugin" } );
	$md->appendChild( $jnl_plugin->xml_dataobj( $dataobj ) );

	return $md_val;
}

1;
