######################################################################
#
# EPrints::MetaField::Longtext;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Longtext> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Longtext;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub get_sql_type
{
	my( $self, $session ) = @_;

	return $session->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_CLOB,
		!$self->get_property( "allow_null" ),
		undef,
		undef,
		$self->get_sql_properties,
	);
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;
	
	return $session->make_text( $value );
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my @classes = defined $self->{dataset} ?
		join('_', 'ep', $self->dataset->base_id, $self->name) :
		();
	my $textarea = $session->make_element(
		"textarea",
		name => $basename,
		id => $basename,
		class => join(' ', @classes),
		rows => $self->{input_rows},
		cols => $self->{input_cols},
		wrap => "virtual" );
	$textarea->appendChild( $session->make_text( $value ) );

	return [ [ { el=>$textarea } ] ];
}


sub form_value_basic
{
	my( $self, $session, $basename ) = @_;

	# this version is just like that for Basic except it
	# does not remove line breaks.
	
	my $value = $session->param( $basename );

	return undef if( !defined($value) or $value eq "" );

	return $value;
}

sub is_browsable
{
	return( 1 );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_rows} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{maxlength} = 65535;
	$defaults{sql_index} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	return "xs:string";
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	return $session->make_doc_fragment;
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

