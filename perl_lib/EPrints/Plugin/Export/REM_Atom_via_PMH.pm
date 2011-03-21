######################################################################
#
# EPrints::Plugin::Export::REM_Atom_via_PMH
#
######################################################################
#
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

	my $main_plugin = $plugin->{session}->plugin( "Export::REM_Atom" );

	my $data = $main_plugin->xml_dataobj( $dataobj, single => 1 );

	my $dc = $plugin->{session}->make_element(
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

