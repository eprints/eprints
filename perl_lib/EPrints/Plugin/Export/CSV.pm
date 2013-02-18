=head1 NAME

EPrints::Plugin::Export::CSV

=head1 DESCRIPTION

Subclass of MultilineCSV but exports only fields set "export_as_xml" and is publicly visible.

=cut

package EPrints::Plugin::Export::CSV;

use EPrints::Plugin::Export::MultilineCSV;

@ISA = ( "EPrints::Plugin::Export::MultilineCSV" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Multiline CSV";
	$self->{visible} = "all";
	
	return $self;
}

sub fields
{
	my( $self, $dataset ) = @_;

	# skip compound, subobjects
	return grep {
			$_->property("export_as_xml") &&
			!$_->is_virtual
		} 
		$dataset->fields;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

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

