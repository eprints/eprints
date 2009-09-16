######################################################################
#
# EPrints::MetaField::Arclanguage;
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

B<EPrints::MetaField::Arclanguage> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# type_set

package EPrints::MetaField::Arclanguage;

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
	my( $self, $session ) = @_;

	return @{$session->get_repository->get_conf( "languages" )};
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return @{$session->get_repository->get_conf( "languages" )};
}

sub render_option
{
	my( $self, $session, $value ) = @_;

	return $session->render_type_name( 'languages', $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}



######################################################################
1;
