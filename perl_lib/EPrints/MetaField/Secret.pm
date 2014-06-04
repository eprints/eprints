######################################################################
#
# EPrints::MetaField::Secret;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Secret> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Secret;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Id );
}

use EPrints::MetaField::Id;

sub get_property_defaults
{
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{repeat_secret} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{text_index} = 0;
	$defaults{sql_index} = 0;

	$defaults{export_as_xml} = 0;

	return %defaults;
}

sub get_sql_index
{
	my( $self ) = @_;

	return ();
}

sub get_search_group { return 'secret'; }  #!! can't really search secret

# REALLY don't index passwords!
sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

# sf2 - that's really a UI business - no?:
sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my @probs = $self->SUPER::validate( $session, $value, $object );

	if( $self->get_property( "repeat_secret" ) )
	{
		my $basename = $self->get_name;

		my $password = $session->param( $basename );
		my $confirm = $session->param( $basename."_confirm" );

		if( !length($password) || $password ne $confirm )
		{
			push @probs, $session->html_phrase( "validate:secret_mismatch" );
		}
	}

	return @probs;
}

sub to_sax
{
	my( $self, $value, %opts );

	return if !$opts{show_secrets};

	$self->SUPER::to_sax( $value, %opts );
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

