######################################################################
#
# EPrints::MetaField::Int;
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

B<EPrints::MetaField::Int> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Int;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;



sub get_sql_type
{
	my( $self, $handle ) = @_;

	return $handle->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_INTEGER,
		!$self->get_property( "allow_null" ),
		undef,
		undef,
		$self->get_sql_properties,
	);
}

sub get_max_input_size
{
	my( $self ) = @_;

	return $self->get_property( "digits" );
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	unless( EPrints::Utils::is_set( $value ) )
	{
		return "";
	}

	# just in case we still use eprints in year 200k 
	my $pad = $self->get_property( "digits" );
	return sprintf( "%0".$pad."d",$value );
}

sub render_search_input
{
	my( $self, $handle, $searchfield ) = @_;
	
	return $handle->render_input_field(
				class => "ep_form_text",
				name=>$searchfield->get_form_prefix,
				value=>$searchfield->get_value,
				size=>9,
				maxlength=>100 );
}

sub from_search_form
{
	my( $self, $handle, $prefix ) = @_;

	my $val = $handle->param( $prefix );
	return unless defined $val;

	my $number = '[0-9]+\.?[0-9]*';

	if( $val =~ m/^($number)?\-?($number)?/ )
	{
		return( $val );
	}
			
	return( undef,undef,undef, $handle->html_phrase( "lib/searchfield:int_err" ) );
}

sub render_search_value
{
	my( $self, $handle, $value ) = @_;

	my $type = $self->get_type;

	my $number = '[0-9]+\.?[0-9]*';

	if( $value =~ m/^($number)-($number)$/ )
	{
		return $handle->html_phrase(
			"lib/searchfield:desc_".$type."_between",
			from => $handle->make_text( $1 ),
			to => $handle->make_text( $2 ) );
	}

	if( $value =~ m/^-($number)$/ )
	{
		return $handle->html_phrase(
			"lib/searchfield:desc_".$type."_orless",
			to => $handle->make_text( $1 ) );
	}

	if( $value =~ m/^($number)-$/ )
	{
		return $handle->html_phrase(
			"lib/searchfield:desc_".$type."_ormore",
			from => $handle->make_text( $1 ) );
	}

	return $handle->make_text( $value );
}

sub get_search_conditions_not_ex
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	# N
	# N-
	# -N
	# N-N

	my $number = '[0-9]+\.?[0-9]*';

	if( $search_value =~ m/^$number$/ )
	{
		return EPrints::Search::Condition->new( 
			'=', 
			$dataset,
			$self, 
			$search_value );
	}

	unless( $search_value=~ m/^($number)?\-($number)?$/ )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	my @r = ();
	if( defined $1 && $1 ne "" )
	{
		push @r, EPrints::Search::Condition->new( 
				'>=',
				$dataset,
				$self,
				$1);
	}

	if( defined $2 && $2 ne "" )
	{
		push @r, EPrints::Search::Condition->new( 
				'<=',
				$dataset,
				$self,
				$2 );
	}

	if( scalar @r == 1 ) { return $r[0]; }
	if( scalar @r == 0 )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	return EPrints::Search::Condition->new( "AND", @r );
}

sub get_search_group { return 'number'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{digits} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{text_index} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	return "xs:integer";
}

sub render_xml_schema_type
{
	my( $self, $handle ) = @_;

	return $handle->make_doc_fragment;
}

######################################################################
1;
