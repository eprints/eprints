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

sub _item_matches
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

sub get_op_val
{
	return 4;
}

sub get_query_joins
{
	my( $self, $joins, %opts ) = @_;

	my $field = $self->{field};
	my $dataset = $field->{dataset};

	$joins->{$dataset->confid} ||= { dataset => $dataset };
	$joins->{$dataset->confid}->{'multiple'} ||= [];

	if( $field->get_property( "multiple" ) )
	{
		my $table = $dataset->get_sql_sub_table_name( $field );
		my $idx = scalar(@{$joins->{$dataset->confid}->{'multiple'}});
		my $sub_alias = $idx . "_" . $table;
		push @{$joins->{$dataset->confid}->{'multiple'}}, {
			table => $table,
			alias => $sub_alias,
			key => $dataset->get_key_field->get_sql_name,
			inner => [$self->{join} = {
				table => "subject_ancestors",
				alias => $idx . "_" . $table . "_subject",
				key => $field->get_sql_name,
				right_key => "subjectid",
			}],
		};
	}
	else
	{
		my $table = "subject_ancestors";
		my $idx = scalar(@{$joins->{$dataset->confid}->{'multiple'}});
		push @{$joins->{$dataset->confid}->{'multiple'}}, $self->{join} = {
			table => $table,
			alias => $idx . "_" . $table,
			key => $field->get_sql_name,
			right_key => "subjectid",
		};
	}
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $dataset = $field->{dataset};

	my $q_table = $db->quote_identifier($self->{join}->{alias});
	my $q_name = $db->quote_identifier("ancestors");
	my $q_value = $db->quote_value( $self->{params}->[0] );

	return "$q_table.$q_name = $q_value";
}

sub joins
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;

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
		my $alias = $main_table."_".refaddr($self);
		my $key_field = $opts{dataset}->get_key_field;
		my $sql = "";
		$sql = $db->quote_identifier( $main_table )." ".$db->quote_identifier( $alias );
		$sql .= " INNER JOIN ".$db->quote_identifier( "subject_ancestors" );
		$sql .= " ON ".$db->quote_identifier( $main_table, $sql_name )."=".$db->quote_identifier( "subject_ancestors", "subjectid" );
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

	return $db->quote_identifier( "subject_ancestors", "ancestors" )." = ".$db->quote_value( $self->{params}->[0] );
}

1;
