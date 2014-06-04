######################################################################
#
# EPrints::MetaField::Itemref;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Itemref> - Reference to an object with an "int" type of ID field.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Dataobjref;

use EPrints::MetaField::Compound;
@ISA = qw( EPrints::MetaField::Compound );

use strict;

sub new
{
	my( $class, %properties ) = @_;

	my $self = $class->SUPER::new( %properties );

	return $self;
}

sub extra_subfields
{
	my( $self ) = @_;

	return (
		{ sub_name=>"id", type=>"int", input_cols=>6, },
	);
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	$defaults{match} = "IN";
	$defaults{text_index} = 1;
	return %defaults;
}

sub _dataset
{
	my( $self ) = @_;

	return $self->{repository}->dataset( $self->get_property('datasetid') );
}

sub get_item
{
	my ($self, $session, $value) = @_;

	return $self->dataobj($value);
}

sub dataobj
{
	my( $self, $value ) = @_;

	return undef if !defined $value;

	return $self->_dataset->dataobj( $value->{id} );
}

sub get_search_conditions
{
	return shift->EPrints::MetaField::Subobject::get_search_conditions(@_);
}

# Compound ignores get_index_codes()
sub get_index_codes
{
	return shift->EPrints::MetaField::get_index_codes(@_);
}

sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	my @codes;

	my $dataobj = $self->dataobj($value);

	if (defined $dataobj)
	{
		my $dataset = $dataobj->{dataset};
		foreach my $field ($dataset->fields)
		{
			# avoids deep recursion if we have a circular relationship
			next if( $field->isa( "EPrints::MetaField::Dataobjref" ) && 
					$field->dataset->id eq $self->_dataset->id );

			my ($codes) = $field->get_index_codes(
				$session,
				$field->value($dataobj)
			);
			push @codes, @$codes;
		}
	}
	else
	{
		foreach my $field (@{$self->property('fields_cache')})
		{
			my ($codes) = $field->get_index_codes_basic(
				$session,
				$value->{$field->property('sub_name')}
			);
			push @codes, @$codes;
		}
	}

	return( \@codes, [], [] );
}

######################################################################
1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2013 University of Southampton.

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

