=head1 NAME

EPrints::Plugin::Export::FOAF

=cut

package EPrints::Plugin::Export::FOAF;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "FOAF Export";
	$self->{accept} = [ 'dataobj/user' ];
	$self->{visible} = "all";
	$self->{suffix} = ".rdf";
	$self->{mimetype} = "text/xml";
	
	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $session = $plugin->{session};
	
	my $response = $session->make_element( "rdf:RDF",
		"xmlns:rdf"=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#",
		"xmlns:rdfs"=>"http://www.w3.org/2000/01/rdf-schema#",
		"xmlns:foaf"=>"http://xmlns.com/foaf/0.1/",
		"xmlns:dc"=>"http://purl.org/dc/elements/1.1/" );

	my $person = $session->make_element( "foaf:Person" );
	
	my %fields = (
		nick => $session->make_text( $dataobj->get_value( "username" ) ),
		name => $dataobj->render_value( "name" ),
	);

	foreach my $field ( keys %fields )
	{
		my $el = $session->make_element( "foaf:$field" );
		$el->appendChild( $fields{$field} );
		$person->appendChild( $el );
	}

	$response->appendChild( $person );

	my $foaf = <<END;
<?xml version="1.0" encoding="utf-8" ?>
END
	$foaf.= EPrints::XML::to_string( $response );
	EPrints::XML::dispose( $response );
	
	return $foaf;
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

