package EPrints::MetaField::State;

use EPrints::MetaField::Set;
@ISA = EPrints::MetaField::Set;

use strict;


# TODO should probably check the DS' valid states
sub validate_value_ISA
{
	my( $self, $value ) = @_;

	return 1 if( !defined $value );
	
	return 0 if( !$self->SUPER::validate_value( $value ) );

        my $is_array = ref( $value ) eq 'ARRAY';
		
	my %valid_options = map { $_ => undef } @{$self->property( 'options' )||[]};

        foreach my $single_value ( $is_array ?
                        @$value :
                        $value
        )
        {
		# type as in PERL data type - perhaps should be explicit
                if( !$self->validate_type( $value ) )
                {
                        return 0;
                }

		if( !exists $valid_options{$value} )
		{
			$self->repository->log( "Invalid set value passed to field ".$self->dataset->id."/".$self->name );
			return 0
		}
	}

	return 1;
}

sub set_value
{
	my( $self, $object, $value ) = @_;

	return $object->transfer( $value );
}

# the ordering for set is NOT the same as for normal
# fields.
sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my @tags = $self->tags( $session );

	return \@tags;
}


sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;

	$defaults{multiple} = 0;
	$defaults{states} = $EPrints::MetaField::REQUIRED;
	$defaults{options} = $EPrints::MetaField::UNDEF;

	return %defaults;
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

