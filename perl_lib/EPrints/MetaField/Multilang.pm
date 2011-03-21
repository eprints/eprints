######################################################################
#
# EPrints::MetaField::Multilang;
#
######################################################################
#
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

		$properties{languages} = $repository->get_conf('languages');
	}

	my $self = $class->SUPER::new( %properties );

	return $self;
}

sub extra_subfields
{
	my( $self ) = @_;

	return (
		{ sub_name=>"lang", type=>"langid", options => $self->property( "languages" ) },
	);
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	my $f = $self->get_property( "fields_cache" );
	my $first_name = $f->[0]->{name};
	my $field = $dataset->get_field( $first_name );
	return $field->get_search_conditions_not_ex( 
		$session, $dataset,$search_value,$match,$merge,$search_mode );
}

sub render_value
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

	if( $alllangs )
	{
		return $self->SUPER::render_value( 
				$session,$value,$alllangs,$nolink,$object);
	}

	my $f = $self->get_property( "fields_cache" );
	my $first_name = $f->[0]->{name};

	my $map = $self->value_to_langhash( $value );

	my $best = $self->most_local( $session, $map );

	my $field = $object->get_dataset->get_field( $first_name );
	return $field->render_single_value( $session, $best );
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
	my( $self , $value , $session , $langid, $dataset ) = @_;

	my $langhash = $self->value_to_langhash( $value );

	my $best = $self->most_local( $session, $langhash );
	
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

