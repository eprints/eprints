######################################################################
#
# EPrints::MetaField::Search;
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

B<EPrints::MetaField::Search> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# datasetid

package EPrints::MetaField::Search;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Longtext );
}

use EPrints::MetaField::Longtext;


sub render_single_value
{
	my( $self, $handle, $value ) = @_;

	my $searchexp = $self->make_searchexp( $handle, $value );
	my $desc = $searchexp->render_description;
	$searchexp->dispose;
	return $desc;
}


######################################################################
# 
# $searchexp = $field->make_searchexp( $handle, $value, [$basename] )
#
# This method should only be called on fields of type "search". 
# Return a search expression from the serialised expression in value.
# $basename is passed to the Search to prefix all HTML form
# field ids when more than one search will exist in the same form. 
#
######################################################################

sub make_searchexp
{
	my( $self, $handle, $value, $basename ) = @_;

	my $ds = $handle->get_repository->get_dataset( 
			$self->{datasetid} );	
	my $fieldnames = $self->get_property( "fieldnames" );

	my $searchexp = EPrints::Search->new(
		handle => $handle,
		dataset => $ds,
		prefix => $basename,
		fieldnames => $fieldnames );

	# don't limit the deserialising unless there are fieldnames
	# defined.	
	if( defined $fieldnames )
	{
		$searchexp->from_string( $value );
	}
	else
	{
		$searchexp->from_string_raw( $value );
	}

	return $searchexp;
}		

sub get_basic_input_elements
{
	my( $self, $handle, $value, $basename, $staff, $obj ) = @_;

	#cjg NOT CSS'd properly.

	my $div = $handle->make_element( 
		"div", 
		style => "padding: 6pt; margin-left: 24pt; " );

	# cjg - make help an option?

	my $searchexp = $self->make_searchexp( 
		$handle,
		$value,
		$basename."_" );

	foreach my $sf ( $searchexp->get_non_filter_searchfields )
	{
		my $sfdiv = $handle->make_element( 
				"div" , 
				class => "ep_search_field_name" );
		$sfdiv->appendChild( $sf->render_name );
		$div->appendChild( $sfdiv );
		$div->appendChild( $sf->render() );
	}

	$searchexp->dispose();

	return [ [ { el=>$div } ] ];
}


sub form_value_basic
{
	my( $self, $handle, $basename ) = @_;
	
	my $ds = $handle->get_repository->get_dataset( 
			$self->{datasetid} );	
	my $searchexp = EPrints::Search->new(
		handle => $handle,
		dataset => $ds,
		prefix => $basename."_",
		fieldnames => $self->get_property( "fieldnames" ) );

	foreach my $sf ( $searchexp->get_non_filter_searchfields )
	{
		$sf->from_form();
	}

	foreach my $sf ( $searchexp->get_non_filter_searchfields )
	{
		$sf->from_form;
	}
	my $value = undef;
	unless( $searchexp->is_blank )
	{
		$value = $searchexp->serialise;	
	}
	$searchexp->dispose();

	return $value;
}

sub get_search_group { return 'search'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	$defaults{fieldnames} = $EPrints::MetaField::UNDEF;;
	return %defaults;
}


######################################################################
1;
