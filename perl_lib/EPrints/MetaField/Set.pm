######################################################################
#
# EPrints::MetaField::Set;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Set> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Set;

use EPrints::MetaField::Text;
@ISA = EPrints::MetaField::Text;

use strict;


sub validate_value
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
			$self->repository->debug_log( "field", "Invalid set value passed to field ".$self->dataset->id."/".$self->name );
			return 0
		}
	}

	return 1;
}






sub set_value
{
	my( $self, $object, $value ) = @_;

	if( $self->get_property( "multiple" ) && !$self->get_property( "sub_name" ) )
	{
		$value = [] if !defined $value;
		my %seen;
		@$value = grep {
			EPrints::Utils::is_set( $_ ) # multiple values must be defined
			&& !$seen{$_}++ # set values must be unique
		} @$value;
	}

	return $self->SUPER::set_value( $object, $value );
}

sub tags
{
	my( $self, $session ) = @_;
	EPrints::abort( "no options in tags()" ) if( !defined $self->{options} );
	return @{$self->{options}};
}

# the ordering for set is NOT the same as for normal
# fields.
sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my @tags = $self->tags( $session );

	return \@tags;
}

sub ordervalue_basic
{
	my( $self , $value , $session , $langid ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	my $label = $self->get_value_label( $session, $value );
	return EPrints::Utils::tree_to_utf8( $label );
}

sub split_search_value
{
	my( $self, $session, $value ) = @_;

	return $self->EPrints::MetaField::split_search_value( $session, $value );
}

sub get_search_group { return 'set'; }

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{options} = $EPrints::MetaField::REQUIRED;
	$defaults{text_index} = 0;
	$defaults{sql_index} = 1;
	$defaults{match} = "EQ";
	$defaults{merge} = "ANY";
	$defaults{order_labels} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	my( $self ) = @_;

	return $self->get_xml_schema_field_type;
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my( $tags, $labels ) = $self->tags_and_labels( $session );

	my $restriction = $session->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	foreach my $value (@$tags)
	{
		my $enumeration = $session->make_element( "xs:enumeration", value => $value );
		$restriction->appendChild( $enumeration );
		if( defined $labels->{$value} )
		{
			my $annotation = $session->make_element( "xs:annotation" );
			$enumeration->appendChild( $annotation );
			my $documentation = $session->make_element( "xs:documentation" );
			$annotation->appendChild( $documentation );
			$documentation->appendChild( $session->make_text( $labels->{$value} ) );
		}
	}

	return $type;
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

