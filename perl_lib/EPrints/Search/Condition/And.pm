######################################################################
#
# EPrints::Search::Condition::And
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search::Condition::And> - Intersect results of several sub-conditions

=head1 DESCRIPTION

Intersect the results of sub-conditions.

=cut

package EPrints::Search::Condition::And;

use EPrints::Search::Condition::Control;
use Scalar::Util;

@ISA = qw( EPrints::Search::Condition::Control );

use strict;

my $MYSQL_MAX_SUBQUERIES = 10;

sub new
{
	my( $class, @params ) = @_;

	@params = grep { !$_->is_empty } @params;

	my $self = bless { op=>"AND", sub_ops=>\@params }, $class;

	return $self;
}

sub optimise_specific
{
	my( $self, %opts ) = @_;

	my $keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		# if an OR contains TRUE or an
		# AND contains FALSE then we can
		# cancel it all out.
		return $sub_op if $sub_op->{op} eq "FALSE";

		# just filter these out
		next if $sub_op->{op} eq "TRUE";
		
		push @{$keep_ops}, $sub_op;
	}
	$self->{sub_ops} = $keep_ops;

	return EPrints::Search::Condition::True->new() if $self->is_empty;

	return $self if @{$self->{sub_ops}} == 1;

	my $dataset = $opts{dataset};

	my %tables;
	$keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		my $table = $sub_op->table;
		# apply simple sub-ops directly to the main table
		if( !defined $table || $table eq $dataset->get_sql_table_name )
		{
			push @$keep_ops, $sub_op;
		}
		else
		{
			push @{$tables{$table}||=[]}, $sub_op;
		}
	}

	foreach my $table (keys %tables)
	{
		if( @{$tables{$table}} == 1 )
		{
			push @$keep_ops, @{$tables{$table}};
		}
		else
		{
			# mysql's optimizer goes squirly if we throw too many sub-queries
			# at it :-(
			if( $opts{session}->get_database->isa( "EPrints::Database::mysql" ) && @{$tables{$table}} > $MYSQL_MAX_SUBQUERIES )
			{
				do
				{
					push @$keep_ops, EPrints::Search::Condition::Or->new( 
						EPrints::Search::Condition::AndSubQuery->new(
							$tables{$table}->[0]->dataset,
							splice(@{$tables{$table}},0,$MYSQL_MAX_SUBQUERIES)
						) );
				} while( @{$tables{$table}} );
			}
			else
			{
				push @$keep_ops, EPrints::Search::Condition::AndSubQuery->new(
						$tables{$table}->[0]->dataset,
						@{$tables{$table}}
					);
			}
		}
	}
	$self->{sub_ops} = $keep_ops;

	return $self;
}

sub joins
{
	my( $self, %opts ) = @_;

	return map {
			$_->joins(%opts)
		} @{$self->{sub_ops}};
}

sub logic
{
	my( $self, %opts ) = @_;

	my @logic = map { $_->logic(%opts) } @{$self->{sub_ops}};
	return () if !@logic;

	return '('.join(" AND ", @logic).')';
}

sub table
{
	my( $self ) = @_;

	return undef;
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

