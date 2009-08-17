######################################################################
#
# EPrints::MetaField::Email;
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

B<EPrints::MetaField::Email> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Email;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub render_single_value
{
	my( $self, $handle, $value ) = @_;
	
	my $text = $handle->make_text( $value );

	return $text if !defined $value;
	return $text if( $self->{render_dont_link} );

	my $a = $handle->render_link( "mailto:".$value );
	$a->appendChild( $text );
	return $a;
}

sub get_index_codes
{
       my( $self, $handle, $value ) = @_;

       if( !$self->get_property( "multiple" ) )
       {
               return( [ $value ], [], [] );
       }
       return( $value, [], [] );
}

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

       return EPrints::Search::Condition->new( 
                       'index',
                       $dataset,
                       $self, 
                       $search_value );
}

sub render_search_value
{
       my( $self, $handle, $value ) = @_;

       my $valuedesc = $handle->make_doc_fragment;
       $valuedesc->appendChild( $handle->make_text( '"' ) );
       $valuedesc->appendChild( $handle->make_text( $value ) );
       $valuedesc->appendChild( $handle->make_text( '"' ) );

       return $valuedesc;
}

######################################################################
1;
