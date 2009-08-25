package EPrints::Plugin::Export::MODS;

use strict;
use warnings;

use EPrints::Plugin::Export::XMLFile;

our @ISA = qw( EPrints::Plugin::Export::XMLFile );

our $PREFIX = "mods:";

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "MODS";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	
	$self->{xmlns} = "http://www.loc.gov/mods/v3";
	$self->{schemaLocation} = "http://www.loc.gov/standards/mods/v3/mods-3-3.xsd";

	return $self;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}


sub xml_dataobj
{
	my( $plugin, $dataobj, $prefix ) = @_;

	my $handle = $plugin->{handle};

	my $dataset = $dataobj->get_dataset;

	$PREFIX = $prefix
		if defined( $prefix );	

	my $nsp = "xmlns:${PREFIX}";
	chop($nsp); # Remove the ':'
	my $mods = $handle->make_element(
		"${PREFIX}mods",
		"version" => "3.3",
		$nsp => $plugin->{ xmlns },
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => ($plugin->{ xmlns } . ' ' . $plugin->{ schemaLocation }),
	);

	# title
	$mods->appendChild( _make_title( $handle, $dataset, $dataobj ));

	# creators
	$mods->appendChild( _make_creators( $handle, $dataset, $dataobj ));

	# abstract
	$mods->appendChild( _make_abstract( $handle, $dataset, $dataobj ));

	# subjects
	$mods->appendChild( _make_subjects( $handle, $dataset, $dataobj ));
	
	# date_issue
	$mods->appendChild( _make_issue_date( $handle, $dataset, $dataobj ));

	# publisher
	$mods->appendChild( _make_publisher( $handle, $dataset, $dataobj ));
	
	# genre
	$mods->appendChild( _make_genre( $handle, $dataset, $dataobj ));
	
	$PREFIX = "mods:";
	
	return $mods;
}

sub _make_title
{
	my( $handle, $dataset, $dataobj ) = @_;

	my $val = $dataobj->get_value( "title" );
	return $handle->make_doc_fragment unless defined $val;
	
	my $titleInfo = $handle->make_element( "${PREFIX}titleInfo" );
	$titleInfo->appendChild( my $title = $handle->make_element( "${PREFIX}title" ));
	$title->appendChild( $handle->make_text( $val ));
	
	return $titleInfo;
}

sub _make_creators
{
	my( $handle, $dataset, $dataobj ) = @_;
	
	my $frag = $handle->make_doc_fragment;
	
	my $creators = $dataobj->get_value( "creators_name" );
	return $frag unless defined $creators;

	foreach my $creator ( @{$creators} )
	{	
		next if !defined $creator;
		$frag->appendChild(my $name = $handle->make_element(
			"${PREFIX}name",
			"type" => "personal"
		));
		$name->appendChild(my $given = $handle->make_element(
			"${PREFIX}namePart",
			"type" => "given"
		));
		$given->appendChild( $handle->make_text( $creator->{ given } ));
		$name->appendChild(my $family = $handle->make_element(
			"${PREFIX}namePart",
			"type" => "family"
		));
		$family->appendChild( $handle->make_text( $creator->{ family } ));
		$name->appendChild(my $role = $handle->make_element(
			"${PREFIX}role",
		));
		$role->appendChild( my $roleTerm = $handle->make_element(
			"${PREFIX}roleTerm",
			"type" => "text"
		));
		$roleTerm->appendChild( $handle->make_text( "author" ));
	}

	return $frag;
}

sub _make_abstract
{
	my( $handle, $dataset, $dataobj ) = @_;
	
	my $val = $dataobj->get_value( "abstract" );
	return $handle->make_doc_fragment unless defined $val;
	
	my $abstract = $handle->make_element( "${PREFIX}abstract" );
	$abstract->appendChild( $handle->make_text( $val ));
	
	return $abstract;
}

sub _make_subjects
{
	my( $handle, $dataset, $dataobj ) = @_;
	
	my $frag = $handle->make_doc_fragment;
	
	my $subjects = $dataset->has_field("subjects") ?
		$dataobj->get_value("subjects") :
		undef;
	return $frag unless EPrints::Utils::is_set( $subjects );
	
	foreach my $val (@$subjects)
	{
		my $subject = $handle->get_subject( $val );
		next unless defined $subject;
		$frag->appendChild( my $classification = $handle->make_element(
			"${PREFIX}classification",
			"authority" => "lcc"
		));
		$classification->appendChild( $handle->make_text(
			EPrints::XML::to_string($subject->render_description)
		));
	}
	
	return $frag;
}

sub _make_issue_date
{
	my( $handle, $dataset, $dataobj ) = @_;
	
	my $val = $dataobj->get_value( "date" );
	return $handle->make_doc_fragment unless defined $val;
	
	$val =~ s/(-0+)+$//;
	
	my $originInfo = $handle->make_element( "${PREFIX}originInfo" );
	$originInfo->appendChild( my $dateIssued = $handle->make_element(
		"${PREFIX}dateIssued",
		"encoding" => "iso8061"
	));
	$dateIssued->appendChild( $handle->make_text( $val ));
	
	return $originInfo;
}

sub _make_publisher
{
	my( $handle, $dataset, $dataobj ) = @_;
	
	my $val;
	
	my $type = lc($dataobj->get_value( "type" ));
	if( $type eq "thesis" and $dataobj->is_set( "institution" ) )
	{
		$val = $dataobj->get_value( "institution" );
		if( $dataobj->is_set( "department" ))
		{
			$val .= ";" . $dataobj->get_value( "department" );
		}
	}
	else
	{
		$val = $dataobj->get_value( "publisher" );		
	}
	
	return $handle->make_doc_fragment unless defined $val;	
	
	my $originInfo = $handle->make_element( "${PREFIX}originInfo" );
	$originInfo->appendChild( my $pub = $handle->make_element( "${PREFIX}publisher" ));
	$pub->appendChild( $handle->make_text( $val ));
	
	return $originInfo;
}

sub _make_genre
{
	my( $handle, $dataset, $dataobj ) = @_;
	
	my $val = $handle->phrase( $dataset->confid()."_typename_".$dataobj->get_type() );
	
	my $genre = $handle->make_element( "${PREFIX}genre" );
	$genre->appendChild( $handle->make_text( $val ));
	
	return $genre; 
}

1;
