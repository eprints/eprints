######################################################################
#
# EPrints::MetaField::Float;
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

B<EPrints::MetaField::Float> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Float;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Int );
}

use EPrints::MetaField::Int;

# does not yet support searching.

sub get_sql_type
{
	my( $self, $session, $notnull ) = @_;

	return $session->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_REAL,
		$notnull
	);
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	unless( EPrints::Utils::is_set( $value ) )
	{
		return "";
	}

	return sprintf( "%020f", $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	return "xs:double";
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	return $session->make_doc_fragment;
}

######################################################################
1;
