######################################################################
#
# EPrints::Search::Condition::InSubject
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search::Condition::InSubject> - "InSubject" search condition

=head1 DESCRIPTION

Matches items which are in the subject or a sub-subject

=cut

package EPrints::Search::Condition::InSubject;

use EPrints::Search::Condition::Comparison;

@ISA = qw( EPrints::Search::Condition::Comparison );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{op} = "in_subject";
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = Scalar::Util::refaddr($self) if !defined $prefix;

	my $db = $opts{session}->get_database;
	my $sql_name = $self->{field}->get_sql_name;

	my( $join ) = $self->SUPER::joins( %opts );

	if( defined $join )
	{
		return ($join, {
			type => "inner",
			table => "subject_ancestors",
			alias => "${prefix}subject_ancestors",
			logic => $db->quote_identifier( $join->{alias}, $sql_name )."=".$db->quote_identifier( "${prefix}subject_ancestors", "subjectid" ),
		});
	}
	else
	{
		my $main_table = $opts{dataset}->get_sql_table_name;
		my $alias = $main_table."_".Scalar::Util::refaddr($self);
		my $ancestors_alias = "${prefix}subject_ancestors";
		my $key_field = $opts{dataset}->get_key_field;
		my $sql = "";
		$sql = $db->quote_identifier( $main_table ).$db->sql_AS.$db->quote_identifier( $alias );
		$sql .= " INNER JOIN ".$db->quote_identifier( "subject_ancestors" );
		$sql .= $db->sql_AS.$db->quote_identifier( $ancestors_alias );
		$sql .= " ON ".$db->quote_identifier( $alias, $sql_name )."=".$db->quote_identifier( $ancestors_alias, "subjectid" );
		return {
			type => "inner",
			subquery => $sql,
			key => $key_field->get_sql_name,
			logic => $db->quote_identifier( $opts{dataset}->get_sql_table_name, $key_field->get_sql_name )."=".$db->quote_identifier( $alias, $key_field->get_sql_name ),
		};
	}
}

sub logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;

	my $prefix = $opts{prefix};
	$prefix = Scalar::Util::refaddr($self) if !defined $prefix;

	return $db->quote_identifier( "${prefix}subject_ancestors", "ancestors" )." = ".$db->quote_value( $self->{params}->[0] );
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

