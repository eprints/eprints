######################################################################
#
# EPrints::Search::Condition::IsNotNull
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search::Condition::IsNull> - "IsNull" search condition

=head1 DESCRIPTION

Matches items where the field is not null.

=cut

package EPrints::Search::Condition::IsNotNull;

use EPrints::Search::Condition::Comparison;

@ISA = qw( EPrints::Search::Condition::Comparison );

use strict;

sub new
{
	my( $class, @params ) = @_;

	return $class->SUPER::new( "is_not_null", @params );
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

	my @sql_and = ();
	foreach my $col_name ( $self->{field}->get_sql_names )
	{
		push @sql_and,
			$db->quote_identifier( $table, $col_name )." != ''";
	}
	return "( ".join( " OR ", @sql_and ).")";
}

1;
