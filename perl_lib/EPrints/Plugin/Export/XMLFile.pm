=head1 NAME

EPrints::Plugin::Export::XMLFile

=cut

package EPrints::Plugin::Export::XMLFile;

# This virtual super-class supports Unicode output

our @ISA = qw( EPrints::Plugin::Export );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{suffix} = ".xml";

	return $self;
}

sub mime_type { shift->SUPER::mime_type() . '+xml; charset=utf-8' }

sub initialise_fh
{
	my( $plugin, $fh ) = @_;

	binmode($fh, ":utf8");
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $xml = $self->xml_dataobj( $dataobj, %opts );
	my $r = EPrints::XML::to_string( $xml );
	EPrints::XML::dispose( $xml );

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

