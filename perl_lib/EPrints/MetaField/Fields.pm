######################################################################
#
# EPrints::MetaField::Fields;
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

B<EPrints::MetaField::Fields> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# set_name

package EPrints::MetaField::Fields;

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

	my @tags = $self->get_unsorted_values( $session );

	return sort {
		EPrints::Utils::tree_to_utf8( $self->render_option( $session, $a ) ) cmp
		EPrints::Utils::tree_to_utf8( $self->render_option( $session, $b ) ) 
	} @tags;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $ds = $session->get_repository->get_dataset( 
			$self->get_property('datasetid') );

	my @types = ();
	foreach my $field ( $ds->get_fields )
	{
		next unless $field->get_property( "show_in_fieldlist" );
		push @types, $field->get_name;
	}

	return @types;
}

# this method uses a dirty little cache to make things run much faster.
sub render_option
{
	my( $self, $session, $value ) = @_;

	if( !defined $value ) { return $self->SUPER::render_option( $session, undef ); }
	my $cacheid = $self->get_property('datasetid').".".$value;

	my $text = $session->{cache_metafield_options}->{$cacheid};
	if( defined $text )
	{
		return $session->make_text( $text );
	}
	my $ds = $session->get_repository->get_dataset( 
			$self->get_property('datasetid') );

	my $field = $ds->get_field( $value );
	$text = EPrints::Utils::tree_to_utf8( $field->render_name( $session ) );
	$session->{cache_metafield_options}->{$cacheid} = $text;

	return $session->make_text( $text );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}

sub get_search_group { return 'set'; }



######################################################################
1;
