######################################################################
#
# EPrints::MetaField::Text;
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

B<EPrints::MetaField::Text> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Text;

use strict;
use warnings;

use EPrints::MetaField;

BEGIN
{
	our( @ISA );
	@ISA = qw( EPrints::MetaField );
}



sub render_search_value
{
	my( $self, $handle, $value ) = @_;

	my $valuedesc = $handle->make_doc_fragment;
	$valuedesc->appendChild( $handle->make_text( '"' ) );
	$valuedesc->appendChild( $handle->make_text( $value ) );
	$valuedesc->appendChild( $handle->make_text( '"' ) );
	my( $good, $bad ) = _extract_words( $handle, $value );

	if( scalar(@{$bad}) )
	{
		my $igfrag = $handle->make_doc_fragment;
		for( my $i=0; $i<scalar(@{$bad}); $i++ )
		{
			if( $i>0 )
			{
				$igfrag->appendChild(
					$handle->make_text( 
						', ' ) );
			}
			$igfrag->appendChild(
				$handle->make_text( 
					'"'.$bad->[$i].'"' ) );
		}
		$valuedesc->appendChild( 
			$handle->html_phrase( 
				"lib/searchfield:desc_ignored",
				list => $igfrag ) );
	}

	return $valuedesc;
}


#sub split_search_value
#{
#	my( $self, $handle, $value ) = @_;
#
#	my( $codes, $bad ) = _extract_words( $handle, $value );
#
#	return @{$codes};
#}

sub get_search_conditions_not_ex
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
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

	# apply stemming and stuff
	my( $codes, $bad ) = _extract_words( $handle, $search_value );

	# Just go "yeah" if stemming removed the word
	if( !EPrints::Utils::is_set( $codes->[0] ) )
	{
		return EPrints::Search::Condition->new( "PASS" );
	}

	return EPrints::Search::Condition->new( 
			'index',
 			$dataset,
			$self, 
			$codes->[0] );
}

sub get_search_group { return 'text'; }

sub get_index_codes
{
	my( $self, $handle, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	if( !$self->get_property( "multiple" ) )
	{
		return $self->get_index_codes_basic( $handle, $value );
	}
	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );
	foreach my $v (@{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_basic( $handle, $v );
		push @{$codes},@{$c};
		push @{$grepcodes},@{$g};
		push @{$ignored},@{$i};
	}

	return( $codes, $grepcodes, $ignored );
}

sub get_index_codes_basic
{
	my( $self, $handle, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	my( $codes, $badwords ) = _extract_words( $handle, $value );

	return( $codes, [], $badwords );
}

# internal function to paper over some cracks in 2.2 
# text indexing config.
sub _extract_words
{
	my( $handle, $value ) = @_;

	my( $codes, $badwords ) = 
		$handle->get_repository->call( 
			"extract_words" ,
			$handle,
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
	return %defaults;
}

######################################################################
=pod

=item $val = $field->value_from_sql_row( $handle, $row )

Shift and return the utf8 value of this field from the database input $row.

=cut
######################################################################

sub value_from_sql_row
{
	my( $self, $handle, $row ) = @_;

	utf8::decode( $row->[0] );

	return shift @$row;
}

######################################################################
1;
