package EPrints::Plugin::Export::EAP;

=head1 NAME

EPrints::Plugin::Export::EAP - Eprints Application Profile

=head1 DESCRIPTION

Not to be confused with Eprints (this software).

http://www.ukoln.ac.uk/repositories/digirep/index/Eprints_Application_Profile

=cut

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

our $prefix = 'epdcx';

# See http://www.ukoln.ac.uk/repositories/digirep/index/Eprints_Type_Vocabulary_Encoding_Scheme
our %EPRINT_TYPES = (
	article => "JournalArticle", # maybe SubmittedJournalArticle
	book => "Book",
	book_section => "BookItem",
	conference_item => "ConferencePaper", # or Conference{Item,Poster}
	thesis => "Thesis",
);

our @SCHOLARLY_WORK_ELEMENTS = (
	"http://purl.org/dc/elements/1.1/title" => "title",
	"http://purl.org/dc/elements/dc/terms/abstract" => "abstract",
	"http://purl.org/dc/elements/dc/elements/1.1/creator" => {
		name => "creators_name",
		render_value => \&name_value,
	},
	"http://purl.org/dc/elements/1.1/subject" => "subjects",
	"http://www.loc.gov/loc.terms/relators/FND" => "funders",
	"http://purl.org/eprint/terms/grantNumber" => "projects",
);
our @EXPRESSION_ELEMENTS = (
	"http://purl.org/dc/elements/1.1/identifier" => {
		name => "official_url",
		render_value => \&doi_value,
	},
	"http://purl.org/dc/elements/1.1/title" => "title",
	"http://purl.org/dc/terms/available" => {
		name => "datestamp",
		render_value => \&datetime_value,
	},
	"http://purl.org/dc/elements/1.1/language" => "lang",
	"http://purl.org/dc/elements/1.1/type" => {
		name => "type",
		render_value => \&type_value,
	},
	"http://purl.org/dc/terms/bibliographicCitation" => {
		name => "eprint_status", # always set, but ignored
		render_value => \&citation_value,
	},
	"http://www.loc.gov/loc.terms/relators/EDT" => {
		name => "editors_name",
		render_value => \&name_value,
	},
);
our @MANIFESTATION_ELEMENTS = (
	"http://purl.org/dc/elements/1.1/format" => "format",
);

sub datetime_value
{
	my( $self, $value ) = @_;

	my( $date, $time ) = split / /, $value;

	$value = $date;
	$value .= "T${time}Z" if $time;

	return $self->{session}->make_text( $value );
}

sub name_value
{
	my( $self, $value ) = @_;

	$value = EPrints::Utils::make_name_string( $value );

	return $self->{session}->make_text( $value );
}

sub type_value
{
	my( $self, $value ) = @_;

	return exists($EPRINT_TYPES{$value}) ?
		("http://purl.org/eprint/type/" . $EPRINT_TYPES{$value}) :
		undef;
}

sub citation_value
{
	my( $self, $value, $dataobj ) = @_;

	$value = EPrints::Utils::tree_to_utf8( $dataobj->render_citation );

	return $self->{session}->make_text( $value );
}

sub doi_value
{
	my( $self, $value ) = @_;

	return unless $value =~ /^doi:/;

	return $self->{session}->make_text( $value );
}

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Eprints Application Profile";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	
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

	EPrints::XML::tidy( $md );

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
	))->appendChild( $self->valueString( $dataobj->get_url, $dataobj, undef,
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

	$description->appendChild( $self->render_elements( $dataobj, \@SCHOLARLY_WORK_ELEMENTS ));

	return $description;
}

sub expression
{
	my( $self, $dataobj, $id, $manifestations ) = @_;

	my $session = $self->{session};

	# the resource
	my $description = $session->make_element(
		"$prefix:description",
		"$prefix:resourceId" => $id,
	);

	$description->appendChild( $self->render_elements( $dataobj, \@EXPRESSION_ELEMENTS ));

	my $dataset = $dataobj->get_dataset;
	if( $dataset->has_field( "refereed" ) and $dataobj->is_set( "refereed" ) )
	{
		if( $dataobj->get_value( "refereed" ) eq "TRUE" )
		{
			$description->appendChild( $session->make_element(
				"$prefix:statement",
				"$prefix:propertyURI" => "http://purl.org/eprint/terms/status",
				"$prefix:valueURI" => "http://purl.org/eprint/status/PeerReviewed",
			));
		}
		else
		{
			$description->appendChild( $session->make_element(
				"$prefix:statement",
				"$prefix:propertyURI" => "http://purl.org/eprint/terms/status",
				"$prefix:valueURI" =>  "http://purl.org/eprint/status/NonPeerReviewed",
			));
		}
	}

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

	$description->appendChild( $self->render_elements( $doc, \@MANIFESTATION_ELEMENTS ));

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

sub render_elements
{
	my( $self, $dataobj, $elements ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	my $dataset = $dataobj->get_dataset;
	for(my $i = 0; $i < @$elements; $i+=2)
	{
		my( $uri, $field ) = @$elements[$i,$i+1];
		my( $f, $fieldname ) = ref($field) ?
			@$field{qw( render_value name )} :
			(\&valueString, $field);
		next unless $dataset->has_field( $fieldname );
		next unless $dataobj->is_set( $fieldname );
		my $value = $dataobj->get_value( $fieldname );
		my @values = ref($value) eq 'ARRAY' ? @$value : ($value);
		foreach my $value (@values)
		{
			my $v = &$f( $self, $value, $dataobj, $field );
			if( $v and ref($v) )
			{
				$frag->appendChild( $session->make_element(
					"$prefix:statement",
					"$prefix:propertyURI" => $uri,
				))->appendChild( $v );
			}
			elsif( defined $v )
			{
				$frag->appendChild( $session->make_element(
					"$prefix:statement",
					"$prefix:propertyURI" => $uri,
					"$prefix:valueURI" => $v,
				));
			}
		}
	}

	return $frag;
}

sub valueString
{
	my( $self, $value, $dataobj, $field, %attr ) = @_;

	my $ele = $self->{session}->make_element( "$prefix:valueString", %attr );
	$ele->appendChild( $self->{session}->make_text( $value ) );

	return $ele;
}

1;
