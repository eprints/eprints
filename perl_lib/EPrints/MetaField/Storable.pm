######################################################################
#
# EPrints::MetaField::Storable;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Storable> - serialise/unserialise Perl structures

=head1 DESCRIPTION

This field supports arbitrary Perl data structures by serialising them using L<Storable>, up to the length of L<EPrints::MetaField::Longtext>.

When serialised into XML the values are further encoded in Base64 to avoid any problems with invalid XML character data being emitted by Storable.

This field does B<not> support storing simple scalars ("Hello, World!").

=over 4

=cut

package EPrints::MetaField::Storable;

use Storable qw();
use MIME::Base64 qw();
use EPrints::MetaField;

@ISA = qw( EPrints::MetaField );

use strict;

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 0;
	$defaults{sql_index} = 0;
	return %defaults;
}

sub get_sql_type
{
	my( $self, $session ) = @_;

	my $database = $session->get_database;

	return $database->get_column_type(
		$self->get_sql_name,
		EPrints::Database::SQL_LONGVARBINARY,
		!$self->get_property( "allow_null" ),
		undef, # maxlength
		undef, # precision
		$self->get_sql_properties,
	);
}

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	my $value = shift @$row;

	return undef unless defined $value;

	return $self->thaw( $session, $value );
}

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	return undef unless defined $value;

	return $session->database->quote_binary( $self->freeze( $session, $value ) );
}

sub to_sax
{
	my( $self, $value, %opts ) = @_;

	# can't freeze undef
	return if !EPrints::Utils::is_set( $value );

	$self->SUPER::to_sax( MIME::Base64::encode_base64($self->freeze( $self->{repository}, $value )), %opts );
}

sub end_element
{
	my( $self, $data, $epdata, $state ) = @_;

	if( $state->{depth} == 1 )
	{
		my $value = $epdata->{$self->name};
		for(ref($value) eq "ARRAY" ? @$value : $value)
		{
			$_ = MIME::Base64::decode_base64( $_ );
			$_ = $self->thaw( $self->{repository}, $_ );
		}
		$epdata->{$self->name} = $value;
	}

	$self->SUPER::end_element( $data, $epdata, $state );
}

sub freeze
{
	my( $class, $session, $value ) = @_;

	local $Storable::canonical = 1;

	if( !ref($value) )
	{
		EPrints::abort( "Asked to freeze non-reference object '$value'" );
	}

	return Storable::nfreeze( $value );
}

sub thaw
{
	my( $class, $session, $value ) = @_;

	return Storable::thaw( $value );
}

sub render_value
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

	if( defined $self->{render_value} )
	{
		return $self->call_property( "render_value", 
			$session, 
			$self, 
			$value, 
			$alllangs, 
			$nolink,
			$object );
	}

	local $Data::Dumper::Terse = 1;

	return $session->make_text( Data::Dumper::Dumper( $value ) );
}

sub ordervalue
{
	return "";
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

