######################################################################
#
# EPrints::Search::Condition::InSubject
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

B<EPrints::Search::Condition::InSubject> - "InSubject" search condition

=head1 DESCRIPTION

Matches items which are in the subject or a sub-subject

=cut

package EPrints::Search::Condition::InSubject;

use EPrints::Search::Condition;

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition );
}

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




sub item_matches
{
	my( $self, $item ) = @_;

 	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	my @sub_ids = $self->{field}->list_values( 
		$item->get_value( $self->{field}->get_name ) );
	# true if {params}->[0] is the ancestor of any of the subjects
	# of the item.

	foreach my $sub_id ( @sub_ids )
	{
		my $s = EPrints::DataObj::Subject->new( 
				$item->get_session,
				$sub_id );	

		if( !defined $s )
		{
			$item->get_session->get_repository->log(
"Attempt to call item_matches on a searchfield with non-existant\n".
"subject id: '$_', item was #".$item->get_id );
			next;
		}

		foreach my $an_sub ( @{$s->get_value( "ancestors" )} )
		{
			return( 1 ) if( $an_sub eq $self->{params}->[0] );
		}
	}

	return( 0 );
}

sub get_tables
{
	my( $self, $session ) = @_;

	my $database = $session->get_database;
	my $tables = $self->SUPER::get_tables( $session );
	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	push @{$tables}, {
		left => $self->{field}->get_dataset->get_key_field->get_name, 
		right => $self->{field}->get_name,
		table => $self->{field}->get_property( "multiple" ) 
			? $self->{field}->get_dataset->get_sql_sub_table_name( $self->{field} )
			: $self->{field}->get_dataset->get_sql_table_name() 
	};
	push @{$tables}, {
		left => "subjectid",
		where => $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"ancestors")."=".$database->quote_value( $self->{params}->[0] ),
		table => 'subject_ancestors',
	};
		
	return $tables;
}

sub get_op_val
{
	return 4;
}

1;
