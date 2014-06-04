######################################################################
#
# EPrints::MetaField::Text;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Text> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Text;

use EPrints::MetaField::Id;

@ISA = qw( EPrints::MetaField::Id );

use strict;

sub get_search_group { return 'text'; }

sub get_index_codes_basic
{
	my( $self, $repository, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	my( $codes, $badwords ) = _extract_words( $repository, $value );
	$_ = lc($_) for @$codes;

	return( $codes, [], $badwords );
}

# internal function to paper over some cracks in 2.2 
# text indexing config.
sub _extract_words
{
	my( $repository, $value ) = @_;

	my( $codes, $badwords ) = 
		$repository->call( 
			"extract_words" ,
			$repository,
			$value );
	my $newbadwords = [];
	foreach( @{$badwords} ) 
	{ 
		next if( $_ eq "" );
		push @{$newbadwords}, $_;
	}
	return( $codes, $newbadwords );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 1;
	$defaults{sql_index} = 0;
	$defaults{match} = "IN";
	return %defaults;
}

=item $cond = $field->get_search_conditions_not_ex( $repository, $dataset, $value, $match, $merge, $mode )

Return the search condition for a search which is not-exact ($match ne "EX").

If match is "IN" $value is split into terms and the first term is used as an index lookup.

=cut

sub get_search_conditions_not_ex
{
	my( $self, $repository, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	if( $match eq "EQ" )
	{
		return EPrints::Search::Condition->new( 
			'=', 
			$dataset,
			$self, 
			$search_value );
	}

	# free text!
	if( !$self->dataset->indexable )
	{
		EPrints->abort( "Can't perform index search on ".$self->dataset->id.".".$self->name." when the ".$self->dataset->id." dataset is not set as indexable" );
	}

	# apply stemming and stuff
	# codes, grep_terms, bad
	my( $codes, undef, undef ) = $self->get_index_codes( $repository,
		$self->property( "multiple" ) ? [$search_value] : $search_value );

	# Just go "yeah" if stemming removed the word
	if( !EPrints::Utils::is_set( $codes->[0] ) )
	{
		return EPrints::Search::Condition->new( "PASS" );
	}

	if( $search_value =~ s/\*$// )
	{
		return EPrints::Search::Condition::IndexStart->new( 
				$dataset,
				$self, 
				$codes->[0] );
	}
	else
	{
		return EPrints::Search::Condition::Index->new( 
				$dataset,
				$self, 
				$codes->[0] );
	}
}

######################################################################
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

