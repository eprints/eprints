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
our $MODS_PREFIX = "mods:";

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

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = "mets-objects";
	
	my $r = [];

	my $part;
	$part = <<EOX;
<?xml version="1.0" encoding="utf-8" ?>

<$toplevel>
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
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}


sub xml_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $session = $plugin->{ session };

	my $id = $dataobj->uri;

	my $mods_plugin = $session->plugin( "Export::MODS" )
		or die "Couldn't get Export::MODS plugin";
	my $conv_plugin = $session->plugin( "Convert" )
		or die "Couldn't get Convert plugin";
	
	my $nsp = "xmlns:${PREFIX}";
	chop($nsp); # remove the trailing ':'
	my $mods_nsp = "xmlns:${MODS_PREFIX}";
	chop($mods_nsp); # remove the trailing ':'
	my $mets = $session->make_element(
		"${PREFIX}mets",
		"OBJID" => $id,
		"LABEL" => "Eprints Item",
		$nsp => $plugin->{ xmlns },
		$mods_nsp => $mods_plugin->{ xmlns },
		"xmlns:xlink" => "http://www.w3.org/1999/xlink",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" =>
			$plugin->{ xmlns } . " " . $plugin->{ schemaLocation } . " " .
			$mods_plugin->{ xmlns } . " " . $mods_plugin->{ schemaLocation }				
	);
	
	# metsHdr
	$mets->appendChild( _make_header( $session, $dataobj ));

	# dmdSec
	my $mods_id = "DMD_".$id."_mods"; # also used in structMap
	$mets->appendChild(my $mods_dmd = $session->make_element(
		"${PREFIX}dmdSec",
		"ID" => $mods_id
	));
	$mods_dmd->appendChild(my $mods_mdWrap = $session->make_element(
		"${PREFIX}mdWrap",
		"MDTYPE" => "mods"
	));
	my $mods = $mods_plugin->xml_dataobj( $dataobj, $MODS_PREFIX );
	$mods_mdWrap->appendChild( my $xmlData = $session->make_element(
		"${PREFIX}xmlData"
	));
	# copy in the child nodes (we don't need to repeat the MODS namespace)
	$xmlData->appendChild( $_ ) for ($mods->getChildNodes);
	
	# amdSec
	my $amd_id = "TMD_".$id;
	my $rights_id = "rights_".$id."_mods";
	$mets->appendChild( _make_amdSec( $session, $dataobj, $amd_id, $rights_id ));
	
	# fileSec
	$mets->appendChild( _make_fileSec( $session, $dataobj, $id, $conv_plugin ));
	
	# structMap
	$mets->appendChild( _make_structMap( $session, $dataobj, $id, $mods_id, $amd_id ));

	return $mets;
}

sub _make_header
{
	my( $session, $dataobj ) = @_;
	
	my $time = EPrints::Time::get_iso_timestamp();
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

sub _make_amdSec
{
	my( $session, $dataobj, $amd_id, $rights_id ) = @_;
	
	my $amdSec = $session->make_element(
		"${PREFIX}amdSec",
		"ID" => $amd_id
	);
	
	$amdSec->appendChild(my $rightsMD = $session->make_element(
		"${PREFIX}rightsMD",
		"ID" => $rights_id
	));
	
	$rightsMD->appendChild( my $mdWrap = $session->make_element(
		"${PREFIX}mdWrap",
		"MDTYPE" => "mods"
	));
	
	$mdWrap->appendChild( my $xmlData = $session->make_element(
		"${PREFIX}xmlData",
	));
	
	$xmlData->appendChild( my $mods_use = $session->make_element(
		"${MODS_PREFIX}useAndReproduction"
	));
	$mods_use->appendChild( $session->html_phrase( "deposit_agreement_text" ));
	
	return $amdSec;
}

sub _make_fileSec
{
	my( $session, $dataobj, $id, $conv_plugin ) = @_;

	my $fileSec = $session->make_element(
		"${PREFIX}fileSec"
	);
	
	foreach my $doc ($dataobj->get_all_documents)
	{
		my $baseurl = $doc->get_baseurl;
		my $id_base = $id."_".$doc->get_id;
		my %files = $doc->files;

		$fileSec->appendChild(my $fileGrp = $session->make_element(
			"${PREFIX}fileGrp",
			"USE" => "reference"
		));

		my $file_idx = 0;
		while( my( $name, $size) = each %files )
		{
			$file_idx++;
			my $url = $baseurl . $name;
			my $mimetype = $doc->mime_type( $name );
			$mimetype = 'application/octet-stream' unless defined $mimetype;

			$fileGrp->appendChild( my $file = $session->make_element(
				"${PREFIX}file",
				"ID" => $id_base."_".$file_idx,
				"SIZE" => $size,
				"OWNERID" => $url,
				"MIMETYPE" => $mimetype
			));

			$file->appendChild( $session->make_element(
				"${PREFIX}FLocat",
				"LOCTYPE" => "URL",
				"xlink:type" => "simple",
				"xlink:href" => $url
			));
		}
	}
	
	return $fileSec;
}

sub _make_structMap
{
	my( $session, $dataobj, $id, $dmd_id, $amd_id ) = @_;
	
	my $structMap = $session->make_element( "${PREFIX}structMap" );
	
	$structMap->appendChild( my $top_div = $session->make_element(
		"${PREFIX}div",
		"DMDID" => $dmd_id,
		"AMDID" => $amd_id
	));
	
	foreach my $doc ($dataobj->get_all_documents)
	{
		my $id_base = $id."_".$doc->get_id;
		my $file_idx = 0;
		my %files = $doc->files;
		if( scalar keys %files > 1 )
		{
			while( my( $name, $size ) = each %files )
			{
				$file_idx++;
				my $file_id = $id_base."_".$file_idx;
				$top_div->appendChild( my $div = $session->make_element(
					"${PREFIX}div"
				));
				$div->appendChild( $session->make_element(
					"${PREFIX}fptr",
					"FILEID" => $file_id
				));
			}
		}
		else
		{
			$file_idx++;
			my $file_id = $id_base."_".$file_idx;
			$top_div->appendChild( $session->make_element(
				"${PREFIX}fptr",
				"FILEID" => $file_id
			));
		}
	}
	
	return $structMap;
}

1;
