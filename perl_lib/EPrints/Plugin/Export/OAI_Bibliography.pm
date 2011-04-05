=head1 NAME

EPrints::Plugin::Export::OAI_Bibliography

=cut

package EPrints::Plugin::Export::OAI_Bibliography;

use EPrints::Plugin::Export::OAI_DC;
@ISA = qw( EPrints::Plugin::Export::OAI_DC );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "DC Bibliography - OAI Schema";
	$self->{accept} = [qw( dataobj/eprint )];
	$self->{visible} = "";

	$self->{metadataPrefix} = "oai_bibl";

	return $self;
}

sub xml_dataobj
{
	my( $self, $dataobj ) = @_;

	my $plugin = $self->{session}->plugin( "Export::Bibliography" );

	my $refs = $plugin->convert_dataobj( $dataobj );

	my $dc = $self->{session}->make_element(
		"oai_dc:dc",
		"xmlns:oai_dc" => $self->{xmlns},
		"xmlns:dc" => "http://purl.org/dc/elements/1.1/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => join(" ", $self->{xmlns}, $self->{schemaLocation} ),
	);

	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the DC element.
	for( @$refs )
	{
		my $value = $_;
		if( ref($value) && $value->isa( "EPrints::DataObj::EPrint" ) )
		{
			$value = $value->export( "COinS" );
		}
		$dc->appendChild(  $self->{session}->render_data_element( 8, "dc:relation", $value ) );
		# produces <key>value</key>
	}

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

