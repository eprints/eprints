######################################################################
#
# EPrints::MetaField::Email;
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

B<EPrints::MetaField::Email> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Email;

use strict;
use warnings;

use EPrints::MetaField::Text;
our @ISA = qw( EPrints::MetaField::Text );

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 0;
	$defaults{sql_index} = 1;
	return %defaults;
}

sub render_search_value
{
	my( $self, $session, $value ) = @_;

	my $valuedesc = $session->make_doc_fragment;
	$valuedesc->appendChild( $session->make_text( '"' ) );
	$valuedesc->appendChild( $session->make_text( $value ) );
	$valuedesc->appendChild( $session->make_text( '"' ) );

	return $valuedesc;
}

sub from_search_form
{
	my( $self, $session, $basename ) = @_;

	# complex text types

	my $val = $session->param( $basename );
	return unless defined $val;

	my $search_type = $session->param( $basename."_merge" );
	my $search_match = $session->param( $basename."_match" );
		
	# Default search type if none supplied (to allow searches 
	# using simple HTTP GETs)
	$search_type = "ALL" unless defined( $search_type );
	$search_match = "EX" unless defined( $search_match );
		
	return unless( defined $val );

	return( $val, $search_type, $search_match );	
}		

sub render_single_value
{
	my( $self, $session, $value ) = @_;
	
	my $text = $session->make_text( $value );

	return $text if !defined $value;
	return $text if( $self->{render_dont_link} );

	my $a = $session->render_link( "mailto:".$value );
	$a->appendChild( $text );
	return $a;
}

######################################################################
1;
