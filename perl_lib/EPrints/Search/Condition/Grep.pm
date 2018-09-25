######################################################################
#
# EPrints::Search::Condition::Grep
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search::Condition::Grep> - "Grep" search condition

=head1 DESCRIPTION

Filter using a grep table

=cut

package EPrints::Search::Condition::Grep;

use EPrints::Search::Condition::Index;

@ISA = qw( EPrints::Search::Condition::Index );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{op} = "grep";
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}

sub table
{
	my( $self ) = @_;

	return undef if( !defined $self->{field} );

	return $self->{field}->{dataset}->get_sql_grep_table_name;
}

sub logic
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;
	if( !$self->{field}->get_property( "multiple" ) )
	{
		$prefix = "";
	}

	my $db = $opts{session}->get_database;
	my $table = $prefix . $self->table;
	my $sql_name = $self->{field}->get_sql_name;

	my @logic;
	foreach my $cond (@{$self->{params}})
	{
		push @logic, sprintf("%s LIKE %s",
			$db->quote_identifier( $table, "grepstring" ),
			$db->quote_value( $cond ) );
	}

	return sprintf( "%s=%s AND (%s)",
		$db->quote_identifier( $table, "fieldname" ),
		$db->quote_value( $sql_name ),
		join(" OR ", @logic));
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

