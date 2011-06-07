=head1 NAME

EPrints::Plugin::Export::ContextObject::DublinCore

=cut

package EPrints::Plugin::Export::ContextObject::DublinCore;

use EPrints::Plugin::Export::OAI_DC;

use EPrints::Plugin::Export::ContextObject;

@ISA = ( "EPrints::Plugin::Export::ContextObject" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL DublinCore";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";

	return $self;
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $dc = $plugin->{session}->plugin( "Export::OAI_DC" );

	return $dc->xml_dataobj( $dataobj, %opts );
}

sub kev_dataobj
{
	my( $plugin, $dataobj, $ctx ) = @_;

	my $dc = $plugin->{session}->plugin( "Export::DC" );

	my $data = $dc->convert_dataobj( $dataobj );

	@$data = map { @$_ } @$data;

	$ctx->dublinCore(@$data);
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

