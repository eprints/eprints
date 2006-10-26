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

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." TEXT".($notnull?" NOT NULL":"");
}

# never SQL index this type
sub get_sql_index
{
	my( $self ) = @_;

	return undef;
}


sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $searchexp = $self->make_searchexp( $session, $value );
	my $desc = $searchexp->render_description;
	$searchexp->dispose;
	return $desc;
}


######################################################################
# 
# $searchexp = $field->make_searchexp( $session, $value, [$basename] )
#
# This method should only be called on fields of type "search". 
# Return a search expression from the serialised expression in value.
# $basename is passed to the Search to prefix all HTML form
# field ids when more than one search will exist in the same form. 
#
######################################################################

sub make_searchexp
{
	my( $self, $session, $value, $basename ) = @_;

	my $ds = $session->get_repository->get_dataset( 
			$self->{datasetid} );	

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $ds,
		prefix => $basename,
		fieldnames => $self->get_property( "fieldnames" ) );
	$searchexp->from_string( $value );

	return $searchexp;
}		

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	#cjg NOT CSS'd properly.

	my $div = $session->make_element( 
		"div", 
		style => "padding: 6pt; margin-left: 24pt; " );

	# cjg - make help an option?

	my $searchexp = $self->make_searchexp( 
		$session,
		$value,
		$basename."_" );
	$div->appendChild( $searchexp->render_search_fields( 0 ) );
	if( $self->get_property( "allow_set_order" ) )
	{
		$div->appendChild( $searchexp->render_order_menu );
	}
	$searchexp->dispose();

	return [ [ { el=>$div } ] ];
}


sub form_value_basic
{
	my( $self, $session, $basename ) = @_;
	
	my $ds = $session->get_repository->get_dataset( 
			$self->{datasetid} );	
	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $ds,
		prefix => $basename."_",
		fieldnames => $self->get_property( "fieldnames" ) );
	$searchexp->from_form;
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
	$defaults{allow_set_order} = 0;
	return %defaults;
}


######################################################################
1;
