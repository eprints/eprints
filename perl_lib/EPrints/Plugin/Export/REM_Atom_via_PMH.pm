######################################################################
#
# EPrints::Plugin::Export::REM_Atom_via_PMH
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Plugin::Export::REM_Atom_via_PMH> - Wrapper for OAI-PMH exportion of REM_Atom objects.

=head1 DESCRIPTION

This plugin enables REM_Atom maps to be discovered via the OAI2 PMH interface to EPrints.

=over 4

=cut
package EPrints::Plugin::Export::REM_Atom_via_PMH;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "OAI-ORE Resource Map - Atom Serialization";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "application/atom+xml";
	
	$self->{xmlns} = "http://www.w3.org/2005/Atom";
	$self->{schemaLocation} = "http://exyus.com/xcs/tasklist/source/?f=put_atom.xsd";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	my $resourceMap = EPrints::XML::to_string( $xml );

	EPrints::XML::dispose($xml);

	return $resourceMap;
}


sub xml_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $main_dc_plugin = $plugin->{handle}->plugin( "Export::REM_Atom" );

	my $data = $main_dc_plugin->output_dataobj( $dataobj, single => 1 );

	my $dc = $plugin->{handle}->make_element(
        	"atom:atom",
		"xmlns" => "http://www.w3.org/2005/Atom",
		"xmlns:atom" => "http://www.w3.org/2005/Atom",
        	"xmlns:dcterms" => "http://purl.org/dc/terms/",
		"xmlns:rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        	"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" =>
 	"http://www.w3.org/2005/Atom http://exyus.com/xcs/tasklist/source/?f=put_atom.xsd" );

	$dc->appendChild( $data );

	return $dc;
}


1;
