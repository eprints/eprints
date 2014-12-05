=head1 NAME

EPrints::Plugin::Export::Subject

=cut

package EPrints::Plugin::Export::Subject;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Subjects file";
	$self->{accept} = [ 'dataobj/subject', 'list/subject' ];
	$self->{visible} = "all";
	$self->{suffix} = ".txt";
	$self->{mimetype} = "text/plain; charset=utf-8";
	
	return $self;
}

sub output_dataobj
{
	my( $self, $dataobj ) = @_;

	my @parts;

	push @parts, $dataobj->get_id;
	my $names = $dataobj->get_value( "name_name" );
	if( EPrints::Utils::is_set( $names ) )
	{
		push @parts, $names->[0];
	}
	else
	{
		push @parts, "";
	}
	my $parents = $dataobj->get_value( "parents" );
	push @parts, join ",", @$parents;
	push @parts, $dataobj->is_set( "depositable" ) && $dataobj->get_value( "depositable" ) eq "TRUE" ? "1" : "0";

	# percent-encode ":" to "%3A"
	@parts = map { s/:/%3A/g } @parts;

	return join(":", @parts)."\n";
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

