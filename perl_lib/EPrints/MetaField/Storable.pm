######################################################################
#
# EPrints::MetaField::Storable;
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

B<EPrints::MetaField::Storable> - serialise/unserialise Perl structures

=head1 DESCRIPTION

This field supports arbitrary Perl data structures by serialising them using L<Storable>, upto the length of L<EPrints::MetaField::Longtext>.

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

sub to_xml_basic
{
	my( $self, $session, $value, $dataset, %opts ) = @_;

	return $self->SUPER::to_xml_basic( $session, MIME::Base64::encode_base64($self->freeze( $session, $value )), $dataset, %opts );
}

# return epdata for a single value of this field
sub xml_to_epdata_basic
{
	my( $self, $session, $xml, %opts ) = @_;

	return $self->thaw( $session, MIME::Base64::decode_base64( $self->SUPER::xml_to_epdata_basic( $session, $xml, %opts ) ) );
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
	my( $self, $session, $value ) = @_;

	local $Data::Dumper::Terse = 1;

	return $session->make_text( Data::Dumper::Dumper( $value ) );
}

sub ordervalue
{
	return "";
}

######################################################################
1;
