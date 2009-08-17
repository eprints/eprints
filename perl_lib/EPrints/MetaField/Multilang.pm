######################################################################
#
# EPrints::MetaField::Multilang;
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

B<EPrints::MetaField::Multilang> - Subclass of compound for multilingual data.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Multilang;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Compound );
}

use EPrints::MetaField::Compound;

sub new
{
	my( $class, %properties ) = @_;

	my $langs = $properties{languages};
	if( !defined $properties{languages} )
	{
		my $repository =
			$properties{repository} ||
			$properties{archive} ||
			$properties{dataset}->get_repository;

		$langs = $repository->get_conf('languages');
	}

	push @{$properties{fields}}, {
			sub_name=>"lang",
			type=>"langid",
			options => $langs,
		};

	my $self = $class->SUPER::new( %properties );

	return $self;
}

sub get_search_conditions_not_ex
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	my $f = $self->get_property( "fields_cache" );
	my $first_name = $f->[0]->{name};
	my $field = $dataset->get_field( $first_name );
	return $field->get_search_conditions_not_ex( 
		$handle, $dataset,$search_value,$match,$merge,$search_mode );
}

sub render_value
{
	my( $self, $handle, $value, $alllangs, $nolink, $object ) = @_;

	if( $alllangs )
	{
		return $self->SUPER::render_value( 
				$handle,$value,$alllangs,$nolink,$object);
	}

	my $f = $self->get_property( "fields_cache" );
	my $first_name = $f->[0]->{name};

	my $map = $self->value_to_langhash( $value );

	my $best = $self->most_local( $handle, $map );

	my $field = $object->get_dataset->get_field( $first_name );
	return $field->render_single_value( $handle, $best );
}

sub value_to_langhash
{
	my( $self, $value ) = @_;

	my $f = $self->get_property( "fields_cache" );
	my $first_name = $f->[0]->{name};
	my %fieldname_to_alias = $self->get_fieldname_to_alias;
	my $map = ();
	foreach my $row ( @{$value} )
	{
		my $lang = $row->{lang};
		$lang = "undef" unless defined $lang;	
		$map->{$lang} = $row->{$fieldname_to_alias{$first_name}};
	}

	return $map;
}

sub ordervalue
{
	my( $self , $value , $handle , $langid, $dataset ) = @_;

	my $langhash = $self->value_to_langhash( $value );

	my $best = $self->most_local( $handle, $langhash );
	
	return $best;
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_ordered} = 0;
	$defaults{languages} = $EPrints::MetaField::UNDEF;
	$defaults{input_boxes} = 1;
	return %defaults;
}

######################################################################

######################################################################
1;
