######################################################################
#
# EPrints::MetaField::Email;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Email> - no description

=head1 DESCRIPTION

Contains an Email address that is linked when rendered.

=over 4

=cut

package EPrints::MetaField::Email;

use EPrints::MetaField::Id;
@ISA = qw( EPrints::MetaField::Id );

use strict;

sub validate_value
{
	my( $self, $value ) = @_;
	
	return 1 if( !defined $value );

	return 0 if( !$self->SUPER::validate_value( $value ) );

        # sf2 - safer than using $self->property( 'multiple' );
        my $is_array = ref( $value ) eq 'ARRAY';

        my @valid_values;
        foreach my $single_value ( $is_array ?
                @$value :
                $value
        )
        {
		# trivial check - it could be much much more complex
                if( $single_value !~ /^.+\@.+\..+$/ )
                {
			$self->repository->debug_log( "field", "Invalid email '$single_value' passed to field ".$self->dataset->id."/".$self->name );
			return 0;
		}
	}

	return 1;
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

