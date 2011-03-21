=head1 NAME

EPrints::DataObj::Import::XML

=cut

######################################################################
#
# EPrints::DataObj::Import::XML
#
######################################################################
#
#
######################################################################

package EPrints::DataObj::Import::XML;

# This is a utility module for importing existing eprints from an XML file

use EPrints;

use strict;

use EPrints::Plugin::Import::XML;

our @ISA = qw( EPrints::Plugin::Import::XML );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{import} = $params{import};
	$self->{id} = "Import::XML"; # hack to make phrases work

	return $self;
}

sub epdata_to_dataobj
{
	my( $self, $dataset, $epdata ) = @_;

	my $dataobj = $self->{import}->epdata_to_dataobj( $dataset, $epdata );

	$self->handler->parsed( $epdata ); # TODO: parse-only import?
	$self->handler->object( $dataset, $dataobj );

	return $dataobj;
}

# suppress warnings, in particular that various imported fields don't exist
# in our repository
sub warning {}

1;

__END__


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

