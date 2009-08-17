######################################################################
#
# EPrints::MetaField::Longtext;
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
	my( $self, $handle ) = @_;

	return $handle->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_LONGVARCHAR,
		!$self->get_property( "allow_null" ),
		undef,
		undef,
		$self->get_sql_properties,
	);
}

# never SQL index this type
sub get_sql_index
{
	my( $self ) = @_;

	return ();
}



sub render_single_value
{
	my( $self, $handle, $value ) = @_;
	
#	my @paras = split( /\r\n\r\n|\r\r|\n\n/ , $value );
#
#	my $frag = $handle->make_doc_fragment();
#	foreach( @paras )
#	{
#		my $p = $handle->make_element( "p" );
#		$p->appendChild( $handle->make_text( $_ ) );
#		$frag->appendChild( $p );
#	}
#	return $frag;

	return $handle->make_text( $value );
}

sub get_basic_input_elements
{
	my( $self, $handle, $value, $basename, $staff, $obj ) = @_;

	my $textarea = $handle->make_element(
		"textarea",
		name => $basename,
		id => $basename,
		rows => $self->{input_rows},
		cols => $self->{input_cols},
		wrap => "virtual" );
	$textarea->appendChild( $handle->make_text( $value ) );

	return [ [ { el=>$textarea } ] ];
}


sub form_value_basic
{
	my( $self, $handle, $basename ) = @_;

	# this version is just like that for Basic except it
	# does not remove line breaks.
	
	my $value = $handle->param( $basename );

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
	$defaults{maxlength} = 16384; # 2^16 / 4 (safely store UTF-8)
	return %defaults;
}

sub get_xml_schema_type
{
	return "xs:string";
}

sub render_xml_schema_type
{
	my( $self, $handle ) = @_;

	return $handle->make_doc_fragment;
}


######################################################################
1;
