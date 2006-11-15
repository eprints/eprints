package EPrints::Plugin::Export::METS;

=head1 NAME

EPrints::Plugin::Export::METS - Export plugin for METS

=head1 DESCRIPTION

This plugin exports EPrint objects in METS xml.

This plugin is based on work by Jon Bell, UWA.

=cut 

use strict;
use warnings;

use EPrints::Plugin::Export;
our @ISA = qw( EPrints::Plugin::Export );

our $PREFIX = "mets:";

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "METS";
	$self->{accept} = [ 'dataobj/eprint', 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";
	
	$self->{xmlns} = "http://www.loc.gov/METS/";
	$self->{schemaLocation} = "http://www.loc.gov/standards/mets/mets.xsd";

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
	my( $plugin, $dataobj ) = @_;

	my $session = $plugin->{ session };

	my $id = $dataobj->get_gid;

	my $mods_plugin = $plugin->{session}->plugin( "Export::MODS" );
	
	my $nsp = "xmlns:${PREFIX}";
	chop($nsp); # remove the trailing ':'
	my $mets = $session->make_element(
		"${PREFIX}mets",
		"OBJID" => $id,
		"LABEL" => "Eprints Item",
		$nsp => $plugin->{ xmlns },
		"xmlns:xlink" => "http://www.w3.org/1999/xlink",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => $plugin->{ xmlns } . " " . $plugin->{ schemaLocation },				
	);
	
	# metsHdr
	$mets->appendChild( _make_header( $session, $dataobj ));

	# dmdSec
	my $mods_id = "DMD_".$id."_mods";
	$mets->appendChild(my $mods_dmd = $session->make_element(
		"dmdSec",
		"ID" => $mods_id
	));
	$mods_dmd->appendChild(my $mods_mdWrap = $session->make_element(
		"mdWrap",
		"MDTYPE" => "MODS"
	));
	$mods_mdWrap->appendChild(
		$mods_plugin->xml_dataobj( $dataobj )
	);
	
	# amdSec
	my $amd_id = "TMD_".$id;
	my $rights_id = "rights_".$id."_mods";
	
	# fileSec
	
	# structMap

	return $mets;
}

sub _make_header
{
	my( $session, $dataobj ) = @_;
	
	my $time = EPrints::Utils::get_iso_timestamp;
	my $repo = $session->get_repository;
	
	my $header = $session->make_element(
		"${PREFIX}metsHdr",
		"CREATEDATA" => $time
	);
	$header->appendChild( my $agent = $session->make_element(
		"${PREFIX}agent",
		"ROLE" => "CUSTODIAN",
		"TYPE" => "ORGANIZATION"
	));
	$agent->appendChild( my $name = $session->make_element(
		"${PREFIX}name",
	));
	my $aname = $session->phrase( "archive_name" );
	$name->appendChild( $session->make_text( $aname ));
	
	return $header;
}

1;