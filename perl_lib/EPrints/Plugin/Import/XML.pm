=head1 NAME

EPrints::Plugin::Import::XML

=cut

package EPrints::Plugin::Import::XML;

use strict;

use EPrints::Plugin::Import::DefaultXML;

our @ISA = qw/ EPrints::Plugin::Import::DefaultXML /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "XML";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/*', 'dataobj/*' ];
	$self->{accept} = ["application/xml; charset=utf-8", "sword:http://eprints.org/ep2/data/2.0"];

	return $self;
}

sub top_level_tag
{
	my( $plugin, $dataset ) = @_;

	return $dataset->confid."s";
}

sub unknown_start_element
{
	my( $self, $found, $expected ) = @_;

	if( $found eq "eprintsdata" ) 
	{
		$self->warning( "You appear to be attempting to import an EPrints 2 XML file!\nThis importer only handles v3 files. Use the migration toolkit to convert!\n" );
	}
	$self->SUPER::unknown_start_element( @_[1..$#_] );
}

sub xml_to_epdata
{
	my( $plugin, $dataset, $xml, %opts ) = @_;

	my $epdata = $dataset->get_object_class->xml_to_epdata(
		$plugin->{session},
		$xml,
		%opts,
		Handler => $plugin->{Handler} );

	return $epdata;
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

