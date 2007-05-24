package EPrints::Plugin::Export::EAP;

=head1 NAME

EPrints::Plugin::Export::EAP - Eprints Application Profile

=head1 DESCRIPTION

Not to be confused with Eprints (this software).

http://www.ukoln.ac.uk/repositories/digirep/index/Eprints_Application_Profile

=cut

# eprint needs magic documents field

# documents needs magic files field

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

our $prefix = 'epdcx';

our %SCHOLARLY_WORK_ELEMENTS = (
	"http://purl.org/dc/elements/1.1/title" => "title",
	"http://purl.org/dc/elements/dc/terms/abstract" => "abstract",
	"http://purl.org/dc/elements/dc/elements/1.1/creator" => "creators_name",
);

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Eprints Application Profile";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";
	
	$self->{xmlns} = "http://purl.org/eprint/epdcx/2006-11-16/";
	$self->{schemaLocation} = "http://purl.org/eprint/epdcx/xsd/2006-11-16/epdcx.xsd";

	return $self;
}


sub output_dataobj
{
	my( $self, $dataobj ) = @_;

	my $xml = $self->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}


sub xml_dataobj
{
	my( $self, $dataobj ) = @_;

	my $session = $self->{session};

	my $main_dc_plugin = $self->{session}->plugin( "Export::DC" );
	
	my $data = $main_dc_plugin->convert_dataobj( $dataobj );

	my $xmlns = $self->{xmlns};
	my $schemaLocation = $self->{schemaLocation};

	my $md = $self->{session}->make_element(
			"$prefix:descriptionSet",
			"xmlns:$prefix" => "$xmlns",
			"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
			"xsi:schemaLocation" => "$xmlns $schemaLocation" );

	my $id = $dataobj->get_id;

	my %expressions = (
		"expression_${id}_1" => $dataobj,
	);

	my %manifestations;
	foreach my $doc ($dataobj->get_all_documents)
	{
		$manifestations{ "manifestation_${id}_" . $doc->get_id } = $doc;
	}

	$md->appendChild( $self->scholarly_work( $dataobj, $dataobj->get_url, \%expressions ) );

	while(my( $id, $eprint ) = each %expressions )
	{
		$md->appendChild( $self->expression( $eprint, $id, \%manifestations ) );
	}

	while(my( $id, $doc ) = each %manifestations)
	{
		$md->appendChild( $self->manifestation( $doc, $id ) );
		$md->appendChild( $self->available( $doc, $id ) );
	}

	return $md;
}

sub scholarly_work
{
	my( $self, $dataobj, $id, $expressions ) = @_;

	my $session = $self->{session};

	# the resource
	my $description = $session->make_element(
		"$prefix:description",
		"$prefix:resourceURI" => $id
	);

	$description->appendChild( $session->make_element(
		"$prefix:statement",
		"$prefix:propertyURI" => "http://purl.org/dc/elements/1.1/type",
		"$prefix:valueURI" => "http://purl.org/eprint/entitType/ScholarlyWork"
	));

	$description->appendChild( $session->make_element(
		"$prefix:statement",
		"$prefix:propertyURI" => "http://purl.org/dc/elements/1.1/identifier",
	))->appendChild( $self->valueString( $dataobj->get_url,
		"$prefix:sesURI" => "http://purl.org/dc/terms/URI",
	) );

	while(my( $id, $eprint ) = each %$expressions )
	{
		$description->appendChild( $session->make_element(
			"$prefix:statement",
			"$prefix:propertyURI" => "http://purl.org/eprint/terms/isExpressedAs",
			"$prefix:valueRef" => $id,
		));
	}

	while(my( $uri, $fieldname ) = each %SCHOLARLY_WORK_ELEMENTS)
	{
		next unless $dataobj->is_set( $fieldname );
		my $field = $dataobj->get_dataset->get_field( $fieldname );
		my $value = $dataobj->get_value( $fieldname );
		my @values = ref($value) eq 'ARRAY' ? @$value : ($value);
		foreach my $value (@values)
		{
			$value = EPrints::Utils::make_name_string( $value )
				if $field->isa( "EPrints::MetaField::Name" );
			$description->appendChild( $session->make_element(
				"$prefix:statement",
				"$prefix:propertyURI" => $uri,
			))->appendChild( $self->valueString( $value ) );
		}

	}

	return $description;
}

sub expression
{
	my( $self, $eprint, $id, $manifestations ) = @_;

	my $session = $self->{session};

	# the resource
	my $description = $session->make_element(
		"$prefix:description",
		"$prefix:resourceId" => $id,
	);

	$description->appendChild( $session->make_element(
		"$prefix:statement",
		"$prefix:propertyURI" => "http://purl.org/dc/elements/1.1/identifier",
	))->appendChild( $self->valueString( EPrints::Utils::tree_to_utf8( $eprint->render_citation ) ) );

	while(my( $id, $eprint ) = each %$manifestations )
	{
		$description->appendChild( $session->make_element(
			"$prefix:statement",
			"$prefix:propertyURI" => "http://purl.org/eprint/terms/isManifestedAs",
			"$prefix:valueRef" => $id,
		));
	}

	return $description;
}

sub manifestation
{
	my( $self, $doc, $id ) = @_;

	my $session = $self->{session};

	# the resource
	my $description = $session->make_element(
		"$prefix:description",
		"$prefix:resourceId" => $id,
	);

	$description->appendChild( $session->make_element(
		"$prefix:statement",
		"$prefix:propertyURI" => "http://purl.org/dc/elements/1.1/type",
		"$prefix:valueURI" => "http://purl.org/eprint/entity/entityType/Manifestation",
	));

	$description->appendChild( $session->make_element(
		"$prefix:statement",
		"$prefix:propertyURI" => "http://purl.org/dc/elements/1.1/format",
	))->appendChild( $self->valueString( $doc->get_value( "format" ) ) );

	$description->appendChild( $session->make_element(
		"$prefix:statement",
		"$prefix:propertyURI" => "http://purl.org/eprint/terms/isAvailableAs",
		"$prefix:valueURI" => $doc->get_url
	));

	return $description;
}

sub available
{
	my( $self, $doc, $id ) = @_;

	my $session = $self->{session};

	# the resource
	my $description = $session->make_element(
		"$prefix:description",
		"$prefix:resourceURI" => $doc->get_url,
	);

	$description->appendChild( $session->make_element(
		"$prefix:statement",
		"$prefix:propertyURI" => "http://purl.org/dc/elements/1.1/type",
		"$prefix:valueURI" => "http://purl.org/eprint/entityType/Copy",
	));

	if( $doc->get_value( "security" ) eq "public" )
	{
		$description->appendChild( $session->make_element(
			"$prefix:statement",
			"$prefix:propertyURI" => "http://purl.org/dc/terms/accessRights",
			"$prefix:valueURI" => "http://purl.org/eprint/accessRights/OpenAccess",
		));
	}

	return $description;
}

sub valueString
{
	my( $self, $value, %attr ) = @_;

	my $ele = $self->{session}->make_element( "$prefix:valueString", %attr );
	$ele->appendChild( $self->{session}->make_text( $value ) );

	return $ele;
}

1;
