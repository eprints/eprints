=head1 NAME

EPrints::Plugin::Export::XMLFiles

=cut

package EPrints::Plugin::Export::XMLFiles;

use EPrints::Plugin::Export::XML;

@ISA = ( "EPrints::Plugin::Export::XML" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "EP3 XML with Files Embedded";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];

	# this module outputs the files of an eprint with
	# no regard to the security settings so should be 
	# not made public without a very good reason.
	$self->{visible} = "staff";

	$self->{suffix} = ".xml";
	$self->{mimetype} .= '; files="base64"';
	$self->{qs} = 0.1;

	return $self;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	return $self->SUPER::output_dataobj( $dataobj, %opts, embed => 1 );
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

