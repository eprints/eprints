=head1 NAME

EPrints::Plugin::Export::DIDL

=head1 DESCRIPTION

Based on L<http://wiki.surffoundation.nl/display/DRIVERguidelines/Use+of+MPEG-21+DIDL+%28xml-container%29+-+Compound+object+wrapping>.

=cut

package EPrints::Plugin::Export::DIDL;

use EPrints v3.3.0;
use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "MPEG-21 DIDL";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";

	$self->{metadataPrefix} = "didl";
	$self->{xmlns} = "urn:mpeg:mpeg21:2002:02-DIDL-NS",
	$self->{schemaLocation} = "http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/did/didl.xsd";

	return $self;
}



sub xml_dataobj
{
	my( $self, $eprint, %opts ) = @_;

	my $xml = $self->{repository}->xml;

	my $didl = $xml->create_element( 
		"didl:DIDL",
		DIDLDocumentId=>$eprint->uri,
		qw(
			xmlns:xsi	http://www.w3.org/2001/XMLSchema-instance
			xmlns:didl	urn:mpeg:mpeg21:2002:02-DIDL-NS
			xmlns:dii	urn:mpeg:mpeg21:2002:01-DII-NS
			xmlns:dip	urn:mpeg:mpeg21:2002:01-DIP-NS
			xmlns:dcterms	http://purl.org/dc/terms/
		),
		"xsi:schemaLocation"=>join(' ', qw(
			urn:mpeg:mpeg21:2002:02-DIDL-NS http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/did/didl.xsd
			urn:mpeg:mpeg21:2002:01-DII-NS http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/dii/dii.xsd
			urn:mpeg:mpeg21:2005:01-DIP-NS http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-21_schema_files/dip/dip.xsd
		)),
	);
	my $item = $xml->create_element( "didl:Item" );
	$didl->appendChild( $item );


	$item->appendChild( $xml->create_data_element( "didl:Descriptor", [
			[
				"didl:Statement", [ 
					[ "dii:Identifier", $eprint->uri ],
				], mimeType => "application/xml"
			],
		] ) );

	my $modified = $eprint->value( "lastmod" );
	$modified =~ s/ /T/;
	$modified =~ s/Z?$/Z/;

	$item->appendChild( $xml->create_data_element( "didl:Descriptor", [
			[
				"didl:Statement", [ 
					[ "dcterms:modified", $modified ],
				], mimeType => "application/xml"
			],
		] ) );

	$item->appendChild( $xml->create_data_element( "didl:Component", [
			[
				"didl:Resource",
					[],
				mimeType => "application/xml",
				ref => $self->dataobj_export_url( $eprint )
			],
		] ) );

	my $iitem = $item->appendChild( $xml->create_element( "didl:Item" ) );

	$iitem->appendChild( $xml->create_data_element( "didl:Descriptor", [
			[
				"didl:Statement", [
					[ "dip:ObjectType", "info:eu-repo/semantics/descriptiveMetadata" ],
				], mimeType => "application/xml",
			],
		] ) );

	my $dc_plugin = $self->{session}->plugin( "Export::OAI_DC" );

	$iitem->appendChild( $xml->create_data_element( "didl:Component", [
			[
				"didl:Resource",
					$dc_plugin->xml_dataobj( $eprint, %opts ),
				mimeType => "application/xml",
			],
		] ) );

	foreach my $doc ( $eprint->get_all_documents )
	{
		my $iitem = $item->appendChild( $xml->create_element( "didl:Item" ) );

		$iitem->appendChild( $xml->create_data_element( "didl:Descriptor", [
				[
					"didl:Statement", [
						[ "dip:ObjectType", "info:eu-repo/semantics/objectFile" ]
					], mimeType => "application/xml"
				],
			] ) );

		$iitem->appendChild( $xml->create_data_element( "didl:Component", [
				[
					"didl:Resource",
						[],
					mimeType => $doc->value( "format" ),
					ref => $doc->get_url(),
				],
			] ) );
	}

	$iitem = $item->appendChild( $xml->create_element( "didl:Item" ) );

	$iitem->appendChild( $xml->create_data_element( "didl:Descriptor", [
			[
				"didl:Statement", [
					[ "dip:ObjectType", "info:eu-repo/semantics/humanStartPage" ]
				], mimeType => "application/xml"
			],
		] ) );

	$iitem->appendChild( $xml->create_data_element( "didl:Component", [
			[
				"didl:Resource",
					[],
				mimeType => "application/html",
				ref => $eprint->get_url
			],
		] ) );

	return $didl;
}

sub output_dataobj
{
	my( $self, $dataobj ) = @_;

	my $didl = $self->xml_dataobj( $dataobj );

	my $r = $self->{repository}->xml->to_string( $didl, indent => 1 );
	$self->{repository}->xml->dispose( $didl );

	return $r;
}


1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

