package EPrints::MetaField::Privs;

use strict;
use warnings;
use EPrints::MetaField::Subobject;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Subobject );
}

######################################################################

sub get_property_defaults
{
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = "acl";	
	$defaults{dataset_fieldname} = "datasetid";
	$defaults{dataobj_fieldname} = "objectid";
	$defaults{multiple} = 1;
	$defaults{text_index} = 0;
	
	return %defaults;
}


sub set_value
{
	my( $self, $dataobj, $value ) = @_;

	if( !defined $value )
	{
		# should delete any related file-dataobj's whether single of multiple
	}


	# don't populate changed nor perform an _equal for object caching
	$dataobj->{data}->{$self->get_name} = $value;
}

sub value
{
	my( $self, $parent ) = @_;

	# sf2 TODO is this relevant to Privs?	
	# parent doesn't have an id defined
	return $self->property( "multiple" ) ? [] : undef
		if( !defined $parent || !EPrints::Utils::is_set( $parent->id ) );

	# sf2 TODO check parent is a User object?

	my $acl_list = $self->repository->dataset( 'acl' )->search(
		filters => [
                                {
                                        meta_fields => [qw( userid )],
                                        value => $parent->id,
                                        match => "EX",
                                }
	] );

	my @acls = $acl_list->slice;
	my @privs;

	foreach my $acl ( @acls )
	{
		my $priv = $acl->value( 'priv' ) or next;
		push @privs, $priv;
	}

	return \@privs;
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

