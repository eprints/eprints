######################################################################
#
# EPrints::MetaField::Namedset;
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

B<EPrints::MetaField::Namedset> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# set_name

package EPrints::MetaField::Namedset;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;

sub tags
{
	my( $self, $handle ) = @_;

	if( defined $self->{options} )
	{
		return @{$self->{options}};
	}
	return $handle->get_repository->get_types( $self->{set_name} );
}

sub get_unsorted_values
{
	my( $self, $handle, $dataset, %opts ) = @_;

	if( defined $self->{options} )
	{
		return @{$self->{options}};
	}
	my @types = $handle->get_repository->get_types( $self->{set_name} );

	return @types;
}

sub render_option
{
	my( $self, $handle, $value ) = @_;

	if( !defined $value )
	{
		return $self->SUPER::render_option( $handle, $value );
	}

	return $handle->render_type_name( $self->{set_name}, $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{set_name} = $EPrints::MetaField::REQUIRED;
	$defaults{options} = $EPrints::MetaField::UNDEF;
	return %defaults;
}

sub get_search_group { return 'set'; }



######################################################################
1;
